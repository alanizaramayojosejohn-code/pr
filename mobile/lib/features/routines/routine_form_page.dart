import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class RoutineFormPage extends StatefulWidget {
  const RoutineFormPage({
    super.key,
    this.initialName = '',
    this.initialDays = const [],
    required this.title,
    required this.onSave,
  });

  final String initialName;
  final List<int> initialDays;
  final String title;
  final Future<void> Function(String name, List<int> days) onSave;

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  late final _ctrl = TextEditingController(text: widget.initialName);
  late final Set<int> _days = Set.from(widget.initialDays);
  bool _saving = false;

  static const _dayDefs = [
    (value: 1, label: 'L', full: 'Lunes'),
    (value: 2, label: 'M', full: 'Martes'),
    (value: 3, label: 'X', full: 'Miércoles'),
    (value: 4, label: 'J', full: 'Jueves'),
    (value: 5, label: 'V', full: 'Viernes'),
    (value: 6, label: 'S', full: 'Sábado'),
    (value: 0, label: 'D', full: 'Domingo'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleDay(int value) {
    setState(() {
      if (_days.contains(value)) {
        _days.remove(value);
      } else {
        _days.add(value);
      }
    });
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(name, _days.toList()..sort());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _ctrl.text.trim().isNotEmpty && !_saving;
    final selectedNames = _dayDefs
        .where((d) => _days.contains(d.value))
        .map((d) => d.full)
        .join(', ');
    final showWarning = _days.length >= 3;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canSave ? _submit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: AppGradient(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              // Name field
              GlassCard(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      color: Color(0xF2FFFFFF), fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la rutina',
                    labelStyle: TextStyle(color: Color(0x99FFFFFF)),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 20),
              // Days multi-select
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DÍAS DE LA SEMANA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0x80FFFFFF),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final d in _dayDefs) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _toggleDay(d.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _days.contains(d.value)
                                      ? kSeed.withValues(alpha: 0.2)
                                      : kGlassFill,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _days.contains(d.value)
                                        ? kSeed
                                        : kGlassBorder,
                                    width: _days.contains(d.value) ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  d.label,
                                  style: TextStyle(
                                    fontWeight: _days.contains(d.value)
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13,
                                    color: _days.contains(d.value)
                                        ? kSeed
                                        : const Color(0x80FFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (d != _dayDefs.last) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    if (_days.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        selectedNames,
                        style: const TextStyle(
                          color: kSeed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    // Warning when >= 3 days selected
                    if (showWarning) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Entrenar los mismos grupos musculares ${_days.length >= 3 ? "tantas veces" : "tan seguido"} por semana puede dificultar la recuperación y aumentar el riesgo de lesión.',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
