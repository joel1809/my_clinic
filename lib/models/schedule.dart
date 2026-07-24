/// Plage de disponibilité d'un médecin (ScheduleResource) : hebdomadaire
/// (weekday renseigné) ou ponctuelle à une date précise (date renseignée).
class Schedule {
  const Schedule({
    required this.id,
    this.weekday,
    this.date,
    required this.dayLabel,
    required this.startTime,
    required this.endTime,
  });

  final int id;
  final int? weekday; // ISO-8601 : 1 = lundi … 7 = dimanche
  final String? date; // Y-m-d
  final String dayLabel; // ex. « Lundi » ou « Mercredi 15 juillet 2026 »
  final String startTime; // H:i
  final String endTime; // H:i

  bool get isWeekly => weekday != null;

  /// Libellé des heures, ex. « 08h00 - 12h00 ».
  String get timeLabel =>
      '${startTime.replaceAll(':', 'h')} - ${endTime.replaceAll(':', 'h')}';

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'] as int,
        weekday: json['weekday'] as int?,
        date: json['date'] as String?,
        dayLabel: json['day_label'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      );
}
