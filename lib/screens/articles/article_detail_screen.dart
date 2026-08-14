import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../theme.dart';
import '../../widgets/rich_text_body.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: FutureBuilder<Article>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ArticleSkeleton();
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
                // L'affichage bord à bord fait passer la fin de l'article sous
                // la barre de navigation du téléphone : on lui rend la hauteur
                // de la zone système.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.page + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppPalette.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          article.category!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppPalette.primary, letterSpacing: .4),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 15, color: AppPalette.inkFaint),
                        const SizedBox(width: 5),
                        Text(
                          article.author ?? 'La clinique',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (article.publishedAt != null) ...[
                          const SizedBox(width: 14),
                          Icon(Icons.calendar_today_outlined,
                              size: 13, color: AppPalette.inkFaint),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('d MMMM yyyy', 'fr_FR')
                                .format(article.publishedAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 36),
                    // Corps de l'article : interligne large et taille légèrement
                    // supérieure au reste de l'app, c'est du texte à lire en
                    // continu et non à balayer.
                    //
                    // L'API le transmet en HTML assaini (l'article est saisi
                    // dans un éditeur enrichi) : titres, listes et gras sont
                    // rendus, comme sur le site web.
                    RichTextBody(
                      html: article.body,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.7,
                        color: AppPalette.ink,
                      ),
                    ),
                    if (article.detailImageUrls.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      for (final url in article.detailImageUrls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                          child: NetworkImageBox(
                            url: url,
                            height: 200,
                            width: double.infinity,
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
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

/// Squelette de l'article pendant le chargement : bandeau, titre sur deux
/// lignes puis lignes de texte, dans les proportions du contenu réel.
class _ArticleSkeleton extends StatelessWidget {
  const _ArticleSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SkeletonBox(height: 220, radius: 0),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 90, height: 22, radius: AppRadius.pill),
              const SizedBox(height: 14),
              const SkeletonBox(height: 28),
              const SizedBox(height: 8),
              const SkeletonBox(width: 220, height: 28),
              const SizedBox(height: 28),
              for (var i = 0; i < 8; i++) ...[
                SkeletonBox(height: 13, width: i.isEven ? null : 260),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
