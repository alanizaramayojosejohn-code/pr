import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/progress_repository.dart';
import 'widgets/bar_chart.dart';
import 'widgets/line_chart.dart';

final _weightProv = FutureProvider.autoDispose<List<WeightPoint>>(
    (_) => ProgressRepository().fetchWeightSeries());

final _weeklyProv = FutureProvider.autoDispose<List<WeeklyCount>>(
    (_) => ProgressRepository().fetchWeeklyWorkoutCounts());

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 80),
      children: [
        // ── Peso corporal ────────────────────────────────────────────────────
        _SectionCard(
          title: 'Peso corporal',
          child: ref.watch(_weightProv).when(
            loading: () => const _LoadingBox(),
            error: (e, _) => _ErrorBox('$e'),
            data: (points) {
              if (points.isEmpty) {
                return const _EmptyBox('Sin medidas de peso aún');
              }
              return LineChart(
                series: [
                  ChartSeries(
                    label: 'Peso',
                    color: cs.primary,
                    points: points
                        .map((p) =>
                            ChartPoint(date: p.date, value: p.weightKg))
                        .toList(),
                  ),
                ],
                unit: 'kg',
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Entrenamientos por semana ─────────────────────────────────────────
        _SectionCard(
          title: 'Entrenamientos por semana',
          child: ref.watch(_weeklyProv).when(
            loading: () => const _LoadingBox(),
            error: (e, _) => _ErrorBox('$e'),
            data: (weeks) => WorkoutBarChart(weeks: weeks, color: cs.primary),
          ),
        ),
      ],
    );
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Error: $message',
          style: TextStyle(
              color: Theme.of(context).colorScheme.error, fontSize: 12),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 80,
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
}
