import '../../../supabase/client.dart';

class WeightPoint {
  const WeightPoint({required this.date, required this.weightKg});
  final String date;
  final double weightKg;
}

class AttendanceData {
  const AttendanceData({
    required this.workoutDays,
    required this.currentStreak,
    required this.thisWeekCount,
    required this.thisMonthCount,
    required this.totalCount,
  });
  final Set<String> workoutDays; // "YYYY-MM-DD" in local time
  final int currentStreak;
  final int thisWeekCount;
  final int thisMonthCount;
  final int totalCount;

  static const empty = AttendanceData(
    workoutDays: {},
    currentStreak: 0,
    thisWeekCount: 0,
    thisMonthCount: 0,
    totalCount: 0,
  );
}

class WeeklyCount {
  const WeeklyCount({required this.weekLabel, required this.count});
  final String weekLabel; // day number of the week's Monday
  final int count;
}

class ProgressRepository {
  Future<List<WeightPoint>> fetchWeightSeries() async {
    // El filtro por user_id no es redundante: un instructor puede leer las
    // mediciones de sus alumnos, así que sin él su propia curva de peso
    // mezclaría datos ajenos.
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supabase
        .from('body_measurements')
        .select('measured_at, weight_kg')
        .eq('user_id', userId)
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

  Future<AttendanceData> fetchAttendance() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return AttendanceData.empty;

    final res = await supabase
        .from('workout_sessions')
        .select('started_at')
        .eq('user_id', userId)
        .not('finished_at', 'is', null);

    final days = <String>{};
    for (final row in (res as List).whereType<Map<String, dynamic>>()) {
      final raw = row['started_at'] as String?;
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt != null) days.add(_dayStr(dt));
    }

    final now = DateTime.now();

    // This calendar week (Mon → Sun)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    var thisWeek = 0;
    for (var i = 0; i < 7; i++) {
      if (days.contains(_dayStr(weekStart.add(Duration(days: i))))) thisWeek++;
    }

    // This calendar month
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = days.where((d) => d.startsWith(monthPrefix)).length;

    // Current streak (counts backwards from today; grace if today not done yet)
    var check = now;
    if (!days.contains(_dayStr(now))) {
      check = now.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(_dayStr(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }

    return AttendanceData(
      workoutDays: days,
      currentStreak: streak,
      thisWeekCount: thisWeek,
      thisMonthCount: thisMonth,
      totalCount: days.length,
    );
  }

  Future<List<WeeklyCount>> fetchWeeklyWorkoutCounts({int weeks = 12}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final cutoff = currentWeekStart.subtract(Duration(days: (weeks - 1) * 7));

    final res = await supabase
        .from('workout_sessions')
        .select('started_at')
        .eq('user_id', userId)
        .not('finished_at', 'is', null)
        .gte('started_at', cutoff.toIso8601String());

    final weekCounts = <DateTime, int>{};
    for (final row in (res as List).whereType<Map<String, dynamic>>()) {
      final raw = row['started_at'] as String?;
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) continue;
      final d = DateTime(dt.year, dt.month, dt.day);
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      weekCounts[weekStart] = (weekCounts[weekStart] ?? 0) + 1;
    }

    return List.generate(weeks, (i) {
      final weekStart =
          currentWeekStart.subtract(Duration(days: (weeks - 1 - i) * 7));
      final count = weekCounts[weekStart] ?? 0;
      return WeeklyCount(weekLabel: '${weekStart.day}', count: count);
    });
  }
}

String _dayStr(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
