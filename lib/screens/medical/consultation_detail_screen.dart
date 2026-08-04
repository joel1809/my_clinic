import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../models/medical_record.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'document_viewer_screen.dart';

/// Détail d'une consultation du dossier médical : motif, diagnostic,
/// prescription et documents joints.
///
/// Tout est déjà porté par la consultation reçue avec le dossier : l'écran
/// s'ouvre sans nouvel appel réseau.
class ConsultationDetailScreen extends StatefulWidget {
  const ConsultationDetailScreen({super.key, required this.consultation});

  final ConsultationItem consultation;

  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  ConsultationItem get _consultation => widget.consultation;

  /// Ouvre un document dans l'application : les images en plein écran,
  /// les PDF dans le lecteur intégré. Les autres formats (rares) s'ouvrent
  /// dans le navigateur via l'URL signée.
  Future<void> _openDocument(MedicalDocumentItem document) async {
    // L'adresse vient de l'API : on refuse tout ce qui sortirait du backend
    // plutôt que de l'ouvrir aveuglément.
    final uri = AppConfig.mediaUri(document.fileUrl);
    if (uri == null) {
      if (mounted) {
        showError(context, 'Ce document a une adresse inattendue.');
      }
      return;
    }
    final url = uri.toString();

    if (document.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('Impossible de charger l\'image.'),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (document.isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(
            title: document.title,
            url: url,
          ),
        ),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Impossible d\'ouvrir le document.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final documents = _consultation.documents;

    final fields = [
      (Icons.notes_outlined, 'Motif', _consultation.reason),
      (Icons.fact_check_outlined, 'Diagnostic', _consultation.diagnosis),
      (
        Icons.medication_outlined,
        'Prescription',
        _consultation.prescription,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la consultation')),
      body: FadeSlideIn(
        child: ListView(
          // Marge basse augmentée de la zone système : en bord à bord, le
          // dernier document passerait sous la barre de navigation.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            // Bandeau date et praticien
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border:
                    Border.all(color: AppPalette.primary.withValues(alpha: .20)),
              ),
              child: Column(
                children: [
                  Icon(Icons.medical_services_outlined,
                      color: AppPalette.primary, size: 28),
                  const SizedBox(height: AppSpacing.gap),
                  Text(
                    _consultation.longDateLabel ?? 'Consultation',
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                  if (_consultation.doctor.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _consultation.doctor,
                      textAlign: TextAlign.center,
                      style: text.titleMedium
                          ?.copyWith(color: AppPalette.inkMuted),
                    ),
                  ],
                  if (_consultation.specialty.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _consultation.specialty,
                      style:
                          text.labelMedium?.copyWith(color: AppPalette.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Compte rendu'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter, vertical: 6),
              child: Column(
                children: [
                  for (final (icon, label, value) in fields)
                    _ConsultationRow(icon: icon, label: label, value: value),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SectionHeader(title: 'Documents joints (${documents.length})'),
            if (documents.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 19, color: AppPalette.inkFaint),
                    const SizedBox(width: AppSpacing.gap),
                    Expanded(
                      child: Text(
                        'Aucun document joint à cette consultation.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final document in documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                  child: _DocumentCard(
                    document: document,
                    onOpen: () => _openDocument(document),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Ligne du compte rendu : libellé au-dessus, texte en dessous, pour laisser
/// respirer des valeurs longues (un diagnostic tient rarement sur une ligne).
class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final filled = value?.trim().isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppPalette.inkFaint),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  filled ? value!.trim() : 'Non renseigné',
                  // Une valeur absente reste lisible mais s'efface : l'œil va
                  // d'abord aux informations réellement remplies.
                  style: filled
                      ? text.bodyLarge
                      : text.bodyLarge?.copyWith(color: AppPalette.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Document joint à la consultation, ouvrable d'un geste.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onOpen});

  final MedicalDocumentItem document;
  final VoidCallback onOpen;

  IconData get _icon => switch (document.type) {
        'analysis_result' => Icons.biotech_outlined,
        'prescription' => Icons.receipt_long_outlined,
        'radiography' => Icons.broken_image_outlined,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    String? issuedLabel;
    if (document.issuedAt != null) {
      final date = DateTime.tryParse(document.issuedAt!);
      if (date != null) {
        issuedLabel = DateFormat('d MMM yyyy', 'fr_FR').format(date);
      }
    }

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.gap),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(_icon, color: AppPalette.primary, size: 21),
          ),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [document.typeLabel, ?issuedLabel].join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            document.isImage || document.isPdf
                ? Icons.visibility_outlined
                : Icons.open_in_new_rounded,
            size: 19,
            color: AppPalette.inkFaint,
          ),
        ],
      ),
    );
  }
}
