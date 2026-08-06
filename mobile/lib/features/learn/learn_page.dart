import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import 'data/articles_repository.dart';
import 'providers.dart';

const _monthNames = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(articlesProvider);
    final ac = AppColors.of(context);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (data) {
        final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, topPad, 20, 100),
          children: [
            Text(
              'Aprender',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: ac.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Guías cortas para entrenar y comer mejor.',
              style: TextStyle(fontSize: 13, color: ac.textMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = data.categories[i];
                  final count = data.byCategory(c.slug).length;
                  return _CategoryPill(name: c.name, count: count);
                },
              ),
            ),
            const SizedBox(height: 20),
            if (data.articles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 48, color: ac.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no hay artículos publicados.',
                      style: TextStyle(color: ac.textMuted),
                    ),
                  ],
                ),
              )
            else
              ...data.articles.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArticleCard(article: a),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Category pill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: ac.glassBorderBase.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ac.glassBorderBase.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ac.textMedium,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: kSeed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: kSeed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Article card ──────────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return GestureDetector(
      onTap: () => context.push('/aprender/${article.slug}'),
      child: GlassCard(
        radius: 16,
        padding: EdgeInsets.zero,
        borderOpacity: 0.10,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 96,
                height: 110,
                child: article.cover.isNotEmpty
                    ? Image.asset(
                        'assets/img/${article.cover}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _CoverFallback(ac: ac),
                      )
                    : _CoverFallback(ac: ac),
              ),
            ),
            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ac.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ac.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 11, color: ac.textDisabled),
                        const SizedBox(width: 3),
                        Text(
                          '${article.readingMinutes} min',
                          style: TextStyle(fontSize: 10, color: ac.textDisabled),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.ac});
  final AppColors ac;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ac.glassBorderBase.withValues(alpha: 0.07),
      child: Icon(Icons.menu_book_rounded, size: 32, color: ac.textDisabled),
    );
  }
}

String formatDate(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final month = _monthNames[d.month - 1];
  return '${d.day} de $month de ${d.year}';
}
