import '../core/api_client.dart';
import '../models/article.dart';
import '../models/paginated.dart';

/// Blog / actualités de la clinique.
class ArticleRepository {
  ArticleRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Article>> list({int page = 1, String? category}) async {
    final json = await _api.get('/articles', query: {
      'page': '$page',
      if (category != null && category.isNotEmpty) 'category': category,
    }) as Map<String, dynamic>;
    return Paginated.fromJson(json, Article.fromJson);
  }

  Future<List<String>> categories() async {
    final json = await _api.get('/articles/categories') as Map<String, dynamic>;
    return (json['data'] as List).map((c) => c.toString()).toList();
  }

  Future<Article> show(String slug) async {
    final json = await _api.get('/articles/$slug') as Map<String, dynamic>;
    return Article.fromJson(json['data'] as Map<String, dynamic>);
  }
}
