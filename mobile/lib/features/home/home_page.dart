import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../history/data/history_repository.dart';
import '../progress/data/progress_repository.dart';
import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import '../workout/providers.dart';
import '../workout/workout_state.dart';

final _attendanceProv = FutureProvider.autoDispose<AttendanceData>(
    (_) => ProgressRepository().fetchAttendance());

final _recentSessionsProv =
    FutureProvider.autoDispose<List<HistorySession>>((ref) async {
  final all = await HistoryRepository().fetchSessions(page: 0);
  return all.take(2).toList();
});

const _weekdayNames = [
  'DOMINGO', 'LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO',
];
const _monthNames = [
  'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
  'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
];
const _dayNamesTitle = [
  'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado',
];

String _streakImagePath(int streak) {
  if (streak == 0) return 'assets/img/Dashboard/falta.webp';
  if (streak < 7) return 'assets/img/Dashboard/inicio.webp';
  if (streak < 14) return 'assets/img/Dashboard/racha_una_semana.webp';
  if (streak < 21) return 'assets/img/Dashboard/racha_dos_semas.webp';
  return 'assets/img/Dashboard/racha_tres semanas.webp';
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(trainingRoutinesProvider);
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? '';
    final firstName = _firstNameFromEmail(email);
    final now = DateTime.now();
    final todayDow = now.weekday % 7;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final workoutState = ref.watch(workoutProvider);
    final hasActiveWorkout = workoutState.status == WorkoutStatus.active ||
        workoutState.status == WorkoutStatus.loading;

    final attendance = ref.watch(_attendanceProv).maybeWhen(
      data: (d) => d,
      orElse: () => AttendanceData.empty,
    );
    final recentSessions = ref.watch(_recentSessionsProv).maybeWhen(
      data: (s) => s,
      orElse: () => <HistorySession>[],
    );

    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(routinesProvider.future),
        ref.refresh(_attendanceProv.future),
        ref.refresh(_recentSessionsProv.future),
      ]),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, topPad, 20, 100),
        children: [
          // ── Date + greeting ─────────────────────────────────────────────
          Text(
            _dateLabel(now),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            firstName.isEmpty ? 'Hola' : 'Hola, $firstName',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Streak banner ────────────────────────────────────────────────
          _StreakBanner(streak: attendance.currentStreak),
          const SizedBox(height: 16),

          // ── Attendance stats ─────────────────────────────────────────────
          _AttendanceRow(data: attendance),
          const SizedBox(height: 24),

          // ── Hero + rest of content ──────────────────────────────────────
          asyncRoutines.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (routines) {
              final today =
                  routines.where((r) => r.daysOfWeek.contains(todayDow)).firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero
                  if (hasActiveWorkout)
                    _ActiveWorkoutBanner(routineName: workoutState.routineName)
                  else if (today != null)
                    _TodayHero(routine: today, todayDow: todayDow)
                  else
                    _EmptyHero(todayDow: todayDow),

                  // Recent workouts
                  if (recentSessions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _RecentWorkoutsSection(sessions: recentSessions),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Streak banner ─────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        _streakImagePath(streak),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ── Recent workouts ───────────────────────────────────────────────────────────

class _RecentWorkoutsSection extends StatelessWidget {
  const _RecentWorkoutsSection({required this.sessions});
  final List<HistorySession> sessions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ÚLTIMOS ENTRENAMIENTOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textMuted,
                letterSpacing: 1,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/historial'),
              child: const Text(
                'Ver todos →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kSeed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final s in sessions) ...[
          _RecentSessionCard(session: s),
          if (s != sessions.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session});
  final HistorySession session;

  @override
  Widget build(BuildContext context) {
    final dur = _fmtDuration(session.durationSec);
    final dateLabel = _relativeDate(session.startedAt);

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.routineName ?? 'Entrenamiento',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.of(context).textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${session.exerciseCount} ej. · $dur',
            style: TextStyle(fontSize: 11, color: AppColors.of(context).textDisabled),
          ),
          if (session.exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: session.exercises.take(4).map((ex) {
                final label = _setsLabel(ex.sets);
                final ac = AppColors.of(context);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ac.bg,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: ac.raised(NeuroSize.sm),
                  ),
                  child: Text(
                    '${ex.exerciseName} $label',
                    style: TextStyle(
                      fontSize: 10,
                      color: ac.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

String _setsLabel(List<HistoryLog> sets) {
  final count = sets.length;
  final freq = <int, int>{};
  for (final s in sets) {
    if (s.reps != null) freq[s.reps!] = (freq[s.reps!] ?? 0) + 1;
  }
  if (freq.isEmpty) return '${count}s';
  final mostCommon =
      freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '$count×$mostCommon';
}

String _fmtDuration(int seconds) {
  final m = (seconds / 60).round();
  if (m < 60) return '${m}min';
  final h = m ~/ 60;
  final rem = m % 60;
  return rem == 0 ? '${h}h' : '${h}h ${rem}min';
}

String _relativeDate(String startedAt) {
  final dt = DateTime.tryParse(startedAt)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff < 7) return 'Hace $diff días';
  return '${dt.day}/${dt.month}';
}

// ── Active workout banner ─────────────────────────────────────────────────────

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({required this.routineName});
  final String routineName;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: true,
      size: NeuroSize.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kSeed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: kSeed, size: 14),
              ),
              const SizedBox(width: 10),
              const Text(
                'ENTRENAMIENTO EN CURSO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: kSeed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            routineName.isEmpty ? 'Cargando…' : routineName,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.of(context).textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/entrenar'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Continuar entrenamiento'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today hero ────────────────────────────────────────────────────────────────

class _TodayHero extends ConsumerWidget {
  const _TodayHero({required this.routine, required this.todayDow});
  final Routine routine;
  final int todayDow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exCount = routine.exercises.length;
    final totalSets =
        routine.exercises.fold<int>(0, (a, e) => a + e.targetSets);

    return GlassCard(
      accent: true,
      size: NeuroSize.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pill(
            text: 'RUTINA DE HOY · ${_dayNamesTitle[todayDow].toUpperCase()}',
            withDot: true,
          ),
          const SizedBox(height: 16),
          Text(
            routine.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$exCount ejercicios · $totalSets series',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.of(context).textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: exCount == 0
                ? null
                : () {
                    ref.read(workoutProvider.notifier).start(routine);
                    context.push('/entrenar');
                  },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Empezar rutina'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty hero ────────────────────────────────────────────────────────────────

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.todayDow});
  final int todayDow;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pill(text: 'HOY · ${_dayNamesTitle[todayDow].toUpperCase()}'),
          const SizedBox(height: 16),
          Text(
            'No tienes rutina asignada para hoy.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.of(context).textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go('/rutinas'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Elegir una rutina'),
          ),
        ],
      ),
    );
  }
}

// ── Pill badge ────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.withDot = false});
  final String text;
  final bool withDot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: kSeed.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kSeed.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withDot) ...[
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: kSeed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: kSeed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attendance stats row ──────────────────────────────────────────────────────

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.data});
  final AttendanceData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStat(
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orange,
          value: '${data.currentStreak}',
          label: 'Racha',
        ),
        const SizedBox(width: 8),
        _MiniStat(
          icon: Icons.calendar_view_week_rounded,
          iconColor: kSeed,
          value: '${data.thisWeekCount}',
          label: 'Semana',
        ),
        const SizedBox(width: 8),
        _MiniStat(
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFF80CBC4),
          value: '${data.thisMonthCount}',
          label: 'Mes',
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        radius: 12,
        size: NeuroSize.sm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.of(context).textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.of(context).textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _firstNameFromEmail(String email) {
  final local = email.split('@').first;
  if (local.isEmpty) return '';
  return local[0].toUpperCase() + local.substring(1);
}

String _dateLabel(DateTime d) {
  final dow = d.weekday % 7;
  final weekday = _weekdayNames[dow];
  final month = _monthNames[d.month - 1];
  return '$weekday, ${d.day} DE $month';
}
