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

    // Le patient charge son propre dossier (pas d'identifiant : /my/...).
    final record = await records.mine();

    expect(record.patient.name, isNotNull);
    expect(record.record, isNotNull,
        reason: 'le patient seedé a une fiche médicale renseignée');
    expect(record.record!.bloodType, isNotNull);
    expect(record.documents, isNotEmpty,
        reason: 'le patient seedé a au moins un document');
    expect(record.documents.first.fileUrl, startsWith('/api/'));

    await auth.logout();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
