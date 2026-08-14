import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/core/session_store.dart';
import 'package:my_clinic/models/appointment.dart';
import 'package:my_clinic/models/user.dart';
import 'package:my_clinic/repositories/appointment_repository.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/screens/appointments/appointment_detail_screen.dart';
import 'package:my_clinic/state/auth_state.dart';

/// Écran de détail : mise en page tenue sur écran étroit et avec une taille de
/// texte système agrandie, actions réservées au médecin.
///
/// La police des tests est plus large que celle d'un appareil (environ un cadratin
/// par caractère) : ces cas sont donc un pire cas volontairement pessimiste.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpDetail(
    WidgetTester tester, {
    required User user,
    Size size = const Size(390, 900),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: _StubAuth(user)),
          Provider<AppointmentRepository>.value(value: _StubRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const AppointmentDetailScreen(appointmentId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le médecin voit les actions et le dossier du patient',
      (tester) async {
    await pumpDetail(tester, user: _doctor);

    expect(find.text('Awa Diomandé'), findsOneWidget);
    // Numéro de dossier renvoyé par l'API : il identifie le patient au
    // registre de la clinique.
    expect(find.text('DOS-2026-0007'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Dossier médical'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le patient ne voit ni confirmation ni données de patient',
      (tester) async {
    await pumpDetail(tester, user: _patient);

    expect(find.text('Confirmer'), findsNothing);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('DOS-2026-0007'), findsNothing);
    expect(find.text('Dossier médical'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Un débordement fait échouer le test de lui-même : Flutter signale
  // « A RenderFlex overflowed » comme une erreur.
  for (final (width, scale) in [(320.0, 1.0), (320.0, 1.5), (412.0, 2.0)]) {
    testWidgets('aucun débordement en ${width}px à l\'échelle $scale',
        (tester) async {
      // Surface haute pour que toutes les cartes soient effectivement
      // construites malgré le défilement paresseux de la liste.
      await pumpDetail(
        tester,
        user: _doctor,
        size: Size(width, 1600),
        textScale: scale,
      );

      expect(find.text('Motif'), findsOneWidget);
      expect(find.text('Demandé le'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

final _doctor = User.fromJson({
  'id': 1,
  'name': 'Dr Emily Carter',
  'email': 'carter@example.com',
  'role': 'doctor',
});

final _patient = User.fromJson({
  'id': 2,
  'name': 'Awa Diomandé',
  'email': 'awa@example.com',
  'role': 'patient',
});

/// Rendez-vous de test : toujours à venir, donc confirmable et annulable.
final _futureDate = DateTime.now().add(const Duration(days: 3));

String get _futureDateString => '${_futureDate.year}-'
    '${_futureDate.month.toString().padLeft(2, '0')}-'
    '${_futureDate.day.toString().padLeft(2, '0')}';

/// Repository de test : un rendez-vous en attente, aucun appel réseau.
class _StubRepo extends AppointmentRepository {
  _StubRepo() : super(ApiClient());

  @override
  Future<Appointment> show(int id) async => Appointment.fromJson({
        'id': 10,
        'scheduled_date': _futureDateString,
        'start_time': '10:00',
        'end_time': '10:30',
        'reason': 'Contrôle annuel de la tension et bilan sanguin complet',
        'status': 'pending',
        'status_label': 'En attente',
        'is_cancellable': true,
        'is_confirmable': true,
        'created_at': '2026-07-20T10:00:00+00:00',
        'doctor': {
          'id': 1,
          'full_name': 'Dr Emily Carter',
          'appointment_duration': 30,
          'specialty': {
            'id': 3,
            'name': 'Gynécologie Obstétrique',
            'slug': 'gynecologie-obstetrique',
          },
        },
        'patient': {
          'id': 7,
          'record_number': 'DOS-2026-0007',
          'name': 'Awa Diomandé',
          'phone': '+225 07 00 00 00',
        },
      });
}

/// Session de test : utilisateur figé, aucun accès au stockage sécurisé.
class _StubAuth extends AuthState {
  _StubAuth(this._user)
      : super(
          api: ApiClient(),
          repository: AuthRepository(ApiClient()),
          store: SessionStore(),
        );

  final User _user;

  @override
  User? get user => _user;
}
