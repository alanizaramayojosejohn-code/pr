import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../workout/providers.dart';
import 'data/routines_repository.dart';
import 'providers.dart';

const _dayPills = [
  (value: null, short: '—'),
  (value: 1, short: 'L'),
  (value: 2, short: 'M'),
  (value: 3, short: 'X'),
  (value: 4, short: 'J'),
  (value: 5, short: 'V'),
  (value: 6, short: 'S'),
  (value: 0, short: 'D'),
];

class RoutineDetailPage extends ConsumerWidget {
  const RoutineDetailPage({super.key, required this.routineId});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/rutinas'),
        ),
        title: const Text('Rutina'),
      ),
      body: asyncRoutines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (routines) {
          final routine = routines.where((r) => r.id == routineId).firstOrNull;
          if (routine == null) {
            return const Center(child: Text('Rutina no encontrada'));
          }
          return _RoutineBody(routine: routine);
        },
      ),
    );
  }
}

class _RoutineBody extends ConsumerWidget {
  const _RoutineBody({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          routine.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statsLabel(routine),
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text(
          'DÍA',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final pill in _dayPills) ...[
              Expanded(child: _DayPill(label: pill.short, active: routine.dayOfWeek == pill.value)),
              if (pill != _dayPills.last) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: routine.exercises.isEmpty
              ? null
              : () {
                  ref.read(workoutProvider.notifier).start(routine);
                  context.push('/entrenar');
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Empezar entreno'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(height: 24),
        if (routine.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Esta rutina no tiene ejercicios.',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...routine.exercises.map(
            (re) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExerciseRow(re: re),
            ),
          ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? cs.primary : cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.re});
  final RoutineExercise re;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imageUrl = re.exercise?.imageUrl;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.fitness_center, size: 22, color: cs.onSurfaceVariant),
                  )
                : Icon(Icons.fitness_center, size: 22, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  re.exercise?.name ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${re.targetSets} × ${re.targetReps}  ·  ${re.restSeconds}s',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statsLabel(Routine r) {
  final exCount = r.exercises.length;
  if (exCount == 0) return 'Sin ejercicios';
  final totalSets = r.exercises.fold<int>(0, (a, e) => a + e.targetSets);
  final totalRest = r.exercises.fold<int>(
    0,
    (a, e) => a + e.targetSets * e.restSeconds,
  );
  final raw = (totalSets * 30 + totalRest) / 60;
  final minutes = (raw / 5).round() * 5;
  final shown = minutes < 5 ? 5 : minutes;
  return '$exCount ej. · ~$shown min';
}
