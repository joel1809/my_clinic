@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/repositories/medical_record_repository.dart';

/// Test d'intégration contre l'API réelle : nécessite le backend démarré
/// (php artisan serve) et sa base de données seedée (php artisan migrate --seed).
///
///   flutter test --run-skipped --tags integration test/medical_record_test.dart
///
/// Un compte patient se connecte et consulte son propre dossier médical via le
/// chemin de code réel de l'app (endpoint GET /my/medical-record). Pas de
/// testWidgets ici : la vraie requête réseau n'est possible que hors du binding
/// de test des widgets. Le rendu de l'écran est couvert par
/// medical_record_screen_test.dart.
void main() {
  // Patient seedé (ClinicSeeder/PatientSeeder) : fiche médicale renseignée
  // + au moins un document.
  const email = 'awa.diomande@my-clinic.test';
  const password = 'password';

  test('un patient connecté consulte son propre dossier médical', () async {
    final api = ApiClient();
    final auth = AuthRepository(api);
    final records = MedicalRecordRepository(api);

    final session = await auth.login(email: email, password: password);
    expect(session.user.role, 'patient');
    api.token = session.token;

    // Le patient charge son propre dossier (pas d'identifiant : /my/...),
    // avec la taille de page qu'utilise l'écran.
    final record = await records.mine(perPage: 5);

    expect(record.patient.name, isNotNull);
    // Numéro de dossier attribué par la clinique, ex. « DOS-2026-0001 »
    expect(record.patient.recordNumber, startsWith('DOS-'));
    expect(record.record, isNotNull,
        reason: 'le patient seedé a une fiche médicale renseignée');
    expect(record.record!.bloodType, isNotNull);
    // L'historique des consultations se lit, et l'API honore `per_page` :
    // c'est lui qui déclenche la pagination à partir de 5 consultations.
    expect(record.consultations.currentPage, 1);
    expect(record.consultations.items.length, lessThanOrEqualTo(5));
    expect(record.consultations.total,
        greaterThanOrEqualTo(record.consultations.items.length));
    expect(record.documents.items, isNotEmpty,
        reason: 'le patient seedé a au moins un document');
    expect(record.documents.total, greaterThanOrEqualTo(1));
    expect(record.documents.items.first.fileUrl, startsWith('/api/'));

    await auth.logout();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
