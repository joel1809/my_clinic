import '../core/api_client.dart';
import '../models/medical_record.dart';

/// Dossiers médicaux des patients (médecins et administrateurs).
class MedicalRecordRepository {
  MedicalRecordRepository(this._api);

  final ApiClient _api;

  /// Dossier d'un patient donné (médecin qui le suit ou administrateur).
  ///
  /// [consultationsPage] choisit la page de l'historique des consultations et
  /// [perPage] sa taille (l'API plafonne à 50).
  Future<PatientRecord> record(
    int patientId, {
    int consultationsPage = 1,
    int? perPage,
  }) =>
      _fetch(
        '/patients/$patientId/medical-record',
        consultationsPage: consultationsPage,
        perPage: perPage,
      );

  /// Dossier du patient connecté (lecture seule).
  Future<PatientRecord> mine({int consultationsPage = 1, int? perPage}) =>
      _fetch(
        '/my/medical-record',
        consultationsPage: consultationsPage,
        perPage: perPage,
      );

  Future<PatientRecord> _fetch(
    String path, {
    required int consultationsPage,
    int? perPage,
  }) async {
    final json = await _api.get(path, query: {
      if (consultationsPage > 1) 'consultations_page': '$consultationsPage',
      if (perPage != null) 'per_page': '$perPage',
    }) as Map<String, dynamic>;

    return PatientRecord.fromJson(json['data'] as Map<String, dynamic>);
  }
}
