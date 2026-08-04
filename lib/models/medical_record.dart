import 'package:intl/intl.dart';

import 'insurance.dart';

/// Dossier médical d'un patient, vu par un médecin ou un administrateur
/// (réponse de GET /patients/{id}/medical-record).
class PatientRecord {
  const PatientRecord({
    required this.patient,
    this.record,
    this.insurances = const [],
    this.consultations = const RecordPage(),
    this.documents = const RecordPage(),
  });

  final RecordPatient patient;
  final MedicalRecordSummary? record;

  /// Assurances couvrant le patient : celles déclarées lors de ses rendez-vous
  /// rejoignent son dossier et y restent, s'ajoutant à celles saisies par
  /// l'administration.
  final List<Insurance> insurances;

  /// Historique paginé des consultations, de la plus récente à la plus
  /// ancienne, chacune avec ses documents joints.
  final RecordPage<ConsultationItem> consultations;

  /// Documents du dossier, paginés (page pilotée par `documents_page`).
  final RecordPage<MedicalDocumentItem> documents;

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
        patient:
            RecordPatient.fromJson(json['patient'] as Map<String, dynamic>),
        record: json['record'] is Map<String, dynamic>
            ? MedicalRecordSummary.fromJson(
                json['record'] as Map<String, dynamic>)
            : null,
        insurances: (json['insurances'] as List? ?? const [])
            .map((i) => Insurance.fromJson(i as Map<String, dynamic>))
            .toList(),
        consultations:
            RecordPage.fromJson(json['consultations'], ConsultationItem.fromJson),
        documents:
            RecordPage.fromJson(json['documents'], MedicalDocumentItem.fromJson),
      );
}

/// Tranche paginée d'une liste du dossier (consultations ou documents) :
/// `{items: [...], pagination: {current_page, last_page, total}}`.
class RecordPage<T> {
  const RecordPage({
    this.items = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;

  /// Nombre d'éléments toutes pages confondues.
  final int total;

  factory RecordPage.fromJson(
    Object? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    // Ancienne forme du dossier (liste à plat, avant la pagination) : tout
    // tient sur une seule page.
    if (json is List) {
      final items =
          json.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      return RecordPage(items: items, total: items.length);
    }
    if (json is! Map<String, dynamic>) return const RecordPage();

    final items = (json['items'] as List? ?? const [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = json['pagination'];
    final meta =
        pagination is Map<String, dynamic> ? pagination : const <String, dynamic>{};

    return RecordPage(
      items: items,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

/// Consultation passée du patient, avec ses documents joints
/// (compte rendu versé au dossier par le médecin).
class ConsultationItem {
  const ConsultationItem({
    required this.id,
    required this.doctor,
    required this.specialty,
    this.consultedAt,
    this.reason,
    this.diagnosis,
    this.prescription,
    this.documents = const [],
  });

  final int id;
  final String doctor; // « Dr Prénom Nom »
  final String specialty;
  final String? consultedAt; // Y-m-d
  final String? reason;
  final String? diagnosis;
  final String? prescription;
  final List<MedicalDocumentItem> documents;

  factory ConsultationItem.fromJson(Map<String, dynamic> json) =>
      ConsultationItem(
        id: json['id'] as int,
        doctor: json['doctor'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        consultedAt: json['consulted_at'] as String?,
        reason: json['reason'] as String?,
        diagnosis: json['diagnosis'] as String?,
        prescription: json['prescription'] as String?,
        documents: (json['documents'] as List? ?? const [])
            .map((d) => MedicalDocumentItem.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  DateTime? get date =>
      consultedAt == null ? null : DateTime.tryParse(consultedAt!);

  /// Libellé long de la date, ex. « 20 mai 2026 » ; `null` si la consultation
  /// n'est pas datée.
  String? get longDateLabel {
    final date = this.date;
    return date == null ? null : DateFormat('d MMMM yyyy', 'fr_FR').format(date);
  }

  /// Libellé court de la date, ex. « 20 mai 2026 ».
  String? get shortDateLabel {
    final date = this.date;
    return date == null ? null : DateFormat('d MMM yyyy', 'fr_FR').format(date);
  }
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
    this.surgicalHistory,
    this.currentMedications,
    this.notes,
  });

  final String? bloodType; // A+, O-, …
  final String? allergies;
  final String? medicalHistory;
  final String? surgicalHistory;
  final String? currentMedications;
  final String? notes;

  factory MedicalRecordSummary.fromJson(Map<String, dynamic> json) =>
      MedicalRecordSummary(
        bloodType: json['blood_type'] as String?,
        allergies: json['allergies'] as String?,
        medicalHistory: json['medical_history'] as String?,
        surgicalHistory: json['surgical_history'] as String?,
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
    this.consultationId,
    this.issuedAt,
    this.notes,
  });

  final int id;

  /// Consultation à laquelle le document est joint, `null` s'il a été versé
  /// au dossier sans consultation associée.
  final int? consultationId;
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
        consultationId: (json['consultation_id'] as num?)?.toInt(),
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
