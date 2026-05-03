import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/workout/services/local_workout_store.dart';
import 'features/workout/services/notification_service.dart';
import 'features/workout/services/workout_timer_service.dart';
import 'supabase/client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  WorkoutTimerService.init();
  if (!kIsWeb) FlutterForegroundTask.initCommunicationPort();
  await NotificationService.init();
  await LocalWorkoutStore.init();

  runApp(const ProviderScope(child: PRApp()));
}
