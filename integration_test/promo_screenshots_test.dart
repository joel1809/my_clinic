import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_clinic/main.dart' as app;
import 'package:my_clinic/widgets/shared.dart';

/// Parcours patient capturé écran par écran sur un téléphone réel, pour
/// produire des visuels de promotion.
///
/// Lancement :
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/promo_screenshots_test.dart \
///     --dart-define=DEMO_EMAIL=... --dart-define=DEMO_PASSWORD=... \
///     -d `appareil`
///
/// Les images arrivent dans `captures/`. Le parcours de réservation s'arrête
/// volontairement juste avant l'envoi : aucun rendez-vous n'est créé dans la
/// base.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('DEMO_EMAIL');
  const password = String.fromEnvironment('DEMO_PASSWORD');

  testWidgets('parcours patient', (tester) async {
    expect(
      email.isNotEmpty && password.isNotEmpty,
      isTrue,
      reason: 'Fournir --dart-define=DEMO_EMAIL=… et --dart-define=DEMO_PASSWORD=…',
    );

    // Sans cette conversion, la capture ne rend qu'un écran noir sur Android.
    await binding.convertFlutterSurfaceToImage();

    var index = 0;
    Future<void> shoot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      index++;
      await binding.takeScreenshot('${index.toString().padLeft(2, '0')}-$name');
    }

    /// Laisse le temps aux appels réseau (tunnel ngrok) d'aboutir.
    Future<void> settle([int seconds = 6]) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }

    app.main();
    await settle();

    // ── Connexion ────────────────────────────────────────────────────────
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'), password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await settle(8);

    // ── Accueil ──────────────────────────────────────────────────────────
    await shoot('accueil');

    // ── Liste des médecins ───────────────────────────────────────────────
    await tester.tap(find.text('Prendre rendez-vous').first);
    await settle();
    await shoot('medecins');

    // ── Fiche médecin ────────────────────────────────────────────────────
    await tester.tap(find.byType(AppCard).first);
    await settle();
    await shoot('fiche-medecin');

    // ── Réservation, étape 1 : le jour ───────────────────────────────────
    await tester.tap(find.widgetWithText(FilledButton, 'Prendre rendez-vous'));
    await settle();
    await shoot('reservation-jour');

    // ── Réservation, étape 2 : le créneau ────────────────────────────────
    final openDay = find.ancestor(
      of: find.text('Créneaux disponibles').first,
      matching: find.byType(AppCard),
    );
    if (openDay.evaluate().isNotEmpty) {
      await tester.tap(openDay.first);
      await settle();
      await shoot('reservation-creneau');

      // ── Réservation, étape 3 : le récapitulatif ───────────────────────
      final slot = find.byWidgetPredicate((widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^\d{1,2}h\d{2}$').hasMatch(widget.data!));
      if (slot.evaluate().isNotEmpty) {
        await tester.tap(slot.first);
        await tester.pumpAndSettle();

        final next = find.textContaining('Continuer');
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next.first);
          await settle(3);
          // On s'arrête ici : appuyer sur « Confirmer le rendez-vous »
          // enregistrerait une vraie demande côté clinique.
          await shoot('reservation-recapitulatif');
        }
      }
    }

    // Retour à l'accueil sans rien envoyer.
    while (find.byIcon(Icons.home_rounded).evaluate().isEmpty &&
        find.byIcon(Icons.home_outlined).evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await settle(2);

    // ── Mes rendez-vous ──────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await settle();
    await shoot('mes-rendez-vous');

    final appointment = find.byType(AppCard);
    if (appointment.evaluate().isNotEmpty) {
      await tester.tap(appointment.first);
      await settle();
      await shoot('detail-rendez-vous');
      await tester.pageBack();
      await settle(2);
    }

    // ── Actualités ───────────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.article_outlined));
    await settle();
    await shoot('actualites');

    final article = find.byType(AppCard);
    if (article.evaluate().isNotEmpty) {
      await tester.tap(article.first);
      await settle();
      await shoot('article');
      await tester.pageBack();
      await settle(2);
    }

    // ── Profil ───────────────────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.person_outline));
    await settle();
    await shoot('profil');

    final record = find.text('Mon dossier médical');
    if (record.evaluate().isNotEmpty) {
      await tester.tap(record);
      await settle();
      await shoot('dossier-medical');
    }
  });
}
