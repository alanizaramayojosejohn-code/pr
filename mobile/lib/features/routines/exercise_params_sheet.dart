import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'exercise_config_controls.dart';

/// Valores editables de un ejercicio dentro de una rutina.
class ExerciseParams {
  const ExerciseParams({
    required this.sets,
    required this.reps,
    required this.rest,
    this.weight,
  });

  final int sets;
  final int reps;
  final int rest;
  final double? weight;
}

/// Hoja para editar series / reps / peso / descanso de un ejercicio ya agregado.
/// La usan tanto la vista de rutina como la de entreno en curso.
class ExerciseParamsSheet extends StatefulWidget {
  const ExerciseParamsSheet({
    super.key,
    required this.exerciseName,
    required this.initial,
    required this.onSave,
    this.onRemove,
    this.setsLocked = false,
  });

  final String exerciseName;
  final ExerciseParams initial;
  final void Function(ExerciseParams) onSave;

  /// Si se pasa, aparece la opción de quitar el ejercicio.
  final VoidCallback? onRemove;

  /// Bloquea las series cuando cambiarlas no tiene un significado claro.
  final bool setsLocked;

  @override
  State<ExerciseParamsSheet> createState() => _ExerciseParamsSheetState();
}

class _ExerciseParamsSheetState extends State<ExerciseParamsSheet> {
  late int _sets;
  late int _reps;
  late int _rest;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _sets = widget.initial.sets;
    _reps = widget.initial.reps;
    _rest = widget.initial.rest;
    _weightCtrl = TextEditingController(
      text: widget.initial.weight == null ? '' : _fmtWeight(widget.initial.weight!),
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final raw = _weightCtrl.text.trim();
    widget.onSave(ExerciseParams(
      sets: _sets,
      reps: _reps,
      rest: _rest,
      weight: raw.isEmpty ? null : double.tryParse(raw),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar ejercicio',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ac.textPrimary),
                    ),
                    Text(
                      widget.exerciseName,
                      style: TextStyle(fontSize: 12, color: ac.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    shape: BoxShape.circle,
                    boxShadow: ac.raised(NeuroSize.sm),
                  ),
                  child: Icon(Icons.close, size: 16, color: ac.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!widget.setsLocked) ...[
            CfgRow(
              label: 'Series',
              child: NeuroStepper(
                value: _sets,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _sets = v),
              ),
            ),
            const SizedBox(height: 10),
          ],
          CfgRow(
            label: 'Repeticiones',
            child: NeuroStepper(
              value: _reps,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _reps = v),
            ),
          ),
          const SizedBox(height: 10),
          CfgRow(label: 'Peso', child: WeightBox(controller: _weightCtrl)),
          const SizedBox(height: 10),
          CfgRow(
            label: 'Descanso',
            child: RestBox(
              value: _rest,
              onChanged: (v) => setState(() => _rest = v.clamp(15, 600)),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (widget.onRemove != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Quitar de la rutina'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmtWeight(double w) =>
    w == w.truncateToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
