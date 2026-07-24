import '../core/api_client.dart';
import '../models/medical_record.dart';

/// Dossiers médicaux des patients (médecins et administrateurs).
class MedicalRecordRepository {
  MedicalRecordRepository(this._api);

  final ApiClient _api;

  /// Dossier d'un patient donné (médecin qui le suit ou administrateur).
  Future<PatientRecord> record(int patientId) async {
    final json = await _api.get('/patients/$patientId/medical-record')
        as Map<String, dynamic>;
    return PatientRecord.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Dossier du patient connecté (lecture seule).
  Future<PatientRecord> mine() async {
    final json = await _api.get('/my/medical-record') as Map<String, dynamic>;
    return PatientRecord.fromJson(json['data'] as Map<String, dynamic>);
  }
}
