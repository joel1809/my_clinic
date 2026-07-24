import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../widgets/shared.dart';

/// Fiche détaillée d'un article (contenu complet + galerie).
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<Article> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<ArticleRepository>().show(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: FutureBuilder<Article>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }

          final article = snapshot.data!;

          return FadeSlideIn(
              child: ListView(
            padding: EdgeInsets.zero,
            children: [
              NetworkImageBox(
                url: article.coverImageUrl,
                height: 220,
                width: double.infinity,
                fallbackIcon: Icons.article_outlined,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (article.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              article.category!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.bold, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          article.author ?? 'La clinique',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 16),
                        if (article.publishedAt != null) ...[
                          Icon(Icons.calendar_today_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMMM yyyy', 'fr_FR')
                                .format(article.publishedAt!),
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      article.plainBody,
                      style: const TextStyle(fontSize: 15, height: 1.65),
                    ),
                    if (article.detailImageUrls.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      for (final url in article.detailImageUrls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NetworkImageBox(
                            url: url,
                            height: 200,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ));
        },
      ),
    );
  }
}
