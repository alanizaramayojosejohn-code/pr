import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import 'data/workout_repository.dart';
import 'services/local_workout_store.dart';
import 'services/notification_service.dart';
import 'services/workout_timer_service.dart';
import 'workout_state.dart';

class WorkoutNotifier extends Notifier<WorkoutState> {
  final _repo = WorkoutRepository();
  Timer? _restTimer;

  @override
  WorkoutState build() {
    WorkoutTimerService.addTickListener(_onTimerData);
    ref.onDispose(() {
      WorkoutTimerService.removeTickListener(_onTimerData);
      _restTimer?.cancel();
      WorkoutTimerService.stop();
    });
    Future.microtask(_tryRestoreSession);
    return const WorkoutState(status: WorkoutStatus.idle);
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
            weight: log?.weight,
            reps: log?.reps,
            done: log != null,
            prevWeight: log?.weight,
            prevReps: log?.reps,
          );
        });
        return ExerciseWorkoutState(config: re, sets: sets);
      }).toList();

      state = WorkoutState(
        status: WorkoutStatus.active,
        sessionId: saved.sessionId,
        routineName: routine.name,
        exercises: exercises,
      );

      if (!kIsWeb) await WorkoutTimerService.start(routine.name);
    } catch (_) {
      await LocalWorkoutStore.clear();
      state = const WorkoutState(status: WorkoutStatus.idle);
    }
  }

  void _onTimerData(Object data) {
    if (data is int && state.status == WorkoutStatus.active) {
      state = state.copyWith(elapsedSeconds: data);
    }
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
          return SetLogState(
            setNumber: n,
            weight: p?.weight,
            reps: p?.reps,
            prevWeight: p?.weight,
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

      await WorkoutTimerService.start(routine.name);
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
      _startRestTimer(ex.config.restSeconds);
      state = state.copyWith(exercises: newExercises, userActiveExIdx: -1);
    } else {
      _restTimer?.cancel();
      state = state.copyWith(exercises: newExercises, restTimer: () => null);
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

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    final total = seconds > 0 ? seconds : 60;
    state = state.copyWith(
      restTimer: () =>
          RestTimerState(totalSeconds: total, remainingSeconds: total),
    );
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
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state.copyWith(restTimer: () => null);
  }

  void navigateTo(int exIdx) {
    if (exIdx < 0 || exIdx >= state.exercises.length) return;
    state = state.copyWith(userActiveExIdx: exIdx);
  }

  Future<void> finish() async {
    _restTimer?.cancel();

    final futures = <Future<void>>[];
    for (final ex in state.exercises) {
      for (final s in ex.sets) {
        if (!s.done && (s.weight != null || s.reps != null)) {
          futures.add(_repo.upsertLog(
            sessionId: state.sessionId,
            exerciseId: ex.config.exerciseId,
            setNumber: s.setNumber,
            weight: s.weight,
            reps: s.reps,
          ));
        }
      }
    }
    await Future.wait(futures);
    await _repo.finishSession(state.sessionId);

    await WorkoutTimerService.stop();
    await LocalWorkoutStore.clear();

    state = state.copyWith(status: WorkoutStatus.done, restTimer: () => null);
  }

  void endSession() {
    _restTimer?.cancel();
    WorkoutTimerService.stop();
    LocalWorkoutStore.clear();
    state = const WorkoutState(status: WorkoutStatus.idle);
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
