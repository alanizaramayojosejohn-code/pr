import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/history_repository.dart';

final _historyProv = FutureProvider.autoDispose<List<HistorySession>>(
    (_) => HistoryRepository().fetchSessions());

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_historyProv).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'Sin entrenos aún',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_historyProv.future),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: sessions.length,
            itemBuilder: (_, i) => _SessionCard(
              session: sessions[i],
              onDeleted: () => ref.refresh(_historyProv.future),
            ),
          ),
        );
      },
    );
  }
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  const _SessionCard({required this.session, required this.onDeleted});
  final HistorySession session;
  final VoidCallback onDeleted;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
              bottom: Radius.circular(12),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.routineName ?? 'Sin rutina',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtDate(s.startedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _StatChips(session: s),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            _SessionDetail(session: s),
            const Divider(height: 1),
            _DeleteBar(session: s, onDeleted: widget.onDeleted),
          ],
        ],
      ),
    );
  }
}

// ─── Stat chips ───────────────────────────────────────────────────────────────

class _StatChips extends StatelessWidget {
  const _StatChips({required this.session});
  final HistorySession session;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Wrap(
      spacing: 12,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.timer_outlined, size: 12),
          const SizedBox(width: 3),
          Text(_fmtDur(session.durationSec), style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fitness_center, size: 12),
          const SizedBox(width: 3),
          Text('${_fmtVol(session.totalVolume)} kg', style: style),
        ]),
        Text(
          '${session.totalSets} series · ${session.exerciseCount} ej',
          style: style,
        ),
      ],
    );
  }
}

// ─── Session detail (exercise tables) ────────────────────────────────────────

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session});
  final HistorySession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: session.exercises.map((g) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    g.exerciseName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                    2: IntrinsicColumnWidth(),
                  },
                  children: [
                    TableRow(
                      decoration:
                          BoxDecoration(color: cs.surfaceContainerHighest),
                      children: [
                        _th('Serie'),
                        _th('Peso (kg)'),
                        _th('Reps'),
                      ],
                    ),
                    ...g.sets.map((set) => TableRow(
                          children: [
                            _td('${set.setNumber}'),
                            _td(set.weight != null
                                ? _fmtNum(set.weight!)
                                : '—'),
                            _td(set.reps != null ? '${set.reps}' : '—'),
                          ],
                        )),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

Widget _th(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(t,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );

Widget _td(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(t, style: const TextStyle(fontSize: 12)),
    );

// ─── Delete bar ───────────────────────────────────────────────────────────────

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.session, required this.onDeleted});
  final HistorySession session;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Eliminar'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar entreno'),
                  content: const Text(
                      '¿Seguro? Esta acción no se puede deshacer.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await HistoryRepository().deleteSession(session.id);
                onDeleted();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _months = [
  '',
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _weekdays = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String _fmtDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${_weekdays[dt.weekday]} ${dt.day} ${_months[dt.month]} ${dt.year}';
  } catch (_) {
    return iso;
  }
}

String _fmtDur(int sec) {
  if (sec < 3600) return '${sec ~/ 60} min';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  return m > 0 ? '${h}h ${m}min' : '${h}h';
}

String _fmtVol(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
