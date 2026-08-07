import 'dart:async';

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
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  WorkoutTimerService.init();
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
    await FlutterForegroundTask.requestNotificationPermission();
  }
  await NotificationService.init();
  await LocalWorkoutStore.init();

  runApp(const PRRoot());
}

/// Recrea el `ProviderScope` entero cada vez que cambia el usuario autenticado.
///
/// En Riverpod 3 los providers **no** son auto-dispose por defecto
/// (`FutureProvider(... isAutoDispose: false)`), así que un `FutureProvider` ya
/// resuelto conserva su valor mientras viva el scope. Como `signOut()` no
/// invalida nada, al entrar con otra cuenta las rutinas, mediciones e historial
/// del usuario anterior seguían en caché y se mostraban como si fueran del
/// nuevo: la consulta ni siquiera se repetía.
///
/// Tirar el scope es preferible a invalidar provider por provider porque no hay
/// lista que mantener: cualquier feature que se agregue queda cubierta sola.
class PRRoot extends StatefulWidget {
  const PRRoot({super.key});

  @override
  State<PRRoot> createState() => _PRRootState();
}

class _PRRootState extends State<PRRoot> {
  StreamSubscription<AuthState>? _sub;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser?.id;
    // Solo importa el cambio de identidad: `onAuthStateChange` también emite en
    // cada refresco de token, y ahí la caché sigue siendo válida.
    _sub = supabase.auth.onAuthStateChange.listen((_) {
      final id = supabase.auth.currentUser?.id;
      if (id == _userId) return;
      setState(() => _userId = id);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey(_userId ?? '_anon'),
      child: const PRApp(),
    );
  }
}
