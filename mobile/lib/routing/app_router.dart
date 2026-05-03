import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import '../features/account/account_page.dart';
import '../features/home/home_page.dart';
import '../features/learn/article_detail_page.dart';
import '../features/history/history_page.dart';
import '../features/measurements/measurements_page.dart';
import '../features/learn/learn_page.dart';
import '../features/progress/progress_page.dart';
import '../features/routines/routine_detail_page.dart';
import '../features/routines/routines_page.dart';
import '../features/workout/workout_page.dart';
import '../shell/main_shell.dart';
import '../supabase/client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuthed = supabase.auth.currentSession != null;
      final isLogin = state.matchedLocation == '/login';
      if (!isAuthed && !isLogin) return '/login';
      if (isAuthed && isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/cuenta', builder: (_, _) => const AccountPage()),
      GoRoute(
        path: '/rutinas/:id',
        builder: (_, state) =>
            RoutineDetailPage(routineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/aprender/:slug',
        builder: (_, state) =>
            ArticleDetailPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/entrenar', builder: (_, _) => const WorkoutPage()),
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          GoRoute(path: '/rutinas', builder: (_, _) => const RoutinesPage()),
          GoRoute(path: '/aprender', builder: (_, _) => const LearnPage()),
          GoRoute(path: '/medidas', builder: (_, _) => const MeasurementsPage()),

          GoRoute(path: '/progreso', builder: (_, _) => const ProgressPage()),
          GoRoute(path: '/historial', builder: (_, _) => const HistoryPage()),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
