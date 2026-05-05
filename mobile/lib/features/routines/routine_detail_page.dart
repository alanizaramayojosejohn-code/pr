import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../workout/providers.dart';
import 'data/routines_repository.dart';
import 'exercise_browser_page.dart';
import 'providers.dart';
import 'routine_form_page.dart';

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
      backgroundColor: kBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/rutinas'),
        ),
        title: const Text('Rutina'),
        actions: [
          asyncRoutines.whenOrNull(
            data: (routines) {
              final routine =
                  routines.where((r) => r.id == routineId).firstOrNull;
              if (routine == null) return null;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Editar',
                    onPressed: () =>
                        _showEditDialog(context, ref, routine),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.8)),
                    tooltip: 'Eliminar rutina',
                    onPressed: () =>
                        _confirmDelete(context, ref, routine),
                  ),
                ],
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: AppGradient(
        child: asyncRoutines.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (routines) {
            final routine =
                routines.where((r) => r.id == routineId).firstOrNull;
            if (routine == null) {
              return const Center(child: Text('Rutina no encontrada'));
            }
            return _RoutineBody(routine: routine);
          },
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Routine routine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoutineFormPage(
          title: 'Editar rutina',
          initialName: routine.name,
          initialDays: routine.daysOfWeek,
          onSave: (name, days) async {
            final repo = ref.read(routinesRepositoryProvider);
            await repo.updateRoutine(routine.id, {
              'name': name,
              'days_of_week': days,
            });
            ref.invalidate(routinesProvider);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
            '"${routine.name}" y todos sus ejercicios serán eliminados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final repo = ref.read(routinesRepositoryProvider);
      await repo.deleteRoutine(routine.id);
      ref.invalidate(routinesProvider);
      if (context.mounted) context.go('/rutinas');
    }
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _RoutineBody extends ConsumerWidget {
  const _RoutineBody({required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          routine.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xF2FFFFFF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statsLabel(routine),
          style: const TextStyle(fontSize: 13, color: Color(0x80FFFFFF)),
        ),
        const SizedBox(height: 20),
        const Text(
          'DÍA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0x80FFFFFF),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final p in _dayPills) ...[
              Expanded(
                child: _DayPill(
                  label: p.short,
                  active: routine.daysOfWeek.contains(p.value),
                ),
              ),
              if (p != _dayPills.last) const SizedBox(width: 5),
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
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'EJERCICIOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0x80FFFFFF),
                letterSpacing: 1,
              ),
            ),
            Text(
              '${routine.exercises.length}',
              style: const TextStyle(fontSize: 11, color: Color(0x66FFFFFF)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ExerciseBrowserPage(routineId: routine.id),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar ejercicio'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: kSeed.withValues(alpha: 0.15),
            foregroundColor: kSeed,
          ),
        ),
        const SizedBox(height: 10),
        if (routine.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Todavía no hay ejercicios.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0x66FFFFFF), height: 1.6, fontSize: 13),
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

// ── Day pill ──────────────────────────────────────────────────────────────────

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? kSeed.withValues(alpha: 0.18) : kGlassFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? kSeed.withValues(alpha: 0.5) : kGlassBorder,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
          color: active ? kSeed : const Color(0x80FFFFFF),
        ),
      ),
    );
  }
}

// ── Exercise row ──────────────────────────────────────────────────────────────

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({required this.re});
  final RoutineExercise re;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = re.exercise?.imageUrl;

    return GlassCard(
      radius: 12,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: kGlassFill,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                          Icons.fitness_center,
                          color: Color(0x66FFFFFF),
                          size: 20),
                    )
                  : const Icon(Icons.fitness_center,
                      color: Color(0x66FFFFFF), size: 20),
            ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xF2FFFFFF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    '${re.targetSets} × ${re.targetReps}',
                    if (re.defaultWeight != null)
                      '${_fmtWeight(re.defaultWeight!)} kg',
                    '${re.restSeconds}s descanso',
                  ].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0x80FFFFFF)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                size: 20,
                color: Colors.white.withValues(alpha: 0.3)),
            onPressed: () => _removeExercise(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _removeExercise(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar ejercicio?'),
        content: Text(re.exercise?.name ?? 'Este ejercicio'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.error),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(routinesRepositoryProvider);
      await repo.removeExercise(re.id);
      ref.invalidate(routinesProvider);
    }
  }
}

String _fmtWeight(double w) =>
    w == w.truncateToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String _statsLabel(Routine r) {
  final exCount = r.exercises.length;
  if (exCount == 0) return 'Sin ejercicios';
  final totalSets = r.exercises.fold<int>(0, (a, e) => a + e.targetSets);
  final totalRest =
      r.exercises.fold<int>(0, (a, e) => a + e.targetSets * e.restSeconds);
  final raw = (totalSets * 30 + totalRest) / 60;
  final minutes = (raw / 5).round() * 5;
  return '$exCount ej. · ~${minutes < 5 ? 5 : minutes} min';
}
