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
    final asyncRoutines = ref.watch(routinesProvider);
    final todayDow = DateTime.now().weekday % 7;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(routinesProvider.future),
        child: asyncRoutines.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (routines) => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Nueva rutina button ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad, 16, 16),
                  child: FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Nueva rutina'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              // ── Grid or empty state ──────────────────────────────────────
              if (routines.isEmpty)
                SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no tenés rutinas.',
                        style: TextStyle(
                            color: Color(0x80FFFFFF), height: 1.5),
                      ),
                    ],
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _RoutineCard(
                        routine: routines[i],
                        isToday: routines[i].daysOfWeek.contains(todayDow),
                      ),
                      childCount: routines.length,
                    ),
                  ),
                ),
            ],
          ),
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
    return GestureDetector(
      onTap: () => context.push('/rutinas/${routine.id}'),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        borderOpacity: isToday ? 0.35 : 0.10,
        fillOpacity: isToday ? 0.09 : 0.06,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(routine: routine, isToday: isToday),
            const SizedBox(height: 10),
            Text(
              routine.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xF2FFFFFF),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statsLabel(routine),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0x80FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.routine, required this.isToday});
  final Routine routine;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final label = _badgeLabel(routine, isToday);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? kSeed.withValues(alpha: 0.18) : kGlassFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isToday ? kSeed.withValues(alpha: 0.35) : kGlassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: isToday ? kSeed : const Color(0x80FFFFFF),
        ),
      ),
    );
  }
}

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
      ],
    );
  }
}
