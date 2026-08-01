import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../workout/providers.dart';
import 'data/routines_repository.dart';
import 'exercise_browser_page.dart';
import 'exercise_params_sheet.dart';
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

    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                  final routine = routines
                      .where((r) => r.id == routineId)
                      .firstOrNull;
                  if (routine == null) return null;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar',
                        onPressed: () => _showEditDialog(context, ref, routine),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.8),
                        ),
                        tooltip: 'Eliminar rutina',
                        onPressed: () => _confirmDelete(context, ref, routine),
                      ),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
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

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
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
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
          '"${routine.name}" y todos sus ejercicios serán eliminados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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

class _RoutineBody extends ConsumerStatefulWidget {
  const _RoutineBody({required this.routine});
  final Routine routine;

  @override
  ConsumerState<_RoutineBody> createState() => _RoutineBodyState();
}

class _RoutineBodyState extends ConsumerState<_RoutineBody> {
  /// Copia local para que el arrastre se vea al instante; el refetch del
  /// provider llega después y coincide con este orden.
  late List<RoutineExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = [...widget.routine.exercises];
  }

  @override
  void didUpdateWidget(covariant _RoutineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _exercises = [...widget.routine.exercises];
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    setState(() {
      final moved = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, moved);
    });
    await ref
        .read(routinesRepositoryProvider)
        .reorderExercises(_exercises.map((e) => e.id).toList());
    ref.invalidate(routinesProvider);
  }

  Future<void> _editExercise(RoutineExercise re) async {
    final ac = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ExerciseParamsSheet(
        exerciseName: re.exercise?.name ?? 'Ejercicio',
        initial: ExerciseParams(
          sets: re.targetSets,
          reps: re.targetReps,
          rest: re.restSeconds,
          weight: re.defaultWeight,
        ),
        onSave: (p) async {
          Navigator.pop(ctx);
          await ref
              .read(routinesRepositoryProvider)
              .updateExercise(
                re.id,
                sets: p.sets,
                reps: p.reps,
                rest: p.rest,
                weight: p.weight,
                clearWeight: p.weight == null,
              );
          ref.invalidate(routinesProvider);
        },
        onRemove: () {
          Navigator.pop(ctx);
          _confirmRemove(re);
        },
      ),
    );
  }

  Future<void> _confirmRemove(RoutineExercise re) async {
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
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(routinesRepositoryProvider).removeExercise(re.id);
    ref.invalidate(routinesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      buildDefaultDragHandles: false,
      onReorder: _onReorder,
      header: _RoutineHeader(
        routine: widget.routine,
        exerciseCount: _exercises.length,
      ),
      itemCount: _exercises.length,
      itemBuilder: (context, i) {
        final re = _exercises[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(re.id),
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExerciseRow(re: re, onTap: () => _editExercise(re)),
          ),
        );
      },
    );
  }
}

class _RoutineHeader extends ConsumerWidget {
  const _RoutineHeader({required this.routine, required this.exerciseCount});
  final Routine routine;
  final int exerciseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          routine.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statsLabel(routine),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.of(context).textMuted,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'DÍA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).textMuted,
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
            Text(
              'EJERCICIOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textMuted,
                letterSpacing: 1,
              ),
            ),
            Text(
              '$exerciseCount',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.of(context).textDisabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseBrowserPage(routineId: routine.id),
            ),
          ),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.of(context).bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                ...AppColors.of(context).raised(NeuroSize.sm),
                BoxShadow(color: kSeed.withValues(alpha: 0.10), blurRadius: 18),
              ],
              border: Border.all(
                color: kSeed.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: kSeed),
                SizedBox(width: 8),
                Text(
                  'Agregar ejercicio',
                  style: TextStyle(
                    color: kSeed,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (exerciseCount == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Todavía no hay ejercicios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.of(context).textDisabled,
                  height: 1.6,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Tocá un ejercicio para editarlo · mantené presionado para reordenar',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.of(context).textDisabled,
              ),
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
    final ac = AppColors.of(context);
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: active ? ac.pressed(NeuroSize.sm) : ac.raised(NeuroSize.sm),
        border: active
            ? Border.all(color: kSeed.withValues(alpha: 0.45), width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          fontSize: 12,
          color: active ? kSeed : ac.textMuted,
        ),
      ),
    );
  }
}

// ── Exercise row ──────────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.re, required this.onTap});
  final RoutineExercise re;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = re.exercise?.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: NeuroCard(
        size: NeuroSize.sm,
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: AppColors.of(
                  context,
                ).glassBorderBase.withValues(alpha: 0.06),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.fitness_center,
                          color: AppColors.of(context).textDisabled,
                          size: 20,
                        ),
                      )
                    : Icon(
                        Icons.fitness_center,
                        color: AppColors.of(context).textDisabled,
                        size: 20,
                      ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).textPrimary,
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
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Solo señal visual: el arrastre lo captura el listener que envuelve
            // la fila entera, igual que en la pantalla de entreno.
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: AppColors.of(context).textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtWeight(double w) =>
    w == w.truncateToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

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
  return '$exCount ej. · ~${minutes < 5 ? 5 : minutes} min';
}
