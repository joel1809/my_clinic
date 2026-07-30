import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'article_detail_screen.dart';

/// Actualités de la clinique : liste paginée, filtrable par catégorie.
class ArticlesTab extends StatefulWidget {
  const ArticlesTab({super.key});

  @override
  State<ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<ArticlesTab> {
  final _scrollController = ScrollController();
  final List<Article> _articles = [];

  List<String> _categories = const [];
  String? _category;

  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  /// Page affichée et nombre total de pages (pagination numérotée).
  int _page = 1;
  int _lastPage = 1;

  /// Dernière page demandée, pour la retenter après une erreur réseau.
  int _requestedPage = 1;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories =
          await context.read<ArticleRepository>().categories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Le filtre est facultatif : on ignore l'échec
    }
  }

  /// Charge une page et remplace la liste affichée par son contenu.
  Future<void> _loadPage(int page) async {
    if (_loading) return;
    _requestedPage = page;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context
          .read<ArticleRepository>()
          .list(page: page, category: _category);
      if (!mounted) return;
      setState(() {
        _articles
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _initialLoaded = true;
      });
      // Nouvelle page : la lecture reprend en haut de la liste
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _loadPage(_page);

  void _selectCategory(String? category) {
    if (_category == category) return;
    _category = category;
    // Nouveau filtre : la pagination repart de la première page
    _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actualités',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              'Conseils santé et nouvelles de la clinique',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        toolbarHeight: 76,
        titleSpacing: AppSpacing.page,
        // Pas d'ombre au défilement : la barre de catégories se trouve juste
        // en dessous de l'en-tête, un trait entre les deux couperait la page
        // en deux au lieu de la structurer.
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          if (_categories.isNotEmpty)
            SizedBox(
              height: 62,
              child: ListView(
                scrollDirection: Axis.horizontal,
                // Les marges verticales sont portées par le défilement lui-même
                // plutôt que par un SizedBox extérieur : les puces gardent
                // ainsi de l'air au-dessus et en dessous sans coller au titre
                // ni aux articles.
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, 10, AppSpacing.page, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterPill(
                      label: 'Toutes',
                      selected: _category == null,
                      onTap: () => _selectCategory(null),
                    ),
                  ),
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterPill(
                        label: category,
                        selected: _category == category,
                        onTap: () => _selectCategory(category),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Le squelette couvre le premier chargement comme les changements de
    // page : la liste affichée est remplacée dans les deux cas.
    if (_loading) {
      return const SkeletonList(height: 260);
    }
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () => _loadPage(_requestedPage),
      );
    }
    if (!_initialLoaded) return const SizedBox.shrink();
    if (_articles.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyView(
            icon: Icons.article_outlined,
            title: 'Aucun article',
            message: 'Les publications de la clinique apparaîtront ici.',
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: _articles.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gutter),
      itemBuilder: (context, index) {
        // Barre de pages en pied de liste
        if (index >= _articles.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.gap),
            child: PaginationBar(
              currentPage: _page,
              lastPage: _lastPage,
              onPageSelected: _loadPage,
            ),
          );
        }
        return FadeSlideIn(
          delay: Duration(milliseconds: 50 * (index % 4)),
          child: _ArticleCard(article: _articles[index]),
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(slug: article.slug),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // L'image épouse les coins hauts de la carte ; l'écrêtage est porté
          // ici plutôt que par la carte, dont l'ombre ne doit pas être rognée.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            child: NetworkImageBox(
              url: article.coverImageUrl,
              height: 168,
              width: double.infinity,
              fallbackIcon: Icons.article_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
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
                          color: AppPalette.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          article.category!,
                          style: text.labelSmall?.copyWith(
                            color: AppPalette.primary,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (article.publishedAt != null)
                      Text(
                        DateFormat('d MMM yyyy', 'fr_FR')
                            .format(article.publishedAt!),
                        style: text.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                if (article.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    article.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
