import 'package:flutter/material.dart';

import '../core/rich_html.dart';
import '../theme.dart';

/// Affiche une rubrique mise en forme reçue de l'API (HTML assaini) avec les
/// styles du système de design : paragraphes, titres, citations, listes à
/// puces et numérotées, gras, italique, souligné, barré.
///
/// Une valeur sans mise en forme — ancienne saisie en texte brut, ou simple
/// phrase — se dessine dans un `Text` ordinaire : l'affichage reste identique
/// à ce qu'il était avant l'éditeur enrichi.
class RichTextBody extends StatelessWidget {
  const RichTextBody({
    super.key,
    required this.html,
    this.style,
    this.emptyPlaceholder,
  });

  /// Contenu mis en forme, tel que reçu de l'API.
  final String? html;

  /// Style de base du texte courant ; les mises en forme s'y ajoutent.
  final TextStyle? style;

  /// Texte affiché en gris quand la rubrique est vide ; sans lui, rien ne
  /// s'affiche.
  final String? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    final blocks = parseRichHtml(html);

    if (blocks.isEmpty) {
      if (emptyPlaceholder == null) return const SizedBox.shrink();
      // Une valeur absente reste lisible mais s'efface : l'œil va d'abord aux
      // informations réellement remplies.
      return Text(
        emptyPlaceholder!,
        style: base.copyWith(color: AppPalette.inkFaint),
      );
    }

    // Cas de loin le plus courant : une valeur d'une seule ligne, sans mise
    // en forme. Inutile de construire une colonne pour elle.
    if (blocks.length == 1 && blocks.first.isPlainParagraph) {
      return Text(blocks.first.text, style: base);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gapBefore(blocks, i)),
            child: _RichBlockView(block: blocks[i], base: base),
          ),
      ],
    );
  }

  /// Espace au-dessus d'un bloc : resserré entre les éléments d'une même
  /// liste, plus large entre deux paragraphes.
  static double _gapBefore(List<RichBlock> blocks, int index) {
    final block = blocks[index];
    if (block.isListItem && blocks[index - 1].isListItem) return 4;
    return block.kind == RichBlockKind.heading ? 12 : 8;
  }
}

/// Dessin d'un bloc selon sa nature.
class _RichBlockView extends StatelessWidget {
  const _RichBlockView({required this.block, required this.base});

  final RichBlock block;
  final TextStyle base;

  /// Décalage des listes imbriquées : le premier niveau reste aligné sur le
  /// texte, chaque niveau suivant rentre d'un cran.
  double get _indent => ((block.depth - 1).clamp(0, 3)) * 16;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(_spans(base), style: base);

    return switch (block.kind) {
      RichBlockKind.heading => Text.rich(
          _spans(base.copyWith(
            fontSize: (base.fontSize ?? 15) + 1,
            fontWeight: FontWeight.w600,
            color: AppPalette.ink,
          )),
        ),
      RichBlockKind.quote => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppPalette.primary.withValues(alpha: .35),
                width: 3,
              ),
            ),
          ),
          child: Text.rich(
            _spans(base.copyWith(
              fontStyle: FontStyle.italic,
              color: AppPalette.inkMuted,
            )),
          ),
        ),
      RichBlockKind.bullet || RichBlockKind.numbered => Padding(
          padding: EdgeInsets.only(left: _indent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: block.kind == RichBlockKind.numbered ? 24 : 16,
                child: Text(
                  block.kind == RichBlockKind.numbered
                      ? '${block.number ?? 1}.'
                      : '•',
                  style: base.copyWith(color: AppPalette.primary),
                ),
              ),
              Expanded(child: text),
            ],
          ),
        ),
      RichBlockKind.paragraph => text,
    };
  }

  /// Fragments du bloc, chacun avec sa mise en forme posée sur [style].
  TextSpan _spans(TextStyle style) => TextSpan(
        children: [
          for (final piece in block.pieces)
            TextSpan(text: piece.text, style: _pieceStyle(piece, style)),
        ],
      );

  static TextStyle _pieceStyle(RichPiece piece, TextStyle base) {
    final decorations = <TextDecoration>[
      if (piece.underline) TextDecoration.underline,
      if (piece.strike) TextDecoration.lineThrough,
    ];

    return base.copyWith(
      fontWeight: piece.bold ? FontWeight.w600 : null,
      fontStyle: piece.italic ? FontStyle.italic : null,
      decoration:
          decorations.isEmpty ? null : TextDecoration.combine(decorations),
      decorationColor: base.color,
    );
  }
}
