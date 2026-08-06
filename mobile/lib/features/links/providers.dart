import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/links_repository.dart';

final linksRepositoryProvider = Provider<LinksRepository>((ref) {
  return LinksRepository();
});

/// Solicitudes pendientes de las dos direcciones: las que mandé y las que me
/// toca responder. La pantalla las separa mirando `iRequested`.
final pendingLinksProvider = FutureProvider<List<LinkRequest>>((ref) async {
  return ref.watch(linksRepositoryProvider).fetchPending();
});

/// Las que espero que me respondan.
final sentLinksProvider = Provider<AsyncValue<List<LinkRequest>>>((ref) {
  return ref
      .watch(pendingLinksProvider)
      .whenData((rs) => rs.where((r) => r.iRequested).toList());
});

/// Las que tengo que responder yo.
final incomingLinksProvider = Provider<AsyncValue<List<LinkRequest>>>((ref) {
  return ref
      .watch(pendingLinksProvider)
      .whenData((rs) => rs.where((r) => !r.iRequested).toList());
});

final myInstructorEmailProvider = FutureProvider<String?>((ref) async {
  return ref.watch(linksRepositoryProvider).fetchMyInstructorEmail();
});
