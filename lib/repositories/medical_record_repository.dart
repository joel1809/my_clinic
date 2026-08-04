import '../core/api_client.dart';
import '../models/medical_record.dart';

/// Dossiers médicaux des patients (médecins et administrateurs).
class MedicalRecordRepository {
  MedicalRecordRepository(this._api);

  final ApiClient _api;

  /// Dossier d'un patient donné (médecin qui le suit ou administrateur).
  ///
  /// Les consultations et les documents sont paginés indépendamment :
  /// [consultationsPage] et [documentsPage] choisissent la page de chaque
  /// liste (10 éléments par page côté API).
  Future<PatientRecord> record(
    int patientId, {
    int consultationsPage = 1,
    int documentsPage = 1,
  }) =>
      _fetch(
        '/patients/$patientId/medical-record',
        consultationsPage: consultationsPage,
        documentsPage: documentsPage,
      );

  /// Dossier du patient connecté (lecture seule).
  Future<PatientRecord> mine({
    int consultationsPage = 1,
    int documentsPage = 1,
  }) =>
      _fetch(
        '/my/medical-record',
        consultationsPage: consultationsPage,
        documentsPage: documentsPage,
      );

  Future<PatientRecord> _fetch(
    String path, {
    required int consultationsPage,
    required int documentsPage,
  }) async {
    final json = await _api.get(path, query: {
      if (consultationsPage > 1) 'consultations_page': '$consultationsPage',
      if (documentsPage > 1) 'documents_page': '$documentsPage',
    }) as Map<String, dynamic>;

    return PatientRecord.fromJson(json['data'] as Map<String, dynamic>);
  }
}
