import '../../../supabase/client.dart';
import '../../routines/data/routines_repository.dart';

/// Un alumno: fila de `profiles` con `instructor_id` apuntando al instructor.
class Client {
  const Client({
    required this.id,
    required this.email,
    required this.status,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String email;
  final String status; // approved | blocked
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isBlocked => status == 'blocked';

  /// Días que le quedan de acceso. Negativo = vencido. Null = sin vencimiento.
  int? get daysLeft {
    final e = expiresAt;
    if (e == null) return null;
    return e.difference(DateTime.now()).inHours ~/ 24;
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    final expires = json['expires_at'] as String?;
    final created = json['created_at'] as String?;
    return Client(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '—',
      status: (json['status'] as String?) ?? 'approved',
      expiresAt: expires == null ? null : DateTime.parse(expires),
      createdAt: created == null ? null : DateTime.parse(created),
    );
  }
}

/// Resumen de constancia de un alumno, para que el instructor vea de un
/// vistazo si está entrenando.
class ClientActivity {
  const ClientActivity({
    required this.thisWeek,
    required this.thisMonth,
    required this.total,
    required this.streak,
    this.lastSessionAt,
    this.lastWeightKg,
    this.lastWeightAt,
  });

  final int thisWeek;
  final int thisMonth;
  final int total;
  final int streak;
  final DateTime? lastSessionAt;
  final double? lastWeightKg;
  final DateTime? lastWeightAt;

  static const empty = ClientActivity(
    thisWeek: 0,
    thisMonth: 0,
    total: 0,
    streak: 0,
  );
}

class InstructorRepository {
  // ── Alumnos ────────────────────────────────────────────────────────────────

  Future<List<Client>> fetchClients() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return [];
    final res = await supabase
        .from('profiles')
        .select('id, email, status, expires_at, created_at')
        .eq('instructor_id', me)
        .order('email', ascending: true);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(Client.fromJson)
        .toList();
  }

  // ── Rutinas del alumno ─────────────────────────────────────────────────────

  Future<List<Routine>> fetchClientRoutines(String clientId) async {
    final res = await supabase
        .from('routines')
        .select('*, routine_exercises(*, exercise:Exercise(*))')
        .eq('user_id', clientId)
        .order('name', ascending: true);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(Routine.fromJson)
        .toList();
  }

  /// Copia la plantilla a la cuenta del alumno. Si ya le habías enviado esa
  /// misma plantilla, se reescribe la copia en vez de duplicarla.
  Future<String> assignTemplate({
    required String templateId,
    required String clientId,
  }) async {
    final res = await supabase.rpc(
      'assign_routine_template',
      params: {'p_template_id': templateId, 'p_client_id': clientId},
    );
    return res as String;
  }

  Future<void> removeClientRoutine(String routineId) async {
    await supabase.from('routine_exercises').delete().eq('routine_id', routineId);
    await supabase.from('routines').delete().eq('id', routineId);
  }

  // ── Actividad ──────────────────────────────────────────────────────────────

  Future<ClientActivity> fetchClientActivity(String clientId) async {
    final sessions = await supabase
        .from('workout_sessions')
        .select('started_at')
        .eq('user_id', clientId)
        .not('finished_at', 'is', null)
        .order('started_at', ascending: false);

    final rows = (sessions as List).whereType<Map<String, dynamic>>().toList();

    final days = <String>{};
    DateTime? last;
    for (final row in rows) {
      final dt = DateTime.tryParse(row['started_at'] as String? ?? '')?.toLocal();
      if (dt == null) continue;
      days.add(_dayStr(dt));
      if (last == null || dt.isAfter(last)) last = dt;
    }

    final now = DateTime.now();

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    var thisWeek = 0;
    for (var i = 0; i < 7; i++) {
      if (days.contains(_dayStr(weekStart.add(Duration(days: i))))) thisWeek++;
    }

    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = days.where((d) => d.startsWith(monthPrefix)).length;

    // Igual que en Progreso: si hoy todavía no entrenó, la racha no se corta.
    var check = days.contains(_dayStr(now))
        ? now
        : now.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(_dayStr(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }

    final weight = await supabase
        .from('body_measurements')
        .select('measured_at, weight_kg')
        .eq('user_id', clientId)
        .not('weight_kg', 'is', null)
        .order('measured_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return ClientActivity(
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      total: days.length,
      streak: streak,
      lastSessionAt: last,
      lastWeightKg: weight == null ? null : (weight['weight_kg'] as num).toDouble(),
      lastWeightAt: weight == null
          ? null
          : DateTime.tryParse(weight['measured_at'] as String? ?? ''),
    );
  }
}

String _dayStr(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
