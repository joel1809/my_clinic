import '../core/app_config.dart';

/// Spécialité médicale (SpecialtyResource).
class Specialty {
  const Specialty({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.imageUrl,
    this.doctorsCount,
  });

  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final int? doctorsCount;

  factory Specialty.fromJson(Map<String, dynamic> json) => Specialty(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        imageUrl: json['image_url'] is String
            ? AppConfig.resolveMediaUrl(json['image_url'] as String)
            : null,
        doctorsCount: json['doctors_count'] as int?,
      );
}
