import '../../../supabase/client.dart';

class WeightPoint {
  const WeightPoint({required this.date, required this.weightKg});
  final String date;
  final double weightKg;
}

class StrengthPoint {
  const StrengthPoint({
    required this.date,
    required this.maxWeight,
    required this.best1rm,
  });
  final String date;
  final double maxWeight;
  final double best1rm;
}

class ExerciseOption {
  const ExerciseOption({
    required this.id,
    required this.name,
    required this.sessions,
  });
  final int id;
  final String name;
  final int sessions;
}

double _epley(double weight, int reps) {
  if (reps <= 1) return weight;
  return weight * (1 + reps / 30);
}

class ProgressRepository {
  Future<List<WeightPoint>> fetchWeightSeries() async {
    final res = await supabase
        .from('body_measurements')
        .select('measured_at, weight_kg')
        .not('weight_kg', 'is', null)
        .order('measured_at', ascending: true);

    final byDay = <String, ({double sum, int count})>{};
    for (final row in (res as List).whereType<Map<String, dynamic>>()) {
      final date = row['measured_at'] as String;
      final w = (row['weight_kg'] as num).toDouble();
      final cur = byDay[date];
      if (cur == null) {
        byDay[date] = (sum: w, count: 1);
      } else {
        byDay[date] = (sum: cur.sum + w, count: cur.count + 1);
      }
    }

    return byDay.entries
        .map((e) => WeightPoint(date: e.key, weightKg: e.value.sum / e.value.count))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<ExerciseOption>> fetchExerciseOptions() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supabase
        .from('exercise_logs')
        .select(
            'exercise_id, session_id, Exercise!inner(id, name), workout_sessions!inner(user_id, finished_at)')
        .not('weight', 'is', null)
        .not('reps', 'is', null)
        .eq('workout_sessions.user_id', userId)
        .not('workout_sessions.finished_at', 'is', null);

    final agg = <int, ({String name, Set<String> sessions})>{};
    for (final row in (res as List).whereType<Map<String, dynamic>>()) {
      final exId = (row['exercise_id'] as num).toInt();
      final exName = (row['Exercise'] as Map?)?['name'] as String? ?? '—';
      final sid = row['session_id'] as String;
      final entry = agg[exId];
      if (entry == null) {
        agg[exId] = (name: exName, sessions: {sid});
      } else {
        entry.sessions.add(sid);
      }
    }

    return agg.entries
        .map((e) => ExerciseOption(
              id: e.key,
              name: e.value.name,
              sessions: e.value.sessions.length,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<StrengthPoint>> fetchStrengthSeries(int exerciseId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supabase
        .from('exercise_logs')
        .select(
            'weight, reps, workout_sessions!inner(started_at, user_id, finished_at)')
        .eq('exercise_id', exerciseId)
        .not('weight', 'is', null)
        .not('reps', 'is', null)
        .eq('workout_sessions.user_id', userId)
        .not('workout_sessions.finished_at', 'is', null);

    final byDay = <String, ({double maxW, double best1rm})>{};
    for (final row in (res as List).whereType<Map<String, dynamic>>()) {
      final sess = row['workout_sessions'] as Map<String, dynamic>?;
      if (sess == null) continue;
      final date = (sess['started_at'] as String).substring(0, 10);
      final w = (row['weight'] as num).toDouble();
      final r = (row['reps'] as num).toInt();
      final rm = _epley(w, r);
      final cur = byDay[date];
      if (cur == null) {
        byDay[date] = (maxW: w, best1rm: rm);
      } else {
        byDay[date] = (
          maxW: w > cur.maxW ? w : cur.maxW,
          best1rm: rm > cur.best1rm ? rm : cur.best1rm,
        );
      }
    }

    return byDay.entries
        .map((e) => StrengthPoint(
              date: e.key,
              maxWeight: e.value.maxW,
              best1rm: e.value.best1rm,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
