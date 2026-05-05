import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'data/routines_repository.dart';

// ── Translation helpers ───────────────────────────────────────────────────────

String _levelEs(String? v) => switch (v) {
      'beginner' => 'Principiante',
      'intermediate' => 'Intermedio',
      'expert' => 'Avanzado',
      _ => v ?? '',
    };

String _mechanicEs(String? v) => switch (v) {
      'compound' => 'Compuesto',
      'isolation' => 'Aislamiento',
      _ => v ?? '',
    };

String _equipmentEs(String? v) => switch (v) {
      'barbell' => 'Barra',
      'dumbbell' => 'Mancuerna',
      'machine' => 'Máquina',
      'cable' => 'Polea',
      'kettlebells' => 'Pesa rusa',
      'e-z curl bar' => 'Barra EZ',
      'body only' => 'Calistenia',
      'other' => 'Otro',
      _ => v ?? '',
    };

String _categoryEs(String? slug) {
  const map = {
    'pecho': 'Pecho',
    'espalda': 'Espalda',
    'hombro': 'Hombros',
    'brazo': 'Brazos',
    'cuadriceps': 'Cuádriceps',
    'isquios': 'Isquios',
    'gluteos': 'Glúteos',
    'pantorrilla': 'Pantorrillas',
    'core': 'Core',
    'aductores': 'Aductores',
  };
  if (slug == null) return '';
  return map[slug] ?? (slug[0].toUpperCase() + slug.substring(1));
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class ExerciseDetailSheet extends StatefulWidget {
  const ExerciseDetailSheet({
    super.key,
    required this.exercise,
    required this.onAdd,
  });
  final ExerciseLite exercise;
  final void Function(int sets, int reps, int rest, double? weight) onAdd;

  @override
  State<ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<ExerciseDetailSheet> {
  int _sets = 4;
  int _reps = 10;
  int _rest = 60;
  final _weightCtrl = TextEditingController();
  late final Future<ExerciseDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture =
        RoutinesRepository().fetchExerciseDetail(widget.exercise.id);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: kGlassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: back circle + name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _DetailCircleBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.exercise.name,
                          style: const TextStyle(
                            color: Color(0xF2FFFFFF),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Detail sections (fetched async)
                  FutureBuilder<ExerciseDetail>(
                    future: _detailFuture,
                    builder: (ctx, snap) {
                      final detail = snap.data;
                      final loading =
                          snap.connectionState == ConnectionState.waiting;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subtitle: Muscle · Level
                          if (detail != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 52, bottom: 12),
                              child: Text(
                                [
                                  _categoryEs(detail.categorySlug),
                                  _levelEs(detail.level),
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: const TextStyle(
                                  color: Color(0x88FFFFFF),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 12),

                          // GIF section or loading placeholder
                          if (loading)
                            _LoadingImage()
                          else
                            _GifSection(
                              url0: detail?.imageUrl ??
                                  widget.exercise.imageUrl,
                              url1: detail?.imageUrl2,
                            ),

                          // Chips
                          if (detail != null) ...[
                            const SizedBox(height: 12),
                            _ChipsRow(detail: detail),
                          ],

                          // Cómo hacerlo
                          if (detail != null &&
                              detail.instructions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _HowToSection(steps: detail.instructions),
                          ],

                          const SizedBox(height: 16),
                          // Divider with tune icon
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: kGlassBorder, height: 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.tune_rounded,
                                    color: kSeed, size: 14),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: kGlassBorder, height: 1)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Config card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kGlassFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: kSeed.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Icon(Icons.tune_rounded,
                                      color: kSeed, size: 15),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Configurar para tu rutina',
                                    style: TextStyle(
                                      color: Color(0xF2FFFFFF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                _CfgRow(
                                  label: 'Series',
                                  child: _DetailStepper(
                                    value: _sets,
                                    min: 1,
                                    max: 20,
                                    onChanged: (v) =>
                                        setState(() => _sets = v),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _CfgRow(
                                  label: 'Repeticiones',
                                  child: _DetailStepper(
                                    value: _reps,
                                    min: 1,
                                    max: 100,
                                    onChanged: (v) =>
                                        setState(() => _reps = v),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _CfgRow(
                                  label: 'Peso',
                                  child: _WeightBox(controller: _weightCtrl),
                                ),
                                const SizedBox(height: 10),
                                _CfgRow(
                                  label: 'Descanso',
                                  child: _RestBox(
                                    value: _rest,
                                    onChanged: (v) =>
                                        setState(() => _rest = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            decoration: BoxDecoration(
              color: kBg,
              border: Border(top: BorderSide(color: kGlassBorder)),
            ),
            child: Row(
              children: [
                _DetailCircleBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                  size: 50,
                  borderColor: kGlassBorderStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Agregar a rutina',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        final w = double.tryParse(_weightCtrl.text.trim());
                        widget.onAdd(_sets, _reps, _rest, w);
                      },
                      style: FilledButton.styleFrom(
                          shape: const StadiumBorder()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── GIF section ───────────────────────────────────────────────────────────────

class _GifSection extends StatefulWidget {
  const _GifSection({this.url0, this.url1});
  final String? url0;
  final String? url1;

  @override
  State<_GifSection> createState() => _GifSectionState();
}

class _GifSectionState extends State<_GifSection> {
  bool _playing = false;
  bool _frame = false; // false = url0, true = url1
  Timer? _timer;

  String? get _activeUrl => _frame ? widget.url1 : widget.url0;

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() {
        _playing = false;
        _frame = false;
      });
    } else {
      setState(() => _playing = true);
      _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
        setState(() => _frame = !_frame);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl0 = widget.url0 != null && widget.url0!.isNotEmpty;
    final hasUrl1 = widget.url1 != null && widget.url1!.isNotEmpty;

    if (!hasUrl0 && !hasUrl1) return const SizedBox.shrink();

    if (!hasUrl1 || _playing) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: hasUrl0 || _playing
                  ? Image.network(
                      _activeUrl ?? widget.url0 ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: kGlassFill),
                    )
                  : Container(color: kGlassFill),
            ),
            if (hasUrl1)
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Two thumbnails side by side + play button
    return Container(
      decoration: BoxDecoration(
        color: kGlassFill,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Thumb(url: widget.url0!, label: 'Inicio')),
                Container(
                    width: 1,
                    color: Colors.black.withValues(alpha: 0.25)),
                Expanded(child: _Thumb(url: widget.url1!, label: 'Fin')),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: kSeed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.label});
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: kGlassFill,
              child: const Center(
                child: Icon(Icons.fitness_center,
                    color: Color(0x33FFFFFF), size: 32),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0x66FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── Chips row ─────────────────────────────────────────────────────────────────

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.detail});
  final ExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (detail.categorySlug != null) _categoryEs(detail.categorySlug),
      if (detail.level != null) _levelEs(detail.level),
      if (detail.equipment != null && detail.equipment!.isNotEmpty)
        _equipmentEs(detail.equipment),
      if (detail.mechanic != null && detail.mechanic!.isNotEmpty)
        _mechanicEs(detail.mechanic),
    ].where((s) => s.isNotEmpty).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map((c) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kSeed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kSeed.withValues(alpha: 0.25)),
                ),
                child: Text(
                  c,
                  style: const TextStyle(
                    color: kSeed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── "Cómo hacerlo" section ────────────────────────────────────────────────────

class _HowToSection extends StatefulWidget {
  const _HowToSection({required this.steps});
  final List<String> steps;

  @override
  State<_HowToSection> createState() => _HowToSectionState();
}

class _HowToSectionState extends State<_HowToSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.steps;
    final visible = _expanded ? all : all.take(2).toList();
    final hasMore = all.length > 2 && !_expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded, size: 14, color: kSeed),
            const SizedBox(width: 6),
            const Text(
              'Cómo hacerlo',
              style: TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...visible.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1, right: 10),
                    decoration: BoxDecoration(
                      color: kSeed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: kSeed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        if (hasMore)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ver los ${all.length} pasos →',
                style: const TextStyle(
                  color: kSeed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────

class _LoadingImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 170,
        decoration: BoxDecoration(
          color: kGlassFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _DetailCircleBtn extends StatelessWidget {
  const _DetailCircleBtn({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.borderColor,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kGlassFill,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor ?? kGlassBorder),
        ),
        child: Icon(icon, color: const Color(0xF2FFFFFF), size: 18),
      ),
    );
  }
}

class _CfgRow extends StatelessWidget {
  const _CfgRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
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

class _DetailStepper extends StatelessWidget {
  const _DetailStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            isPlus: false,
            onTap: value <= min ? null : () => onChanged(value - step),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepBtn(
            isPlus: true,
            onTap: value >= max ? null : () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.isPlus, required this.onTap});
  final bool isPlus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isPlus ? kSeed : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPlus ? Icons.add : Icons.remove,
          size: 14,
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.25)
              : isPlus
                  ? Colors.black
                  : const Color(0xCCFFFFFF),
        ),
      ),
    );
  }
}

class _WeightBox extends StatelessWidget {
  const _WeightBox({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
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
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(color: Color(0x44FFFFFF), fontSize: 15),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'kg',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestBox extends StatelessWidget {
  const _RestBox({required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
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
              color: value > 15
                  ? const Color(0xCCFFFFFF)
                  : const Color(0x33FFFFFF),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xF2FFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'seg',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(value + 15),
            child: const Icon(Icons.add, size: 14, color: Color(0xCCFFFFFF)),
          ),
        ],
      ),
    );
  }
}
