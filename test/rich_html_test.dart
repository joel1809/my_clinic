import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/core/rich_html.dart';

/// Lecture du HTML assaini que l'API transmet pour les rubriques cliniques
/// (allergies, antécédents, diagnostic, prescription…), saisies dans un
/// éditeur enrichi côté administration.
void main() {
  group('parseRichHtml', () {
    test('une valeur vide ou absente ne donne aucun bloc', () {
      expect(parseRichHtml(null), isEmpty);
      expect(parseRichHtml(''), isEmpty);
      expect(parseRichHtml('   '), isEmpty);
      // Un paragraphe vide laissé par l'éditeur ne compte pas non plus.
      expect(parseRichHtml('<p></p>'), isEmpty);
    });

    test('découpe les paragraphes et décode les entités', () {
      final blocks = parseRichHtml('<p>Premier.</p><p>Second &amp; dernier.</p>');

      expect(blocks, hasLength(2));
      expect(blocks.first.kind, RichBlockKind.paragraph);
      expect(blocks.first.text, 'Premier.');
      expect(blocks.last.text, 'Second & dernier.');
    });

    test('relève le gras et l\'italique fragment par fragment', () {
      final blocks =
          parseRichHtml('<p><strong>Arachides</strong> et <em>lactose</em></p>');

      expect(blocks, hasLength(1));
      final pieces = blocks.single.pieces;
      expect(pieces.map((piece) => piece.text),
          ['Arachides', ' et ', 'lactose']);
      expect(pieces[0].bold, isTrue);
      expect(pieces[1].isPlain, isTrue);
      expect(pieces[2].italic, isTrue);
    });

    test('numérote les listes et retient leur imbrication', () {
      final blocks = parseRichHtml(
        '<ul><li>Asthme</li><li>Diabète<ul><li>type 2</li></ul></li></ul>'
        '<ol><li>Amoxicilline</li><li>Paracétamol</li></ol>',
      );

      expect(blocks.map((block) => block.text),
          ['Asthme', 'Diabète', 'type 2', 'Amoxicilline', 'Paracétamol']);
      expect(blocks[0].kind, RichBlockKind.bullet);
      expect(blocks[0].depth, 1);
      // Élément de la liste imbriquée.
      expect(blocks[2].depth, 2);
      expect(blocks[3].kind, RichBlockKind.numbered);
      expect(blocks[3].number, 1);
      expect(blocks[4].number, 2);
    });

    test('distingue titres et citations', () {
      final blocks =
          parseRichHtml('<h3>Suivi</h3><blockquote><p>À revoir.</p></blockquote>');

      expect(blocks.first.kind, RichBlockKind.heading);
      expect(blocks.last.kind, RichBlockKind.quote);
      expect(blocks.last.text, 'À revoir.');
    });

    test('garde un saut de ligne voulu dans le paragraphe', () {
      final blocks = parseRichHtml('<p>Matin<br>Soir</p>');

      expect(blocks, hasLength(1));
      expect(blocks.single.text, 'Matin\nSoir');
    });

    test('lit une ancienne saisie en texte brut', () {
      // Avant l'éditeur enrichi, les rubriques étaient de simples zones de
      // texte : les dossiers déjà remplis doivent rester lisibles.
      final blocks = parseRichHtml('Pénicilline\n\nContrôle annuel');

      expect(blocks.map((block) => block.text),
          ['Pénicilline', 'Contrôle annuel']);
      expect(blocks.every((block) => block.isPlainParagraph), isTrue);
    });

    test('un « < » isolé reste du texte, pas une balise', () {
      final blocks = parseRichHtml('Tension < 12');

      expect(blocks.single.text, 'Tension < 12');
    });

    test('ignore les balises inconnues en gardant leur texte', () {
      final blocks = parseRichHtml('<p><span class="x">Suivi</span> régulier</p>');

      expect(blocks.single.text, 'Suivi régulier');
    });
  });

  group('richHtmlToPlainText', () {
    test('sépare les paragraphes d\'une ligne vide', () {
      expect(
        richHtmlToPlainText('<p>Premier paragraphe.</p><p>Second &amp; dernier.</p>'),
        'Premier paragraphe.\n\nSecond & dernier.',
      );
    });

    test('marque les éléments de liste, ligne à ligne', () {
      expect(
        richHtmlToPlainText('<ul><li>Asthme</li><li>Diabète</li></ul>'),
        '• Asthme\n• Diabète',
      );
      expect(
        richHtmlToPlainText('<ol><li>Matin</li><li>Soir</li></ol>'),
        '1. Matin\n2. Soir',
      );
    });

    test('une valeur absente donne une chaîne vide', () {
      expect(richHtmlToPlainText(null), '');
    });
  });
}
