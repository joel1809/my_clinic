import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/rich_html.dart';
import '../../models/insurance.dart';
import '../../models/medical_record.dart';
import '../../repositories/medical_record_repository.dart';
import '../../theme.dart';
import '../../widgets/rich_text_body.dart';
import '../../widgets/shared.dart';
import 'consultation_detail_screen.dart';

/// Dossier médical, en lecture seule : synthèse clinique (groupe sanguin,
/// allergies, antécédents, traitements) et historique paginé des
/// consultations, chacune donnant accès à ses documents joints (analyses,
/// ordonnances, radios…).
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
  /// Consultations par page : au-delà, la liste passe en pages numérotées
  /// plutôt que de s'allonger indéfiniment sous la fiche médicale.
  static const _perPage = 5;

  late Future<PatientRecord> _future;

  /// Page courante de l'historique des consultations.
  int _consultationsPage = 1;

  /// Dernier dossier reçu, gardé affiché pendant le chargement d'une autre
  /// page : la liste ne repasse pas par un squelette à chaque pagination.
  PatientRecord? _lastRecord;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = context.read<MedicalRecordRepository>();
    _future = widget.patientId == null
        ? repository.mine(
            consultationsPage: _consultationsPage,
            perPage: _perPage,
          )
        : repository.record(
            widget.patientId!,
            consultationsPage: _consultationsPage,
            perPage: _perPage,
          );
  }

  void _openConsultationsPage(int page) {
    setState(() {
      _consultationsPage = page;
      _load();
    });
  }

  /// Ouvre le détail d'une consultation : le contenu vient de la liste déjà
  /// chargée, l'écran s'ouvre donc sans nouvel appel réseau.
  void _openConsultation(ConsultationItem consultation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationDetailScreen(consultation: consultation),
      ),
    );
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
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }

          if (snapshot.hasData) _lastRecord = snapshot.data;
          // Pendant un changement de page, le dossier déjà affiché reste en
          // place ; le squelette n'apparaît qu'au tout premier chargement.
          final record = snapshot.data ?? _lastRecord;
          if (record == null) {
            return const SkeletonList(height: 120);
          }
          final loading =
              snapshot.connectionState == ConnectionState.waiting;

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
              SectionHeader(
                  title: 'Consultations (${record.consultations.total})'),
              if (record.consultations.items.isEmpty)
                const _PlaceholderCard(
                  message: 'Aucune consultation enregistrée pour ce patient.',
                )
              else ...[
                for (final consultation in record.consultations.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                    child: _ConsultationCard(
                      consultation: consultation,
                      onTap: () => _openConsultation(consultation),
                    ),
                  ),
                PaginationBar(
                  currentPage: record.consultations.currentPage,
                  lastPage: record.consultations.lastPage,
                  enabled: !loading,
                  onPageSelected: _openConsultationsPage,
                ),
              ],
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
          Icon(Icons.info_outline_rounded,
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
            decoration: BoxDecoration(
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
                // Numéro de dossier, quand la clinique en a attribué un
                if (patient.recordNumber != null) ...[
                  const SizedBox(height: 5),
                  RecordNumberBadge(number: patient.recordNumber!),
                ],
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
              label: 'Antécédents médicaux',
              value: record?.medicalHistory,
            ),
            _RecordRow(
              icon: Icons.healing_outlined,
              label: 'Antécédents chirurgicaux',
              value: record?.surgicalHistory,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône et intitulé à la couleur de marque : ils forment un même
          // bloc, qui détache chaque rubrique de la précédente dans une fiche
          // qui en empile sept.
          Icon(icon, size: 19, color: AppPalette.primary),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                // Les rubriques cliniques sont saisies dans un éditeur enrichi
                // côté administration : listes, gras, titres… L'API les
                // transmet en HTML assaini.
                RichTextBody(
                  html: value,
                  style: text.bodyLarge,
                  emptyPlaceholder: 'Non renseigné',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Consultation passée : date et médecin, puis motif, diagnostic et
/// prescription renseignés, et enfin les documents joints, ouvrables d'un
/// geste vers son détail.
class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.consultation, required this.onTap});

  final ConsultationItem consultation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final documentCount = consultation.documents.length;

    // Aperçu du compte rendu : le motif, à défaut le diagnostic. Le détail
    // porte l'ensemble, la carte n'en donne que de quoi se repérer — la mise
    // en forme du diagnostic y est ramenée à une ligne de texte courante.
    final summary = [consultation.reason, consultation.diagnosis]
        .map((value) =>
            richHtmlToPlainText(value).replaceAll(RegExp(r'\s*\n+\s*'), ' '))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return AppCard(
      onTap: onTap,
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
            child: Icon(Icons.medical_services_outlined,
                color: AppPalette.primary, size: 21),
          ),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consultation.longDateLabel ?? 'Consultation',
                    style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [consultation.doctor, consultation.specialty]
                      .where((part) => part.isNotEmpty)
                      .join(' · '),
                  style: text.bodySmall,
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                ],
                if (documentCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.attach_file_rounded,
                          size: 15, color: AppPalette.primary),
                      const SizedBox(width: 4),
                      Text(
                        documentCount > 1
                            ? '$documentCount documents'
                            : '1 document',
                        style: text.labelMedium
                            ?.copyWith(color: AppPalette.primary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: AppPalette.inkFaint),
        ],
      ),
    );
  }
}
