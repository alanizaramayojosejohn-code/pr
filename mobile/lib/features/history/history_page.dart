import 'package:flutter/material.dart';

import 'data/history_repository.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = HistoryRepository();
  final _sessions = <HistorySession>[];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 0;
        _sessions.clear();
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = reset ? 0 : _page;
      final result = await _repo.fetchSessions(page: page);
      if (!mounted) return;
      setState(() {
        _sessions.addAll(result);
        _page = page + 1;
        _hasMore = result.length == HistoryRepository.pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPad, 16, 80),
          children: [
            Center(
              child: Text(
                'Sin entrenos aún',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 80),
        itemCount: _sessions.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _sessions.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: _loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton(
                      onPressed: () => _load(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cargar más'),
                    ),
            );
          }
          return _SessionCard(
            session: _sessions[i],
            onDeleted: () => _load(reset: true),
          );
        },
      ),
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
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Always-visible summary ──────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_expanded ? 0 : 12),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Routine name + date
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.routineName ?? 'Sin rutina',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_fmtDate(s.startedAt), style: labelStyle),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Duration + volume
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(_fmtDur(s.durationSec), style: labelStyle),
                      const SizedBox(width: 14),
                      Icon(Icons.fitness_center,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${_fmtVol(s.totalVolume)} kg', style: labelStyle),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Exercise summary list
                  ...s.exercises.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.exerciseName,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _setsLabel(g.sets),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Expand chevron
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded detail ─────────────────────────────────────────────
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

// "3×12" — uses most-common rep count across done sets
String _setsLabel(List<HistoryLog> sets) {
  final count = sets.length;
  if (count == 0) return '—';
  final reps = sets.map((s) => s.reps).whereType<int>().toList();
  if (reps.isEmpty) return '$count series';
  final freq = <int, int>{};
  for (final r in reps) {
    freq[r] = (freq[r] ?? 0) + 1;
  }
  final mostCommon =
      freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '$count×$mostCommon';
}
