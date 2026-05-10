import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import 'data/workout_repository.dart';
import 'pr_detector.dart';
import 'services/local_workout_store.dart';
import 'services/notification_service.dart';
import 'services/workout_timer_service.dart';
import 'workout_state.dart';

class WorkoutNotifier extends Notifier<WorkoutState> {
  final _repo = WorkoutRepository();
  Timer? _restTimer;
  Timer? _elapsedTimer;

  // PR tracking for this session
  int? _pendingRestSeconds;
  final _shownPRs = <int, Set<PRType>>{}; // exerciseId → shown PR types

  @override
  WorkoutState build() {
    WorkoutTimerService.addTickListener(_onTimerData);
    ref.onDispose(() {
      WorkoutTimerService.removeTickListener(_onTimerData);
      _restTimer?.cancel();
      _elapsedTimer?.cancel();
      WorkoutTimerService.stop();
    });
    Future.microtask(_tryRestoreSession);
    return const WorkoutState(status: WorkoutStatus.idle);
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == WorkoutStatus.active) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  Future<void> _tryRestoreSession() async {
    final saved = await LocalWorkoutStore.load();
    if (saved == null) return;

    try {
      state = const WorkoutState(status: WorkoutStatus.loading);

      final routines =
          await ref.read(routinesRepositoryProvider).fetchAll();
      final routine = routines.firstWhere(
        (r) => r.id == saved.routineId,
        orElse: () => throw Exception('routine not found'),
      );

      final doneLogs = await _repo.fetchSessionLogs(saved.sessionId);

      final exercises = routine.exercises.map((re) {
        final sets = List.generate(re.targetSets, (i) {
          final setNum = i + 1;
          final log = doneLogs[re.exerciseId]?[setNum];
          return SetLogState(
            setNumber: setNum,
            weight: log?.weight ?? re.defaultWeight,
            reps: log?.reps,
            done: log != null,
            prevWeight: log?.weight ?? re.defaultWeight,
            prevReps: log?.reps,
          );
        });
        return ExerciseWorkoutState(config: re, sets: sets);
      }).toList();

      final startedAt = DateTime.tryParse(saved.startedAt);
      final elapsed = startedAt != null
          ? DateTime.now().difference(startedAt).inSeconds
          : 0;

      state = WorkoutState(
        status: WorkoutStatus.active,
        sessionId: saved.sessionId,
        routineName: routine.name,
        exercises: exercises,
        elapsedSeconds: elapsed,
      );

      _startElapsedTimer();
      if (!kIsWeb) await WorkoutTimerService.start(routine.name);
      _loadPRBests(routine.exercises.map((e) => e.exerciseId).toList(), saved.sessionId);
    } catch (_) {
      await LocalWorkoutStore.clear();
      state = const WorkoutState(status: WorkoutStatus.idle);
    }
  }

  void _onTimerData(Object data) {
    // Foreground service data — used only to keep the notification in sync.
    // Elapsed time is driven by _elapsedTimer (plain Dart timer) for reliability.
  }

  Future<void> start(Routine routine) async {
    _restTimer?.cancel();
    state = WorkoutState(status: WorkoutStatus.loading, routineName: routine.name);

    try {
      final session = await _repo.startSession(routine.id);
      final prefill = await _repo.fetchPrefillData(routine.id, session.id);

      final exercises = routine.exercises.map((re) {
        final exPrefill = prefill[re.exerciseId] ?? const [];
        final sets = List.generate(re.targetSets, (i) {
          final n = i + 1;
          final p = _pickPrefill(exPrefill, n, i);
          final weight = p?.weight ?? re.defaultWeight;
          return SetLogState(
            setNumber: n,
            weight: weight,
            reps: p?.reps,
            prevWeight: weight,
            prevReps: p?.reps,
          );
        });
        return ExerciseWorkoutState(config: re, sets: sets);
      }).toList();

      state = WorkoutState(
        status: WorkoutStatus.active,
        sessionId: session.id,
        routineName: routine.name,
        exercises: exercises,
      );

      _startElapsedTimer();
      await WorkoutTimerService.start(routine.name);
      // Load historical bests in background — non-critical
      _loadPRBests(routine.exercises.map((e) => e.exerciseId).toList(), session.id);
      await LocalWorkoutStore.save(
        sessionId: session.id,
        routineId: routine.id,
        startedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await NotificationService.requestPermission();
    } catch (e) {
      state = WorkoutState(status: WorkoutStatus.idle, error: e.toString());
    }
  }

  void updateWeight(int exIdx, int setIdx, double? w) {
    if (exIdx >= state.exercises.length) return;
    final ex = state.exercises[exIdx];
    if (setIdx >= ex.sets.length) return;
    final newSet = ex.sets[setIdx].copyWith(weight: () => w);
    _patchExercise(exIdx, ex.withSet(setIdx, newSet));
  }

  void updateReps(int exIdx, int setIdx, int? r) {
    if (exIdx >= state.exercises.length) return;
    final ex = state.exercises[exIdx];
    if (setIdx >= ex.sets.length) return;
    final newSet = ex.sets[setIdx].copyWith(reps: () => r);
    _patchExercise(exIdx, ex.withSet(setIdx, newSet));
  }

  void toggleCheck(int exIdx, int setIdx) {
    if (exIdx >= state.exercises.length) return;
    final ex = state.exercises[exIdx];
    if (setIdx >= ex.sets.length) return;
    final set = ex.sets[setIdx];
    final nowDone = !set.done;
    final newSet = set.copyWith(done: nowDone);
    final newEx = ex.withSet(setIdx, newSet);
    final newExercises = [...state.exercises];
    newExercises[exIdx] = newEx;

    if (nowDone) {
      final pr = _checkPR(ex, set);
      if (pr != null) {
        HapticFeedback.heavyImpact();
        _pendingRestSeconds = ex.effectiveRestSeconds;
        state = state.copyWith(
          exercises: newExercises,
          userActiveExIdx: -1,
          pendingPR: () => pr,
        );
      } else {
        _startRestTimer(ex.effectiveRestSeconds);
        state = state.copyWith(exercises: newExercises, userActiveExIdx: -1);
      }
    } else {
      _pendingRestSeconds = null;
      _restTimer?.cancel();
      state = state.copyWith(
        exercises: newExercises,
        restTimer: () => null,
        pendingPR: () => null,
      );
    }

    _repo.upsertLog(
      sessionId: state.sessionId,
      exerciseId: ex.config.exerciseId,
      setNumber: set.setNumber,
      weight: set.weight,
      reps: set.reps,
      restSecondsUsed: nowDone ? ex.config.restSeconds : null,
    );
  }

  void clearPR() {
    final pr = state.pendingPR;
    state = state.copyWith(pendingPR: () => null);
    if (pr != null) {
      // Mark all shown PR types so they don't repeat this session
      final shown = _shownPRs.putIfAbsent(pr.exerciseId, () => {});
      for (final hit in pr.hits) {
        shown.add(hit.type);
      }
    }
    if (_pendingRestSeconds != null) {
      _startRestTimer(_pendingRestSeconds!);
      _pendingRestSeconds = null;
    }
  }

  PendingPR? _checkPR(ExerciseWorkoutState ex, SetLogState set) {
    final weight = set.weight;
    final reps = set.reps;
    if (weight == null || reps == null) return null;

    final exId = ex.config.exerciseId;
    final bests = state.prBests[exId] ?? const ExerciseBests();

    // Volume from sets already done for this exercise (excluding this one,
    // which has done=false in ex since we're called before patching)
    final sessionVolBefore = ex.sets
        .where((s) => s.done)
        .fold(0.0, (sum, s) => sum + (s.weight ?? 0) * (s.reps ?? 0));

    final allHits = PRDetector.check(
      weight: weight,
      reps: reps,
      bests: bests,
      sessionVolumeBeforeSet: sessionVolBefore,
    );

    // Filter out PR types already celebrated this session for this exercise
    final shownForEx = _shownPRs[exId] ?? const {};
    final hits = allHits.where((h) => !shownForEx.contains(h.type)).toList();

    if (hits.isEmpty) return null;
    return PendingPR(
      exerciseId: exId,
      exerciseName: ex.config.exercise?.name ?? 'Ejercicio',
      hits: hits,
    );
  }

  Future<void> _loadPRBests(List<int> exerciseIds, String sessionId) async {
    try {
      final bests = await _repo.fetchExerciseBests(exerciseIds, sessionId);
      if (state.status != WorkoutStatus.idle) {
        state = state.copyWith(prBests: bests);
      }
    } catch (_) {
      // PR detection is non-critical; ignore errors
    }
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    final total = seconds > 0 ? seconds : 60;
    state = state.copyWith(
      restTimer: () =>
          RestTimerState(totalSeconds: total, remainingSeconds: total),
    );
    WorkoutTimerService.startRest(total);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final cur = state.restTimer;
      if (cur == null) {
        t.cancel();
        return;
      }
      final rem = cur.remainingSeconds - 1;
      if (rem <= 0) {
        t.cancel();
        state = state.copyWith(restTimer: () => null);
        NotificationService.showRestDone();
      } else {
        state = state.copyWith(
          restTimer: () => RestTimerState(
            totalSeconds: cur.totalSeconds,
            remainingSeconds: rem,
          ),
        );
      }
    });
  }

  void adjustRest(int delta) {
    final cur = state.restTimer;
    if (cur == null) return;
    final newRem = (cur.remainingSeconds + delta).clamp(5, 600);
    state = state.copyWith(
      restTimer: () =>
          RestTimerState(totalSeconds: cur.totalSeconds, remainingSeconds: newRem),
    );
    WorkoutTimerService.startRest(newRem);
  }

  void skipRest() {
    _restTimer?.cancel();
    WorkoutTimerService.cancelRest();
    state = state.copyWith(restTimer: () => null);
  }

  void navigateTo(int exIdx) {
    if (exIdx < 0 || exIdx >= state.exercises.length) return;
    state = state.copyWith(userActiveExIdx: exIdx);
  }

  Future<void> finish() async {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();

    // Upsert every set unconditionally — done sets may have been saved
    // fire-and-forget in toggleCheck; non-done sets need saving now.
    final logFutures = <Future<void>>[];
    for (final ex in state.exercises) {
      for (final s in ex.sets) {
        logFutures.add(_repo.upsertLog(
          sessionId: state.sessionId,
          exerciseId: ex.config.exerciseId,
          setNumber: s.setNumber,
          weight: s.weight,
          reps: s.reps,
          restSecondsUsed: s.done ? ex.effectiveRestSeconds : null,
        ));
      }
    }
    await Future.wait(logFutures);
    await _repo.finishSession(state.sessionId);

    // Persist used weight back to routine so next session pre-fills correctly.
    // Non-critical — wrap in try/catch so a Supabase RLS or network error here
    // doesn't prevent the workout from being marked done.
    try {
      final routinesRepo = ref.read(routinesRepositoryProvider);
      final weightFutures = <Future<void>>[];
      for (final ex in state.exercises) {
        final firstWeight = ex.sets
            .firstWhere((s) => s.weight != null, orElse: () => ex.sets.first)
            .weight;
        if (firstWeight != null) {
          weightFutures.add(
            routinesRepo.updateExerciseDefaultWeight(ex.config.id, firstWeight),
          );
        }
      }
      await Future.wait(weightFutures);
    } catch (_) {}

    await WorkoutTimerService.stop();
    await LocalWorkoutStore.clear();

    state = state.copyWith(status: WorkoutStatus.done, restTimer: () => null);
  }

  void endSession() {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    WorkoutTimerService.stop();
    LocalWorkoutStore.clear();
    state = const WorkoutState(status: WorkoutStatus.idle);
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final list = [...state.exercises];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(exercises: list, userActiveExIdx: -1);
  }

  void updateRestSeconds(int exIdx, int seconds) {
    if (exIdx >= state.exercises.length) return;
    final ex = state.exercises[exIdx];
    _patchExercise(exIdx, ex.withRest(seconds));
    ref
        .read(routinesRepositoryProvider)
        .updateExerciseRest(ex.config.id, seconds)
        .ignore();
  }

  void _patchExercise(int exIdx, ExerciseWorkoutState newEx) {
    final list = [...state.exercises];
    list[exIdx] = newEx;
    state = state.copyWith(exercises: list);
  }

  PrefillLog? _pickPrefill(List<PrefillLog> logs, int setNumber, int fallbackIdx) {
    for (final l in logs) {
      if (l.setNumber == setNumber) return l;
    }
    if (fallbackIdx < logs.length) return logs[fallbackIdx];
    if (logs.isNotEmpty) return logs.last;
    return null;
  }
}
