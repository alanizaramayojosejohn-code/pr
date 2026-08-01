import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Controles de series / reps / peso / descanso.
///
/// Viven aquí porque los comparten la hoja de alta ([ExerciseDetailSheet]) y la
/// de edición ([ExerciseParamsSheet]); antes eran privados de la primera.

class CfgRow extends StatelessWidget {
  const CfgRow({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: ac.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class NeuroStepper extends StatelessWidget {
  const NeuroStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: ac.pressed(NeuroSize.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            isPlus: false,
            enabled: value > min,
            onTap: value <= min ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ac.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepBtn(
            isPlus: true,
            enabled: value < max,
            onTap: value >= max ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(
      {required this.isPlus, required this.enabled, required this.onTap});
  final bool isPlus;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isPlus ? kSeed : ac.bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isPlus ? null : ac.raised(NeuroSize.sm),
        ),
        child: Icon(
          isPlus ? Icons.add : Icons.remove,
          size: 14,
          color: !enabled
              ? ac.textDisabled
              : isPlus
                  ? Colors.black
                  : ac.textSecondary,
        ),
      ),
    );
  }
}

class WeightBox extends StatelessWidget {
  const WeightBox({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: ac.pressed(NeuroSize.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: TextStyle(
                color: ac.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(color: ac.textDisabled, fontSize: 15),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                filled: false,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'kg',
            style: TextStyle(
              color: ac.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class RestBox extends StatelessWidget {
  const RestBox({super.key, required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: ac.pressed(NeuroSize.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: kSeed, size: 13),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: value > 15 ? () => onChanged(value - 15) : null,
            child: Icon(
              Icons.remove,
              size: 14,
              color: value > 15 ? ac.textSecondary : ac.textDisabled,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: TextStyle(
              color: ac.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'seg',
            style: TextStyle(
              color: ac.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(value + 15),
            child: Icon(Icons.add, size: 14, color: ac.textSecondary),
          ),
        ],
      ),
    );
  }
}
