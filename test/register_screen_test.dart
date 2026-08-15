import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/screens/auth/register_screen.dart';

/// Inscription d'un patient : le numéro de téléphone est demandé dès la
/// création du compte — la clinique s'en sert pour les rappels, et la prise de
/// rendez-vous l'exige de toute façon.
void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      home: RegisterScreen(),
    ));
  }

  /// Remplit tout sauf le téléphone, puis demande la création du compte.
  Future<void> submitWithout(WidgetTester tester, {String phone = ''}) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom complet'), 'Awa Diop');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), 'awa@exemple.test');
    if (phone.isNotEmpty) {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Téléphone'), phone);
    }
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'), 'motdepasse1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'motdepasse1');

    // Le formulaire dépasse la hauteur de la surface de test : le bouton
    // n'est pas atteignable sans faire défiler jusqu'à lui.
    final submit = find.widgetWithText(FilledButton, 'Créer mon compte');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
  }

  testWidgets('le téléphone n\'est pas présenté comme facultatif',
      (tester) async {
    await pumpForm(tester);

    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Téléphone (facultatif)'), findsNothing);
  });

  testWidgets('refuse la création du compte sans numéro de téléphone',
      (tester) async {
    await pumpForm(tester);
    await submitWithout(tester);

    expect(find.text('Veuillez indiquer un numéro de téléphone.'),
        findsOneWidget);
  });

  testWidgets('un numéro renseigné lève l\'erreur', (tester) async {
    await pumpForm(tester);
    await submitWithout(tester, phone: '+221 77 123 45 67');

    expect(find.text('Veuillez indiquer un numéro de téléphone.'), findsNothing);
  });
}
