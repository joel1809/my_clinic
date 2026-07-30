import '../core/app_config.dart';

/// Assurance partenaire (PartnerResource) : proposée au patient lors de la
/// prise de rendez-vous pour déclarer sa ou ses couvertures.
class Insurance {
  const Insurance({
    required this.id,
    required this.name,
    this.category,
    this.logoUrl,
    this.websiteUrl,
  });

  final int id;
  final String name;
  final String? category;
  final String? logoUrl;
  final String? websiteUrl;

  factory Insurance.fromJson(Map<String, dynamic> json) => Insurance(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String?,
        logoUrl: json['logo_url'] is String
            ? AppConfig.resolveMediaUrl(json['logo_url'] as String)
            : null,
        websiteUrl: json['website_url'] as String?,
      );
}
