import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_providers.dart';
import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import '../workout/providers.dart';
import '../workout/workout_state.dart';

const _weekdayNames = [
  'DOMINGO', 'LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO',
];
const _monthNames = [
  'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
  'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
];
const _dayNamesTitle = [
  'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado',
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(routinesProvider);
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? '';
    final firstName = _firstNameFromEmail(email);
    final now = DateTime.now();
    final todayDow = now.weekday % 7;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final workoutState = ref.watch(workoutProvider);
    final hasActiveWorkout = workoutState.status == WorkoutStatus.active ||
        workoutState.status == WorkoutStatus.loading;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(routinesProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            _dateLabel(now),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            firstName.isEmpty ? 'Hola' : 'Hola, $firstName',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 24),
          if (hasActiveWorkout)
            _ActiveWorkoutBanner(routineName: workoutState.routineName)
          else
            asyncRoutines.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (routines) {
                final today =
                    routines.where((r) => r.dayOfWeek == todayDow).firstOrNull;
                if (today != null) {
                  return _TodayHero(routine: today, todayDow: todayDow);
                }
                return _EmptyHero(todayDow: todayDow);
              },
            ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({required this.routineName});
  final String routineName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'ENTRENAMIENTO EN CURSO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            routineName.isEmpty ? 'Cargando…' : routineName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.push('/entrenar'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continuar entrenamiento'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHero extends ConsumerWidget {
  const _TodayHero({required this.routine, required this.todayDow});
  final Routine routine;
  final int todayDow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final exCount = routine.exercises.length;
    final totalSets = routine.exercises.fold<int>(0, (a, e) => a + e.targetSets);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pill(
            text: 'RUTINA DE HOY · ${_dayNamesTitle[todayDow].toUpperCase()}',
            withDot: true,
          ),
          const SizedBox(height: 14),
          Text(
            routine.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$exCount ejercicios · $totalSets series',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: exCount == 0
                ? null
                : () {
                    ref.read(workoutProvider.notifier).start(routine);
                    context.push('/entrenar');
                  },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Empezar rutina'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.todayDow});
  final int todayDow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pill(text: 'HOY · ${_dayNamesTitle[todayDow].toUpperCase()}'),
          const SizedBox(height: 14),
          Text(
            'No tenés rutina asignada para hoy.',
            style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => context.go('/rutinas'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary),
            ),
            child: const Text('Elegir una rutina'),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.withDot = false});
  final String text;
  final bool withDot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: cs.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String _firstNameFromEmail(String email) {
  final local = email.split('@').first;
  if (local.isEmpty) return '';
  return local[0].toUpperCase() + local.substring(1);
}

String _dateLabel(DateTime d) {
  final dow = d.weekday % 7;
  final weekday = _weekdayNames[dow];
  final month = _monthNames[d.month - 1];
  return '$weekday, ${d.day} DE $month';
}
