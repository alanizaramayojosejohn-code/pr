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
  final String? muscle; // null = todos
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
  const ExerciseBrowserPage({super.key, required this.routineId});
  final String routineId;

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
        onAdd: (sets, reps, rest, weight) {
          ref
              .read(routinesRepositoryProvider)
              .addExercise(widget.routineId, ex.id,
                  sets: sets, reps: reps, rest: rest, weight: weight)
              .then((_) {
            ref.invalidate(routinesProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${ex.name} agregado')),
              );
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              _showList ? Icons.arrow_back_ios_new_rounded : Icons.close,
              size: 18,
            ),
            onPressed: _showList ? _backToCategories : () => Navigator.pop(context),
          ),
          title: _showList
              ? Text(_selectedGroup?.label ?? 'Resultados')
              : const Text('Agregar ejercicio'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Color(0xF2FFFFFF), fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Buscar entre 873 ejercicios…',
                  hintStyle: const TextStyle(color: Color(0x55FFFFFF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0x88FFFFFF), size: 22),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Color(0x88FFFFFF), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSeed, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: AppGradient(
          child: _showList ? _buildExerciseList() : _buildCategoryGrid(),
        ),
      ),
    );
  }

  // ── Category grid ───────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _groups.length,
      itemBuilder: (context, i) {
        final g = _groups[i];
        return GestureDetector(
          onTap: () => _selectGroup(g),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            radius: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: g.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: g.color.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Icon(g.icon, color: g.color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  g.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xCCFFFFFF),
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

  // ── Exercise list ───────────────────────────────────────────────────────────

  Widget _buildExerciseList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'Sin resultados',
              style: const TextStyle(color: Color(0x66FFFFFF)),
            ),
          ],
        ),
      );
    }
    final hasMore = _exercises.length == _offset && _exercises.length >= _pageSize;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: _exercises.length + 1, // +1 for footer
      itemBuilder: (context, i) {
        if (i == _exercises.length) {
          // Footer: loader or "cargar más" or end label
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (hasMore) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: kGlassBorderStrong),
                  foregroundColor: const Color(0xCCFFFFFF),
                ),
                child: Text('Cargar más (${_exercises.length} cargados)'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '${_exercises.length} ejercicio${_exercises.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Color(0x44FFFFFF), fontSize: 12),
              ),
            ),
          );
        }

        final ex = _exercises[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.white.withValues(alpha: 0.06),
              child: ex.imageUrl != null && ex.imageUrl!.isNotEmpty
                  ? Image.network(
                      ex.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                          Icons.fitness_center,
                          color: Color(0x66FFFFFF),
                          size: 20),
                    )
                  : const Icon(Icons.fitness_center,
                      color: Color(0x66FFFFFF), size: 20),
            ),
          ),
          title: Text(
            ex.name,
            style: const TextStyle(
              color: Color(0xF2FFFFFF),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: kSeed.withValues(alpha: 0.8),
              size: 26,
            ),
            onPressed: () => _pickExercise(ex),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          onTap: () => _pickExercise(ex),
        );
      },
    );
  }
}


