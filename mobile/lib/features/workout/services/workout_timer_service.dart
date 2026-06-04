import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void workoutTimerEntryPoint() {
  FlutterForegroundTask.setTaskHandler(WorkoutTimerHandler());
}

class WorkoutTimerHandler extends TaskHandler {
  int _elapsed = 0;
  int _restRemaining = 0;
  String _routineName = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _elapsed = 0;
    _restRemaining = 0;
    _routineName = '';
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final name = data['routineName'];
      if (name is String) _routineName = name;
      final rest = data['rest'];
      if (rest is int) _restRemaining = rest;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _elapsed++;
    if (_restRemaining > 0) _restRemaining--;
    _updateNotif();
    FlutterForegroundTask.sendDataToMain(
        {'elapsed': _elapsed, 'restRemaining': _restRemaining});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({'action': id});
  }

  void _updateNotif() {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    final elapsed =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final isResting = _restRemaining > 0;

    // El título siempre incluye el cronómetro para que sea visible
    // incluso con la notificación colapsada.
    final title = _routineName.isNotEmpty ? '$_routineName · $elapsed' : elapsed;
    final text =
        isResting ? 'Descanso: ${_restRemaining}s' : 'Entrenando';
    final buttons = isResting
        ? [NotificationButton(id: 'skip_rest', text: 'Siguiente serie')]
        : [NotificationButton(id: 'complete_set', text: 'Completar serie')];

    // Siempre pasa notificationButtons para que no desaparezcan entre ticks.
    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationButtons: buttons,
    );
  }
}

class WorkoutTimerService {
  static void init() {
    if (kIsWeb) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_timer_v2',
        channelName: 'Cronómetro de entrenamiento',
        channelDescription: 'Keeps workout timer running in background',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
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

  static Future<void> start(String routineName) async {
    if (kIsWeb) return;
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.health],
      notificationTitle: routineName,
      notificationText: '00:00',
      notificationButtons: [
        NotificationButton(id: 'complete_set', text: 'Completar serie'),
      ],
      callback: workoutTimerEntryPoint,
    );
    // Envía el nombre de la rutina al handler para que lo use en el título.
    FlutterForegroundTask.sendDataToTask({'routineName': routineName});
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
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
}
