import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'notification_service.dart';

/// Claves persistidas por [FlutterForegroundTask.saveData] (SharedPreferences).
///
/// Android puede matar y recrear el servicio en cualquier momento; cuando lo
/// hace, `onStart` vuelve a correr sobre un handler nuevo. Guardar estos tres
/// datos en disco es lo que permite que el cronómetro continúe en vez de
/// reiniciarse en 00:00.
const _kStartedAt = 'workout_started_at';
const _kRestEndsAt = 'workout_rest_ends_at';
const _kRoutineName = 'workout_routine_name';

int get _nowMs => DateTime.now().millisecondsSinceEpoch;

@pragma('vm:entry-point')
void workoutTimerEntryPoint() {
  FlutterForegroundTask.setTaskHandler(WorkoutTimerHandler());
}

class WorkoutTimerHandler extends TaskHandler {
  /// Epoch ms. Toda la cuenta se deriva de estos dos instantes, nunca de un
  /// contador incremental: si Android congela el proceso o se salta ticks, al
  /// siguiente tick el cálculo se pone al día solo.
  int _startedAt = 0;
  int _restEndsAt = 0;

  String _routineName = '';
  bool _restAlertSent = true;

  // Última notificación publicada, para no llamar a updateService cada segundo
  // si el texto no cambió.
  String _lastTitle = '';
  String _lastText = '';
  bool _lastResting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startedAt = await FlutterForegroundTask.getData<int>(key: _kStartedAt) ?? 0;
    _restEndsAt =
        await FlutterForegroundTask.getData<int>(key: _kRestEndsAt) ?? 0;
    _routineName =
        await FlutterForegroundTask.getData<String>(key: _kRoutineName) ?? '';

    if (_startedAt == 0) {
      _startedAt = timestamp.millisecondsSinceEpoch;
      await FlutterForegroundTask.saveData(key: _kStartedAt, value: _startedAt);
    }

    // Si el descanso venció mientras el servicio estaba muerto, no avises tarde:
    // un "descanso terminado" cinco minutos después confunde más que ayuda.
    _restAlertSent = _restEndsAt == 0 || _nowMs >= _restEndsAt;

    // El isolate del servicio tiene su propia instancia del plugin de
    // notificaciones y hay que inicializarla aquí.
    await NotificationService.init();
    _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;

    final name = data['routineName'];
    if (name is String) {
      _routineName = name;
      FlutterForegroundTask.saveData(key: _kRoutineName, value: name);
    }

    final startedAt = data['startedAt'];
    if (startedAt is int) {
      _startedAt = startedAt;
      FlutterForegroundTask.saveData(key: _kStartedAt, value: startedAt);
    }

    // Segundos de descanso; 0 lo cancela.
    final rest = data['rest'];
    if (rest is int) {
      _restEndsAt = rest > 0 ? _nowMs + rest * 1000 : 0;
      _restAlertSent = rest <= 0;
      FlutterForegroundTask.saveData(key: _kRestEndsAt, value: _restEndsAt);
    }

    // Refleja el cambio ya, sin esperar al siguiente segundo.
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({'action': id});
  }

  void _tick() {
    final now = _nowMs;
    final elapsed = _startedAt > 0 ? (now - _startedAt) ~/ 1000 : 0;

    var restRemaining = 0;
    if (_restEndsAt > 0) {
      final remainingMs = _restEndsAt - now;
      restRemaining = remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;

      if (restRemaining == 0 && !_restAlertSent) {
        _restAlertSent = true;
        _restEndsAt = 0;
        FlutterForegroundTask.saveData(key: _kRestEndsAt, value: 0);
        // Se dispara desde aquí, no desde el isolate principal: este isolate
        // sigue vivo con la app en segundo plano, el otro no.
        NotificationService.showRestDone();
      }
    }

    _updateNotif(elapsed, restRemaining);
    FlutterForegroundTask.sendDataToMain({
      'elapsed': elapsed,
      'restRemaining': restRemaining,
      'startedAt': _startedAt,
    });
  }

  void _updateNotif(int elapsed, int restRemaining) {
    final isResting = restRemaining > 0;
    final title = _routineName.isNotEmpty
        ? '$_routineName · ${_formatClock(elapsed)}'
        : _formatClock(elapsed);
    final text = isResting ? 'Descanso: ${restRemaining}s' : 'Entrenando';

    if (title == _lastTitle && text == _lastText && isResting == _lastResting) {
      return;
    }
    _lastTitle = title;
    _lastText = text;
    _lastResting = isResting;

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      // Hay que reenviar los botones en cada update o desaparecen.
      notificationButtons: isResting
          ? const [NotificationButton(id: 'skip_rest', text: 'Siguiente serie')]
          : const [
              NotificationButton(id: 'complete_set', text: 'Completar serie')
            ],
    );
  }
}

String _formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

class WorkoutTimerService {
  static void init() {
    if (kIsWeb) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // El id cambia a v3 a propósito: los ajustes de un canal son inmutables
        // una vez creado, así que la única forma de bajar la importancia en
        // instalaciones existentes es estrenar canal.
        channelId: 'workout_timer_v3',
        channelName: 'Cronómetro de entrenamiento',
        channelDescription: 'Mantiene el cronómetro corriendo en segundo plano',
        // LOW + onlyAlertOnce: esta notificación se refresca cada segundo, no
        // debe intentar alertar en cada tick.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  /// Arranca (o reapunta) el servicio. Devuelve `true` si quedó corriendo.
  ///
  /// [startedAt] debe ser el inicio real de la sesión, no "ahora": al restaurar
  /// una sesión guardada el cronómetro tiene que continuar donde iba.
  static Future<bool> start(String routineName, DateTime startedAt) async {
    if (kIsWeb) return false;
    final startedAtMs = startedAt.millisecondsSinceEpoch;

    // Se persiste antes de arrancar para que onStart lo encuentre ya escrito.
    await FlutterForegroundTask.saveData(key: _kStartedAt, value: startedAtMs);
    await FlutterForegroundTask.saveData(key: _kRoutineName, value: routineName);
    await FlutterForegroundTask.saveData(key: _kRestEndsAt, value: 0);

    if (await FlutterForegroundTask.isRunningService) {
      // Servicio superviviente de una sesión anterior: reapuntarlo a ésta, en
      // vez de dejarlo mostrando la rutina vieja como hacía el `return` previo.
      FlutterForegroundTask.sendDataToTask({
        'routineName': routineName,
        'startedAt': startedAtMs,
        'rest': 0,
      });
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.health],
      notificationTitle: routineName,
      notificationText: '00:00',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.alanizjose.pr.NOTIFICATION_ICON',
      ),
      notificationButtons: const [
        NotificationButton(id: 'complete_set', text: 'Completar serie'),
      ],
      callback: workoutTimerEntryPoint,
    );

    if (result is ServiceRequestFailure) {
      debugPrint('WorkoutTimerService.start falló: ${result.error}');
      return false;
    }

    FlutterForegroundTask.sendDataToTask({
      'routineName': routineName,
      'startedAt': startedAtMs,
    });
    return true;
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    await FlutterForegroundTask.removeData(key: _kStartedAt);
    await FlutterForegroundTask.removeData(key: _kRestEndsAt);
    await FlutterForegroundTask.removeData(key: _kRoutineName);
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }

  static void addTickListener(void Function(Object) callback) {
    if (kIsWeb) return;
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  static void removeTickListener(void Function(Object) callback) {
    if (kIsWeb) return;
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  static void startRest(int seconds) {
    if (kIsWeb) return;
    FlutterForegroundTask.sendDataToTask({'rest': seconds});
  }

  static void cancelRest() {
    if (kIsWeb) return;
    FlutterForegroundTask.sendDataToTask({'rest': 0});
  }

  /// En Xiaomi, Oppo, Huawei y similares la optimización de batería mata el
  /// servicio a los pocos minutos con la pantalla apagada. Se pide una vez; si
  /// el usuario ya lo concedió, Android no vuelve a mostrar el diálogo.
  static Future<void> ensureBatteryExemption() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) return;
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (e) {
      debugPrint('No se pudo pedir la exención de batería: $e');
    }
  }
}
