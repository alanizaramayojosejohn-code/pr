import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/progress_repository.dart';
import 'widgets/line_chart.dart';

final _weightProv = FutureProvider.autoDispose<List<WeightPoint>>(
    (_) => ProgressRepository().fetchWeightSeries());

final _exerciseOptsProv = FutureProvider.autoDispose<List<ExerciseOption>>(
    (_) => ProgressRepository().fetchExerciseOptions());

final _strengthProv =
    FutureProvider.autoDispose.family<List<StrengthPoint>, int>(
        (_, id) => ProgressRepository().fetchStrengthSeries(id));

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  int? _selectedExId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // ── Weight ──────────────────────────────────────────────────────────
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

        // ── Strength ─────────────────────────────────────────────────────────
        _SectionCard(
          title: 'Progresión de fuerza',
          child: ref.watch(_exerciseOptsProv).when(
            loading: () => const _LoadingBox(),
            error: (e, _) => _ErrorBox('$e'),
            data: (opts) {
              if (opts.isEmpty) {
                return const _EmptyBox('Sin entrenos registrados');
              }
              final selId = _selectedExId ?? opts.first.id;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(selId),
                    initialValue: selId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: opts
                        .map((o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(
                                '${o.name} (${o.sessions})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedExId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  ref.watch(_strengthProv(selId)).when(
                    loading: () => const _LoadingBox(),
                    error: (e, _) => _ErrorBox('$e'),
                    data: (pts) {
                      if (pts.isEmpty) {
                        return const _EmptyBox(
                            'Sin datos para este ejercicio');
                      }
                      return LineChart(
                        series: [
                          ChartSeries(
                            label: 'Peso máx',
                            color: cs.primary,
                            points: pts
                                .map((p) => ChartPoint(
                                    date: p.date, value: p.maxWeight))
                                .toList(),
                          ),
                          ChartSeries(
                            label: '1RM estimado',
                            color: cs.tertiary,
                            points: pts
                                .map((p) => ChartPoint(
                                    date: p.date, value: p.best1rm))
                                .toList(),
                          ),
                        ],
                        unit: 'kg',
                      );
                    },
                  ),
                ],
              );
            },
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
