import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

/// Actions de gestion d'un rendez-vous (confirmation, clôture, annulation,
/// appel du patient) partagées par la liste et le détail : chaque écran garde
/// son propre indicateur de chargement mais la confirmation utilisateur,
/// l'appel à l'API et les messages restent identiques partout.
///
/// Chaque action renvoie le rendez-vous mis à jour, ou `null` si l'utilisateur
/// a renoncé ou si l'appel a échoué (l'erreur est déjà affichée). `onBusy`
/// n'encadre que l'appel réseau, pas la boîte de dialogue.

/// Demande confirmation puis confirme le rendez-vous (médecin / administrateur).
Future<Appointment?> confirmAppointment(
  BuildContext context,
  Appointment appointment, {
  required ValueChanged<bool> onBusy,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.check_circle_outline,
      color: Colors.green.shade600,
      title: 'Confirmer ce rendez-vous ?',
      message: appointment.patient?.name != null
          ? '${appointment.patient!.name} sera informé(e) que sa consultation '
              'du ${appointment.longDateLabel.toLowerCase()} à '
              '${appointment.startTime} est confirmée.'
          : 'Le patient sera informé que sa consultation est confirmée.',
      cancelLabel: 'Pas maintenant',
      confirmLabel: 'Confirmer',
    ),
  );
  if (agreed != true || !context.mounted) return null;

  onBusy(true);
  try {
    final updated =
        await context.read<AppointmentRepository>().confirm(appointment.id);
    if (context.mounted) showSuccess(context, 'Rendez-vous confirmé.');
    return updated;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  } finally {
    onBusy(false);
  }
}

/// Demande confirmation puis clôture le rendez-vous (médecin / administrateur).
///
/// Le serveur n'ouvre cette action qu'à un rendez-vous confirmé dont le
/// créneau est écoulé (`is_completable`) : la consultation a eu lieu.
Future<Appointment?> completeAppointment(
  BuildContext context,
  Appointment appointment, {
  required ValueChanged<bool> onBusy,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.task_alt_rounded,
      // Couleur du statut « Terminé », pour que l'action annonce l'état
      // dans lequel elle place le rendez-vous
      color: AppPalette.inkMuted,
      title: 'Terminer ce rendez-vous ?',
      message: appointment.patient?.name != null
          ? 'La consultation de ${appointment.patient!.name} du '
              '${appointment.longDateLabel.toLowerCase()} à '
              '${appointment.startTime} sera marquée comme terminée.'
          : 'La consultation sera marquée comme terminée.',
      cancelLabel: 'Pas maintenant',
      confirmLabel: 'Terminer',
    ),
  );
  if (agreed != true || !context.mounted) return null;

  onBusy(true);
  try {
    final updated =
        await context.read<AppointmentRepository>().complete(appointment.id);
    if (context.mounted) showSuccess(context, 'Rendez-vous terminé.');
    return updated;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  } finally {
    onBusy(false);
  }
}

/// Demande confirmation puis annule le rendez-vous.
///
/// [asStaff] adapte le message : le médecin annule le rendez-vous d'un patient
/// (qui sera prévenu), le patient annule le sien.
Future<Appointment?> cancelAppointment(
  BuildContext context,
  Appointment appointment, {
  required bool asStaff,
  required ValueChanged<bool> onBusy,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => _ActionDialog(
      icon: Icons.cancel_outlined,
      color: Theme.of(context).colorScheme.error,
      title: 'Annuler ce rendez-vous ?',
      message: asStaff
          ? 'Le patient sera informé de l\'annulation et le créneau '
              'redeviendra disponible. Cette action est définitive.'
          : 'Le créneau sera libéré et redeviendra disponible pour les autres '
              'patients. Cette action est définitive.',
      cancelLabel: 'Garder',
      confirmLabel: 'Annuler le RDV',
    ),
  );
  if (agreed != true || !context.mounted) return null;

  onBusy(true);
  try {
    final updated =
        await context.read<AppointmentRepository>().cancel(appointment.id);
    if (context.mounted) showSuccess(context, 'Rendez-vous annulé.');
    return updated;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  } finally {
    onBusy(false);
  }
}

/// Ouvre l'application téléphone sur le numéro du patient.
Future<void> callPatient(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Impossible d\'appeler le $phone.')),
      );
  }
}

/// Boîte de dialogue commune aux actions : icône colorée, message et
/// deux boutons dont l'action principale reprend la couleur de l'icône.
class _ActionDialog extends StatelessWidget {
  const _ActionDialog({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      // Le titre garde tous ses mots sur une seule ligne : s'il manque de
      // place (écran étroit, texte système agrandi), il est réduit plutôt que
      // coupé en deux.
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: color,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
