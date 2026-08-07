import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'data/routines_repository.dart';
import 'exercise_detail_sheet.dart';
import 'providers.dart';

class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key, required this.routineId});
  final String routineId;

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<ExerciseLite> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String _currentQuery = '';
  int _offset = 0;
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _fetch('', reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String query, {required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _currentQuery = query;
        _items = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final repo = ref.read(routinesRepositoryProvider);
    final results = await repo.searchExercises(
      query,
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );
    if (!mounted) return;
    setState(() {
      if (reset) {
        _items = results;
      } else {
        _items = [..._items, ...results];
      }
      _offset = (reset ? 0 : _offset) + results.length;
      _loading = false;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      _fetch(_currentQuery, reset: false);
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetch(q.trim(), reset: true);
    });
  }

  Future<void> _pick(ExerciseLite ex) async {
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.of(context).bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
                color: AppColors.of(context).glassBorderBase.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).glassBorderBase.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Agregar ejercicio',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: AppColors.of(context).textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  style: TextStyle(color: AppColors.of(context).textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar ejercicio…',
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.of(context).textDisabled, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.of(context).textDisabled,
                                size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados para "${_searchCtrl.text}"',
                              style: TextStyle(
                                  color: AppColors.of(context).textDisabled),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount:
                                _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child:
                                          CircularProgressIndicator()),
                                );
                              }
                              final ex = _items[i];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: AppColors.of(context).glassBorderBase.withValues(alpha: 0.06),
                                    child: ex.imageUrl != null &&
                                            ex.imageUrl!.isNotEmpty
                                        ? Image.network(
                                            ex.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, _, _) => Icon(
                                                    Icons.fitness_center,
                                                    color: AppColors.of(context).textDisabled,
                                                    size: 20),
                                          )
                                        : Icon(Icons.fitness_center,
                                            color: AppColors.of(context).textDisabled,
                                            size: 20),
                                  ),
                                ),
                                title: Text(
                                  ex.name,
                                  style: TextStyle(
                                    color: AppColors.of(context).textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: kSeed.withValues(alpha: 0.8),
                                    size: 24,
                                  ),
                                  onPressed: () => _pick(ex),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                onTap: () => _pick(ex),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}



