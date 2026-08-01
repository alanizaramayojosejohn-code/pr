import '../../../supabase/client.dart';
import '../pr_detector.dart';

class WorkoutSession {
  const WorkoutSession({required this.id, required this.routineId});
  final String id;
  final String routineId;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
      );
}

class PrefillLog {
  const PrefillLog({required this.setNumber, this.weight, this.reps});
  final int setNumber;
  final double? weight;
  final int? reps;
}

class WorkoutRepository {
  Future<WorkoutSession> startSession(String routineId) async {
    final res = await supabase
        .from('workout_sessions')
        .insert({
          'routine_id': routineId,
          'user_id': supabase.auth.currentUser!.id,
        })
        .select('id, routine_id')
        .single();
    return WorkoutSession.fromJson(res);
  }

  Future<Map<int, List<PrefillLog>>> fetchPrefillData(
      String routineId, String currentSessionId) async {
    final prev = await supabase
        .from('workout_sessions')
        .select('id')
        .eq('routine_id', routineId)
        .neq('id', currentSessionId)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (prev == null) return {};

    final logs = await supabase
        .from('exercise_logs')
        .select('exercise_id, set_number, weight, reps')
        .eq('session_id', prev['id'] as String);

    final result = <int, List<PrefillLog>>{};
    for (final row in (logs as List)) {
      final m = row as Map<String, dynamic>;
      final exId = (m['exercise_id'] as num).toInt();
      result.putIfAbsent(exId, () => []).add(PrefillLog(
        setNumber: (m['set_number'] as num).toInt(),
        weight: m['weight'] == null ? null : (m['weight'] as num).toDouble(),
        reps: m['reps'] == null ? null : (m['reps'] as num).toInt(),
      ));
    }
    return result;
  }

  Future<void> upsertLog({
    required String sessionId,
    required int exerciseId,
    required int setNumber,
    double? weight,
    int? reps,
    int? restSecondsUsed,
  }) async {
    await supabase
        .from('exercise_logs')
        .delete()
        .eq('session_id', sessionId)
        .eq('exercise_id', exerciseId)
        .eq('set_number', setNumber);
    await supabase.from('exercise_logs').insert({
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'rest_seconds_used': restSecondsUsed,
    });
  }

  Future<Map<int, Map<int, PrefillLog>>> fetchSessionLogs(String sessionId) async {
    final logs = await supabase
        .from('exercise_logs')
        .select('exercise_id, set_number, weight, reps')
        .eq('session_id', sessionId);

    final result = <int, Map<int, PrefillLog>>{};
    for (final row in (logs as List)) {
      final m = row as Map<String, dynamic>;
      final exId = (m['exercise_id'] as num).toInt();
      final setNum = (m['set_number'] as num).toInt();
      result.putIfAbsent(exId, () => <int, PrefillLog>{})[setNum] = PrefillLog(
        setNumber: setNum,
        weight: m['weight'] == null ? null : (m['weight'] as num).toDouble(),
        reps: m['reps'] == null ? null : (m['reps'] as num).toInt(),
      );
    }
    return result;
  }

  /// Borra lo registrado de un ejercicio en la sesión. Se usa al quitarlo del
  /// entreno en curso: si no, sus series quedarían huérfanas en el historial.
  Future<void> deleteExerciseLogs({
    required String sessionId,
    required int exerciseId,
  }) async {
    await supabase
        .from('exercise_logs')
        .delete()
        .eq('session_id', sessionId)
        .eq('exercise_id', exerciseId);
  }

  Future<void> finishSession(String sessionId) async {
    await supabase
        .from('workout_sessions')
        .update({'finished_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', sessionId);
  }

  /// Fetches historical bests per exercise for PR detection.
  /// Excludes [currentSessionId] so ongoing sets don't inflate the baseline.
  Future<Map<int, ExerciseBests>> fetchExerciseBests(
      List<int> exerciseIds, String currentSessionId) async {
    if (exerciseIds.isEmpty) return {};
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final sessionRows = await supabase
        .from('workout_sessions')
        .select('id')
        .eq('user_id', userId)
        .not('finished_at', 'is', null)
        .neq('id', currentSessionId);

    final sessionIds =
        (sessionRows as List).map((r) => r['id'] as String).toList();
    if (sessionIds.isEmpty) return {};

    final logRows = await supabase
        .from('exercise_logs')
        .select('exercise_id, session_id, weight, reps')
        .inFilter('session_id', sessionIds)
        .inFilter('exercise_id', exerciseIds);

    final builders = <int, _BestsBuilder>{};
    final sessionVols = <String, Map<int, double>>{};

    for (final row in (logRows as List)) {
      final m = row as Map<String, dynamic>;
      final exId = (m['exercise_id'] as num).toInt();
      final sid = m['session_id'] as String;
      final w = m['weight'] == null ? null : (m['weight'] as num).toDouble();
      final r = m['reps'] == null ? null : (m['reps'] as num).toInt();

      if (w == null || r == null || w <= 0 || r <= 0) continue;

      final b = builders.putIfAbsent(exId, () => _BestsBuilder());
      if (b.maxWeight == null || w > b.maxWeight!) b.maxWeight = w;

      final orm = PRDetector.estimateOneRm(w, r);
      if (b.maxOneRm == null || orm > b.maxOneRm!) b.maxOneRm = orm;

      final prev = b.repsByWeight[w] ?? 0;
      if (r > prev) b.repsByWeight[w] = r;

      final sv = sessionVols.putIfAbsent(sid, () => {});
      sv[exId] = (sv[exId] ?? 0) + w * r;
    }

    for (final sv in sessionVols.values) {
      for (final e in sv.entries) {
        final b = builders[e.key];
        if (b == null) continue;
        if (b.maxSessionVolume == null || e.value > b.maxSessionVolume!) {
          b.maxSessionVolume = e.value;
        }
      }
    }

    return builders.map(
      (exId, b) => MapEntry(
        exId,
        ExerciseBests(
          maxWeight: b.maxWeight,
          maxOneRm: b.maxOneRm,
          maxSessionVolume: b.maxSessionVolume,
          repsByWeight: Map.unmodifiable(b.repsByWeight),
        ),
      ),
    );
  }
}

class _BestsBuilder {
  double? maxWeight;
  double? maxOneRm;
  double? maxSessionVolume;
  final repsByWeight = <double, int>{};
}
