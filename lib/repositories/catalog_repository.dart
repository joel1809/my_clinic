import '../core/api_client.dart';
import '../models/availability.dart';
import '../models/doctor.dart';
import '../models/insurance.dart';
import '../models/specialty.dart';

/// Catalogue : spécialités, médecins et leurs disponibilités.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<Specialty>> specialties() async {
    final json = await _api.get('/specialties') as Map<String, dynamic>;
    return (json['data'] as List)
        .map((s) => Specialty.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<Doctor>> doctors({int? specialtyId}) async {
    final json = await _api.get('/doctors', query: {
      if (specialtyId != null) 'specialty_id': '$specialtyId',
    }) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((d) => Doctor.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<Doctor> doctor(int id) async {
    final json = await _api.get('/doctors/$id') as Map<String, dynamic>;
    return Doctor.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Assurances partenaires proposées lors de la prise de rendez-vous.
  Future<List<Insurance>> insurances() async {
    final json = await _api.get('/insurances') as Map<String, dynamic>;
    return (json['data'] as List)
        .map((i) => Insurance.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// Prochains jours de consultation (authentifié).
  Future<List<AvailableDay>> days(int doctorId) async {
    final json = await _api.get('/doctors/$doctorId/days') as Map<String, dynamic>;
    return (json['data'] as List)
        .map((d) => AvailableDay.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Créneaux d'une date donnée (authentifié).
  Future<List<TimeSlot>> slots(int doctorId, String date) async {
    final json = await _api.get('/doctors/$doctorId/slots', query: {
      'date': date,
    }) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
