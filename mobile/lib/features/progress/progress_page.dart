import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../measurements/data/measurements_repository.dart';
import '../measurements/providers.dart';
import 'data/progress_repository.dart';
import 'widgets/bar_chart.dart';
import 'widgets/line_chart.dart';

final _weightProv = FutureProvider.autoDispose<List<WeightPoint>>(
    (_) => ProgressRepository().fetchWeightSeries());

final _weeklyProv = FutureProvider.autoDispose<List<WeeklyCount>>(
    (_) => ProgressRepository().fetchWeeklyWorkoutCounts());

const _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} de ${_monthNames[d.month - 1]} de ${d.year}';
}

String _fmtNum(double? v) {
  if (v == null) return '';
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  int _tab = 0;
  bool _showForm = false;
  DateTime _formDate = DateTime.now();
  late final Map<String, TextEditingController> _fieldCtrls;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fieldCtrls = {
      for (final f in kMeasurementFields) f.key: TextEditingController(),
    };
    for (final c in _fieldCtrls.values) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _fieldCtrls.values) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _hasAnyValue => kMeasurementFields.any((f) {
        final v = _fieldCtrls[f.key]?.text.trim() ?? '';
        return v.isNotEmpty && double.tryParse(v) != null;
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _formDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _formDate = picked);
  }

  Future<void> _createMeasurement() async {
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'measured_at': _formDate.toIso8601String().substring(0, 10),
    };
    for (final f in kMeasurementFields) {
      final v = double.tryParse(_fieldCtrls[f.key]?.text.trim() ?? '');
      if (v != null) payload[f.key] = v;
    }
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) payload['notes'] = notes;

    final ok = await ref.read(measurementsProvider.notifier).create(payload);
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) {
          _showForm = false;
          _formDate = DateTime.now();
          for (final c in _fieldCtrls.values) {
            c.clear();
          }
          _notesCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_weightProv);
        ref.invalidate(_weeklyProv);
        ref.invalidate(measurementsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 100),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progreso',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: ac.textPrimary,
                  ),
                ),
              ),
              if (_tab == 1)
                GestureDetector(
                  onTap: () => setState(() => _showForm = !_showForm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: ac.bg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: _showForm
                          ? ac.pressed(NeuroSize.sm)
                          : [
                              ...ac.raised(NeuroSize.sm),
                              BoxShadow(
                                  color: kSeed.withValues(alpha: 0.12),
                                  blurRadius: 12),
                            ],
                      border: Border.all(
                          color: kSeed.withValues(
                              alpha: _showForm ? 0.15 : 0.30),
                          width: 1),
                    ),
                    child: Text(
                      _showForm ? 'Cancelar' : '+ Nueva medida',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _showForm ? ac.textMuted : kSeed,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tab switcher ─────────────────────────────────────────────────
          _NeuroTabSwitcher(
            tab: _tab,
            onChanged: (t) => setState(() {
              _tab = t;
              _showForm = false;
            }),
          ),
          const SizedBox(height: 20),

          // ── Content ──────────────────────────────────────────────────────
          if (_tab == 0) ...[
            _SectionCard(
              title: 'Peso corporal',
              icon: Icons.monitor_weight_outlined,
              child: ref.watch(_weightProv).when(
                loading: () => const _LoadingBox(),
                error: (e, _) => _ErrorBox('$e'),
                data: (points) => points.isEmpty
                    ? const _EmptyBox(
                        'Registra tu peso en Medidas para ver el gráfico')
                    : LineChart(
                        series: [
                          ChartSeries(
                            label: 'Peso',
                            color: cs.primary,
                            points: points
                                .map((p) => ChartPoint(
                                    date: p.date, value: p.weightKg))
                                .toList(),
                          ),
                        ],
                        unit: 'kg',
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Entrenamientos / semana',
              icon: Icons.bar_chart_rounded,
              child: ref.watch(_weeklyProv).when(
                loading: () => const _LoadingBox(),
                error: (e, _) => _ErrorBox('$e'),
                data: (weeks) => weeks.isEmpty
                    ? const _EmptyBox(
                        'Completa tu primer entreno para ver estadísticas')
                    : WorkoutBarChart(weeks: weeks, color: cs.primary),
              ),
            ),
          ] else ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _showForm
                  ? _NewMeasurementForm(
                      date: _formDate,
                      fieldCtrls: _fieldCtrls,
                      notesCtrl: _notesCtrl,
                      saving: _saving,
                      hasAnyValue: _hasAnyValue,
                      onPickDate: _pickDate,
                      onSave: _createMeasurement,
                    )
                  : const SizedBox.shrink(),
            ),
            ref.watch(measurementsProvider).when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(e.toString(),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
              data: (ms) {
                if (ms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten_outlined,
                            size: 48, color: ac.textDisabled),
                        const SizedBox(height: 12),
                        Text('Aún no registraste medidas.',
                            style: TextStyle(color: ac.textMuted)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: ms
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MeasurementCard(
                                key: ValueKey(m.id), m: m),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab Switcher ──────────────────────────────────────────────────────────────

class _NeuroTabSwitcher extends StatelessWidget {
  const _NeuroTabSwitcher({required this.tab, required this.onChanged});
  final int tab;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ac.pressed(NeuroSize.sm),
      ),
      child: Row(
        children: [
          _TabOption(
              label: 'Gráficas',
              value: 0,
              current: tab,
              onChanged: onChanged),
          const SizedBox(width: 4),
          _TabOption(
              label: 'Medidas',
              value: 1,
              current: tab,
              onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TabOption extends StatelessWidget {
  const _TabOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int current;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isActive = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ac.bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? ac.raised(NeuroSize.sm) : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? kSeed : ac.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return NeuroCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kSeed),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ac.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── New Measurement Form ──────────────────────────────────────────────────────

class _NewMeasurementForm extends StatelessWidget {
  const _NewMeasurementForm({
    required this.date,
    required this.fieldCtrls,
    required this.notesCtrl,
    required this.saving,
    required this.hasAnyValue,
    required this.onPickDate,
    required this.onSave,
  });

  final DateTime date;
  final Map<String, TextEditingController> fieldCtrls;
  final TextEditingController notesCtrl;
  final bool saving;
  final bool hasAnyValue;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeuroCard(
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: onPickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: kSeed),
                  const SizedBox(width: 8),
                  Text(
                    _fmtDate(date.toIso8601String().substring(0, 10)),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kSeed,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18, color: kSeed),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FieldGrid(fieldCtrls: fieldCtrls),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: (saving || !hasAnyValue) ? null : onSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fieldCtrls});
  final Map<String, TextEditingController> fieldCtrls;

  @override
  Widget build(BuildContext context) {
    final pairs = <Widget>[];
    for (var i = 0; i < kMeasurementFields.length; i += 2) {
      final a = kMeasurementFields[i];
      final b =
          i + 1 < kMeasurementFields.length ? kMeasurementFields[i + 1] : null;
      pairs.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                  child: _NumInput(
                      field: a, controller: fieldCtrls[a.key]!)),
              if (b != null) ...[
                const SizedBox(width: 10),
                Expanded(
                    child: _NumInput(
                        field: b, controller: fieldCtrls[b.key]!)),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: pairs);
  }
}

// ── Measurement Card ──────────────────────────────────────────────────────────

class _MeasurementCard extends ConsumerStatefulWidget {
  const _MeasurementCard({required super.key, required this.m});
  final BodyMeasurement m;

  @override
  ConsumerState<_MeasurementCard> createState() => _MeasurementCardState();
}

class _MeasurementCardState extends ConsumerState<_MeasurementCard> {
  late final Map<String, TextEditingController> _ctrls;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in kMeasurementFields)
        f.key: TextEditingController(
            text: _fmtNum(widget.m.fieldValue(f.key))),
    };
    _notesCtrl = TextEditingController(text: widget.m.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateField(String key, String raw) async {
    final Map<String, dynamic> patch;
    if (raw.trim().isEmpty) {
      patch = {key: null};
    } else {
      final v = double.tryParse(raw.trim());
      if (v == null) return;
      patch = {key: v};
    }
    await ref.read(measurementsProvider.notifier).patch(widget.m.id, patch);
  }

  Future<void> _updateNotes(String v) async {
    await ref.read(measurementsProvider.notifier).patch(widget.m.id, {
      'notes': v.trim().isEmpty ? null : v.trim(),
    });
  }

  Future<void> _pickDate() async {
    final current =
        DateTime.tryParse(widget.m.measuredAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      await ref.read(measurementsProvider.notifier).patch(widget.m.id, {
        'measured_at': picked.toIso8601String().substring(0, 10),
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar medida?'),
        content: Text(_fmtDate(widget.m.measuredAt)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(measurementsProvider.notifier).remove(widget.m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return NeuroCard(
      size: NeuroSize.sm,
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: ac.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDate(widget.m.measuredAt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 12, color: ac.textDisabled),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _delete,
                child: Icon(Icons.close_rounded,
                    size: 18, color: ac.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < kMeasurementFields.length; i += 2) ...[
            Row(
              children: [
                Expanded(
                  child: _NumInput(
                    field: kMeasurementFields[i],
                    controller: _ctrls[kMeasurementFields[i].key]!,
                    onCommit: (v) =>
                        _updateField(kMeasurementFields[i].key, v),
                  ),
                ),
                if (i + 1 < kMeasurementFields.length) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumInput(
                      field: kMeasurementFields[i + 1],
                      controller: _ctrls[kMeasurementFields[i + 1].key]!,
                      onCommit: (v) =>
                          _updateField(kMeasurementFields[i + 1].key, v),
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
            if (i + 2 < kMeasurementFields.length)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: 'Notas',
              hintStyle: TextStyle(color: ac.textDisabled),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: TextStyle(fontSize: 12, color: ac.textMedium),
            onEditingComplete: () => _updateNotes(_notesCtrl.text),
            onTapOutside: (_) => _updateNotes(_notesCtrl.text),
          ),
        ],
      ),
    );
  }
}

// ── Numeric Input ─────────────────────────────────────────────────────────────

class _NumInput extends StatelessWidget {
  const _NumInput({
    required this.field,
    required this.controller,
    this.onCommit,
  });

  final MeasurementFieldDef field;
  final TextEditingController controller;
  final void Function(String)? onCommit;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              field.label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ac.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Text(field.unit,
                style: TextStyle(fontSize: 9, color: ac.textDisabled)),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onTap: () => controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          onEditingComplete:
              onCommit == null ? null : () => onCommit!(controller.text),
          onTapOutside:
              onCommit == null ? null : (_) => onCommit!(controller.text),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(
            hintText: '—',
            hintStyle: TextStyle(color: ac.textDisabled),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ac.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 100, child: Center(child: CircularProgressIndicator()));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12)),
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
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.of(context).textMuted),
          ),
        ),
      );
}
