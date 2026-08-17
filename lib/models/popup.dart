import '../core/app_config.dart';
import '../core/rich_html.dart';

/// Pop-up informationnel de la clinique (PopupResource) : annonce, campagne
/// de prévention, fermeture exceptionnelle… affiché au démarrage.
class Popup {
  const Popup({
    required this.id,
    required this.title,
    required this.frequency,
    required this.dailyDisplayLimit,
    required this.delaySeconds,
    required this.storageKeyRaw,
    this.content,
    this.imageUrl,
    this.buttonText,
    this.buttonUrl,
  });

  final int id;
  final String title;
  final String? content; // HTML basique, nettoyé côté serveur
  final String? imageUrl;
  final String? buttonText;
  final String? buttonUrl;
  final String frequency; // once | session | daily | always
  final int dailyDisplayLimit; // affichages par jour pour « daily »
  final int delaySeconds;

  /// Empreinte de mémorisation telle que renvoyée par l'API : elle change à
  /// chaque modification du pop-up, pour qu'un contenu mis à jour soit
  /// réaffiché. Voir [storageKey], qui en dérive la clé réellement utilisée.
  final String storageKeyRaw;

  factory Popup.fromJson(Map<String, dynamic> json) => Popup(
        id: json['id'] as int,
        title: json['title'] as String,
        content: json['content'] as String?,
        imageUrl: json['image_url'] is String
            ? AppConfig.resolveMediaUrl(json['image_url'] as String)
            : null,
        buttonText: json['button_text'] as String?,
        // Le lien du bouton est contrôlé comme l'illustration, aux hôtes tiers
        // près : il mène au backend, ou à un hôte inscrit dans la liste fixée
        // à la construction (voir AppConfig.linkUri). Écarté, le bouton
        // disparaît (voir `hasButton` dans info_popup.dart) plutôt que de
        // rester affiché sans rien faire.
        buttonUrl: json['button_url'] is String
            ? AppConfig.resolveLinkUrl(json['button_url'] as String)
            : null,
        frequency: json['frequency'] as String? ?? 'always',
        dailyDisplayLimit: (json['daily_display_limit'] as num?)?.toInt() ?? 1,
        delaySeconds: (json['delay_seconds'] as num?)?.toInt() ?? 0,
        storageKeyRaw: json['storage_key'] as String? ?? '',
      );

  /// Préfixe commun aux clés de toutes les versions de ce pop-up : sert à
  /// purger les mémorisations d'anciennes versions.
  String get storagePrefix => 'popup-$id-';

  /// Clé sous laquelle l'affichage de ce pop-up est mémorisé localement.
  ///
  /// Elle est construite ici plutôt que reprise telle quelle de l'API : cette
  /// valeur désigne une entrée des préférences de l'application, qui est
  /// écrite puis purgée par préfixe. Une réponse forgée pourrait sinon
  /// désigner la clé d'un autre composant et l'écraser. On ne garde donc de
  /// l'empreinte reçue que des caractères inoffensifs, sous un préfixe propre
  /// à ce pop-up.
  String get storageKey => '$storagePrefix${_tag(storageKeyRaw)}';

  /// Suffixe de la clé : l'empreinte reçue, débarrassée de son préfixe s'il
  /// est déjà celui attendu, puis réduite aux lettres, chiffres, « _ » et
  /// « - ». Une empreinte vide ou entièrement écartée donne une clé stable,
  /// qui mémorise alors le pop-up sans distinguer ses versions.
  String _tag(String raw) {
    final withoutPrefix =
        raw.startsWith(storagePrefix) ? raw.substring(storagePrefix.length) : raw;
    final cleaned = withoutPrefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');

    if (cleaned.isEmpty) return 'v';
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64);
  }

  /// Message en texte lisible : le contenu peut contenir du HTML basique.
  String get plainContent => richHtmlToPlainText(content);
}
