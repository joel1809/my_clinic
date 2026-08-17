import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/core/session_store.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/repositories/branding_repository.dart';
import 'package:my_clinic/screens/auth/login_screen.dart';
import 'package:my_clinic/state/auth_state.dart';
import 'package:my_clinic/state/branding_state.dart';

/// Connexion : le patient qui a oublié son mot de passe doit trouver la sortie
/// depuis cet écran, et y revenir prêt à se connecter.
void main() {
  Future<_StubAuth> pumpLogin(WidgetTester tester) async {
    final auth = _StubAuth();

    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: auth),
          ChangeNotifierProvider<BrandingState>(
            create: (_) => BrandingState(BrandingRepository(ApiClient())),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    return auth;
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

  testWidgets('ouvre le parcours avec l\'adresse déjà saisie', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), 'awa@exemple.test');
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    expect(find.text('Retrouver votre compte'), findsOneWidget);
    // L'adresse est reprise : elle n'est pas à retaper.
    expect(find.text('awa@exemple.test'), findsOneWidget);
  });

  testWidgets('revient de la réinitialisation avec l\'adresse pré-remplie',
      (tester) async {
    final auth = await pumpLogin(tester);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), 'awa@exemple.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le code'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Code reçu par e-mail'), '048291');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        'motdepasse1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'motdepasse1');
    await tester
        .tap(find.widgetWithText(FilledButton, 'Réinitialiser le mot de passe'));
    await tester.pumpAndSettle();

    expect(auth.resetEmail, 'awa@exemple.test');
    // De retour sur la connexion, il ne reste que le mot de passe à saisir.
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
    expect(find.text('awa@exemple.test'), findsOneWidget);
  });
}

/// Session de test : le parcours de réinitialisation est simulé, aucun appel
/// réseau ni accès au stockage sécurisé.
class _StubAuth extends AuthState {
  _StubAuth()
      : super(
          api: ApiClient(),
          repository: AuthRepository(ApiClient()),
          store: SessionStore(),
        );

  String? resetEmail;

  @override
  Future<String> requestPasswordResetCode({required String email}) async =>
      'Si un compte correspond à cette adresse, un code de réinitialisation '
      'vient de lui être envoyé par e-mail.';

  @override
  Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    resetEmail = email;
    return 'Votre mot de passe a été réinitialisé.';
  }
}
