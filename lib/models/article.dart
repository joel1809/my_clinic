import '../core/app_config.dart';

/// Article de blog (ArticleResource).
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.slug,
    this.category,
    this.summary,
    this.coverImageUrl,
    this.publishedAt,
    this.author,
    this.body,
    this.detailImageUrls = const [],
  });

  final int id;
  final String title;
  final String slug;
  final String? category;
  final String? summary;
  final String? coverImageUrl;
  final DateTime? publishedAt;
  final String? author;
  final String? body; // uniquement sur la fiche détaillée
  final List<String> detailImageUrls;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as int,
        title: json['title'] as String,
        slug: json['slug'] as String,
        category: json['category'] as String?,
        summary: json['summary'] as String?,
        coverImageUrl: json['cover_image_url'] is String
            ? AppConfig.resolveMediaUrl(json['cover_image_url'] as String)
            : null,
        publishedAt: json['published_at'] is String
            ? DateTime.tryParse(json['published_at'] as String)
            : null,
        author: json['author'] as String?,
        body: json['body'] as String?,
        detailImageUrls: json['detail_image_urls'] is List
            ? (json['detail_image_urls'] as List)
                .map((u) => AppConfig.resolveMediaUrl(u.toString()))
                .toList()
            : const [],
      );

  /// Contenu texte lisible : le corps peut contenir du HTML basique.
  String get plainBody => (body ?? '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
