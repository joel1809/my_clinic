import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/models/article.dart';
import 'package:my_clinic/repositories/article_repository.dart';
import 'package:my_clinic/screens/articles/article_detail_screen.dart';

/// Fiche détaillée d'un article : le corps est saisi dans un éditeur enrichi
/// et transmis par l'API en HTML assaini ; l'écran doit le rendre mis en
/// forme, et non aplati en un bloc de texte.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpArticle(WidgetTester tester, Article article) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ArticleRepository>.value(value: _StubArticleRepo(article)),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: ArticleDetailScreen(slug: 'prevention-du-paludisme'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rend le corps mis en forme reçu de l\'API', (tester) async {
    await pumpArticle(
      tester,
      Article.fromJson(const {
        'id': 1,
        'title': 'Prévention du paludisme',
        'slug': 'prevention-du-paludisme',
        'body': '<p>Trois gestes <strong>simples</strong> :</p>'
            '<ul><li>Moustiquaire</li><li>Répulsif</li></ul>',
      }),
    );

    expect(find.text('Prévention du paludisme'), findsOneWidget);
    // Chaque élément de liste est une ligne à part, et le gras est porté par
    // un fragment : le paragraphe reste entier.
    expect(find.text('Trois gestes simples :', findRichText: true),
        findsOneWidget);
    expect(find.text('Moustiquaire', findRichText: true), findsOneWidget);
    expect(find.text('Répulsif', findRichText: true), findsOneWidget);
    // Aucune balise ne doit transparaître à l'écran.
    expect(find.textContaining('<', findRichText: true), findsNothing);
  });

  testWidgets('un corps en texte brut s\'affiche tel quel', (tester) async {
    // Article saisi avant l'éditeur enrichi : l'affichage ne change pas.
    await pumpArticle(
      tester,
      Article.fromJson(const {
        'id': 2,
        'title': 'Horaires d\'été',
        'slug': 'horaires-ete',
        'body': 'La clinique ouvre de 8h à 15h en août.',
      }),
    );

    expect(find.text('La clinique ouvre de 8h à 15h en août.'), findsOneWidget);
  });
}

/// Repository de test : renvoie un article prédéfini sans appel réseau.
class _StubArticleRepo extends ArticleRepository {
  _StubArticleRepo(this._article) : super(ApiClient());

  final Article _article;

  @override
  Future<Article> show(String slug) async => _article;
}
