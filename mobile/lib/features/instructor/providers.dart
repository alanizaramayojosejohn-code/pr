import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routines/data/routines_repository.dart';
import 'data/instructor_repository.dart';

final instructorRepositoryProvider = Provider<InstructorRepository>((ref) {
  return InstructorRepository();
});

final clientsProvider = FutureProvider<List<Client>>((ref) async {
  return ref.watch(instructorRepositoryProvider).fetchClients();
});

final clientRoutinesProvider =
    FutureProvider.family<List<Routine>, String>((ref, clientId) async {
  return ref.watch(instructorRepositoryProvider).fetchClientRoutines(clientId);
});

final clientActivityProvider =
    FutureProvider.family<ClientActivity, String>((ref, clientId) async {
  return ref.watch(instructorRepositoryProvider).fetchClientActivity(clientId);
});
