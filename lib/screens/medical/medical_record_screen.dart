import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../models/medical_record.dart';
import '../../repositories/medical_record_repository.dart';
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
    final url = '${AppConfig.baseUrl}${document.fileUrl}';

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
      Uri.parse(url),
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
            const Text('Dossier médical', style: TextStyle(fontSize: 17)),
            if (widget.patientName != null)
              Text(
                widget.patientName!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: FutureBuilder<PatientRecord>(
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

          final record = snapshot.data!;

          return FadeSlideIn(
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PatientCard(patient: record.patient),
              const SizedBox(height: 16),
              _SectionTitle('Fiche médicale'),
              const SizedBox(height: 8),
              if (record.record == null)
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'Aucune fiche médicale renseignée pour ce patient.'),
                  ),
                )
              else
                _RecordCard(record: record.record!),
              const SizedBox(height: 16),
              _SectionTitle('Documents (${record.documents.length})'),
              const SizedBox(height: 8),
              if (record.documents.isEmpty)
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun document dans ce dossier.'),
                  ),
                )
              else
                for (final document in record.documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final RecordPatient patient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String? birthDateLabel;
    if (patient.birthDate != null) {
      final date = DateTime.tryParse(patient.birthDate!);
      if (date != null) {
        birthDateLabel = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
      }
    }

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                (patient.name?.trim().isNotEmpty ?? false)
                    ? patient.name!.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name ?? 'Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      patient.genderLabel,
                      if (birthDateLabel != null) 'né(e) le $birthDateLabel',
                      if (patient.phone != null) patient.phone!,
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final MedicalRecordSummary record;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _RecordRow(
              icon: Icons.bloodtype_outlined,
              label: 'Groupe sanguin',
              value: record.bloodType,
            ),
            _RecordRow(
              icon: Icons.warning_amber_outlined,
              label: 'Allergies',
              value: record.allergies,
            ),
            _RecordRow(
              icon: Icons.history_outlined,
              label: 'Antécédents',
              value: record.medicalHistory,
            ),
            _RecordRow(
              icon: Icons.medication_outlined,
              label: 'Traitements en cours',
              value: record.currentMedications,
            ),
            _RecordRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: record.notes,
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  (value?.trim().isNotEmpty ?? false)
                      ? value!.trim()
                      : 'Non renseigné',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
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
    final scheme = Theme.of(context).colorScheme;

    String? issuedLabel;
    if (document.issuedAt != null) {
      final date = DateTime.tryParse(document.issuedAt!);
      if (date != null) {
        issuedLabel = DateFormat('d MMM yyyy', 'fr_FR').format(date);
      }
    }

    return Card(
      color: Colors.white,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_icon, color: scheme.primary, size: 22),
        ),
        title: Text(
          document.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [document.typeLabel, ?issuedLabel].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          document.isImage || document.isPdf
              ? Icons.visibility_outlined
              : Icons.open_in_new,
          size: 20,
          color: Colors.grey.shade500,
        ),
        onTap: onOpen,
      ),
    );
  }
}
