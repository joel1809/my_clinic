import 'package:flutter/material.dart';

import 'doctor.dart';

/// Patient concerné par un rendez-vous (exposé aux médecins/admins).
class AppointmentPatient {
  const AppointmentPatient({required this.id, this.name, this.phone});

  final int id;
  final String? name;
  final String? phone;

  factory AppointmentPatient.fromJson(Map<String, dynamic> json) =>
      AppointmentPatient(
        id: json['id'] as int,
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
    this.doctor,
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
  final Doctor? doctor;
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
        doctor: json['doctor'] is Map<String, dynamic>
            ? Doctor.fromJson(json['doctor'] as Map<String, dynamic>)
            : null,
        patient: json['patient'] is Map<String, dynamic>
            ? AppointmentPatient.fromJson(
                json['patient'] as Map<String, dynamic>)
            : null,
        createdAt: json['created_at'] as String?,
      );

  Color statusColor(BuildContext context) => switch (status) {
        'pending' => Colors.orange,
        'confirmed' => Colors.green,
        'cancelled' => Theme.of(context).colorScheme.error,
        'completed' => Colors.blueGrey,
        _ => Theme.of(context).colorScheme.primary,
      };

  bool get isUpcoming => status == 'pending' || status == 'confirmed';
}
