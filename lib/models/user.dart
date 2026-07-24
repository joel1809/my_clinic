/// Profil patient rattaché au compte (UserResource -> patient).
class PatientProfile {
  const PatientProfile({
    required this.id,
    this.gender,
    this.birthDate,
    this.address,
  });

  final int id;
  final String? gender; // male | female
  final String? birthDate; // Y-m-d
  final String? address;

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
        id: json['id'] as int,
        gender: json['gender'] as String?,
        birthDate: json['birth_date'] as String?,
        address: json['address'] as String?,
      );

  String get genderLabel => switch (gender) {
        'male' => 'Homme',
        'female' => 'Femme',
        _ => '—',
      };
}

/// Compte utilisateur (UserResource).
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.patient,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role; // patient | doctor | admin | contributor
  final PatientProfile? patient;

  bool get isPatient => role == 'patient';
  bool get isDoctor => role == 'doctor';
  bool get isAdmin => role == 'admin';

  /// Personnel de la clinique : accède à la gestion des rendez-vous
  /// et aux dossiers médicaux.
  bool get isStaff => isDoctor || isAdmin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        patient: json['patient'] is Map<String, dynamic>
            ? PatientProfile.fromJson(json['patient'] as Map<String, dynamic>)
            : null,
      );
}
