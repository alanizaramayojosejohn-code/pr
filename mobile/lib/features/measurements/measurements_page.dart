import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'data/measurements_repository.dart';
import 'providers.dart';

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

// ─── Page ────────────────────────────────────────────────────────────────────

class MeasurementsPage extends ConsumerStatefulWidget {
  const MeasurementsPage({super.key});

  @override
  ConsumerState<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends ConsumerState<MeasurementsPage> {
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
  }

  @override
  void dispose() {
    for (final c in _fieldCtrls.values) { c.dispose(); }
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

  Future<void> _create() async {
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
          for (final c in _fieldCtrls.values) { c.clear(); }
          _notesCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(measurementsProvider);
    final ac = AppColors.of(context);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(measurementsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis medidas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: ac.textPrimary,
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _showForm = !_showForm),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: const StadiumBorder(),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: _showForm
                        ? ac.glassBorderBase.withValues(alpha: 0.20)
                        : kSeed.withValues(alpha: 0.50),
                  ),
                  foregroundColor: _showForm ? ac.textMuted : kSeed,
                ),
                child: Text(
                  _showForm ? 'Cancelar' : '+ Nueva medida',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _showForm
                ? _NewForm(
                    date: _formDate,
                    fieldCtrls: _fieldCtrls,
                    notesCtrl: _notesCtrl,
                    saving: _saving,
                    hasAnyValue: _hasAnyValue,
                    onPickDate: _pickDate,
                    onSave: _create,
                  )
                : const SizedBox.shrink(),
          ),

          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(e.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            data: (ms) {
              if (ms.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.straighten_outlined, size: 48,
                          color: ac.textDisabled),
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
                          child: _MeasurementCard(key: ValueKey(m.id), m: m),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── New Form ─────────────────────────────────────────────────────────────────

class _NewForm extends StatelessWidget {
  const _NewForm({
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
    final ac = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: onPickDate,
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: kSeed),
                  const SizedBox(width: 8),
                  Text(
                    _fmtDate(date.toIso8601String().substring(0, 10)),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kSeed,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: kSeed),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FieldGrid(fieldCtrls: fieldCtrls),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notas (opcional)',
                filled: true,
                fillColor: ac.glassBorderBase.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: ac.glassBorderBase.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: ac.glassBorderBase.withValues(alpha: 0.12)),
                ),
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
      final b = i + 1 < kMeasurementFields.length ? kMeasurementFields[i + 1] : null;
      pairs.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: _NumInput(field: a, controller: fieldCtrls[a.key]!)),
              if (b != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _NumInput(field: b, controller: fieldCtrls[b.key]!)),
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

// ─── Measurement Card ─────────────────────────────────────────────────────────

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
        f.key: TextEditingController(text: _fmtNum(widget.m.fieldValue(f.key))),
    };
    _notesCtrl = TextEditingController(text: widget.m.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
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
    final current = DateTime.tryParse(widget.m.measuredAt) ?? DateTime.now();
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
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
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

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      borderOpacity: 0.10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: ac.textMuted),
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
                    Icon(Icons.edit_outlined, size: 12, color: ac.textDisabled),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _delete,
                child: Icon(Icons.close_rounded, size: 18, color: ac.textDisabled),
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
                    onCommit: (v) => _updateField(kMeasurementFields[i].key, v),
                  ),
                ),
                if (i + 1 < kMeasurementFields.length) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumInput(
                      field: kMeasurementFields[i + 1],
                      controller: _ctrls[kMeasurementFields[i + 1].key]!,
                      onCommit: (v) => _updateField(kMeasurementFields[i + 1].key, v),
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
            if (i + 2 < kMeasurementFields.length) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: 'Notas',
              hintStyle: TextStyle(color: ac.textDisabled),
              filled: true,
              fillColor: ac.glassBorderBase.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
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

// ─── Numeric Input ────────────────────────────────────────────────────────────

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
            Text(
              field.unit,
              style: TextStyle(fontSize: 9, color: ac.textDisabled),
            ),
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(
            hintText: '—',
            hintStyle: TextStyle(color: ac.textDisabled),
            filled: true,
            fillColor: ac.glassBorderBase.withValues(alpha: 0.07),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: ac.glassBorderBase.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: ac.glassBorderBase.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kSeed, width: 1.5),
            ),
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
