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
    required this.storageKey,
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

  /// Clé de mémorisation locale : elle change à chaque modification du
  /// pop-up, pour qu'un contenu mis à jour soit réaffiché.
  final String storageKey;

  factory Popup.fromJson(Map<String, dynamic> json) => Popup(
        id: json['id'] as int,
        title: json['title'] as String,
        content: json['content'] as String?,
        imageUrl: json['image_url'] is String
            ? AppConfig.resolveMediaUrl(json['image_url'] as String)
            : null,
        buttonText: json['button_text'] as String?,
        buttonUrl: json['button_url'] as String?,
        frequency: json['frequency'] as String? ?? 'always',
        dailyDisplayLimit: (json['daily_display_limit'] as num?)?.toInt() ?? 1,
        delaySeconds: (json['delay_seconds'] as num?)?.toInt() ?? 0,
        storageKey: json['storage_key'] as String? ?? 'popup-${json['id']}',
      );

  /// Préfixe commun aux clés de toutes les versions de ce pop-up : sert à
  /// purger les mémorisations d'anciennes versions.
  String get storagePrefix => 'popup-$id-';

  /// Message en texte lisible : le contenu peut contenir du HTML basique.
  String get plainContent => richHtmlToPlainText(content);
}
