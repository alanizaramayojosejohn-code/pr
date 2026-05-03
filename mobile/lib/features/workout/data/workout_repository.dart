import '../../../supabase/client.dart';

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
    await supabase.from('exercise_logs').upsert(
      {
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'set_number': setNumber,
        'weight': weight,
        'reps': reps,
        'rest_seconds_used': restSecondsUsed,
      },
      onConflict: 'session_id,exercise_id,set_number',
    );
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

  Future<void> finishSession(String sessionId) async {
    await supabase
        .from('workout_sessions')
        .update({'finished_at': DateTime.now().toIso8601String()})
        .eq('id', sessionId);
  }
}
