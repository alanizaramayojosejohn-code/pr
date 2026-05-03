import '../../../supabase/client.dart';

class ExerciseLite {
  ExerciseLite({required this.id, required this.name, this.imageUrl});

  final int id;
  final String name;
  final String? imageUrl;

  factory ExerciseLite.fromJson(Map<String, dynamic> json) {
    return ExerciseLite(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }
}

class RoutineExercise {
  RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.position,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
    this.exercise,
  });

  final String id;
  final String routineId;
  final int exerciseId;
  final int position;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final ExerciseLite? exercise;

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final ex = json['exercise'];
    return RoutineExercise(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      exerciseId: json['exercise_id'] as int,
      position: (json['position'] as num?)?.toInt() ?? 0,
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 0,
      targetReps: (json['target_reps'] as num?)?.toInt() ?? 0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 0,
      exercise: ex is Map<String, dynamic> ? ExerciseLite.fromJson(ex) : null,
    );
  }
}

class Routine {
  Routine({
    required this.id,
    required this.userId,
    required this.name,
    this.dayOfWeek,
    this.notes,
    required this.createdAt,
    required this.exercises,
  });

  final String id;
  final String userId;
  final String name;
  final int? dayOfWeek;
  final String? notes;
  final DateTime createdAt;
  final List<RoutineExercise> exercises;

  factory Routine.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['routine_exercises'] as List?) ?? const [];
    final exercises = rawExercises
        .whereType<Map<String, dynamic>>()
        .map(RoutineExercise.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Routine(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: (json['name'] as String?) ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      exercises: exercises,
    );
  }
}

class RoutinesRepository {
  Future<List<Routine>> fetchAll() async {
    final res = await supabase
        .from('routines')
        .select('*, routine_exercises(*, exercise:Exercise(*))')
        .order('day_of_week', ascending: true, nullsFirst: false);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(Routine.fromJson)
        .toList();
  }
}
