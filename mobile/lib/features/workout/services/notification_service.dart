import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Idempotente a propósito: se llama desde `main()` y también desde el isolate
  /// del foreground service, que tiene su propia copia de esta clase.
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_workout'),
      ),
    );
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showRestDone() async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: 42,
      title: 'Descanso terminado',
      body: 'Siguiente serie lista',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          // Canal nuevo: la importancia de uno existente no se puede subir
          // desde la app una vez creado.
          'rest_done_v3',
          'Aviso de descanso',
          channelDescription: 'Avisa cuando termina el descanso entre series',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
          // category + usage de alarma: es lo que hace que se oiga en el
          // gimnasio con música puesta y que Doze no lo silencie. Si resulta
          // demasiado agresivo, bajar a AudioAttributesUsage.notification.
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          visibility: NotificationVisibility.public,
          autoCancel: true,
          // Se retira sola: pasado un minuto ya no aporta nada.
          timeoutAfter: 60000,
        ),
      ),
    );
  }
}
