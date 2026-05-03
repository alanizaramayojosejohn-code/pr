import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
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
    await _plugin.show(
      id: 42,
      title: 'Descanso terminado',
      body: 'Siguiente serie lista',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_done_v2',
          'Aviso de descanso',
          channelDescription: 'Avisa cuando termina el descanso entre series',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
          visibility: NotificationVisibility.public,
          autoCancel: true,
        ),
      ),
    );
  }
}
