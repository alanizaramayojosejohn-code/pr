import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void workoutTimerEntryPoint() {
  FlutterForegroundTask.setTaskHandler(WorkoutTimerHandler());
}

class WorkoutTimerHandler extends TaskHandler {
  int _elapsed = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _elapsed = 0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _elapsed++;
    _updateNotif();
    FlutterForegroundTask.sendDataToMain(_elapsed);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  void _updateNotif() {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    FlutterForegroundTask.updateService(
      notificationText:
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
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
      callback: workoutTimerEntryPoint,
    );
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
}
