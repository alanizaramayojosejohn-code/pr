import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/routines_repository.dart';

final routinesRepositoryProvider = Provider<RoutinesRepository>((ref) {
  return RoutinesRepository();
});

final routinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repo = ref.watch(routinesRepositoryProvider);
  return repo.fetchAll();
});
