import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/core/api_exception.dart';
import 'package:my_clinic/core/session_store.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/screens/auth/forgot_password_screen.dart';
import 'package:my_clinic/state/auth_state.dart';

/// Mot de passe oublié : l'API envoie un code à six chiffres par e-mail, que
/// le patient saisit ici avec son nouveau mot de passe. Aucun appel réseau —
/// l'état d'authentification est simulé.
void main() {
  /// Ouvre l'écran depuis une page d'accueil factice, pour que la fermeture
  /// de l'écran (et sa valeur de retour) soit observable.
  Future<String? Function()> pumpFlow(
    WidgetTester tester,
    _StubAuth auth, {
    String initialEmail = '',
  }) async {
    String? popped;

    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('fr'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) =>
                          ForgotPasswordScreen(initialEmail: initialEmail),
                    ),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    return () => popped;
  }

  /// Ouvre l'écran et amène le parcours à l'étape du code.
  Future<String? Function()> pumpAtCodeStep(
    WidgetTester tester,
    _StubAuth auth, {
    String email = 'awa@exemple.test',
  }) async {
    final result = await pumpFlow(tester, auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le code'));
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('demande un code puis propose de le saisir', (tester) async {
    final auth = _StubAuth();
    await pumpAtCodeStep(tester, auth, email: '  Awa@Exemple.test  ');

    // L'adresse part normalisée : le plafond de l'API compte par adresse
    // visée, les variantes de casse ne doivent pas le contourner.
    expect(auth.requestedEmail, 'awa@exemple.test');

    // Réponse de l'API affichée telle quelle : elle ne dit pas si un compte
    // existe à cette adresse.
    expect(find.textContaining('Si un compte correspond'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Code reçu par e-mail'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        findsOneWidget);
  });

  testWidgets('n\'appelle pas l\'API sans adresse e-mail', (tester) async {
    final auth = _StubAuth();
    await pumpFlow(tester, auth);

    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le code'));
    await tester.pumpAndSettle();

    expect(auth.requestedEmail, isNull);
    expect(find.text('Veuillez indiquer votre adresse e-mail.'), findsOneWidget);
  });

  testWidgets('rend lisible le plafond de demandes de l\'API', (tester) async {
    // L'API limite les envois par adresse visée : le message anglais du
    // serveur (« Too Many Attempts. ») est remplacé par le délai à attendre.
    final auth = _StubAuth(
      sendError: ApiException(429, 'Too Many Attempts.',
          retryAfter: const Duration(seconds: 30)),
    );
    await pumpFlow(tester, auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'), 'awa@exemple.test');
    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Réessayez dans 30 secondes'), findsOneWidget);
    // Le parcours reste à l'étape de la demande.
    expect(find.widgetWithText(FilledButton, 'Envoyer le code'), findsOneWidget);
  });

  testWidgets('réinitialise le mot de passe et rend l\'adresse traitée',
      (tester) async {
    final auth = _StubAuth();
    final result = await pumpAtCodeStep(tester, auth);

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

    expect(auth.resetPayload, {
      'email': 'awa@exemple.test',
      'code': '048291',
      'password': 'motdepasse1',
      'password_confirmation': 'motdepasse1',
    });
    // L'écran se ferme en rendant l'adresse, que la connexion pré-remplit.
    expect(result(), 'awa@exemple.test');
    expect(find.textContaining('Votre mot de passe a été réinitialisé'),
        findsOneWidget);
  });

  testWidgets('affiche sous le champ le refus d\'un code périmé',
      (tester) async {
    final auth = _StubAuth(
      resetError: ApiException(422, 'Données invalides.', errors: {
        'code': ['Ce code de réinitialisation est invalide ou a expiré.'],
      }),
    );
    await pumpAtCodeStep(tester, auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Code reçu par e-mail'), '000000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        'motdepasse1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'motdepasse1');
    await tester
        .tap(find.widgetWithText(FilledButton, 'Réinitialiser le mot de passe'));
    await tester.pumpAndSettle();

    expect(find.text('Ce code de réinitialisation est invalide ou a expiré.'),
        findsOneWidget);
    // Le parcours reste sur place : le patient corrige son code.
    expect(find.widgetWithText(FilledButton, 'Réinitialiser le mot de passe'),
        findsOneWidget);
  });

  testWidgets('refuse localement un code incomplet et une confirmation '
      'différente', (tester) async {
    final auth = _StubAuth();
    await pumpAtCodeStep(tester, auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Code reçu par e-mail'), '123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
        'motdepasse1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'motdepasse2');
    await tester
        .tap(find.widgetWithText(FilledButton, 'Réinitialiser le mot de passe'));
    await tester.pumpAndSettle();

    expect(auth.resetPayload, isNull);
    expect(find.text('Le code de réinitialisation comporte six chiffres.'),
        findsOneWidget);
    expect(find.text('La confirmation du mot de passe ne correspond pas.'),
        findsOneWidget);
  });

  testWidgets('permet de repartir de l\'adresse quand le code n\'arrive pas',
      (tester) async {
    final auth = _StubAuth();
    await pumpAtCodeStep(tester, auth);

    await tester.tap(find.text('Je n\'ai pas reçu de code'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Envoyer le code'), findsOneWidget);
    // L'adresse déjà saisie est conservée : une nouvelle demande remplace
    // la précédente côté serveur.
    expect(find.text('awa@exemple.test'), findsOneWidget);
  });
}

/// Session de test : les deux étapes du parcours sont simulées, et l'on peut
/// leur faire renvoyer l'erreur de l'API.
class _StubAuth extends AuthState {
  _StubAuth({this.sendError, this.resetError})
      : super(
          api: ApiClient(),
          repository: AuthRepository(ApiClient()),
          store: SessionStore(),
        );

  final Object? sendError;
  final Object? resetError;

  String? requestedEmail;
  Map<String, String>? resetPayload;

  @override
  Future<String> requestPasswordResetCode({required String email}) async {
    requestedEmail = email;
    if (sendError != null) throw sendError!;
    return 'Si un compte correspond à cette adresse, un code de '
        'réinitialisation vient de lui être envoyé par e-mail.';
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    resetPayload = {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    if (resetError != null) throw resetError!;
    return 'Votre mot de passe a été réinitialisé. Vous pouvez maintenant '
        'vous connecter.';
  }
}
