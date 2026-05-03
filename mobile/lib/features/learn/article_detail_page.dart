import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/articles_repository.dart';
import 'learn_page.dart' show formatDate;
import 'providers.dart';

class ArticleDetailPage extends ConsumerWidget {
  const ArticleDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(articlesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/aprender'),
        ),
        title: const Text('Aprender'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final article = data.findArticle(slug);
          if (article == null) {
            return const Center(child: Text('Artículo no encontrado'));
          }
          final categoryName = data.findCategory(article.category)?.name ?? article.category;
          return _ArticleBody(article: article, categoryName: categoryName);
        },
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.article, required this.categoryName});
  final Article article;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          categoryName.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          article.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${formatDate(article.published)} · ${article.readingMinutes} min · ${article.author}',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        MarkdownBody(
          data: article.body,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            h2: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            h3: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            listBullet: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            tableHead: const TextStyle(fontWeight: FontWeight.w700),
            tableBorder: TableBorder.all(color: cs.outlineVariant),
            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            blockquoteDecoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              border: Border(left: BorderSide(color: cs.primary, width: 3)),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          ),
          onTapLink: (_, href, _) async {
            // External link handling deferred — for now, no-op.
          },
        ),
      ],
    );
  }
}
