import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/routines_repository.dart';
import 'providers.dart';

const _dayNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(routinesProvider);
    final todayDow = DateTime.now().weekday % 7; // Dart: Mon=1..Sun=7 → Sun=0..Sat=6

    return RefreshIndicator(
      onRefresh: () => ref.refresh(routinesProvider.future),
      child: asyncRoutines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (routines) {
          if (routines.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Aún no tienes rutinas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: routines.length,
            itemBuilder: (context, i) => _RoutineCard(
              routine: routines[i],
              isToday: routines[i].dayOfWeek == todayDow,
            ),
          );
        },
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.isToday});

  final Routine routine;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isToday ? cs.primary : cs.outlineVariant,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/rutinas/${routine.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(routine: routine, isToday: isToday),
              const SizedBox(height: 10),
              Text(
                routine.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statsLabel(routine),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;
    final label = _badgeLabel(routine, isToday);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: isToday ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _badgeLabel(Routine r, bool isToday) {
  if (r.dayOfWeek == null) return 'SIN DÍA';
  final name = _dayNames[r.dayOfWeek!].toUpperCase();
  return isToday ? 'HOY · $name' : name;
}

String _statsLabel(Routine r) {
  final exCount = r.exercises.length;
  if (exCount == 0) return 'Sin ejercicios';
  final totalSets = r.exercises.fold<int>(0, (a, e) => a + e.targetSets);
  final totalRest = r.exercises.fold<int>(
    0,
    (a, e) => a + e.targetSets * e.restSeconds,
  );
  final raw = (totalSets * 30 + totalRest) / 60;
  final minutes = (raw / 5).round() * 5;
  final shown = minutes < 5 ? 5 : minutes;
  return '$exCount ej. · ~$shown min';
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
        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(
          'No se pudieron cargar las rutinas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
