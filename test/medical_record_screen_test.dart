import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/models/insurance.dart';
import 'package:my_clinic/models/medical_record.dart';
import 'package:my_clinic/repositories/medical_record_repository.dart';
import 'package:my_clinic/screens/medical/medical_record_screen.dart';

/// Rendu de l'écran « Mon dossier médical » (MedicalRecordScreen.mine) : on
/// vérifie que la fiche clinique et l'historique des consultations
/// s'affichent, sans appel réseau (le dossier est fourni par un stub).
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<_StubRecordRepo> pumpScreen(
    WidgetTester tester, {
    PatientRecord? record,
  }) async {
    final repository = _StubRecordRepo(record);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MedicalRecordRepository>.value(value: repository),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: MedicalRecordScreen.mine(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('affiche la synthèse clinique et les documents du patient',
      (tester) async {
    await pumpScreen(tester);

    // Identité + synthèse clinique.
    expect(find.text('Dossier médical'), findsOneWidget);
    expect(find.text('Awa Diomandé'), findsWidgets);
    // Numéro de dossier renvoyé par l'API, en pilule sous le nom.
    expect(find.text('DOS-2026-0042'), findsOneWidget);
    // Les intitulés de section sont rendus en capitales par SectionHeader.
    expect(find.text('FICHE MÉDICALE'), findsOneWidget);
    expect(find.text('Groupe sanguin'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Pénicilline (éruption cutanée)'), findsOneWidget);

    // Assurances reportées au dossier depuis les rendez-vous du patient.
    expect(find.text('Assurances'), findsOneWidget);
    expect(find.text('Assurance Alpha, Mutuelle Beta'), findsOneWidget);

    // Consultations : la section est plus bas que la hauteur du viewport de
    // test, il faut faire défiler pour l'atteindre.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('CONSULTATIONS (1)'), findsOneWidget);
    expect(find.text('Dr Kouadio N\'Guessan · Cardiologie'), findsOneWidget);
    // La carte résume : le motif, et le nombre de documents joints. Le
    // compte rendu complet est sur l'écran de détail.
    expect(find.text('Douleurs thoraciques à l\'effort'), findsOneWidget);
    expect(find.text('1 document'), findsOneWidget);
    expect(find.text('Angor stable'), findsNothing);
    // Les documents sont joints à leur consultation : plus de section à part.
    expect(find.textContaining('DOCUMENTS'), findsNothing);

    // Aucun état « vide » pour ce patient.
    expect(find.textContaining('Aucune fiche médicale'), findsNothing);
    expect(find.textContaining('Aucune consultation'), findsNothing);
  });

  testWidgets('un dossier vide affiche les messages d\'absence',
      (tester) async {
    await pumpScreen(
      tester,
      record: const PatientRecord(
        patient: RecordPatient(id: 9, name: 'Nouveau Patient'),
      ),
    );

    expect(find.textContaining('Aucune fiche médicale'), findsOneWidget);
    // Dossier sans numéro (ouvert avant la numérotation) : pas de pilule.
    expect(find.textContaining('DOS-'), findsNothing);
    expect(find.text('CONSULTATIONS (0)'), findsOneWidget);
    expect(find.textContaining('Aucune consultation'), findsOneWidget);
  });

  testWidgets('une carte de consultation ouvre son détail', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dr Kouadio N\'Guessan · Cardiologie'));
    await tester.pumpAndSettle();

    // Le compte rendu complet, absent de la carte, est ici.
    expect(find.text('Détail de la consultation'), findsOneWidget);
    expect(find.text('Angor stable'), findsOneWidget);
    expect(find.text('Bêtabloquant, contrôle dans 3 mois.'), findsOneWidget);

    // Les documents joints s'ouvrent depuis le détail.
    expect(find.text('DOCUMENTS JOINTS (1)'), findsOneWidget);
    expect(find.text('Ordonnance — traitement antipaludéen'), findsOneWidget);
  });

  testWidgets('rend les rubriques mises en forme reçues de l\'API',
      (tester) async {
    // Depuis le passage de l'administration à un éditeur enrichi, l'API
    // transmet ces rubriques en HTML assaini.
    await pumpScreen(
      tester,
      record: const PatientRecord(
        patient: RecordPatient(id: 11, name: 'Awa Diomandé'),
        record: MedicalRecordSummary(
          allergies: '<ul><li>Arachides</li><li>Pollen</li></ul>',
          medicalHistory: '<p>Asthme <strong>léger</strong></p>',
        ),
        consultations: RecordPage(
          total: 1,
          items: [
            ConsultationItem(
              id: 4,
              doctor: 'Dr Kouadio N\'Guessan',
              specialty: 'Cardiologie',
              consultedAt: '2026-05-20',
              diagnosis: '<p>Angor <strong>stable</strong></p>',
              prescription: '<ol><li>Bêtabloquant</li><li>Contrôle</li></ol>',
            ),
          ],
        ),
      ),
    );

    // Chaque élément de liste est une ligne à part, et non un bloc de texte
    // où les puces se seraient collées les unes aux autres.
    expect(find.text('Arachides', findRichText: true), findsOneWidget);
    expect(find.text('Pollen', findRichText: true), findsOneWidget);
    // Le gras est porté par un fragment : le texte du bloc reste entier.
    expect(find.text('Asthme léger', findRichText: true), findsOneWidget);
    // Aucune balise ne doit transparaître à l'écran.
    expect(find.textContaining('<', findRichText: true), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Sur la carte, la mise en forme est ramenée à une ligne de texte.
    expect(find.text('Angor stable'), findsOneWidget);

    await tester.tap(find.text('Dr Kouadio N\'Guessan · Cardiologie'));
    await tester.pumpAndSettle();

    expect(find.text('Angor stable', findRichText: true), findsOneWidget);
    expect(find.text('Bêtabloquant', findRichText: true), findsOneWidget);
    expect(find.text('Contrôle', findRichText: true), findsOneWidget);
    expect(find.textContaining('<', findRichText: true), findsNothing);
  });

  testWidgets('demande 5 consultations par page et pagine au-delà',
      (tester) async {
    // Douze consultations réparties par l'API en trois pages de cinq.
    final repository = await pumpScreen(
      tester,
      record: PatientRecord(
        patient: const RecordPatient(id: 7, name: 'Awa Diomandé'),
        consultations: RecordPage(
          total: 12,
          lastPage: 3,
          items: [
            for (var i = 0; i < 5; i++)
              ConsultationItem(
                id: i,
                doctor: 'Dr Kouadio N\'Guessan',
                specialty: 'Cardiologie',
                consultedAt: '2026-05-0${i + 1}',
              ),
          ],
        ),
      ),
    );

    expect(repository.requestedPerPage, 5,
        reason: 'la pagination démarre à 5 consultations');

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Barre de pages présente : on demande la deuxième.
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
  });
}

/// Repository de test : renvoie un dossier prédéfini sans appel réseau.
class _StubRecordRepo extends MedicalRecordRepository {
  _StubRecordRepo([PatientRecord? record])
      : _record = record ?? _defaultRecord,
        super(ApiClient());

  final PatientRecord _record;

  @override
  Future<PatientRecord> mine({int consultationsPage = 1, int? perPage}) async {
    requestedPages.add(consultationsPage);
    requestedPerPage = perPage;
    return _record;
  }

  /// Pages demandées à l'API, dans l'ordre.
  final List<int> requestedPages = [];
  int? requestedPerPage;
}

const _defaultRecord = PatientRecord(
  patient: RecordPatient(
    id: 7,
    recordNumber: 'DOS-2026-0042',
    name: 'Awa Diomandé',
    phone: '+225 07 00 00 00 00',
    gender: 'female',
    birthDate: '1985-04-12',
    address: 'Cocody, Abidjan',
  ),
  record: MedicalRecordSummary(
    bloodType: 'O+',
    allergies: 'Pénicilline (éruption cutanée)',
    medicalHistory: 'Hypertension artérielle diagnostiquée en 2023.',
    surgicalHistory: 'Appendicectomie en 2010.',
    currentMedications: 'Amlodipine 5 mg, 1 comprimé par jour.',
  ),
  insurances: [
    Insurance(id: 1, name: 'Assurance Alpha'),
    Insurance(id: 2, name: 'Mutuelle Beta'),
  ],
  consultations: RecordPage(
    total: 1,
    items: [
      ConsultationItem(
        id: 4,
        doctor: 'Dr Kouadio N\'Guessan',
        specialty: 'Cardiologie',
        consultedAt: '2026-05-20',
        reason: 'Douleurs thoraciques à l\'effort',
        diagnosis: 'Angor stable',
        prescription: 'Bêtabloquant, contrôle dans 3 mois.',
        documents: [
          MedicalDocumentItem(
            id: 2,
            consultationId: 4,
            type: 'prescription',
            typeLabel: 'Ordonnance',
            title: 'Ordonnance — traitement antipaludéen',
            isImage: false,
            isPdf: true,
            fileUrl: '/api/v1/medical-documents/2/file?expires=1&signature=x',
            issuedAt: '2025-11-15',
          ),
        ],
      ),
    ],
  ),
);
