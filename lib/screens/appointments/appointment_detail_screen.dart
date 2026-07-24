import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import '../medical/medical_record_screen.dart';

/// Détail d'un rendez-vous avec possibilité d'annulation.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Future<Appointment> _future;
  bool _cancelling = false;
  bool _confirming = false;
  bool _changed = false;

  Future<void> _confirm(Appointment appointment) async {
    setState(() => _confirming = true);
    try {
      await context
          .read<AppointmentRepository>()
          .confirm(appointment.id);
      if (!mounted) return;
      _changed = true;
      showSuccess(context, 'Rendez-vous confirmé.');
      setState(_load);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context
        .read<AppointmentRepository>()
        .show(widget.appointmentId);
  }

  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text(
            'Le créneau sera libéré et redeviendra disponible pour les autres patients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler le RDV'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<AppointmentRepository>()
          .cancel(appointment.id);
      if (!mounted) return;
      _changed = true;
      showSuccess(context, 'Rendez-vous annulé.');
      setState(_load);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Détail du rendez-vous')),
        body: FutureBuilder<Appointment>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(
                error: snapshot.error!,
                onRetry: () => setState(_load),
              );
            }

            final appointment = snapshot.data!;
            final isStaff =
                context.watch<AuthState>().user?.isStaff ?? false;
            final statusColor = appointment.statusColor(context);
            final date = DateTime.tryParse(appointment.scheduledDate);
            final dateLabel = date != null
                ? toBeginningOfSentenceCase(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date))
                : appointment.scheduledDate;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Statut
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      appointment.statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (appointment.doctor != null)
                          Row(
                            children: [
                              NetworkImageBox(
                                url: appointment.doctor!.photoUrl,
                                width: 56,
                                height: 56,
                                borderRadius: BorderRadius.circular(12),
                                fallbackIcon: Icons.person,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appointment.doctor!.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    if (appointment
                                            .doctor!.specialty !=
                                        null)
                                      Text(
                                        appointment
                                            .doctor!.specialty!.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const Divider(height: 28),
                        _DetailRow(
                          icon: Icons.event_outlined,
                          label: 'Date',
                          value: dateLabel,
                        ),
                        _DetailRow(
                          icon: Icons.schedule_outlined,
                          label: 'Horaire',
                          value:
                              '${appointment.startTime} - ${appointment.endTime}',
                        ),
                        _DetailRow(
                          icon: Icons.notes_outlined,
                          label: 'Motif',
                          value: appointment.reason,
                        ),
                        if (isStaff && appointment.patient != null) ...[
                          const Divider(height: 28),
                          _DetailRow(
                            icon: Icons.person_outline,
                            label: 'Patient',
                            value: appointment.patient!.name ?? '—',
                          ),
                          if (appointment.patient!.phone != null)
                            _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Téléphone',
                              value: appointment.patient!.phone!,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (isStaff && appointment.patient != null) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicalRecordScreen(
                          patientId: appointment.patient!.id,
                          patientName: appointment.patient!.name,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.folder_shared_outlined),
                    label: const Text('Dossier médical du patient'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isStaff && appointment.isConfirmable) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: _confirming
                        ? null
                        : () => _confirm(appointment),
                    icon: _confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmer le rendez-vous'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (appointment.isCancellable)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _cancelling ? null : () => _cancel(appointment),
                    icon: _cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler ce rendez-vous'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
