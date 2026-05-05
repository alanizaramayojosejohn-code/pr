import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class ArticleCategory {
  ArticleCategory({
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.sort,
  });

  final String slug;
  final String name;
  final String description;
  final String icon;
  final int sort;

  factory ArticleCategory.fromJson(Map<String, dynamic> json) => ArticleCategory(
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        icon: (json['icon'] as String?) ?? '',
        sort: (json['sort'] as num?)?.toInt() ?? 0,
      );
}

class Article {
  Article({
    required this.slug,
    required this.title,
    required this.category,
    required this.excerpt,
    required this.cover,
    required this.published,
    required this.author,
    required this.body,
    required this.readingMinutes,
  });

  final String slug;
  final String title;
  final String category;
  final String excerpt;
  final String cover;
  final String published;
  final String author;
  final String body;
  final int readingMinutes;
}

class ArticlesData {
  ArticlesData({required this.categories, required this.articles});
  final List<ArticleCategory> categories;
  final List<Article> articles;

  List<Article> byCategory(String slug) =>
      articles.where((a) => a.category == slug).toList();

  Article? findArticle(String slug) {
    for (final a in articles) {
      if (a.slug == slug) return a;
    }
    return null;
  }

  ArticleCategory? findCategory(String slug) {
    for (final c in categories) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

class ArticlesRepository {
  static const _articleSlugs = [
    'primeras-pesas',
    'cuanta-proteina-por-dia',
    'descansar-bien-importa',
    'constancia-vs-motivacion',
  ];

  Future<ArticlesData> load() async {
    final metaRaw = await rootBundle.loadString('assets/articles/_meta.json');
    final meta = json.decode(metaRaw) as Map<String, dynamic>;
    final categories = (meta['categories'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ArticleCategory.fromJson)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));

    final articles = <Article>[];
    for (final slug in _articleSlugs) {
      final raw = await rootBundle.loadString('assets/articles/$slug.md');
      articles.add(_parseArticle(slug, raw));
    }
    articles.sort((a, b) => b.published.compareTo(a.published));

    return ArticlesData(categories: categories, articles: articles);
  }

  Article _parseArticle(String slug, String raw) {
    final fmMatch = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$').firstMatch(raw);
    final data = <String, String>{};
    var body = raw;
    if (fmMatch != null) {
      final fmText = fmMatch.group(1) ?? '';
      body = fmMatch.group(2) ?? '';
      for (final line in fmText.split(RegExp(r'\r?\n'))) {
        final m = RegExp(r'^([a-zA-Z_][\w-]*)\s*:\s*(.*)$').firstMatch(line);
        if (m == null) continue;
        final key = m.group(1) ?? '';
        var value = (m.group(2) ?? '').trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
             (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        data[key] = value;
      }
    }

    return Article(
      slug: slug,
      title: data['title'] ?? 'Sin título',
      category: data['category'] ?? 'entrenamiento',
      excerpt: data['excerpt'] ?? '',
      cover: data['cover'] ?? '',
      published: data['published'] ?? '',
      author: data['author'] ?? 'PR Team',
      body: body,
      readingMinutes: _readingTime(body),
    );
  }

  int _readingTime(String body) {
    final cleaned = body.replaceAll(RegExp(r'[#*_`>\-\[\]()!]'), ' ').trim();
    if (cleaned.isEmpty) return 1;
    final words = cleaned.split(RegExp(r'\s+')).length;
    final minutes = (words / 220).round();
    return minutes < 1 ? 1 : minutes;
  }
}
