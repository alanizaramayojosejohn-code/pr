import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'data/routines_repository.dart';
import 'exercise_detail_sheet.dart';
import 'providers.dart';

// ── Muscle group catalogue ────────────────────────────────────────────────────

class _MuscleGroup {
  const _MuscleGroup(this.label, this.muscle, this.icon, this.color);
  final String label;
  final String? muscle;
  final IconData icon;
  final Color color;
}

const _groups = [
  _MuscleGroup('Todos',        null,           Icons.apps_rounded,               Color(0xFF64748B)),
  _MuscleGroup('Pecho',        'pecho',        Icons.crop_free_rounded,           Color(0xFFEF4444)),
  _MuscleGroup('Espalda',      'espalda',      Icons.view_agenda_rounded,         Color(0xFF3B82F6)),
  _MuscleGroup('Hombros',      'hombro',       Icons.horizontal_rule_rounded,     Color(0xFF8B5CF6)),
  _MuscleGroup('Brazos',       'brazo',        Icons.fitness_center_rounded,      Color(0xFF22C55E)),
  _MuscleGroup('Cuádriceps',   'cuadriceps',   Icons.directions_run_rounded,      Color(0xFFF97316)),
  _MuscleGroup('Isquios',      'isquios',      Icons.directions_walk_rounded,     Color(0xFFEAB308)),
  _MuscleGroup('Glúteos',      'gluteos',      Icons.radio_button_unchecked,      Color(0xFFEC4899)),
  _MuscleGroup('Pantorrillas', 'pantorrilla',  Icons.airline_seat_legroom_extra,  Color(0xFFA78BFA)),
  _MuscleGroup('Core',         'core',         Icons.crop_square_rounded,         Color(0xFF38BDF8)),
  _MuscleGroup('Aductores',    'aductores',    Icons.swap_horiz_rounded,          Color(0xFFFB923C)),
];

// ── Page ──────────────────────────────────────────────────────────────────────

class ExerciseBrowserPage extends ConsumerStatefulWidget {
  const ExerciseBrowserPage({
    super.key,
    required this.routineId,
    this.onAdd,
  });
  final String routineId;

  /// Si se pasa, el alta la resuelve quien abrió la página. Lo usa el entreno
  /// en curso, que además de guardar en la rutina tiene que sumar el ejercicio
  /// a la sesión activa.
  final Future<void> Function(
    ExerciseLite exercise,
    int sets,
    int reps,
    int rest,
    double? weight,
  )? onAdd;

  @override
  ConsumerState<ExerciseBrowserPage> createState() =>
      _ExerciseBrowserPageState();
}

class _ExerciseBrowserPageState extends ConsumerState<ExerciseBrowserPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  _MuscleGroup? _selectedGroup;
  bool _showList = false;

  List<ExerciseLite> _exercises = [];
  bool _loading = false;
  bool _loadingMore = false;
  String _activeQuery = '';
  String? _activeMuscle;
  int _offset = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _fetchList(String query, String? muscle,
      {bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _exercises = [];
        _offset = 0;
        _activeQuery = query;
        _activeMuscle = muscle;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final repo = ref.read(routinesRepositoryProvider);
    final results = await repo.searchExercises(
      query,
      categorySlug: muscle,
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );
    if (!mounted) return;
    setState(() {
      if (reset) {
        _exercises = results;
      } else {
        _exercises = [..._exercises, ...results];
      }
      _offset = (reset ? 0 : _offset) + results.length;
      _loading = false;
      _loadingMore = false;
    });
  }

  void _loadMore() => _fetchList(_activeQuery, _activeMuscle, reset: false);

  void _selectGroup(_MuscleGroup g) {
    _searchCtrl.clear();
    setState(() {
      _selectedGroup = g;
      _showList = true;
    });
    _fetchList('', g.muscle);
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (q.trim().isEmpty && _selectedGroup == null) {
        setState(() => _showList = false);
        return;
      }
      setState(() => _showList = true);
      _fetchList(q.trim(), _selectedGroup?.muscle);
    });
  }

  void _backToCategories() {
    _searchCtrl.clear();
    setState(() {
      _showList = false;
      _selectedGroup = null;
      _exercises = [];
    });
  }

  Future<void> _pickExercise(ExerciseLite ex) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseDetailSheet(
        exercise: ex,
        onAdd: (sets, reps, rest, weight) async {
          final handler = widget.onAdd;
          if (handler != null) {
            await handler(ex, sets, reps, rest, weight);
          } else {
            await ref.read(routinesRepositoryProvider).addExercise(
                  widget.routineId,
                  ex.id,
                  sets: sets,
                  reps: reps,
                  rest: rest,
                  weight: weight,
                );
            ref.invalidate(routinesProvider);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${ex.name} agregado')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ac.overlayStyle,
      child: Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              _showList ? Icons.arrow_back_ios_new_rounded : Icons.close,
              size: 18,
            ),
            onPressed: _showList
                ? _backToCategories
                : () => Navigator.pop(context),
          ),
          title: Text(_showList
              ? (_selectedGroup?.label ?? 'Resultados')
              : 'Agregar ejercicio'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: ac.bg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ac.pressed(NeuroSize.sm),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: ac.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar entre 873 ejercicios…',
                    hintStyle:
                        TextStyle(color: ac.textDisabled, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: ac.textMuted, size: 22),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: ac.textMuted, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _showList ? _buildExerciseList() : _buildCategoryGrid(),
      ),
    );
  }

  // ── Category grid ─────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    final ac = AppColors.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: _groups.length,
      itemBuilder: (context, i) {
        final g = _groups[i];
        return GestureDetector(
          onTap: () => _selectGroup(g),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ac.bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: ac.raised(NeuroSize.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      ...ac.raised(NeuroSize.sm),
                      BoxShadow(
                          color: g.color.withValues(alpha: 0.15),
                          blurRadius: 14),
                    ],
                  ),
                  child: Icon(g.icon, color: g.color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  g.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ac.textMedium,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Exercise list ──────────────────────────────────────────────────────────

  Widget _buildExerciseList() {
    final ac = AppColors.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: ac.textDisabled),
            const SizedBox(height: 12),
            Text('Sin resultados',
                style: TextStyle(color: ac.textDisabled)),
          ],
        ),
      );
    }
    final hasMore =
        _exercises.length == _offset && _exercises.length >= _pageSize;

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: _exercises.length + 1,
      itemBuilder: (context, i) {
        if (i == _exercises.length) {
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (hasMore) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _loadMore,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ac.bg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ac.raised(NeuroSize.sm),
                  ),
                  child: Text(
                    'Cargar más (${_exercises.length} cargados)',
                    style: TextStyle(
                        color: ac.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '${_exercises.length} ejercicio${_exercises.length == 1 ? '' : 's'}',
                style: TextStyle(color: ac.textDisabled, fontSize: 12),
              ),
            ),
          );
        }

        final ex = _exercises[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _pickExercise(ex),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ac.bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: ac.raised(NeuroSize.sm),
              ),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ac.bg,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: ac.pressed(NeuroSize.sm),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: ex.imageUrl != null && ex.imageUrl!.isNotEmpty
                        ? Image.network(
                            ex.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                                Icons.fitness_center,
                                color: ac.textDisabled,
                                size: 22),
                          )
                        : Icon(Icons.fitness_center,
                            color: ac.textDisabled, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ex.name,
                      style: TextStyle(
                        color: ac.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ac.bg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        ...ac.raised(NeuroSize.sm),
                        BoxShadow(
                            color: kSeed.withValues(alpha: 0.12),
                            blurRadius: 12),
                      ],
                    ),
                    child: const Icon(Icons.add, size: 16, color: kSeed),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
