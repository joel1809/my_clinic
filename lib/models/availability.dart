/// Jour de consultation d'un médecin (GET /doctors/{id}/days).
class AvailableDay {
  const AvailableDay({
    required this.date,
    required this.label,
    required this.available,
  });

  final String date; // Y-m-d
  final String label; // ex. « Lundi 3 août 2026 »
  final bool available;

  factory AvailableDay.fromJson(Map<String, dynamic> json) => AvailableDay(
        date: json['date'] as String,
        label: json['label'] as String,
        available: json['available'] as bool,
      );
}

/// Créneau horaire d'un médecin (GET /doctors/{id}/slots?date=).
class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    required this.label,
    required this.available,
  });

  final String start; // H:i
  final String end; // H:i
  final String label; // ex. « 09h00 - 09h30 »
  final bool available;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        start: json['start'] as String,
        end: json['end'] as String,
        label: json['label'] as String,
        available: json['available'] as bool,
      );
}
