import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/articles_repository.dart';
import 'learn_page.dart' show formatDate;
import 'providers.dart';

const _kSeed = Color(0xFF22C55E);

class ArticleDetailPage extends ConsumerWidget {
  const ArticleDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(articlesProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const _BackButton(),
        title: const Text('Aprender'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final article = data.findArticle(slug);
          if (article == null) {
            return const Center(child: Text('Artículo no encontrado'));
          }
          final categoryName =
              data.findCategory(article.category)?.name ?? article.category;
          return _ArticleBody(article: article, categoryName: categoryName);
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () =>
              context.canPop() ? context.pop() : context.go('/aprender'),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
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
    final topPad = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HeroImage(article: article, topPad: topPad),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryPill(name: categoryName),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _MetaRow(article: article),
                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: article.body,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    h2: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                    h3: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    listBullet:
                        theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    tableHead: const TextStyle(fontWeight: FontWeight.w700),
                    tableBorder: TableBorder.all(color: cs.outlineVariant),
                    tableCellsPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    blockquoteDecoration: BoxDecoration(
                      color: _kSeed.withValues(alpha: 0.08),
                      border: Border(
                        left: BorderSide(
                            color: _kSeed.withValues(alpha: 0.7), width: 3),
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    blockquotePadding:
                        const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                  onTapLink: (_, href, _) async {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.article, required this.topPad});
  final Article article;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = 220.0 + topPad;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          article.cover.isNotEmpty
              ? Image.asset(
                  'assets/img/${article.cover}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _HeroFallback(cs: cs),
                )
              : _HeroFallback(cs: cs),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHigh,
      child: Icon(
        Icons.menu_book_rounded,
        size: 48,
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kSeed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _kSeed.withValues(alpha: 0.35)),
      ),
      child: Text(
        name.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _kSeed,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        );
    final dot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: labelStyle),
    );

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _kSeed.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Center(
            child: Text(
              article.author.isNotEmpty
                  ? article.author[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kSeed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          article.author,
          style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
        dot,
        Text(formatDate(article.published), style: labelStyle),
        dot,
        Text('${article.readingMinutes} min', style: labelStyle),
      ],
    );
  }
}
