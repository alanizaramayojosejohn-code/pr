import '../../../supabase/client.dart';

class ExerciseLite {
  ExerciseLite({required this.id, required this.name, this.imageUrl});

  final int id;
  final String name;
  final String? imageUrl;

  factory ExerciseLite.fromJson(Map<String, dynamic> json) {
    return ExerciseLite(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ExerciseDetail {
  ExerciseDetail({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imageUrl2,
    this.level,
    this.equipment,
    this.mechanic,
    this.categorySlug,
    required this.instructions,
  });

  final int id;
  final String name;
  final String? imageUrl;
  final String? imageUrl2;
  final String? level;
  final String? equipment;
  final String? mechanic;
  final String? categorySlug;
  final List<String> instructions;

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    final cat = json['exercise_categories'];
    String? catSlug;
    if (cat is Map) {
      catSlug = cat['slug'] as String?;
    } else if (cat is List && cat.isNotEmpty) {
      catSlug = (cat.first as Map?)?['slug'] as String?;
    }

    final desc = (json['description'] as String?) ?? '';
    final instructions = desc.isNotEmpty
        ? desc.split('\n\n').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    return ExerciseDetail(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      imageUrl2: json['image_url_2'] as String?,
      level: json['level'] as String?,
      equipment: json['equipment'] as String?,
      mechanic: json['mechanic'] as String?,
      categorySlug: catSlug,
      instructions: instructions,
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
    this.defaultWeight,
    this.exercise,
  });

  final String id;
  final String routineId;
  final int exerciseId;
  final int position;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final double? defaultWeight;
  final ExerciseLite? exercise;

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final ex = json['exercise'];
    return RoutineExercise(
      id: json['id'] as String,
      routineId: json['routine_id'] as String,
      exerciseId: (json['exercise_id'] as num).toInt(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 0,
      targetReps: (json['target_reps'] as num?)?.toInt() ?? 0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 0,
      defaultWeight: json['default_weight'] == null
          ? null
          : (json['default_weight'] as num).toDouble(),
      exercise: ex is Map<String, dynamic> ? ExerciseLite.fromJson(ex) : null,
    );
  }
}

class Routine {
  Routine({
    required this.id,
    required this.userId,
    required this.name,
    required this.daysOfWeek,
    this.notes,
    required this.createdAt,
    required this.exercises,
    this.isTemplate = false,
    this.sourceTemplateId,
    this.assignedBy,
  });

  final String id;
  final String userId;
  final String name;
  final List<int> daysOfWeek; // empty = no day assigned
  final String? notes;
  final DateTime createdAt;
  final List<RoutineExercise> exercises;

  /// Plantilla del instructor: no se entrena, se envía a los alumnos.
  final bool isTemplate;

  /// Plantilla de la que salió esta copia, si la mandó un instructor.
  final String? sourceTemplateId;
  final String? assignedBy;

  bool get isAssigned => assignedBy != null;

  factory Routine.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['routine_exercises'] as List?) ?? const [];
    final exercises = rawExercises
        .whereType<Map<String, dynamic>>()
        .map(RoutineExercise.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final rawDays = json['days_of_week'];
    final days = rawDays is List
        ? rawDays.whereType<num>().map((n) => n.toInt()).toList()
        : <int>[];

    return Routine(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: (json['name'] as String?) ?? '',
      daysOfWeek: days,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      exercises: exercises,
      isTemplate: (json['is_template'] as bool?) ?? false,
      sourceTemplateId: json['source_template_id'] as String?,
      assignedBy: json['assigned_by'] as String?,
    );
  }
}

class RoutinesRepository {
  // ── Read ────────────────────────────────────────────────────────────────────

  Future<List<Routine>> fetchAll() async {
    final userId = supabase.auth.currentUser!.id;
    final res = await supabase
        .from('routines')
        .select('*, routine_exercises(*, exercise:Exercise(*))')
        .eq('user_id', userId)
        .order('name', ascending: true);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(Routine.fromJson)
        .toList();
  }

  Future<ExerciseDetail> fetchExerciseDetail(int id) async {
    final res = await supabase
        .from('Exercise')
        .select(
            'id, name, image_url, image_url_2, level, equipment, mechanic, description, exercise_categories(slug)')
        .eq('id', id)
        .single();
    return ExerciseDetail.fromJson(res);
  }

  Future<List<ExerciseLite>> searchExercises(
    String query, {
    String? categorySlug,
    int limit = 25,
    int offset = 0,
  }) async {
    var req = supabase.from('Exercise').select(
      categorySlug != null
          ? 'id, name, image_url, exercise_categories!inner(slug)'
          : 'id, name, image_url',
    );
    if (query.isNotEmpty) {
      req = req.ilike('name', '%$query%');
    }
    if (categorySlug != null) {
      req = req.eq('exercise_categories.slug', categorySlug);
    }
    final res = await req.order('name').range(offset, offset + limit - 1);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(ExerciseLite.fromJson)
        .toList();
  }

  // ── Routine mutations ────────────────────────────────────────────────────────

  /// Devuelve el id de la rutina creada para poder abrirla enseguida.
  Future<String> createRoutine({
    required String name,
    List<int> daysOfWeek = const [],
    bool isTemplate = false,
  }) async {
    final res = await supabase
        .from('routines')
        .insert({
          'name': name,
          'user_id': supabase.auth.currentUser!.id,
          'days_of_week': daysOfWeek,
          'is_template': isTemplate,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> updateRoutine(String id, Map<String, dynamic> changes) async {
    await supabase.from('routines').update(changes).eq('id', id);
  }

  Future<void> deleteRoutine(String id) async {
    await supabase.from('routines').delete().eq('id', id);
  }

  // ── Routine-exercise mutations ───────────────────────────────────────────────

  /// Devuelve la fila creada —con el ejercicio ya embebido— para que quien
  /// llama pueda insertarla en su estado sin recargar toda la rutina.
  Future<RoutineExercise> addExercise(
    String routineId,
    int exerciseId, {
    required int sets,
    required int reps,
    required int rest,
    double? weight,
  }) async {
    final existing = await supabase
        .from('routine_exercises')
        .select('position')
        .eq('routine_id', routineId)
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle();
    final position =
        existing == null ? 1 : ((existing['position'] as num).toInt() + 1);
    final res = await supabase
        .from('routine_exercises')
        .insert({
          'routine_id': routineId,
          'exercise_id': exerciseId,
          'position': position,
          'target_sets': sets,
          'target_reps': reps,
          'rest_seconds': rest,
          if (weight != null) 'default_weight': weight,
        })
        .select('*, exercise:Exercise(*)')
        .single();
    return RoutineExercise.fromJson(res);
  }

  /// Actualiza solo los campos indicados. [clearWeight] distingue "no tocar el
  /// peso" (weight == null) de "dejarlo vacío".
  Future<void> updateExercise(
    String routineExerciseId, {
    int? sets,
    int? reps,
    int? rest,
    double? weight,
    bool clearWeight = false,
  }) async {
    final changes = <String, dynamic>{};
    if (sets != null) changes['target_sets'] = sets;
    if (reps != null) changes['target_reps'] = reps;
    if (rest != null) changes['rest_seconds'] = rest;
    if (clearWeight) {
      changes['default_weight'] = null;
    } else if (weight != null) {
      changes['default_weight'] = weight;
    }
    if (changes.isEmpty) return;
    await supabase
        .from('routine_exercises')
        .update(changes)
        .eq('id', routineExerciseId);
  }

  /// Reescribe las posiciones según el orden de [orderedIds] (1-based, igual
  /// que [addExercise]).
  Future<void> reorderExercises(List<String> orderedIds) async {
    await Future.wait([
      for (var i = 0; i < orderedIds.length; i++)
        supabase
            .from('routine_exercises')
            .update({'position': i + 1})
            .eq('id', orderedIds[i]),
    ]);
  }

  Future<void> updateExerciseDefaultWeight(
      String routineExerciseId, double weight) async {
    await supabase
        .from('routine_exercises')
        .update({'default_weight': weight})
        .eq('id', routineExerciseId);
  }

  Future<void> updateExerciseRest(
      String routineExerciseId, int restSeconds) async {
    await supabase
        .from('routine_exercises')
        .update({'rest_seconds': restSeconds})
        .eq('id', routineExerciseId);
  }

  Future<void> removeExercise(String routineExerciseId) async {
    await supabase
        .from('routine_exercises')
        .delete()
        .eq('id', routineExerciseId);
  }
}
