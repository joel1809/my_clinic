import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'doctor.dart';
import 'insurance.dart';

/// Patient concerné par un rendez-vous (exposé aux médecins/admins).
class AppointmentPatient {
  const AppointmentPatient({
    required this.id,
    this.recordNumber,
    this.name,
    this.phone,
  });

  final int id;

  /// Numéro de dossier attribué par la clinique, ex. « DOS-2026-0001 » : il
  /// désigne le patient sans ambiguïté, même en cas d'homonymie. `null` pour
  /// un dossier ouvert avant la mise en place de la numérotation.
  final String? recordNumber;

  final String? name;
  final String? phone;

  factory AppointmentPatient.fromJson(Map<String, dynamic> json) =>
      AppointmentPatient(
        id: json['id'] as int,
        recordNumber: json['record_number'] as String?,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
      );
}

/// Rendez-vous (AppointmentResource).
class Appointment {
  const Appointment({
    required this.id,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.isCancellable,
    required this.isConfirmable,
    required this.isCompletable,
    this.doctor,
    this.insurances = const [],
    this.patient,
    this.createdAt,
  });

  final int id;
  final String scheduledDate; // Y-m-d
  final String startTime; // H:i
  final String endTime; // H:i
  final String reason;
  final String status; // pending | confirmed | cancelled | completed
  final String statusLabel;
  final bool isCancellable;
  final bool isConfirmable;

  /// Le rendez-vous peut-il être clôturé par le médecin consulté ? Le serveur
  /// ne l'accorde qu'à un rendez-vous confirmé dont le créneau est écoulé.
  final bool isCompletable;

  final Doctor? doctor;

  /// Assurances déclarées par le patient à la réservation.
  final List<Insurance> insurances;

  final AppointmentPatient? patient;
  final String? createdAt;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        scheduledDate: json['scheduled_date'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String,
        statusLabel: json['status_label'] as String,
        isCancellable: json['is_cancellable'] as bool? ?? false,
        isConfirmable: json['is_confirmable'] as bool? ?? false,
        isCompletable: json['is_completable'] as bool? ?? false,
        doctor: json['doctor'] is Map<String, dynamic>
            ? Doctor.fromJson(json['doctor'] as Map<String, dynamic>)
            : null,
        insurances: json['insurances'] is List
            ? (json['insurances'] as List)
                .whereType<Map<String, dynamic>>()
                .map(Insurance.fromJson)
                .toList()
            : const [],
        patient: json['patient'] is Map<String, dynamic>
            ? AppointmentPatient.fromJson(
                json['patient'] as Map<String, dynamic>)
            : null,
        createdAt: json['created_at'] as String?,
      );

  /// Couleur du statut, prise dans la palette du système de design.
  Color statusColor(BuildContext context) => switch (status) {
        'pending' => AppPalette.warning,
        'confirmed' => AppPalette.success,
        'cancelled' => AppPalette.danger,
        'completed' => AppPalette.inkMuted,
        _ => AppPalette.primary,
      };

  IconData get statusIcon => switch (status) {
        'pending' => Icons.hourglass_top_rounded,
        'confirmed' => Icons.check_circle_rounded,
        'cancelled' => Icons.cancel_rounded,
        'completed' => Icons.task_alt_rounded,
        _ => Icons.event_rounded,
      };

  /// Date du rendez-vous, ou null si le serveur renvoie un format inattendu.
  DateTime? get date => DateTime.tryParse(scheduledDate);

  /// Le jour du rendez-vous est-il révolu ?
  bool get isPast {
    final date = this.date;
    if (date == null) return false;
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Rendez-vous encore d'actualité : non annulé/terminé et pas encore passé.
  bool get isUpcoming =>
      (status == 'pending' || status == 'confirmed') && !isPast;

  /// Libellé long de la date, ex. « Lundi 3 août 2026 ».
  String get longDateLabel {
    final date = this.date;
    if (date == null) return scheduledDate;
    return toBeginningOfSentenceCase(
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date));
  }

  /// Libellé court de la date, ex. « lun. 3 août ».
  String get shortDateLabel {
    final date = this.date;
    if (date == null) return scheduledDate;
    return DateFormat('EEE d MMM', 'fr_FR').format(date);
  }

  String get timeRangeLabel => '$startTime - $endTime';
}
