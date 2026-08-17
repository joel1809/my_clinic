import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/repositories/branding_repository.dart';
import 'package:my_clinic/screens/auth/login_screen.dart';
import 'package:my_clinic/state/branding_state.dart';

/// Connexion : le patient qui a oublié son mot de passe doit trouver la sortie
/// depuis cet écran, sans avoir à deviner qu'elle se trouve sur le site.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<BrandingState>(
        create: (_) => BrandingState(BrandingRepository(ApiClient())),
        child: const MaterialApp(
          locale: Locale('fr'),
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('propose la réinitialisation du mot de passe', (tester) async {
    await pumpLogin(tester);

    expect(
      find.widgetWithText(TextButton, 'Mot de passe oublié ?'),
      findsOneWidget,
    );
    // L'action reste secondaire : la connexion garde le bouton plein.
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });
}
