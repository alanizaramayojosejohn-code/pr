import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/articles_repository.dart';

final articlesRepositoryProvider = Provider<ArticlesRepository>((ref) {
  return ArticlesRepository();
});

final articlesProvider = FutureProvider<ArticlesData>((ref) async {
  final repo = ref.watch(articlesRepositoryProvider);
  return repo.load();
});
