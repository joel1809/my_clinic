import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../models/insurance.dart';
import '../../models/medical_record.dart';
import '../../repositories/medical_record_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'document_viewer_screen.dart';

/// Dossier médical, en lecture seule : synthèse clinique (groupe sanguin,
/// allergies, antécédents, traitements) et documents (analyses, ordonnances,
/// radios…).
///
/// Deux usages : un médecin ou un administrateur consulte le dossier d'un
/// patient qu'il suit (`patientId` fourni) ; un patient consulte son propre
/// dossier (constructeur [MedicalRecordScreen.mine]).
class MedicalRecordScreen extends StatefulWidget {
  const MedicalRecordScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  /// Dossier du patient connecté (via GET /my/medical-record).
  const MedicalRecordScreen.mine({super.key})
      : patientId = null,
        patientName = null;

  /// Identifiant du patient consulté ; `null` pour le dossier personnel.
  final int? patientId;
  final String? patientName;

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  late Future<PatientRecord> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = context.read<MedicalRecordRepository>();
    _future = widget.patientId == null
        ? repository.mine()
        : repository.record(widget.patientId!);
  }

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
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(
                                  child: CircularProgressIndicator()),
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dossier médical',
                style: Theme.of(context).textTheme.titleLarge),
            if (widget.patientName != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.patientName!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        toolbarHeight: 70,
      ),
      body: FutureBuilder<PatientRecord>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(height: 120);
          }
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }

          final record = snapshot.data!;

          return FadeSlideIn(
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
              _PatientCard(patient: record.patient),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Fiche médicale'),
              // Les assurances suffisent à remplir la carte : un patient peut
              // en avoir déclaré sans qu'aucune synthèse clinique n'existe.
              if (record.record == null && record.insurances.isEmpty)
                const _PlaceholderCard(
                  message: 'Aucune fiche médicale renseignée pour ce patient.',
                )
              else
                _RecordCard(
                  record: record.record,
                  insurances: record.insurances,
                ),
              const SizedBox(height: 28),
              SectionHeader(title: 'Documents (${record.documents.length})'),
              if (record.documents.isEmpty)
                const _PlaceholderCard(
                  message: 'Aucun document dans ce dossier.',
                )
              else
                for (final document in record.documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                    child: _DocumentCard(
                      document: document,
                      onOpen: () => _openDocument(document),
                    ),
                  ),
            ],
          ));
        },
      ),
    );
  }
}

/// Carte de remplacement quand une section du dossier est vide.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 19, color: AppPalette.inkFaint),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final RecordPatient patient;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    String? birthDateLabel;
    if (patient.birthDate != null) {
      final date = DateTime.tryParse(patient.birthDate!);
      if (date != null) {
        birthDateLabel = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
      }
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppPalette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              (patient.name?.trim().isNotEmpty ?? false)
                  ? patient.name!.trim()[0].toUpperCase()
                  : '?',
              style: text.headlineSmall?.copyWith(color: AppPalette.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name ?? 'Patient', style: text.titleMedium),
                const SizedBox(height: 3),
                Text(
                  [
                    patient.genderLabel,
                    if (birthDateLabel != null) 'né(e) le $birthDateLabel',
                    if (patient.phone != null) patient.phone!,
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.insurances});

  /// Synthèse clinique, absente tant qu'aucune fiche n'a été ouverte.
  final MedicalRecordSummary? record;
  final List<Insurance> insurances;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter, vertical: 6),
      child: Column(
        children: [
            _RecordRow(
              icon: Icons.bloodtype_outlined,
              label: 'Groupe sanguin',
              value: record?.bloodType,
            ),
            _RecordRow(
              icon: Icons.warning_amber_outlined,
              label: 'Allergies',
              value: record?.allergies,
            ),
            _RecordRow(
              icon: Icons.history_outlined,
              label: 'Antécédents',
              value: record?.medicalHistory,
            ),
            _RecordRow(
              icon: Icons.medication_outlined,
              label: 'Traitements en cours',
              value: record?.currentMedications,
            ),
            _RecordRow(
              icon: Icons.health_and_safety_outlined,
              label: 'Assurances',
              value: insurances.map((i) => i.name).join(', '),
            ),
            _RecordRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: record?.notes,
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
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
