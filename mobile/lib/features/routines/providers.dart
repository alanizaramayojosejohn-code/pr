import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/routines_repository.dart';

final routinesRepositoryProvider = Provider<RoutinesRepository>((ref) {
  return RoutinesRepository();
});

/// Todas las rutinas del usuario, plantillas incluidas. Es la fuente única:
/// invalidarla refresca también las dos vistas derivadas de abajo.
final routinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repo = ref.watch(routinesRepositoryProvider);
  return repo.fetchAll();
});

/// Lo que se entrena. Un instructor no quiere ver sus plantillas mezcladas
/// con las rutinas que hace él mismo.
final trainingRoutinesProvider = Provider<AsyncValue<List<Routine>>>((ref) {
  return ref
      .watch(routinesProvider)
      .whenData((rs) => rs.where((r) => !r.isTemplate).toList());
});

/// La biblioteca del instructor.
final templatesProvider = Provider<AsyncValue<List<Routine>>>((ref) {
  return ref
      .watch(routinesProvider)
      .whenData((rs) => rs.where((r) => r.isTemplate).toList());
});
