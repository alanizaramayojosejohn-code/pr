import '../routines/data/routines_repository.dart';
import 'pr_detector.dart';

enum WorkoutStatus { idle, loading, active, done }

class SetLogState {
  const SetLogState({
    required this.setNumber,
    this.weight,
    this.reps,
    this.done = false,
    this.prevWeight,
    this.prevReps,
  });

  final int setNumber;
  final double? weight;
  final int? reps;
  final bool done;
  final double? prevWeight;
  final int? prevReps;

  String get prevLabel {
    if (prevWeight != null && prevReps != null) {
      return '${_fmtW(prevWeight!)}×$prevReps';
    }
    if (prevWeight != null) return _fmtW(prevWeight!);
    if (prevReps != null) return '×$prevReps';
    return '—';
  }

  SetLogState copyWith({
    double? Function()? weight,
    int? Function()? reps,
    bool? done,
  }) =>
      SetLogState(
        setNumber: setNumber,
        weight: weight != null ? weight() : this.weight,
        reps: reps != null ? reps() : this.reps,
        done: done ?? this.done,
        prevWeight: prevWeight,
        prevReps: prevReps,
      );
}

class ExerciseWorkoutState {
  const ExerciseWorkoutState({
    required this.config,
    required this.sets,
    this.restSecondsOverride,
  });

  final RoutineExercise config;
  final List<SetLogState> sets;
  final int? restSecondsOverride;

  int get effectiveRestSeconds => restSecondsOverride ?? config.restSeconds;
  bool get allDone => sets.every((s) => s.done);
  int get firstPendingIdx => sets.indexWhere((s) => !s.done);

  ExerciseWorkoutState withSet(int idx, SetLogState set) {
    final s = [...sets];
    s[idx] = set;
    return ExerciseWorkoutState(
      config: config,
      sets: s,
      restSecondsOverride: restSecondsOverride,
    );
  }

  ExerciseWorkoutState withRest(int seconds) => ExerciseWorkoutState(
        config: config,
        sets: sets,
        restSecondsOverride: seconds,
      );
}

class RestTimerState {
  const RestTimerState({required this.totalSeconds, required this.remainingSeconds});
  final int totalSeconds;
  final int remainingSeconds;

  double get progress =>
      totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

  String get label {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    if (m > 0) {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return s.toString();
  }
}

class WorkoutState {
  const WorkoutState({
    required this.status,
    this.sessionId = '',
    this.routineName = '',
    this.exercises = const [],
    this.userActiveExIdx = -1,
    this.restTimer,
    this.elapsedSeconds = 0,
    this.error,
    this.prBests = const {},
    this.pendingPR,
  });

  final WorkoutStatus status;
  final String sessionId;
  final String routineName;
  final List<ExerciseWorkoutState> exercises;
  final int userActiveExIdx;
  final RestTimerState? restTimer;
  final int elapsedSeconds;
  final String? error;
  final Map<int, ExerciseBests> prBests;
  final PendingPR? pendingPR;

  int get autoActiveExIdx {
    for (var i = 0; i < exercises.length; i++) {
      if (!exercises[i].allDone) return i;
    }
    return exercises.isEmpty ? 0 : exercises.length - 1;
  }

  int get activeExIdx =>
      (userActiveExIdx >= 0 && userActiveExIdx < exercises.length)
          ? userActiveExIdx
          : autoActiveExIdx;

  bool get allDone =>
      exercises.isNotEmpty && exercises.every((e) => e.allDone);

  int get doneSetCount => exercises.fold(
      0, (sum, e) => sum + e.sets.where((s) => s.done).length);

  String get elapsedLabel {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  WorkoutState copyWith({
    WorkoutStatus? status,
    String? sessionId,
    String? routineName,
    List<ExerciseWorkoutState>? exercises,
    int? userActiveExIdx,
    RestTimerState? Function()? restTimer,
    int? elapsedSeconds,
    String? Function()? error,
    Map<int, ExerciseBests>? prBests,
    PendingPR? Function()? pendingPR,
  }) =>
      WorkoutState(
        status: status ?? this.status,
        sessionId: sessionId ?? this.sessionId,
        routineName: routineName ?? this.routineName,
        exercises: exercises ?? this.exercises,
        userActiveExIdx: userActiveExIdx ?? this.userActiveExIdx,
        restTimer: restTimer != null ? restTimer() : this.restTimer,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        error: error != null ? error() : this.error,
        prBests: prBests ?? this.prBests,
        pendingPR: pendingPR != null ? pendingPR() : this.pendingPR,
      );
}

String _fmtW(double w) =>
    w == w.truncateToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
