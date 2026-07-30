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
/// vérifie que la fiche clinique et les documents du patient s'affichent, sans
/// appel réseau (le dossier est fourni par un repository stub).
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MedicalRecordRepository>.value(value: _StubRecordRepo()),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: MedicalRecordScreen.mine(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche la synthèse clinique et les documents du patient',
      (tester) async {
    await pumpScreen(tester);

    // Identité + synthèse clinique.
    expect(find.text('Dossier médical'), findsOneWidget);
    expect(find.text('Awa Diomandé'), findsWidgets);
    // Les intitulés de section sont rendus en capitales par SectionHeader.
    expect(find.text('FICHE MÉDICALE'), findsOneWidget);
    expect(find.text('Groupe sanguin'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Pénicilline (éruption cutanée)'), findsOneWidget);

    // Assurances reportées au dossier depuis les rendez-vous du patient.
    expect(find.text('Assurances'), findsOneWidget);
    expect(find.text('Assurance Alpha, Mutuelle Beta'), findsOneWidget);

    // Documents : la section est plus bas que la hauteur du viewport de test,
    // il faut faire défiler pour l'atteindre.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('DOCUMENTS (1)'), findsOneWidget);
    expect(find.text('Ordonnance — traitement antipaludéen'), findsOneWidget);

    // Aucun état « vide » pour ce patient.
    expect(find.textContaining('Aucune fiche médicale'), findsNothing);
    expect(find.textContaining('Aucun document'), findsNothing);
  });

  testWidgets('un dossier vide affiche les messages d\'absence',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MedicalRecordRepository>.value(
            value: _StubRecordRepo(
              const PatientRecord(
                patient: RecordPatient(id: 9, name: 'Nouveau Patient'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: MedicalRecordScreen.mine(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune fiche médicale'), findsOneWidget);
    expect(find.text('DOCUMENTS (0)'), findsOneWidget);
    expect(find.textContaining('Aucun document'), findsOneWidget);
  });
}

/// Repository de test : renvoie un dossier prédéfini sans appel réseau.
class _StubRecordRepo extends MedicalRecordRepository {
  _StubRecordRepo([PatientRecord? record])
      : _record = record ?? _defaultRecord,
        super(ApiClient());

  final PatientRecord _record;

  @override
  Future<PatientRecord> mine() async => _record;
}

const _defaultRecord = PatientRecord(
  patient: RecordPatient(
    id: 7,
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
    currentMedications: 'Amlodipine 5 mg, 1 comprimé par jour.',
  ),
  insurances: [
    Insurance(id: 1, name: 'Assurance Alpha'),
    Insurance(id: 2, name: 'Mutuelle Beta'),
  ],
  documents: [
    MedicalDocumentItem(
      id: 2,
      type: 'prescription',
      typeLabel: 'Ordonnance',
      title: 'Ordonnance — traitement antipaludéen',
      isImage: false,
      isPdf: true,
      fileUrl: '/api/v1/medical-documents/2/file?expires=1&signature=x',
      issuedAt: '2025-11-15',
    ),
  ],
);
