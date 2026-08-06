import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import 'data/routines_repository.dart';
import 'providers.dart';
import 'routine_form_page.dart';

class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(trainingRoutinesProvider);
    final todayDow = DateTime.now().weekday % 7;
    final ac = AppColors.of(context);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncRoutines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (routines) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPad, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rutinas',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: ac.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showCreateDialog(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: kSeed,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: kSeed.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFF0F2318)),
                            SizedBox(width: 6),
                            Text(
                              'Nueva',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F2318),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (routines.isEmpty)
              SliverFillRemaining(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center_outlined,
                        size: 48, color: ac.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes rutinas.',
                      style: TextStyle(color: ac.textMuted, height: 1.5),
                    ),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 172,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == routines.length) {
                        return _AddCard(
                            onTap: () => _showCreateDialog(context, ref));
                      }
                      return _RoutineCard(
                        routine: routines[i],
                        isToday: routines[i].daysOfWeek.contains(todayDow),
                      );
                    },
                    childCount: routines.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoutineFormPage(
          title: 'Nueva rutina',
          onSave: (name, days) async {
            final repo = ref.read(routinesRepositoryProvider);
            await repo.createRoutine(name: name, daysOfWeek: days);
            ref.invalidate(routinesProvider);
          },
        ),
      ),
    );
  }
}

// ── Routine card ──────────────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.isToday});
  final Routine routine;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/rutinas/${routine.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ac.bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isToday
              ? [
                  ...ac.raised(NeuroSize.md),
                  BoxShadow(
                    color: kSeed.withValues(alpha: 0.12),
                    blurRadius: 22,
                  ),
                ]
              : ac.raised(NeuroSize.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayChip(routine: routine, isToday: isToday),
            const SizedBox(height: 10),
            Text(
              routine.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ac.textPrimary,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statsLabel(routine),
              style: TextStyle(fontSize: 11, color: ac.textMuted),
            ),
            const Spacer(),
            _EmpezarButton(isToday: isToday, routineId: routine.id),
          ],
        ),
      ),
    );
  }
}

// ── Day chip ──────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({required this.routine, required this.isToday});
  final Routine routine;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final label = _badgeLabel(routine, isToday);
    if (isToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: kSeed,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Color(0xFF0F2318),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: ac.raised(NeuroSize.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: ac.textMuted,
        ),
      ),
    );
  }
}

// ── Empezar button ────────────────────────────────────────────────────────────

class _EmpezarButton extends StatelessWidget {
  const _EmpezarButton({required this.isToday, required this.routineId});
  final bool isToday;
  final String routineId;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/rutinas/$routineId'),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: isToday ? kSeed : ac.bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isToday
              ? [BoxShadow(color: kSeed.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))]
              : ac.raised(NeuroSize.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: isToday ? const Color(0xFF0F2318) : ac.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Empezar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isToday ? const Color(0xFF0F2318) : ac.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add card ──────────────────────────────────────────────────────────────────

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ac.bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ac.pressed(NeuroSize.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ac.bg,
                shape: BoxShape.circle,
                boxShadow: ac.raised(NeuroSize.sm),
              ),
              child: Icon(Icons.add, size: 16, color: kSeed),
            ),
            const SizedBox(height: 10),
            Text(
              'Nueva rutina',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ac.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Crear desde cero',
              style: TextStyle(fontSize: 10, color: ac.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _badgeLabel(Routine r, bool isToday) {
  if (r.daysOfWeek.isEmpty) return 'SIN DÍA';
  const shorts = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
  final sorted = [...r.daysOfWeek]..sort();
  final label = sorted.map((d) => shorts[d]).join(' · ');
  return isToday ? 'HOY · $label' : label;
}

String _statsLabel(Routine r) {
  final exCount = r.exercises.length;
  if (exCount == 0) return 'Sin ejercicios';
  final totalSets = r.exercises.fold<int>(0, (a, e) => a + e.targetSets);
  final totalRest =
      r.exercises.fold<int>(0, (a, e) => a + e.targetSets * e.restSeconds);
  final raw = (totalSets * 30 + totalRest) / 60;
  final minutes = (raw / 5).round() * 5;
  return '$exCount ej. · ~${minutes < 5 ? 5 : minutes} min';
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline,
            size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text('No se pudieron cargar las rutinas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: ac.textMuted, fontSize: 12)),
      ],
    );
  }
}
