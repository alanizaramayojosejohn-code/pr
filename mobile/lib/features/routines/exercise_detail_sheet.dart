import 'dart:async';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'data/routines_repository.dart';
import 'exercise_config_controls.dart';

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
    final ac = AppColors.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: ac.shadowSh, blurRadius: 24, offset: const Offset(0, -8)),
          BoxShadow(
              color: ac.shadowHi, blurRadius: 12, offset: const Offset(0, -3)),
        ],
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
                color: ac.textDisabled.withValues(alpha: 0.4),
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
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _NeuroCircleBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.exercise.name,
                          style: TextStyle(
                            color: ac.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  FutureBuilder<ExerciseDetail>(
                    future: _detailFuture,
                    builder: (ctx, snap) {
                      final detail = snap.data;
                      final loading =
                          snap.connectionState == ConnectionState.waiting;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subtitle
                          if (detail != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 52, bottom: 12),
                              child: Text(
                                [
                                  _categoryEs(detail.categorySlug),
                                  _levelEs(detail.level),
                                ]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: TextStyle(
                                    color: ac.textMuted, fontSize: 13),
                              ),
                            )
                          else
                            const SizedBox(height: 12),

                          // Image
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

                          // How-to
                          if (detail != null &&
                              detail.instructions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _HowToSection(steps: detail.instructions),
                          ],

                          const SizedBox(height: 16),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: ac.dividerColor
                                          .withValues(alpha: 0.6),
                                      height: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Icon(Icons.tune_rounded,
                                    color: kSeed, size: 14),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: ac.dividerColor
                                          .withValues(alpha: 0.6),
                                      height: 1)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Config card
                          NeuroCard(
                            radius: 16,
                            padding: const EdgeInsets.all(16),
                            accent: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  const Icon(Icons.tune_rounded,
                                      color: kSeed, size: 15),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Configurar para tu rutina',
                                    style: TextStyle(
                                      color: ac.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                CfgRow(
                                  label: 'Series',
                                  child: NeuroStepper(
                                    value: _sets,
                                    min: 1,
                                    max: 20,
                                    onChanged: (v) =>
                                        setState(() => _sets = v),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CfgRow(
                                  label: 'Repeticiones',
                                  child: NeuroStepper(
                                    value: _reps,
                                    min: 1,
                                    max: 100,
                                    onChanged: (v) =>
                                        setState(() => _reps = v),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CfgRow(
                                  label: 'Peso',
                                  child: WeightBox(controller: _weightCtrl),
                                ),
                                const SizedBox(height: 10),
                                CfgRow(
                                  label: 'Descanso',
                                  child: RestBox(
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
              color: ac.bg,
              border: Border(
                  top: BorderSide(
                      color: ac.dividerColor.withValues(alpha: 0.6))),
              boxShadow: [
                BoxShadow(
                    color: ac.shadowHi,
                    blurRadius: 10,
                    offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                _NeuroCircleBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                  size: 50,
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
                        final w =
                            double.tryParse(_weightCtrl.text.trim());
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
  bool _frame = false;
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
    final ac = AppColors.of(context);
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
                      errorBuilder: (_, _, _) =>
                          Container(color: ac.bg),
                    )
                  : Container(color: ac.bg),
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
                      color: Colors.black.withValues(alpha: 0.55),
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
        color: ac.bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: ac.pressed(NeuroSize.sm),
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
                    color: Colors.black.withValues(alpha: 0.2)),
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
    final ac = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: ac.bg,
              child: Center(
                child: Icon(Icons.fitness_center,
                    color: ac.textDisabled, size: 32),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: ac.textMuted,
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
    final ac = AppColors.of(context);
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ac.bg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: ac.raised(NeuroSize.sm),
                  border: Border.all(
                      color: kSeed.withValues(alpha: 0.25), width: 1),
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
    final ac = AppColors.of(context);
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
            Text(
              'Cómo hacerlo',
              style: TextStyle(
                color: ac.textPrimary,
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
                      style: TextStyle(
                        color: ac.textSecondary,
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
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: ac.pressed(NeuroSize.md),
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
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _NeuroCircleBtn extends StatelessWidget {
  const _NeuroCircleBtn({
    required this.icon,
    required this.onTap,
    this.size = 40,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ac.bg,
          shape: BoxShape.circle,
          boxShadow: ac.raised(NeuroSize.sm),
        ),
        child: Icon(icon, color: ac.textPrimary, size: 18),
      ),
    );
  }
}
