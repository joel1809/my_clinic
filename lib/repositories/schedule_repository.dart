import '../core/api_client.dart';
import '../models/schedule.dart';

/// Plages de disponibilité du médecin connecté.
class ScheduleRepository {
  ScheduleRepository(this._api);

  final ApiClient _api;

  Future<List<Schedule>> list() async {
    final json = await _api.get('/my/schedules') as Map<String, dynamic>;
    return (json['data'] as List)
        .map((item) => Schedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Crée une plage par jour de la semaine ou par date sélectionnée,
  /// avec les mêmes heures de début et de fin.
  Future<List<Schedule>> create({
    List<int> weekdays = const [],
    List<String> dates = const [],
    required String startTime,
    required String endTime,
  }) async {
    final json = await _api.post('/my/schedules', body: {
      if (weekdays.isNotEmpty) 'weekdays': weekdays,
      if (dates.isNotEmpty) 'dates': dates,
      'start_time': startTime,
      'end_time': endTime,
    }) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((item) => Schedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Modifie les heures d'une plage (le jour reste inchangé).
  Future<Schedule> update(
    int id, {
    required String startTime,
    required String endTime,
  }) async {
    final json = await _api.patch('/my/schedules/$id', body: {
      'start_time': startTime,
      'end_time': endTime,
    }) as Map<String, dynamic>;
    return Schedule.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> remove(int id) => _api.delete('/my/schedules/$id');
}
