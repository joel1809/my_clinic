/// Lecture du texte mis en forme renvoyé par l'API.
///
/// Les rubriques cliniques du dossier médical (allergies, antécédents,
/// traitements, diagnostic, prescription…) sont saisies dans un éditeur
/// enrichi côté administration : l'API les transmet en HTML assaini, limité
/// à un petit jeu de balises — paragraphes, titres, citations, listes à
/// puces ou numérotées, gras, italique, souligné, barré.
///
/// Ce module traduit ce HTML en blocs simples, que `RichTextBody` dessine
/// avec le système de design de l'application. Les anciennes valeurs, saisies
/// en texte brut avant l'éditeur enrichi, restent lisibles : sans balise,
/// chaque ligne vide sépare deux paragraphes.
library;

/// Nature d'un bloc de contenu.
enum RichBlockKind {
  paragraph,
  heading,
  quote,

  /// Élément d'une liste à puces.
  bullet,

  /// Élément d'une liste numérotée.
  numbered,
}

/// Fragment de texte d'un bloc, avec sa mise en forme.
class RichPiece {
  const RichPiece(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Fragment sans aucune mise en forme : il peut alors s'afficher dans un
  /// simple `Text`, sans passer par un `TextSpan`.
  bool get isPlain => !bold && !italic && !underline && !strike;

  RichPiece withText(String text) => RichPiece(
        text,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
      );

  /// Deux fragments voisins de même mise en forme se réunissent en un seul.
  bool sameStyleAs(RichPiece other) =>
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      strike == other.strike;
}

/// Bloc de contenu : un paragraphe, un titre, une citation ou un élément de
/// liste, composé de fragments diversement mis en forme.
class RichBlock {
  const RichBlock({
    required this.kind,
    required this.pieces,
    this.depth = 0,
    this.number,
  });

  final RichBlockKind kind;
  final List<RichPiece> pieces;

  /// Niveau d'imbrication dans les listes : 0 hors liste, 1 pour une liste de
  /// premier niveau, 2 pour une liste imbriquée…
  final int depth;

  /// Rang dans une liste numérotée.
  final int? number;

  /// Texte du bloc, mise en forme ôtée.
  String get text => pieces.map((piece) => piece.text).join();

  bool get isListItem =>
      kind == RichBlockKind.bullet || kind == RichBlockKind.numbered;

  /// Bloc ordinaire, sans mise en forme : il se dessine tel quel.
  bool get isPlainParagraph =>
      kind == RichBlockKind.paragraph &&
      depth == 0 &&
      pieces.every((piece) => piece.isPlain);
}

/// Découpe un contenu mis en forme en blocs affichables.
///
/// Une valeur vide, absente ou réduite à des balises sans texte donne une
/// liste vide : l'appelant affiche alors son propre repli (« Non renseigné »).
List<RichBlock> parseRichHtml(String? html) {
  final source = html ?? '';
  if (source.trim().isEmpty) return const [];

  // Ancienne saisie en texte brut : aucune balise à interpréter. Un « < »
  // isolé (« tension < 12 ») n'en fait pas du HTML pour autant.
  if (!_RichHtmlParser.hasTag(source)) return _plainTextBlocks(source);

  return _RichHtmlParser(source).parse();
}

/// Contenu mis en forme réduit à du texte lisible, pour les endroits où la
/// place manque : aperçu d'une consultation dans une liste, message d'un
/// pop-up, corps d'un article.
///
/// Les paragraphes sont séparés d'une ligne vide, les éléments d'une même
/// liste se suivent ligne à ligne, précédés de leur puce ou de leur numéro.
String richHtmlToPlainText(String? html) {
  final blocks = parseRichHtml(html);
  final buffer = StringBuffer();

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (i > 0) {
      final previous = blocks[i - 1];
      buffer.write(block.isListItem && previous.isListItem ? '\n' : '\n\n');
    }
    buffer.write(switch (block.kind) {
      RichBlockKind.bullet => '• ',
      RichBlockKind.numbered => '${block.number ?? i + 1}. ',
      _ => '',
    });
    buffer.write(block.text);
  }

  return buffer.toString();
}

/// Texte brut découpé en paragraphes : une ligne vide les sépare, les retours
/// à la ligne simples restent dans le paragraphe.
List<RichBlock> _plainTextBlocks(String source) {
  return source
      .split(RegExp(r'\n[ \t]*\n'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .map((paragraph) => RichBlock(
            kind: RichBlockKind.paragraph,
            pieces: [RichPiece(paragraph)],
          ))
      .toList();
}

/// Lecteur du sous-ensemble de HTML produit par l'éditeur enrichi.
///
/// Le contenu est déjà assaini par l'API : il n'y a ni script, ni style, ni
/// attribut à interpréter. On ne cherche donc pas à couvrir HTML dans son
/// ensemble, seulement les balises que l'éditeur sait produire ; toute autre
/// balise est ignorée et son texte conservé.
class _RichHtmlParser {
  _RichHtmlParser(this._source);

  final String _source;

  static final _tagPattern = RegExp(r'<(/?)\s*([a-zA-Z][a-zA-Z0-9]*)[^>]*>');

  /// Le contenu porte-t-il au moins une balise à interpréter ?
  static bool hasTag(String source) => _tagPattern.hasMatch(source);

  static const _styleTags = <String, String>{
    'strong': 'bold',
    'b': 'bold',
    'em': 'italic',
    'i': 'italic',
    'u': 'underline',
    's': 'strike',
    'del': 'strike',
    'strike': 'strike',
  };

  final _blocks = <RichBlock>[];
  final _pieces = <RichPiece>[];

  /// Balises de style ouvertes, dans l'ordre : le gras d'un fragment vient de
  /// la présence d'un « bold » dans cette pile.
  final _styles = <String>[];

  /// Listes ouvertes, de la plus extérieure à la plus imbriquée.
  final _lists = <_ListLevel>[];

  bool _inListItem = false;
  bool _inHeading = false;
  int _quoteDepth = 0;

  List<RichBlock> parse() {
    var index = 0;
    for (final match in _tagPattern.allMatches(_source)) {
      if (match.start > index) {
        _appendText(_source.substring(index, match.start));
      }
      index = match.end;

      final closing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();
      if (closing) {
        _closeTag(tag);
      } else {
        _openTag(tag);
      }
    }
    if (index < _source.length) _appendText(_source.substring(index));
    _flush();

    return _blocks;
  }

  void _openTag(String tag) {
    final style = _styleTags[tag];
    if (style != null) {
      _styles.add(style);
      return;
    }

    switch (tag) {
      case 'br':
        // Une rupture de ligne voulue : elle reste dans le bloc courant.
        _appendPiece('\n');
      case 'p':
      case 'div':
        _flush();
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _flush();
        _inHeading = true;
      case 'blockquote':
        _flush();
        _quoteDepth++;
      case 'ul':
      case 'ol':
        _flush();
        _lists.add(_ListLevel(ordered: tag == 'ol'));
      case 'li':
        _flush();
        _inListItem = true;
        if (_lists.isNotEmpty) _lists.last.counter++;
    }
  }

  void _closeTag(String tag) {
    final style = _styleTags[tag];
    if (style != null) {
      // On retire la dernière ouverture de ce style : une balise fermée sans
      // ouverture correspondante est simplement ignorée.
      final position = _styles.lastIndexOf(style);
      if (position >= 0) _styles.removeAt(position);
      return;
    }

    switch (tag) {
      case 'p':
      case 'div':
        _flush();
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _flush();
        _inHeading = false;
      case 'blockquote':
        _flush();
        if (_quoteDepth > 0) _quoteDepth--;
      case 'ul':
      case 'ol':
        _flush();
        if (_lists.isNotEmpty) _lists.removeLast();
        _inListItem = false;
      case 'li':
        _flush();
        _inListItem = false;
    }
  }

  /// Texte d'un nœud : espaces multiples réduits, entités décodées.
  void _appendText(String raw) {
    final text = _decodeEntities(raw).replaceAll(RegExp(r'\s+'), ' ');
    if (text.trim().isEmpty && _pieces.isEmpty) return;
    _appendPiece(text);
  }

  void _appendPiece(String text) {
    if (text.isEmpty) return;
    final piece = RichPiece(
      text,
      bold: _styles.contains('bold'),
      italic: _styles.contains('italic'),
      underline: _styles.contains('underline'),
      strike: _styles.contains('strike'),
    );

    if (_pieces.isNotEmpty && _pieces.last.sameStyleAs(piece)) {
      _pieces.last = _pieces.last.withText(_pieces.last.text + text);
      return;
    }
    _pieces.add(piece);
  }

  /// Clôt le bloc en cours : les fragments accumulés en forment un, sauf s'il
  /// ne reste que des espaces (`<p></p>` vide, saut de ligne d'indentation).
  void _flush() {
    final pieces = _trimEdges(_pieces);
    _pieces.clear();
    if (pieces.isEmpty) return;

    _blocks.add(RichBlock(
      kind: _currentKind,
      pieces: pieces,
      depth: _lists.length,
      number: _inListItem && _lists.isNotEmpty && _lists.last.ordered
          ? _lists.last.counter
          : null,
    ));
  }

  RichBlockKind get _currentKind {
    if (_inListItem && _lists.isNotEmpty) {
      return _lists.last.ordered ? RichBlockKind.numbered : RichBlockKind.bullet;
    }
    if (_inHeading) return RichBlockKind.heading;
    if (_quoteDepth > 0) return RichBlockKind.quote;
    return RichBlockKind.paragraph;
  }

  /// Ôte les espaces de bord du bloc sans toucher à ceux qui séparent deux
  /// fragments (« **gras** puis suite »).
  static List<RichPiece> _trimEdges(List<RichPiece> pieces) {
    final trimmed = List<RichPiece>.from(pieces);
    if (trimmed.isNotEmpty) {
      trimmed.first = trimmed.first.withText(trimmed.first.text.trimLeft());
      trimmed.last = trimmed.last.withText(trimmed.last.text.trimRight());
    }
    trimmed.removeWhere((piece) => piece.text.isEmpty);

    return trimmed;
  }

  static String _decodeEntities(String text) {
    if (!text.contains('&')) return text;

    return text
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (match) => _fromCharCode(int.tryParse(match.group(1)!)),
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (match) => _fromCharCode(int.tryParse(match.group(1)!, radix: 16)),
        )
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        // En dernier : une esperluette décodée trop tôt ferait relire les
        // entités qu'elle précède (« &amp;lt; » doit rester « &lt; »).
        .replaceAll('&amp;', '&');
  }

  static String _fromCharCode(int? code) =>
      code == null || code <= 0 || code > 0x10FFFF ? '' : String.fromCharCode(code);
}

/// Liste ouverte : sa nature et le rang de son dernier élément.
class _ListLevel {
  _ListLevel({required this.ordered});

  final bool ordered;
  int counter = 0;
}
