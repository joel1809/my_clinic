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
    _StubRepo? repo,
    Size size = const Size(390, 900),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: _StubAuth(user)),
          Provider<AppointmentRepository>.value(value: repo ?? _StubRepo()),
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

  testWidgets('le médecin clôture le rendez-vous une fois le créneau écoulé',
      (tester) async {
    final repo = _StubRepo(completable: true);
    await pumpDetail(tester, user: _doctor, repo: repo);

    expect(find.textContaining('Le créneau est écoulé'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.text('Annuler'), findsNothing);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    expect(find.text('Terminer ce rendez-vous ?'), findsOneWidget);
    expect(repo.completedId, isNull);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Terminer'),
    ));
    await tester.pumpAndSettle();

    expect(repo.completedId, 10);
    expect(find.text('Rendez-vous terminé.'), findsOneWidget);
    // Barre d'actions repliée : plus rien à faire sur ce rendez-vous
    expect(find.text('Terminer'), findsNothing);
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('le patient ne peut pas clôturer son rendez-vous',
      (tester) async {
    await pumpDetail(tester, user: _patient, repo: _StubRepo(completable: true));

    expect(find.text('Terminer'), findsNothing);
    expect(find.textContaining('Le créneau est écoulé'), findsNothing);
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

String _dateString(DateTime date) => '${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String get _futureDateString => _dateString(_futureDate);

Map<String, dynamic> _appointmentJson({
  String status = 'pending',
  String statusLabel = 'En attente',
  bool isCancellable = true,
  bool isConfirmable = true,
  bool isCompletable = false,
  String? date,
}) =>
    {
      'id': 10,
      'scheduled_date': date ?? _futureDateString,
      'start_time': '10:00',
      'end_time': '10:30',
      'reason': 'Contrôle annuel de la tension et bilan sanguin complet',
      'status': status,
      'status_label': statusLabel,
      'is_cancellable': isCancellable,
      'is_confirmable': isConfirmable,
      'is_completable': isCompletable,
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
    };

/// Repository de test : un rendez-vous en attente — ou, si [completable], un
/// rendez-vous confirmé du jour dont le créneau est écoulé. Aucun appel réseau.
class _StubRepo extends AppointmentRepository {
  _StubRepo({this.completable = false}) : super(ApiClient());

  final bool completable;

  int? completedId;

  @override
  Future<Appointment> show(int id) async => Appointment.fromJson(
        completable
            ? _appointmentJson(
                status: 'confirmed',
                statusLabel: 'Confirmé',
                isCancellable: false,
                isConfirmable: false,
                isCompletable: true,
                date: _dateString(DateTime.now()),
              )
            : _appointmentJson(),
      );

  @override
  Future<Appointment> complete(int id) async {
    completedId = id;
    return Appointment.fromJson(_appointmentJson(
      status: 'completed',
      statusLabel: 'Terminé',
      isCancellable: false,
      isConfirmable: false,
      date: _dateString(DateTime.now()),
    ));
  }
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
