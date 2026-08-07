import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final ac = AppColors.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 80),
        itemCount: _sessions.isEmpty ? 1 : _sessions.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (_sessions.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: ac.textDisabled),
                  const SizedBox(height: 12),
                  Text('Sin entrenos aún', style: TextStyle(color: ac.textMuted)),
                ],
              ),
            );
          }
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
                        side: BorderSide(
                            color: ac.glassBorderBase.withValues(alpha: 0.15)),
                      ),
                      child: const Text('Cargar más'),
                    ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SessionCard(
              session: _sessions[i],
              onDeleted: () => _load(reset: true),
            ),
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
    final ac = AppColors.of(context);

    return GlassCard(
      radius: 14,
      padding: EdgeInsets.zero,
      borderOpacity: 0.10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.routineName ?? 'Sin rutina',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ac.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtDate(s.startedAt),
                        style: TextStyle(fontSize: 11, color: ac.textDisabled),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: ac.textMuted),
                      const SizedBox(width: 3),
                      Text(_fmtDur(s.durationSec),
                          style: TextStyle(fontSize: 11, color: ac.textMuted)),
                      const SizedBox(width: 10),
                      Icon(Icons.fitness_center_outlined, size: 12, color: ac.textMuted),
                      const SizedBox(width: 3),
                      Text('${s.exerciseCount} ej.',
                          style: TextStyle(fontSize: 11, color: ac.textMuted)),
                    ],
                  ),
                  if (s.exercises.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: s.exercises.take(4).map((ex) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ac.glassBorderBase.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: ac.glassBorderBase.withValues(alpha: 0.10)),
                          ),
                          child: Text(
                            '${ex.exerciseName} ${_setsLabel(ex.sets)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: ac.textMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: ac.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: ac.dividerColor),
            _SessionDetail(session: s),
            Divider(height: 1, color: ac.dividerColor),
            _DeleteBar(session: s, onDeleted: widget.onDeleted),
          ],
        ],
      ),
    );
  }
}

// ─── Session detail ───────────────────────────────────────────────────────────

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session});
  final HistorySession session;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: session.exercises.map((g) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.exerciseName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kSeed,
                  ),
                ),
                const SizedBox(height: 6),
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                    2: IntrinsicColumnWidth(),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: ac.glassBorderBase.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      children: [
                        _th('Serie', ac),
                        _th('Peso (kg)', ac),
                        _th('Reps', ac),
                      ],
                    ),
                    ...g.sets.map((set) => TableRow(children: [
                          _td('${set.setNumber}', ac),
                          _td(set.weight != null ? _fmtNum(set.weight!) : '—', ac),
                          _td(set.reps != null ? '${set.reps}' : '—', ac),
                        ])),
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

Widget _th(String t, AppColors ac) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ac.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );

Widget _td(String t, AppColors ac) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(t, style: TextStyle(fontSize: 12, color: ac.textMedium)),
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
                  content: const Text('¿Seguro? Esta acción no se puede deshacer.'),
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
  '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _weekdays = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String _fmtDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${_weekdays[dt.weekday]} ${dt.day} ${_months[dt.month]}';
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

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

String _setsLabel(List<HistoryLog> sets) {
  final count = sets.length;
  if (count == 0) return '—';
  final reps = sets.map((s) => s.reps).whereType<int>().toList();
  if (reps.isEmpty) return '$count series';
  final freq = <int, int>{};
  for (final r in reps) { freq[r] = (freq[r] ?? 0) + 1; }
  final mostCommon =
      freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '$count×$mostCommon';
}
