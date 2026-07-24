/// Dossier médical d'un patient, vu par un médecin ou un administrateur
/// (réponse de GET /patients/{id}/medical-record).
class PatientRecord {
  const PatientRecord({
    required this.patient,
    this.record,
    this.documents = const [],
  });

  final RecordPatient patient;
  final MedicalRecordSummary? record;
  final List<MedicalDocumentItem> documents;

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
        patient:
            RecordPatient.fromJson(json['patient'] as Map<String, dynamic>),
        record: json['record'] is Map<String, dynamic>
            ? MedicalRecordSummary.fromJson(
                json['record'] as Map<String, dynamic>)
            : null,
        documents: (json['documents'] as List? ?? const [])
            .map((d) =>
                MedicalDocumentItem.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

/// Identité du patient concerné.
class RecordPatient {
  const RecordPatient({
    required this.id,
    this.name,
    this.phone,
    this.gender,
    this.birthDate,
    this.address,
  });

  final int id;
  final String? name;
  final String? phone;
  final String? gender; // male | female
  final String? birthDate; // Y-m-d
  final String? address;

  factory RecordPatient.fromJson(Map<String, dynamic> json) => RecordPatient(
        id: json['id'] as int,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
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

/// Synthèse clinique de la fiche médicale.
class MedicalRecordSummary {
  const MedicalRecordSummary({
    this.bloodType,
    this.allergies,
    this.medicalHistory,
    this.currentMedications,
    this.notes,
  });

  final String? bloodType; // A+, O-, …
  final String? allergies;
  final String? medicalHistory;
  final String? currentMedications;
  final String? notes;

  factory MedicalRecordSummary.fromJson(Map<String, dynamic> json) =>
      MedicalRecordSummary(
        bloodType: json['blood_type'] as String?,
        allergies: json['allergies'] as String?,
        medicalHistory: json['medical_history'] as String?,
        currentMedications: json['current_medications'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Document versé au dossier (analyse, ordonnance, radio, …).
class MedicalDocumentItem {
  const MedicalDocumentItem({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.isImage,
    required this.isPdf,
    required this.fileUrl,
    this.issuedAt,
    this.notes,
  });

  final int id;
  final String type; // analysis_result | prescription | radiography | other
  final String typeLabel;
  final String title;
  final bool isImage;
  final bool isPdf;

  /// URL signée relative (à préfixer de AppConfig.baseUrl), valable 30 min.
  final String fileUrl;
  final String? issuedAt; // Y-m-d
  final String? notes;

  factory MedicalDocumentItem.fromJson(Map<String, dynamic> json) =>
      MedicalDocumentItem(
        id: json['id'] as int,
        type: json['type'] as String,
        typeLabel: json['type_label'] as String,
        title: json['title'] as String,
        isImage: json['is_image'] as bool? ?? false,
        isPdf: json['is_pdf'] as bool? ?? false,
        fileUrl: json['file_url'] as String,
        issuedAt: json['issued_at'] as String?,
        notes: json['notes'] as String?,
      );
}
