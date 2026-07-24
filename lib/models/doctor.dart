import '../core/app_config.dart';
import 'specialty.dart';

/// Médecin (DoctorResource).
class Doctor {
  const Doctor({
    required this.id,
    required this.fullName,
    required this.appointmentDuration,
    this.bio,
    this.photoUrl,
    this.specialty,
  });

  final int id;
  final String fullName;
  final String? bio;
  final String? photoUrl;
  final int appointmentDuration; // minutes
  final Specialty? specialty;

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        bio: json['bio'] as String?,
        photoUrl: json['photo_url'] is String
            ? AppConfig.resolveMediaUrl(json['photo_url'] as String)
            : null,
        appointmentDuration: (json['appointment_duration'] as num?)?.toInt() ?? 30,
        specialty: json['specialty'] is Map<String, dynamic>
            ? Specialty.fromJson(json['specialty'] as Map<String, dynamic>)
            : null,
      );
}
