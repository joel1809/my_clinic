import 'package:flutter/material.dart';

import '../core/app_config.dart';

/// Identité visuelle de la clinique (BrandingController) : logos, favicon et
/// couleurs administrés depuis « Paramètres du site ».
///
/// L'application la récupère au démarrage puis la conserve localement : les
/// écrans affichent donc le logo du site dès la première image, même hors
/// ligne, et suivent la charte dès que l'administrateur la change.
class Branding {
  const Branding({
    required this.siteName,
    required this.version,
    this.logoUrlRaw,
    this.logoDarkUrlRaw,
    this.faviconUrlRaw,
    this.logoHeight,
    this.logoDarkHeight,
    this.primaryColor,
    this.headingColor,
    this.textColor,
    this.updatedAt,
  });

  final String siteName;

  /// Adresses telles que renvoyées par l'API : elles pointent vers l'APP_URL
  /// du backend et sont réécrites à la lecture, car l'hôte joignable depuis
  /// l'appareil peut avoir changé depuis leur mise en cache.
  final String? logoUrlRaw;
  final String? logoDarkUrlRaw;
  final String? faviconUrlRaw;

  /// Hauteurs d'affichage des logos en pixels logiques, réglées dans
  /// « Paramètres du site » (celles du site public sur petit écran, pour que
  /// le logo garde la même allure d'un support à l'autre). `null` tant
  /// qu'aucune n'est réglée : l'application applique alors sa propre mise en
  /// page.
  final double? logoHeight;
  final double? logoDarkHeight;

  /// Couleurs de la charte, `null` si l'API n'en a pas renvoyé de valide :
  /// l'application garde alors celles de son système de design.
  final Color? primaryColor;
  final Color? headingColor;
  final Color? textColor;

  /// Empreinte des réglages visuels : elle change dès qu'un logo ou une
  /// couleur est modifié, ce qui permet de purger les images en cache.
  final String version;

  final DateTime? updatedAt;

  /// Logo principal, pour les fonds clairs.
  String? get logoUrl => _resolved(logoUrlRaw);

  /// Logo en version claire, pour les fonds sombres (écran de démarrage).
  String? get logoDarkUrl => _resolved(logoDarkUrlRaw);

  String? get faviconUrl => _resolved(faviconUrlRaw);

  static String? _resolved(String? url) =>
      url == null ? null : AppConfig.resolveMediaUrl(url);

  factory Branding.fromJson(Map<String, dynamic> json) {
    final colors = json['colors'];
    final palette = colors is Map<String, dynamic> ? colors : const {};

    return Branding(
      siteName: json['site_name'] as String? ?? '',
      logoUrlRaw: json['logo_url'] as String?,
      logoDarkUrlRaw: json['logo_dark_url'] as String?,
      faviconUrlRaw: json['favicon_url'] as String?,
      logoHeight: (json['logo_height'] as num?)?.toDouble(),
      logoDarkHeight: (json['logo_dark_height'] as num?)?.toDouble(),
      primaryColor: parseHexColor(palette['primary']),
      headingColor: parseHexColor(palette['heading']),
      textColor: parseHexColor(palette['text']),
      version: json['version'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  /// Même forme que la charge utile de l'API : l'identité mise en cache se
  /// relit avec [Branding.fromJson].
  Map<String, dynamic> toJson() => {
        'site_name': siteName,
        'logo_url': logoUrlRaw,
        'logo_dark_url': logoDarkUrlRaw,
        'favicon_url': faviconUrlRaw,
        'logo_height': logoHeight,
        'logo_dark_height': logoDarkHeight,
        'colors': {
          'primary': hexOf(primaryColor),
          'heading': hexOf(headingColor),
          'text': hexOf(textColor),
        },
        'version': version,
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Adresses des images de la charte, pour vider le cache d'une version
  /// remplacée (un logo peut être téléversé sous le même nom de fichier).
  List<String> get imageUrls =>
      [logoUrl, logoDarkUrl, faviconUrl].whereType<String>().toList();

  /// Couleur `#RGB` ou `#RRGGBB`, ou `null` si la valeur n'en est pas une.
  static Color? parseHexColor(Object? value) {
    if (value is! String) return null;

    final match =
        RegExp(r'^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$').firstMatch(value.trim());
    if (match == null) return null;

    var digits = match.group(1)!;
    // Forme courte : #ABC vaut #AABBCC.
    if (digits.length == 3) {
      digits = digits.split('').map((c) => '$c$c').join();
    }

    return Color(int.parse('FF$digits', radix: 16));
  }

  static String? hexOf(Color? color) => color == null
      ? null
      : '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
