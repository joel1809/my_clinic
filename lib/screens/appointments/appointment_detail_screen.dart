import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
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
                return const SkeletonList(height: 130, count: 3);
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
    final text = Theme.of(context).textTheme;
    final statusColor = appointment.statusColor(context);

    // Sans barre d'actions en dessous, c'est au contenu de laisser la place de
    // la zone système : sinon il passe sous la barre de navigation.
    final hasActionBar =
        appointment.isCancellable || (isStaff && appointment.isConfirmable);
    final bottomInset =
        hasActionBar ? 8.0 : AppSpacing.page + MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.page, AppSpacing.page, bottomInset),
      children: [
        // Bandeau date / horaire, teinté selon le statut
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: statusColor.withValues(alpha: .20)),
            ),
            child: Column(
              children: [
                StatusPill(appointment: appointment, large: true),
                const SizedBox(height: AppSpacing.gutter),
                Text(
                  appointment.longDateLabel,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.timeRangeLabel,
                  style: text.titleMedium?.copyWith(color: AppPalette.inkMuted),
                ),
                if (appointment.status == 'pending') ...[
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    isStaff
                        ? 'Ce rendez-vous attend votre confirmation.'
                        : 'En attente de confirmation par la clinique.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),
        if (appointment.doctor != null)
          AppCard(
            child: Row(
              children: [
                NetworkImageBox(
                  url: appointment.doctor!.photoUrl,
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appointment.doctor!.fullName,
                          style: text.titleSmall),
                      if (appointment.doctor!.specialty != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          appointment.doctor!.specialty!.name,
                          style: text.labelMedium
                              ?.copyWith(color: AppPalette.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.gap),
        AppCard(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.notes_outlined,
                label: 'Motif',
                value: appointment.reason.trim().isEmpty
                    ? '—'
                    : appointment.reason,
              ),
              if (appointment.insurances.isNotEmpty)
                _DetailRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Assurance',
                  value: appointment.insurances
                      .map((i) => i.name)
                      .join(', '),
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
        if (isStaff && appointment.patient != null) ...[
          const SizedBox(height: AppSpacing.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials(appointment.patient!.name),
                        style: text.titleMedium
                            ?.copyWith(color: AppPalette.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appointment.patient!.name ?? 'Patient',
                              style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            appointment.patient!.phone ??
                                'Aucun téléphone renseigné',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (appointment.patient!.phone != null)
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.primarySoft,
                          foregroundColor: AppPalette.primary,
                        ),
                        onPressed: () =>
                            callPatient(context, appointment.patient!.phone!),
                        icon: const Icon(Icons.phone_rounded, size: 20),
                        tooltip: 'Appeler le patient',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gutter),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
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
                    icon: const Icon(Icons.folder_shared_outlined, size: 19),
                    label: const Text('Dossier médical'),
                  ),
                ),
              ],
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
            color: AppPalette.shadow.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 12, AppSpacing.page, 12),
          child: Row(
            children: [
              if (canCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.controlHeight),
                      foregroundColor: AppPalette.danger,
                      side: BorderSide(
                        color: AppPalette.danger.withValues(alpha: .45),
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
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.controlHeight),
                      backgroundColor: AppPalette.success,
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

  /// Libellé le plus long de l'écran : toutes les lignes dimensionnent leur
  /// colonne sur lui, donc les valeurs démarrent sur la même colonne sans
  /// qu'aucun libellé ne se coupe en deux lignes.
  static const _widestLabel = 'Demandé le';

  /// Marge de sécurité après le libellé mesuré, pour que la valeur ne vienne
  /// pas coller au texte.
  static const _labelGap = 12.0;

  @override
  Widget build(BuildContext context) {
    // Même interligne pour le libellé et la valeur, afin que les deux
    // premières lignes reposent sur la même ligne de base.
    final labelStyle = TextStyle(color: Colors.grey.shade600, height: 1.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // La colonne est mesurée à la taille de texte réellement appliquée :
          // « Demandé le » tient sur une ligne même avec un texte système
          // agrandi, là où une largeur fixe finissait par le couper.
          final painter = TextPainter(
            text: TextSpan(text: _widestLabel, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();

          // Sur un écran étroit, le libellé ne prend jamais plus de la moitié
          // de la ligne, sinon la valeur n'aurait plus de place.
          final labelWidth = math.min(
            painter.width + _labelGap,
            constraints.maxWidth * .5,
          );

          return Row(
            // Icône et libellé restent au niveau de la première ligne quand la
            // valeur est longue (un motif de consultation, par exemple).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              SizedBox(
                width: labelWidth,
                child: Text(label, style: labelStyle),
              ),
              Expanded(
                child: Text(
                  value,
                  style:
                      const TextStyle(fontWeight: FontWeight.w500, height: 1.35),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
