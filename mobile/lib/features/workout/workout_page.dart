import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    if (ws.status == WorkoutStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onCancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                ws: ws,
                onCancel: _onCancel,
                onFinish: _onFinish,
              ),
              if (ws.restTimer != null)
                _RestBanner(
                  rt: ws.restTimer!,
                  onAdjust: (d) =>
                      ref.read(workoutProvider.notifier).adjustRest(d),
                  onSkip: () => ref.read(workoutProvider.notifier).skipRest(),
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
                      ? const Center(child: Text('Esta rutina no tiene ejercicios.'))
                      : _ActiveWorkout(ws: ws),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalSets =
        ws.exercises.fold<int>(0, (s, e) => s + e.sets.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Salir',
            onPressed: onCancel,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ws.routineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (ws.status == WorkoutStatus.active)
                  Text(
                    '${ws.elapsedLabel}  ·  ${ws.doneSetCount}/$totalSets series',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: ws.status == WorkoutStatus.active ? onFinish : null,
            child: Text(
              'Finalizar',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rest Banner ─────────────────────────────────────────────────────────────

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      color: cs.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DESCANSO',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: cs.onSecondaryContainer,
                ),
              ),
              Text(
                rt.label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSecondaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rt.progress,
              minHeight: 6,
              backgroundColor: cs.secondary.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(cs.secondary),
            ),
          ),
          const SizedBox(height: 10),
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
  const _RestPill({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? cs.secondary : cs.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.secondary),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary ? cs.onSecondary : cs.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

// ─── Active Workout ──────────────────────────────────────────────────────────

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
      onReorder: (oldIndex, newIndex) =>
          ref.read(workoutProvider.notifier).reorderExercises(oldIndex, newIndex),
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

// ─── Exercise Card ───────────────────────────────────────────────────────────

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({
    super.key,
    required this.exIdx,
    required this.ex,
  });
  final int exIdx;
  final ExerciseWorkoutState ex;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  late final List<TextEditingController> _weightCtrls;
  late final List<TextEditingController> _repsCtrls;

  void _showRestEditor(BuildContext context) {
    final ex = ref.read(workoutProvider).exercises[widget.exIdx];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RestEditorSheet(
        exerciseName: ex.config.exercise?.name ?? 'Ejercicio',
        currentRest: ex.effectiveRestSeconds,
        onSave: (seconds) {
          ref.read(workoutProvider.notifier).updateRestSeconds(widget.exIdx, seconds);
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

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workoutProvider);
    final ex = ws.exercises.length > widget.exIdx
        ? ws.exercises[widget.exIdx]
        : widget.ex;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imageUrl = ex.config.exercise?.imageUrl;
    final firstPending = ex.firstPendingIdx;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    width: 52,
                    height: 52,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.fitness_center, color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fitness_center, color: cs.onSurfaceVariant),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.config.exercise?.name ?? '—',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${ex.config.targetSets} series · ${ex.config.targetReps} reps',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showRestEditor(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 12, color: cs.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    _fmtRestLabel(ex.effectiveRestSeconds),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.primary,
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
                Icon(
                  Icons.drag_handle_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
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
                  child: Text(
                    '#',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ANTERIOR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'KG',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    'REPS',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Set rows
          ...ex.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return _SetRow(
              set: s,
              setIdx: i,
              exIdx: widget.exIdx,
              isActive: i == firstPending,
              weightCtrl: _weightCtrls[i],
              repsCtrl: _repsCtrls[i],
              onWeightChanged: (v) => _handleWeightChanged(i, v),
              onRepsChanged: (v) => _handleRepsChanged(i, v),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Set Row ─────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(workoutProvider.notifier);

    Color bgColor;
    if (set.done) {
      bgColor = cs.primaryContainer.withValues(alpha: 0.5);
    } else if (isActive) {
      bgColor = cs.primaryContainer.withValues(alpha: 0.25);
    } else {
      bgColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Set number bubble
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: set.done
                  ? cs.primary
                  : isActive
                      ? cs.primaryContainer
                      : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${set.setNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: set.done
                    ? cs.onPrimary
                    : isActive
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
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
                color: cs.onSurfaceVariant,
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
                color: set.done ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: set.done ? cs.primary : cs.outline,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check,
                size: 18,
                color: set.done ? cs.onPrimary : cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Numeric Input ───────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return TextField(
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
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        isDense: true,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                    Text(
                      'Descanso',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.exerciseName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _fmtRestLabel(_seconds),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
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
            children: presets
                .map((s) => ChoiceChip(
                      label: Text(_fmtRestLabel(s)),
                      selected: _seconds == s,
                      onSelected: (_) => setState(() => _seconds = s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => widget.onSave(_seconds),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Done View ───────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({required this.ws, required this.onEnd});
  final WorkoutState ws;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_rounded,
                size: 36, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(
            '¡Entreno finalizado!',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$totalSets ${totalSets == 1 ? 'serie completada' : 'series completadas'}  ·  ${ws.elapsedLabel}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onEnd,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Volver al inicio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
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
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 44,
                    color: Color(0xFFF9A825),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
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
              // Exercise name
              Text(
                pr.exerciseName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // PR rows
              ...pr.hits.map((h) => _PRHitRow(hit: h)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  backgroundColor: const Color(0xFFFFA000),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PRHitRow extends StatelessWidget {
  const _PRHitRow({required this.hit});
  final PRHit hit;

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
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

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
