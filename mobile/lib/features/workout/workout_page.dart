import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../routines/exercise_browser_page.dart';
import 'pr_detector.dart';
import 'providers.dart';
import 'workout_state.dart';

class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  Future<void> _onCancel() async {
    final ws = ref.read(workoutProvider);
    if (ws.doneSetCount == 0) {
      ref.read(workoutProvider.notifier).endSession();
      if (mounted) context.go('/');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del entreno?'),
        content: Text(
          'Completaste ${ws.doneSetCount} '
          '${ws.doneSetCount == 1 ? 'serie' : 'series'}. '
          'El progreso quedará sin finalizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quedarme'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(workoutProvider.notifier).endSession();
      context.go('/');
    }
  }

  Future<void> _onFinish() async {
    final ws = ref.read(workoutProvider);
    if (!ws.allDone) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Finalizar entreno?'),
          content: const Text(
            'Todavía hay series sin completar. ¿Finalizar de todas formas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(workoutProvider.notifier).finish();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar: $e')),
        );
      }
    }
  }

  void _showPRDialog(PendingPR pr) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 550),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => _PRDialog(
        pr: pr,
        onContinue: () {
          Navigator.of(ctx).pop();
          ref.read(workoutProvider.notifier).clearPR();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorkoutState>(workoutProvider, (prev, next) {
      if (next.pendingPR != null && prev?.pendingPR == null && mounted) {
        _showPRDialog(next.pendingPR!);
      }
    });

    final ws = ref.watch(workoutProvider);
    final ac = AppColors.of(context);

    if (ws.status == WorkoutStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ac.overlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onCancel();
        },
        child: Scaffold(
          backgroundColor: ac.bg,
          body: SafeArea(
            child: Column(
              children: [
                _Header(ws: ws, onCancel: _onCancel, onFinish: _onFinish),
                if (ws.restTimer != null)
                  _RestBanner(
                    rt: ws.restTimer!,
                    onAdjust: (d) =>
                        ref.read(workoutProvider.notifier).adjustRest(d),
                    onSkip: () =>
                        ref.read(workoutProvider.notifier).skipRest(),
                  ),
                Expanded(
                  child: switch (ws.status) {
                    WorkoutStatus.loading =>
                      const Center(child: CircularProgressIndicator()),
                    WorkoutStatus.done => _DoneView(
                        ws: ws,
                        onEnd: () {
                          ref.read(workoutProvider.notifier).endSession();
                          context.go('/');
                        },
                      ),
                    _ => ws.exercises.isEmpty
                        ? Center(
                            child: Text(
                              'Esta rutina no tiene ejercicios.',
                              style: TextStyle(color: ac.textMuted),
                            ),
                          )
                        : _ActiveWorkout(ws: ws),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.ws,
    required this.onCancel,
    required this.onFinish,
  });
  final WorkoutState ws;
  final VoidCallback onCancel;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final totalSets =
        ws.exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final canFinish = ws.status == WorkoutStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ac.bg,
        boxShadow: [
          BoxShadow(
              color: ac.shadowSh, blurRadius: 8, offset: const Offset(0, 4)),
          BoxShadow(
              color: ac.shadowHi, blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ac.bg,
                shape: BoxShape.circle,
                boxShadow: ac.raised(NeuroSize.sm),
              ),
              child:
                  Icon(Icons.close, size: 18, color: ac.textPrimary),
            ),
          ),
          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ws.routineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ac.textPrimary,
                  ),
                ),
                if (ws.status == WorkoutStatus.active)
                  Text(
                    '${ws.elapsedLabel}  ·  ${ws.doneSetCount}/$totalSets series',
                    style:
                        TextStyle(fontSize: 11, color: ac.textMuted),
                  ),
              ],
            ),
          ),
          // Finish button
          GestureDetector(
            onTap: canFinish ? onFinish : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ac.bg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: canFinish
                    ? [
                        ...ac.raised(NeuroSize.sm),
                        BoxShadow(
                            color: kSeed.withValues(alpha: 0.12),
                            blurRadius: 12),
                      ]
                    : ac.pressed(NeuroSize.sm),
              ),
              child: Text(
                'Finalizar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: canFinish ? kSeed : ac.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rest Banner ──────────────────────────────────────────────────────────────

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.rt,
    required this.onAdjust,
    required this.onSkip,
  });
  final RestTimerState rt;
  final void Function(int) onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      color: ac.bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DESCANSO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: ac.textMuted,
                ),
              ),
              Text(
                rt.label,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: kSeed,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Neuro inset progress track
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: ac.bg,
              borderRadius: BorderRadius.circular(4),
              boxShadow: ac.pressed(NeuroSize.sm),
            ),
            clipBehavior: Clip.hardEdge,
            child: LayoutBuilder(
              builder: (_, constraints) => Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * rt.progress,
                    decoration: BoxDecoration(
                      color: kSeed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RestPill(label: '−15s', onTap: () => onAdjust(-15)),
              const SizedBox(width: 8),
              _RestPill(label: '+15s', onTap: () => onAdjust(15)),
              const SizedBox(width: 8),
              _RestPill(label: 'Saltar', onTap: onSkip, primary: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestPill extends StatelessWidget {
  const _RestPill(
      {required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? kSeed : ac.bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: primary
              ? [
                  BoxShadow(
                      color: kSeed.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : ac.raised(NeuroSize.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.black : ac.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Active Workout ───────────────────────────────────────────────────────────

class _ActiveWorkout extends ConsumerWidget {
  const _ActiveWorkout({required this.ws});
  final WorkoutState ws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Material(
          elevation: lerpDouble(0, 10, animation.value)!,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          shadowColor: Colors.black45,
          child: child,
        ),
        child: child,
      ),
      onReorder: (oldIndex, newIndex) => ref
          .read(workoutProvider.notifier)
          .reorderExercises(oldIndex, newIndex),
      footer: const _AddExerciseButton(),
      itemCount: ws.exercises.length,
      itemBuilder: (context, i) {
        final ex = ws.exercises[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(ex.config.id),
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExerciseCard(
              key: ValueKey('card_${ex.config.id}'),
              exIdx: i,
              ex: ex,
            ),
          ),
        );
      },
    );
  }
}

// ─── Add Exercise Button ──────────────────────────────────────────────────────

class _AddExerciseButton extends ConsumerWidget {
  const _AddExerciseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: () => _openBrowser(context, ref),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: ac.bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              ...ac.raised(NeuroSize.sm),
              BoxShadow(color: kSeed.withValues(alpha: 0.10), blurRadius: 18),
            ],
            border: Border.all(color: kSeed.withValues(alpha: 0.22), width: 1),
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
    );
  }

  void _openBrowser(BuildContext context, WidgetRef ref) {
    final routineId = ref.read(workoutProvider).routineId;
    if (routineId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseBrowserPage(
          routineId: routineId,
          onAdd: (ex, sets, reps, rest, weight) => ref
              .read(workoutProvider.notifier)
              .addExercise(ex.id,
                  sets: sets, reps: reps, rest: rest, weight: weight),
        ),
      ),
    );
  }
}

// ─── Exercise Card ────────────────────────────────────────────────────────────

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({super.key, required this.exIdx, required this.ex});
  final int exIdx;
  final ExerciseWorkoutState ex;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  late final List<TextEditingController> _weightCtrls;
  late final List<TextEditingController> _repsCtrls;

  Future<void> _confirmRemove(BuildContext context) async {
    final ex = ref.read(workoutProvider).exercises[widget.exIdx];
    final doneCount = ex.sets.where((s) => s.done).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar ejercicio?'),
        content: Text(
          doneCount > 0
              ? '${ex.config.exercise?.name ?? 'Este ejercicio'} se quita de la rutina y se '
                  'borran las $doneCount series que ya registraste hoy.'
              : '${ex.config.exercise?.name ?? 'Este ejercicio'} se quita de la rutina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workoutProvider.notifier).removeExercise(widget.exIdx);
  }

  void _showRestEditor(BuildContext context) {
    final ac = AppColors.of(context);
    final ex = ref.read(workoutProvider).exercises[widget.exIdx];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RestEditorSheet(
        exerciseName: ex.config.exercise?.name ?? 'Ejercicio',
        currentRest: ex.effectiveRestSeconds,
        onSave: (seconds) {
          ref
              .read(workoutProvider.notifier)
              .updateRestSeconds(widget.exIdx, seconds);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _weightCtrls = widget.ex.sets.map((s) {
      return TextEditingController(text: _fmtWeight(s.weight));
    }).toList();
    _repsCtrls = widget.ex.sets.map((s) {
      return TextEditingController(text: s.reps?.toString() ?? '');
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _weightCtrls) {
      c.dispose();
    }
    for (final c in _repsCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleWeightChanged(int setIdx, String v) {
    final notifier = ref.read(workoutProvider.notifier);
    final ex = ref.read(workoutProvider).exercises[widget.exIdx];
    final oldWeight = ex.sets[setIdx].weight;
    final newWeight = double.tryParse(v);
    notifier.updateWeight(widget.exIdx, setIdx, newWeight);
    for (var j = setIdx + 1; j < ex.sets.length; j++) {
      if (!ex.sets[j].done && ex.sets[j].weight == oldWeight) {
        _weightCtrls[j].text = v;
        notifier.updateWeight(widget.exIdx, j, newWeight);
      }
    }
  }

  void _handleRepsChanged(int setIdx, String v) {
    final notifier = ref.read(workoutProvider.notifier);
    final ex = ref.read(workoutProvider).exercises[widget.exIdx];
    final oldReps = ex.sets[setIdx].reps;
    final newReps = int.tryParse(v);
    notifier.updateReps(widget.exIdx, setIdx, newReps);
    for (var j = setIdx + 1; j < ex.sets.length; j++) {
      if (!ex.sets[j].done && ex.sets[j].reps == oldReps) {
        _repsCtrls[j].text = v;
        notifier.updateReps(widget.exIdx, j, newReps);
      }
    }
  }

  /// Los controllers se indexan por posición, así que hay que alinearlos
  /// **antes** de tocar el estado: el notifier actualiza de forma síncrona y el
  /// rebuild llegaría con la lista de series ya cambiada y la de controllers no.
  void _addSet() {
    final exercises = ref.read(workoutProvider).exercises;
    if (widget.exIdx >= exercises.length) return;
    final ex = exercises[widget.exIdx];
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    _weightCtrls.add(TextEditingController(text: _fmtWeight(last?.weight)));
    _repsCtrls.add(TextEditingController(text: last?.reps?.toString() ?? ''));
    ref.read(workoutProvider.notifier).addSet(widget.exIdx);
  }

  void _removeSet(int setIdx) {
    if (setIdx >= _weightCtrls.length) return;
    final w = _weightCtrls.removeAt(setIdx);
    final r = _repsCtrls.removeAt(setIdx);
    // Se descartan después del frame: los TextField todavía están montados y
    // usar un controller ya liberado lanza excepción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      w.dispose();
      r.dispose();
    });
    ref.read(workoutProvider.notifier).removeSet(widget.exIdx, setIdx);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final ws = ref.watch(workoutProvider);
    final ex = ws.exercises.length > widget.exIdx
        ? ws.exercises[widget.exIdx]
        : widget.ex;
    final imageUrl = ex.config.exercise?.imageUrl;
    final firstPending = ex.firstPendingIdx;

    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ac.raised(NeuroSize.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: ac.pressed(NeuroSize.sm),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                              Icons.fitness_center,
                              color: ac.textDisabled),
                        )
                      : Icon(Icons.fitness_center, color: ac.textDisabled),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.config.exercise?.name ?? '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ac.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            // ex.sets.length, no config.targetSets: al agregar
                            // o quitar series el config queda desactualizado.
                            '${ex.sets.length} series · ${ex.config.targetReps} reps',
                            style: TextStyle(
                                fontSize: 12, color: ac.textMuted),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showRestEditor(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: ac.bg,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  ...ac.raised(NeuroSize.sm),
                                  BoxShadow(
                                      color:
                                          kSeed.withValues(alpha: 0.08),
                                      blurRadius: 8),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 12, color: kSeed),
                                  const SizedBox(width: 3),
                                  Text(
                                    _fmtRestLabel(
                                        ex.effectiveRestSeconds),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: kSeed,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmRemove(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Icon(Icons.close_rounded,
                        size: 18,
                        color: ac.textDisabled.withValues(alpha: 0.7)),
                  ),
                ),
                Icon(Icons.drag_handle_rounded,
                    size: 20,
                    color: ac.textDisabled.withValues(alpha: 0.5)),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('#',
                      style: TextStyle(
                          fontSize: 9,
                          color: ac.textMuted,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('ANTERIOR',
                      style: TextStyle(
                          fontSize: 9,
                          color: ac.textMuted,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  width: 60,
                  child: Text('KG',
                      style: TextStyle(
                          fontSize: 9,
                          color: ac.textMuted,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text('REPS',
                      style: TextStyle(
                          fontSize: 9,
                          color: ac.textMuted,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Set rows — deslizar a la derecha agrega una serie, a la izquierda
          // quita esta.
          ...ex.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Dismissible(
              key: ValueKey('set_${ex.config.id}_${s.setNumber}'),
              background: const _SwipeHint(adding: true),
              secondaryBackground: const _SwipeHint(adding: false),
              // Ambas acciones se resuelven acá y siempre devuelve false: al
              // renumerar, la key de la fila quitada puede volver a existir y
              // onDismissed haría saltar "dismissed widget still in the tree".
              // La fila desaparece igual porque cambia el estado.
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  _addSet();
                } else if (ex.sets.length > 1) {
                  _removeSet(i);
                }
                return false;
              },
              child: _SetRow(
                set: s,
                setIdx: i,
                exIdx: widget.exIdx,
                isActive: i == firstPending,
                weightCtrl: _weightCtrls[i],
                repsCtrl: _repsCtrls[i],
                onWeightChanged: (v) => _handleWeightChanged(i, v),
                onRepsChanged: (v) => _handleRepsChanged(i, v),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Swipe Hint ───────────────────────────────────────────────────────────────

/// Fondo que asoma al deslizar una serie: verde y "Serie +" hacia la derecha,
/// rojo y "Quitar" hacia la izquierda.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.adding});
  final bool adding;

  @override
  Widget build(BuildContext context) {
    final color = adding ? kSeed : Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: adding ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(adding ? Icons.add_rounded : Icons.delete_outline_rounded,
              size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            adding ? 'Serie' : 'Quitar',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Set Row ──────────────────────────────────────────────────────────────────

class _SetRow extends ConsumerWidget {
  const _SetRow({
    required this.set,
    required this.setIdx,
    required this.exIdx,
    required this.isActive,
    required this.weightCtrl,
    required this.repsCtrl,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });
  final SetLogState set;
  final int setIdx;
  final int exIdx;
  final bool isActive;
  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  final void Function(String) onWeightChanged;
  final void Function(String) onRepsChanged;

  void _openTypePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SetTypePickerSheet(
        current: set.setType,
        onSelect: (type) {
          ref
              .read(workoutProvider.notifier)
              .updateSetType(exIdx, setIdx, type);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final notifier = ref.read(workoutProvider.notifier);

    final (bubbleColor, bubbleTextColor, bubbleLabel) =
        _setBubbleStyle(set.setType, set.done, isActive, ac, set.setNumber);

    // Bubble shadow: only for normal type (non-done)
    List<BoxShadow>? bubbleShadow;
    if (!set.done && set.setType == SetType.normal) {
      bubbleShadow =
          isActive ? ac.pressed(NeuroSize.sm) : ac.raised(NeuroSize.sm);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: set.done ? kSeed.withValues(alpha: 0.07) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Set number / type bubble
          GestureDetector(
            onTap: () => _openTypePicker(context, ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
                boxShadow: bubbleShadow,
              ),
              child: Text(
                bubbleLabel,
                style: TextStyle(
                  fontSize: bubbleLabel.length > 1 ? 9 : 12,
                  fontWeight: FontWeight.w800,
                  color: bubbleTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Previous label
          Expanded(
            child: Text(
              set.prevLabel,
              style: TextStyle(
                fontSize: 12,
                color: ac.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Weight input
          SizedBox(
            width: 60,
            child: _NumField(
              controller: weightCtrl,
              hint: '0',
              decimal: true,
              onChanged: onWeightChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Reps input
          SizedBox(
            width: 48,
            child: _NumField(
              controller: repsCtrl,
              hint: '0',
              decimal: false,
              onChanged: onRepsChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Check button
          GestureDetector(
            onTap: () => notifier.toggleCheck(exIdx, setIdx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: set.done ? kSeed : ac.bg,
                shape: BoxShape.circle,
                boxShadow: set.done
                    ? [
                        BoxShadow(
                            color: kSeed.withValues(alpha: 0.35),
                            blurRadius: 10)
                      ]
                    : isActive
                        ? [
                            ...ac.raised(NeuroSize.sm),
                            BoxShadow(
                                color: kSeed.withValues(alpha: 0.10),
                                blurRadius: 8)
                          ]
                        : ac.raised(NeuroSize.sm),
                border: set.done
                    ? null
                    : isActive
                        ? Border.all(
                            color: kSeed.withValues(alpha: 0.35),
                            width: 1.5)
                        : null,
              ),
              child: Icon(
                Icons.check,
                size: 18,
                color: set.done
                    ? Colors.black
                    : isActive
                        ? kSeed.withValues(alpha: 0.7)
                        : ac.textDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Numeric Input ────────────────────────────────────────────────────────────

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.hint,
    required this.decimal,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: ac.pressed(NeuroSize.sm),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: () => controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[\d.]') : RegExp(r'\d'),
          ),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ac.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: ac.textDisabled),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Rest Editor Sheet ────────────────────────────────────────────────────────

class _RestEditorSheet extends StatefulWidget {
  const _RestEditorSheet({
    required this.exerciseName,
    required this.currentRest,
    required this.onSave,
  });
  final String exerciseName;
  final int currentRest;
  final void Function(int) onSave;

  @override
  State<_RestEditorSheet> createState() => _RestEditorSheetState();
}

class _RestEditorSheetState extends State<_RestEditorSheet> {
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.currentRest;
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    const presets = [30, 45, 60, 90, 120, 180];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descanso',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ac.textPrimary)),
                    Text(
                      widget.exerciseName,
                      style: TextStyle(
                          fontSize: 12, color: ac.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    shape: BoxShape.circle,
                    boxShadow: ac.raised(NeuroSize.sm),
                  ),
                  child:
                      Icon(Icons.close, size: 16, color: ac.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _fmtRestLabel(_seconds),
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: kSeed,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RestPill(
                label: '−15s',
                onTap: () => setState(
                    () => _seconds = (_seconds - 15).clamp(15, 600)),
              ),
              const SizedBox(width: 12),
              _RestPill(
                label: '+15s',
                onTap: () => setState(
                    () => _seconds = (_seconds + 15).clamp(15, 600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: presets.map((s) {
              final isSelected = _seconds == s;
              return GestureDetector(
                onTap: () => setState(() => _seconds = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ac.bg,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isSelected
                        ? ac.pressed(NeuroSize.sm)
                        : ac.raised(NeuroSize.sm),
                    border: isSelected
                        ? Border.all(
                            color: kSeed.withValues(alpha: 0.4),
                            width: 1.5)
                        : null,
                  ),
                  child: Text(
                    _fmtRestLabel(s),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color:
                          isSelected ? kSeed : ac.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => widget.onSave(_seconds),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Done View ────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({required this.ws, required this.onEnd});
  final WorkoutState ws;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final totalSets = ws.exercises.fold<int>(
        0, (s, e) => s + e.sets.where((l) => l.done).length);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ac.bg,
              shape: BoxShape.circle,
              boxShadow: [
                ...ac.raised(NeuroSize.md),
                BoxShadow(
                    color: kSeed.withValues(alpha: 0.18),
                    blurRadius: 24),
              ],
            ),
            child:
                Icon(Icons.emoji_events_rounded, size: 36, color: kSeed),
          ),
          const SizedBox(height: 20),
          Text(
            '¡Entreno finalizado!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ac.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$totalSets ${totalSets == 1 ? 'serie completada' : 'series completadas'}  ·  ${ws.elapsedLabel}',
            style: TextStyle(fontSize: 14, color: ac.textMuted),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onEnd,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Volver al inicio',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ─── PR Celebration Dialog ────────────────────────────────────────────────────

class _PRDialog extends StatelessWidget {
  const _PRDialog({required this.pr, required this.onContinue});
  final PendingPR pr;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: ac.bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: ac.shadowSh,
                  blurRadius: 40,
                  offset: const Offset(0, 12)),
              BoxShadow(
                  color: ac.shadowHi,
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.emoji_events_rounded,
                      size: 44, color: Color(0xFFF9A825)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: const Color(0xFFFFB300), width: 1.5),
                ),
                child: const Text(
                  'NUEVO PR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE65100),
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                pr.exerciseName,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ac.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ...pr.hits.map((h) => _PRHitRow(hit: h, ac: ac)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  backgroundColor: const Color(0xFFFFA000),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PRHitRow extends StatelessWidget {
  const _PRHitRow({required this.hit, required this.ac});
  final PRHit hit;
  final AppColors ac;

  @override
  Widget build(BuildContext context) {
    final (icon, label, valueStr) = switch (hit.type) {
      PRType.oneRm => (
          Icons.bolt_rounded,
          '1RM estimado',
          '${hit.newValue.toStringAsFixed(1)} kg',
        ),
      PRType.sessionVolume => (
          Icons.stacked_bar_chart_rounded,
          'Volumen total',
          '${hit.newValue.toStringAsFixed(0)} kg',
        ),
      PRType.absoluteWeight => (
          Icons.fitness_center_rounded,
          'Peso máximo',
          '${hit.newValue.toStringAsFixed(1)} kg',
        ),
      PRType.repsAtWeight => (
          Icons.repeat_rounded,
          'Reps (mismo peso)',
          '×${hit.newValue.toInt()}',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFF57F17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ac.textPrimary)),
          ),
          Text(
            valueStr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF57F17),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Set Type Picker Sheet ────────────────────────────────────────────────────

class _SetTypePickerSheet extends StatefulWidget {
  const _SetTypePickerSheet(
      {required this.current, required this.onSelect});
  final SetType current;
  final void Function(SetType) onSelect;

  @override
  State<_SetTypePickerSheet> createState() => _SetTypePickerSheetState();
}

class _SetTypePickerSheetState extends State<_SetTypePickerSheet> {
  SetType? _expanded;

  static const _types = [
    (
      type: SetType.warmup,
      label: 'Calentamiento',
      short: 'Para preparar los músculos',
      detail:
          'Una serie con poco peso antes de tus series principales. '
          'Su objetivo es calentar músculos y articulaciones sin cansarte. '
          'Por ejemplo, si vas a levantar 60 kg, calienta con 30–40 kg. '
          'No cuenta para tu progreso, pero reduce el riesgo de lesión.',
    ),
    (
      type: SetType.normal,
      label: 'Normal',
      short: 'Tu serie de trabajo principal',
      detail:
          'La serie estándar donde usas el peso y las repeticiones '
          'que tienes planificadas. Es la que cuenta para tu progreso '
          'y para detectar nuevos récords personales.',
    ),
    (
      type: SetType.toFailure,
      label: 'Al fallo',
      short: 'Hasta no poder hacer una más',
      detail:
          'Haces repeticiones hasta que físicamente ya no puedes completar '
          'una más con buena técnica. Maximiza el estímulo muscular, '
          'pero úsala con moderación — solo en ejercicios seguros y '
          'preferiblemente al final del entreno para no acumularte.',
    ),
    (
      type: SetType.drop,
      label: 'Drop set',
      short: 'Baja el peso y sigue',
      detail:
          'Al llegar al fallo (o casi), reduces el peso un 20–30 % '
          'y continúas haciendo repeticiones sin descanso. '
          'Es una forma de prolongar la serie más allá del fallo normal '
          'y aumentar el estímulo. Ideal para el último ejercicio del día.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tipo de serie',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    shape: BoxShape.circle,
                    boxShadow: ac.raised(NeuroSize.sm),
                  ),
                  child: Icon(Icons.close,
                      size: 16, color: ac.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in _types) ...[
            _SetTypeOption(
              typeDef: t,
              selected: widget.current == t.type,
              expanded: _expanded == t.type,
              onTap: () => widget.onSelect(t.type),
              onToggleInfo: () => setState(() {
                _expanded = _expanded == t.type ? null : t.type;
              }),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SetTypeOption extends StatelessWidget {
  const _SetTypeOption({
    required this.typeDef,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.onToggleInfo,
  });

  final ({
    SetType type,
    String label,
    String short,
    String detail,
  }) typeDef;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggleInfo;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final (color, _, abbr) = _setTypeMeta(typeDef.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? ac.pressed(NeuroSize.sm)
            : ac.raised(NeuroSize.sm),
        border: selected
            ? Border.all(color: color.withValues(alpha: 0.40), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        abbr,
                        style: TextStyle(
                          fontSize: abbr.length > 1 ? 9 : 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(typeDef.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ac.textPrimary)),
                          Text(typeDef.short,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ac.textMuted)),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: color),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onToggleInfo,
                      child: Icon(
                        expanded
                            ? Icons.help_rounded
                            : Icons.help_outline_rounded,
                        size: 20,
                        color: expanded ? color : ac.textMuted,
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      typeDef.detail,
                      style: TextStyle(
                          fontSize: 13,
                          color: ac.textSecondary,
                          height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

(Color, IconData, String) _setTypeMeta(SetType type) {
  return switch (type) {
    SetType.warmup    => (const Color(0xFFFF8C00), Icons.local_fire_department_rounded, 'C'),
    SetType.normal    => (kSeed, Icons.fitness_center_rounded, 'N'),
    SetType.toFailure => (const Color(0xFFE53935), Icons.whatshot_rounded, 'F'),
    SetType.drop      => (const Color(0xFF7B1FA2), Icons.arrow_downward_rounded, 'D'),
  };
}

(Color, Color, String) _setBubbleStyle(
  SetType type,
  bool done,
  bool isActive,
  AppColors ac,
  int setNumber,
) {
  if (done) {
    final (color, _, abbr) = _setTypeMeta(type);
    return (color, Colors.white, abbr);
  }
  if (type != SetType.normal) {
    final (color, _, abbr) = _setTypeMeta(type);
    return (
      color.withValues(alpha: isActive ? 0.25 : 0.12),
      color,
      abbr,
    );
  }
  return (
    isActive ? kSeed.withValues(alpha: 0.18) : ac.bg,
    isActive ? kSeed : ac.textMuted,
    '$setNumber',
  );
}

String _fmtWeight(double? w) {
  if (w == null) return '';
  if (w == w.truncateToDouble()) return w.toInt().toString();
  return w.toStringAsFixed(1);
}

String _fmtRestLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m > 0 && s > 0) return '${m}m ${s}s';
  if (m > 0) return '${m}m';
  return '${s}s';
}
