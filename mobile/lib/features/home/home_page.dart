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

const _quotes = [
  'El dolor de hoy es la fuerza de mañana.',
  'No pares cuando estés cansado. Para cuando hayas terminado.',
  'Cada repetición te acerca a tu mejor versión.',
  'Te vez flaco, leventa unas pesas.',
  'Tu cuerpo puede hacerlo. Es tu mente a la que tienes que convencer.',
  'El único entreno malo es el que no hiciste.',
  'Pequeñas mejoras diarias llevan a resultados sorprendentes.',
  'No te compares con otros. Compárate con quien eras ayer.',
  'El éxito no llega de la nada. Llega de un esfuerzo constante.',
  'Cada serie cuenta. Cada paso importa.',
  'Los límites existen solo en la mente.',
  'Ya se te nota el gym, sigue así ;) ',
  'Sé más fuerte que tus excusas.',
  'El esfuerzo de hoy es el resultado de mañana.',
  'Recuerda maximo peso posible con tecnica perfecta!',
  'Entrena, come, duerme y repite.',
  'La disciplina es elegir entre lo que quieres ahora y lo que mas quieres.',
  'Nunca te arrepentirás de un entrenamiento.',
  'Hoy es un gran día para ser tu mejor versión.',
  'Cada gota de sudor es un paso más hacia tu meta.',
  'Los grandes resultados requieren grandes esfuerzos.',
  'Tu potencial no tiene límites.',
  'La motivación te arranca, el hábito te mantiene.',
  'Confía en el proceso.',
  'Un día a la vez, una rep a la vez.',
  'El cuerpo logra lo que la mente cree.',
  'Se consistente. El tiempo hara el resto.',
  'Desafía tus límites todos los días.',
  'Cada entrenamiento es una versión mejorada de ti mismo.',
  '¿Y esa estética? ;)',
  '¡Deja de perder tiempo y ponte a entrenar!',
];

String _quoteOfTheDay() {
  final dayOfYear =
      DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
  return _quotes[dayOfYear % _quotes.length];
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(routinesProvider);
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
              color: const Color(0xF2FFFFFF),
            ),
          ),
          const SizedBox(height: 20),

          // ── Quote of the day ────────────────────────────────────────────
          _QuoteCard(quote: _quoteOfTheDay()),
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

// ── Quote card ────────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: kSeed.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Text(
        '"$quote"',
        style: const TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Color(0xCCFFFFFF),
          height: 1.6,
        ),
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
            const Text(
              'ÚLTIMOS ENTRENAMIENTOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0x80FFFFFF),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xF2FFFFFF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${session.exerciseCount} ej. · $dur',
            style: const TextStyle(fontSize: 11, color: Color(0x66FFFFFF)),
          ),
          if (session.exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: session.exercises.take(4).map((ex) {
                final label = _setsLabel(ex.sets);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kGlassBorder),
                  ),
                  child: Text(
                    '${ex.exerciseName} $label',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xCCFFFFFF),
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
      borderOpacity: 0.20,
      fillOpacity: 0.09,
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xF2FFFFFF),
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
      borderOpacity: 0.16,
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Color(0xF2FFFFFF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$exCount ejercicios · $totalSets series',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0x80FFFFFF),
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
          const Text(
            'No tenés rutina asignada para hoy.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0x99FFFFFF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go('/rutinas'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              foregroundColor: const Color(0xCCFFFFFF),
              side: const BorderSide(color: kGlassBorderStrong),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xF2FFFFFF),
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0x80FFFFFF),
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
