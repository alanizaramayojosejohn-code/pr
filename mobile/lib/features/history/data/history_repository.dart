import '../../../supabase/client.dart';

class HistoryLog {
  const HistoryLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    this.weight,
    this.reps,
    this.restSecondsUsed,
  });
  final int exerciseId;
  final String exerciseName;
  final int setNumber;
  final double? weight;
  final int? reps;
  final int? restSecondsUsed;
}

class HistoryExerciseGroup {
  const HistoryExerciseGroup({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.maxWeight,
    required this.totalVolume,
  });
  final int exerciseId;
  final String exerciseName;
  final List<HistoryLog> sets;
  final double? maxWeight;
  final double totalVolume;
}

class HistorySession {
  const HistorySession({
    required this.id,
    required this.routineName,
    required this.startedAt,
    required this.durationSec,
    required this.totalSets,
    required this.totalVolume,
    required this.exerciseCount,
    required this.exercises,
  });
  final String id;
  final String? routineName;
  final String startedAt;
  final int durationSec;
  final int totalSets;
  final double totalVolume;
  final int exerciseCount;
  final List<HistoryExerciseGroup> exercises;
}

class HistoryRepository {
  static const pageSize = 8;

  Future<List<HistorySession>> fetchSessions({int page = 0}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final ss = await supabase
        .from('workout_sessions')
        .select('id, routine_id, started_at, finished_at, routines(name)')
        .eq('user_id', userId)
        .not('finished_at', 'is', null)
        .order('started_at', ascending: false)
        .range(page * pageSize, page * pageSize + pageSize - 1);

    final rawSessions = (ss as List).whereType<Map<String, dynamic>>().toList();
    if (rawSessions.isEmpty) return [];

    final ids = rawSessions.map((s) => s['id'] as String).toList();
    final logsRes = await supabase
        .from('exercise_logs')
        .select('session_id, exercise_id, set_number, weight, reps, rest_seconds_used')
        .inFilter('session_id', ids)
        .order('set_number', ascending: true);

    final rawLogs = (logsRes as List).whereType<Map<String, dynamic>>().toList();

    // Fetch exercise names separately to avoid FK join dependency
    final exerciseIds = rawLogs
        .map((l) => (l['exercise_id'] as num).toInt())
        .toSet()
        .toList();
    final nameMap = <int, String>{};
    if (exerciseIds.isNotEmpty) {
      final exRes = await supabase
          .from('Exercise')
          .select('id, name')
          .inFilter('id', exerciseIds);
      for (final row in (exRes as List).whereType<Map<String, dynamic>>()) {
        nameMap[(row['id'] as num).toInt()] = (row['name'] as String?) ?? '—';
      }
    }

    final logsBySession = <String, List<Map<String, dynamic>>>{};
    for (final l in rawLogs) {
      final sid = l['session_id'] as String;
      // Inject the name so _buildSession can use it
      l['_exerciseName'] = nameMap[(l['exercise_id'] as num).toInt()] ?? '—';
      logsBySession.putIfAbsent(sid, () => []).add(l);
    }

    return rawSessions
        .map((s) => _buildSession(s, logsBySession[s['id'] as String] ?? []))
        .toList();
  }

  HistorySession _buildSession(
    Map<String, dynamic> s,
    List<Map<String, dynamic>> logs,
  ) {
    final groups = <int, _GroupBuilder>{};
    var totalVolume = 0.0;

    for (final l in logs) {
      final exId = (l['exercise_id'] as num).toInt();
      final exName = l['_exerciseName'] as String? ?? '—';
      final w = l['weight'] == null ? null : (l['weight'] as num).toDouble();
      final r = l['reps'] == null ? null : (l['reps'] as num).toInt();
      final rest = l['rest_seconds_used'] == null
          ? null
          : (l['rest_seconds_used'] as num).toInt();

      final g = groups.putIfAbsent(exId, () => _GroupBuilder(exId, exName));
      g.sets.add(HistoryLog(
        exerciseId: exId,
        exerciseName: exName,
        setNumber: (l['set_number'] as num).toInt(),
        weight: w,
        reps: r,
        restSecondsUsed: rest,
      ));
      if (w != null && r != null) {
        final vol = w * r;
        g.totalVolume += vol;
        totalVolume += vol;
        if (g.maxWeight == null || w > g.maxWeight!) g.maxWeight = w;
      }
    }

    final startedAt = s['started_at'] as String;
    final finishedAt = s['finished_at'] as String;
    final duration = DateTime.parse(finishedAt)
            .difference(DateTime.parse(startedAt))
            .inSeconds
            .clamp(0, double.maxFinite.toInt());

    final exercises = groups.values
        .map((g) => HistoryExerciseGroup(
              exerciseId: g.exerciseId,
              exerciseName: g.exerciseName,
              sets: g.sets,
              maxWeight: g.maxWeight,
              totalVolume: g.totalVolume,
            ))
        .toList();

    return HistorySession(
      id: s['id'] as String,
      routineName: (s['routines'] as Map?)?['name'] as String?,
      startedAt: startedAt,
      durationSec: duration,
      totalSets: logs.length,
      totalVolume: totalVolume,
      exerciseCount: groups.length,
      exercises: exercises,
    );
  }

  Future<void> deleteSession(String id) async {
    await supabase.from('exercise_logs').delete().eq('session_id', id);
    await supabase.from('workout_sessions').delete().eq('id', id);
  }
}

class _GroupBuilder {
  _GroupBuilder(this.exerciseId, this.exerciseName);
  final int exerciseId;
  final String exerciseName;
  final List<HistoryLog> sets = [];
  double? maxWeight;
  double totalVolume = 0;
}
