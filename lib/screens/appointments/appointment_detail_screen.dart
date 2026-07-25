import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import '../medical/medical_record_screen.dart';
import 'appointment_actions.dart';
import 'appointments_tab.dart' show StatusPill;

/// Détail d'un rendez-vous, avec confirmation et annulation pour le médecin
/// consulté (ou l'administration) et annulation pour le patient.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Future<Appointment> _future;

  /// Rendez-vous à jour après une action, affiché à la place du chargement.
  Appointment? _appointment;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        context.read<AppointmentRepository>().show(widget.appointmentId);
  }

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  Future<void> _run(Future<Appointment?> Function() action) async {
    final updated = await action();
    if (updated != null && mounted) {
      setState(() {
        _appointment = updated;
        _changed = true;
      });
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
            if (_appointment == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(
                  error: snapshot.error!,
                  onRetry: () => setState(_load),
                );
              }
            }

            final appointment = _appointment ?? snapshot.data!;
            final isStaff = context.watch<AuthState>().user?.isStaff ?? false;

            return Column(
              children: [
                Expanded(child: _buildContent(appointment, isStaff)),
                _buildActionBar(appointment, isStaff),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(Appointment appointment, bool isStaff) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = appointment.statusColor(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      children: [
        // Bandeau date / horaire, teinté selon le statut
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: .25)),
            ),
            child: Column(
              children: [
                StatusPill(appointment: appointment, large: true),
                const SizedBox(height: 14),
                Text(
                  appointment.longDateLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.timeRangeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (appointment.status == 'pending') ...[
                  const SizedBox(height: 10),
                  Text(
                    isStaff
                        ? 'Ce rendez-vous attend votre confirmation.'
                        : 'En attente de confirmation par la clinique.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (appointment.doctor != null)
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.doctor!.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (appointment.doctor!.specialty != null)
                          Text(
                            appointment.doctor!.specialty!.name,
                            style: TextStyle(
                                fontSize: 13, color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Motif',
                  value: appointment.reason.trim().isEmpty
                      ? '—'
                      : appointment.reason,
                ),
                if (appointment.createdAt != null)
                  _DetailRow(
                    icon: Icons.history_rounded,
                    label: 'Demandé le',
                    value: _createdAtLabel(appointment.createdAt!),
                  ),
              ],
            ),
          ),
        ),
        if (isStaff && appointment.patient != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          _initials(appointment.patient!.name),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.patient!.name ?? 'Patient',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              appointment.patient!.phone ??
                                  'Aucun téléphone renseigné',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      if (appointment.patient!.phone != null)
                        IconButton.filledTonal(
                          onPressed: () => callPatient(
                              context, appointment.patient!.phone!),
                          icon: const Icon(Icons.phone_rounded),
                          tooltip: 'Appeler le patient',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MedicalRecordScreen(
                            patientId: appointment.patient!.id,
                            patientName: appointment.patient!.name,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.folder_shared_outlined),
                      label: const Text('Dossier médical'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Barre d'actions fixe en bas d'écran ; masquée quand aucune action n'est
  /// possible (rendez-vous passé, annulé ou terminé).
  Widget _buildActionBar(Appointment appointment, bool isStaff) {
    final canConfirm = isStaff && appointment.isConfirmable;
    final canCancel = appointment.isCancellable;
    if (!canConfirm && !canCancel) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              if (canCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() => cancelAppointment(
                              context,
                              appointment,
                              asStaff: isStaff,
                              onBusy: _setBusy,
                            )),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Annuler'),
                  ),
                ),
              if (canConfirm && canCancel) const SizedBox(width: 12),
              if (canConfirm)
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() => confirmAppointment(
                            context, appointment, onBusy: _setBusy)),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmer'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Date de création renvoyée au format ISO 8601 par l'API.
  String _createdAtLabel(String createdAt) {
    final date = DateTime.tryParse(createdAt);
    if (date == null) return createdAt;
    final local = date.toLocal();
    return '${local.day} ${monthShort(local)} ${local.year}';
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
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

  /// Même largeur de libellé que le récapitulatif de prise de rendez-vous,
  /// pour que les valeurs démarrent toutes sur la même colonne.
  static const _labelWidth = 78.0;

  /// Plafond de la colonne de libellé : au-delà, la valeur n'aurait plus assez
  /// de place sur un écran étroit.
  static const _maxLabelWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    // La colonne suit la taille de texte du système, sinon « Demandé le »
    // passe sur deux lignes dès que l'utilisateur agrandit le texte.
    final labelWidth = MediaQuery.textScalerOf(context)
        .scale(_labelWidth)
        .clamp(_labelWidth, _maxLabelWidth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        // Icône et libellé restent au niveau de la première ligne quand la
        // valeur est longue (un motif de consultation, par exemple).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              // Même interligne que la valeur pour que les deux premières
              // lignes reposent sur la même ligne de base.
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
