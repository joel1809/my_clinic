import '../core/api_client.dart';
import '../models/appointment.dart';
import '../models/paginated.dart';

/// Rendez-vous du patient connecté.
class AppointmentRepository {
  AppointmentRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Appointment>> list({int page = 1}) async {
    final json = await _api.get('/appointments', query: {'page': '$page'})
        as Map<String, dynamic>;
    return Paginated.fromJson(json, Appointment.fromJson);
  }

  Future<Appointment> show(int id) async {
    final json = await _api.get('/appointments/$id') as Map<String, dynamic>;
    return Appointment.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Appointment> book({
    required int specialtyId,
    required int doctorId,
    required String scheduledDate,
    required String startTime,
    required String phone,
    required String reason,
  }) async {
    final json = await _api.post('/appointments', body: {
      'specialty_id': specialtyId,
      'doctor_id': doctorId,
      'scheduled_date': scheduledDate,
      'start_time': startTime,
      'phone': phone,
      'reason': reason,
    }) as Map<String, dynamic>;
    return Appointment.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Appointment> cancel(int id) async {
    final json =
        await _api.patch('/appointments/$id/cancel') as Map<String, dynamic>;
    return Appointment.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Confirme un rendez-vous en attente (médecin consulté ou administrateur).
  Future<Appointment> confirm(int id) async {
    final json =
        await _api.patch('/appointments/$id/confirm') as Map<String, dynamic>;
    return Appointment.fromJson(json['data'] as Map<String, dynamic>);
  }
}
