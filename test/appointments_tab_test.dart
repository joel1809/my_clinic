import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/core/session_store.dart';
import 'package:my_clinic/models/appointment.dart';
import 'package:my_clinic/models/paginated.dart';
import 'package:my_clinic/models/user.dart';
import 'package:my_clinic/repositories/appointment_repository.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/screens/appointments/appointments_tab.dart';
import 'package:my_clinic/state/auth_state.dart';

/// Onglet « Rendez-vous » : le médecin peut confirmer ou annuler une demande
/// directement depuis la liste, le patient ne voit que l'annulation.
/// Aucun appel réseau : la liste vient d'un repository stub.
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpTab(
    WidgetTester tester, {
    required User user,
    required _StubAppointmentRepo repo,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthState>.value(value: _StubAuth(user)),
          Provider<AppointmentRepository>.value(value: repo),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          home: AppointmentsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le médecin confirme un rendez-vous depuis la liste',
      (tester) async {
    final repo = _StubAppointmentRepo();
    await pumpTab(tester, user: _doctor, repo: repo);

    // La demande du patient est visible avec ses deux actions
    expect(find.text('Awa Diomandé'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    // Confirmation demandée avant d'appeler l'API
    expect(find.text('Confirmer ce rendez-vous ?'), findsOneWidget);
    expect(repo.confirmedId, isNull);

    // Le bouton « Confirmer » de la boîte de dialogue, pas celui de la carte
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Confirmer'),
    ));
    await tester.pumpAndSettle();

    expect(repo.confirmedId, 10);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('Rendez-vous confirmé.'), findsOneWidget);
    // L'action n'a plus lieu d'être une fois le rendez-vous confirmé
    expect(find.text('Confirmer'), findsNothing);
  });

  testWidgets('le médecin annule un rendez-vous depuis la liste',
      (tester) async {
    final repo = _StubAppointmentRepo();
    await pumpTab(tester, user: _doctor, repo: repo);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler ce rendez-vous ?'), findsOneWidget);
    expect(find.textContaining('Le patient sera informé'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Annuler le RDV'));
    await tester.pumpAndSettle();

    expect(repo.cancelledId, 10);
    expect(find.text('Rendez-vous annulé.'), findsOneWidget);
  });

  testWidgets('le médecin clôture un rendez-vous dont le créneau est écoulé',
      (tester) async {
    final repo = _StubAppointmentRepo(completable: true);
    await pumpTab(tester, user: _doctor, repo: repo);

    // Le rendez-vous est confirmé : seule la clôture est proposée
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.text('Annuler'), findsNothing);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    // Confirmation demandée avant d'appeler l'API
    expect(find.text('Terminer ce rendez-vous ?'), findsOneWidget);
    expect(repo.completedId, isNull);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Terminer'),
    ));
    await tester.pumpAndSettle();

    expect(repo.completedId, 10);
    expect(find.text('Rendez-vous terminé.'), findsOneWidget);

    // Clôturé, le rendez-vous quitte « À venir » pour l'historique, sans
    // action restante
    expect(find.text('Terminer'), findsNothing);
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();

    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('Terminer'), findsNothing);
  });

  testWidgets('le patient ne voit pas la clôture de son rendez-vous',
      (tester) async {
    final repo = _StubAppointmentRepo(completable: true);
    await pumpTab(tester, user: _patient, repo: repo);

    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('Terminer'), findsNothing);
  });

  testWidgets('le patient ne peut pas confirmer son rendez-vous',
      (tester) async {
    final repo = _StubAppointmentRepo();
    await pumpTab(tester, user: _patient, repo: repo);

    expect(find.text('Mes rendez-vous'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.text('Annuler'), findsOneWidget);
    // Le filtre « À confirmer » est réservé au personnel
    expect(find.text('À confirmer'), findsNothing);
  });

  testWidgets('le filtre « Historique » masque les rendez-vous à venir',
      (tester) async {
    final repo = _StubAppointmentRepo();
    await pumpTab(tester, user: _doctor, repo: repo);

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();

    expect(find.text('Awa Diomandé'), findsNothing);
    expect(find.textContaining('Aucun rendez-vous passé'), findsOneWidget);
  });
}

final _doctor = User.fromJson({
  'id': 1,
  'name': 'Dr Ndiaye',
  'email': 'ndiaye@example.com',
  'role': 'doctor',
});

final _patient = User.fromJson({
  'id': 2,
  'name': 'Awa Diomandé',
  'email': 'awa@example.com',
  'role': 'patient',
});

/// Date du rendez-vous de test : toujours à venir.
final _futureDate = DateTime.now().add(const Duration(days: 3));

String _dateString(DateTime date) => '${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String get _futureDateString => _dateString(_futureDate);

/// Un rendez-vous terminable a eu lieu le jour même : il reste donc dans
/// « À venir », là où le médecin le clôture.
String get _todayDateString => _dateString(DateTime.now());

Map<String, dynamic> _appointmentJson({
  String status = 'pending',
  String statusLabel = 'En attente',
  bool isConfirmable = true,
  bool isCancellable = true,
  bool isCompletable = false,
  String? date,
}) =>
    {
      'id': 10,
      'scheduled_date': date ?? _futureDateString,
      'start_time': '09:00',
      'end_time': '09:30',
      'reason': 'Contrôle annuel',
      'status': status,
      'status_label': statusLabel,
      'is_cancellable': isCancellable,
      'is_confirmable': isConfirmable,
      'is_completable': isCompletable,
      'doctor': {
        'id': 1,
        'full_name': 'Dr Ndiaye',
        'appointment_duration': 30,
        'specialty': {'id': 3, 'name': 'Cardiologie', 'slug': 'cardiologie'},
      },
      'patient': {'id': 7, 'name': 'Awa Diomandé', 'phone': '+225 07 00 00 00'},
    };

/// Repository de test : une seule page contenant une demande en attente, ou
/// un rendez-vous confirmé dont le créneau est écoulé si [completable].
class _StubAppointmentRepo extends AppointmentRepository {
  _StubAppointmentRepo({this.completable = false}) : super(ApiClient());

  final bool completable;

  int? confirmedId;
  int? cancelledId;
  int? completedId;

  Map<String, dynamic> get _item => completable
      ? _appointmentJson(
          status: 'confirmed',
          statusLabel: 'Confirmé',
          isConfirmable: false,
          isCancellable: false,
          isCompletable: true,
          date: _todayDateString,
        )
      : _appointmentJson();

  @override
  Future<Paginated<Appointment>> list({int page = 1}) async => Paginated(
        items: [Appointment.fromJson(_item)],
        currentPage: 1,
        lastPage: 1,
      );

  @override
  Future<Appointment> complete(int id) async {
    completedId = id;
    return Appointment.fromJson(_appointmentJson(
      status: 'completed',
      statusLabel: 'Terminé',
      isConfirmable: false,
      isCancellable: false,
      date: _todayDateString,
    ));
  }

  @override
  Future<Appointment> confirm(int id) async {
    confirmedId = id;
    return Appointment.fromJson(_appointmentJson(
      status: 'confirmed',
      statusLabel: 'Confirmé',
      isConfirmable: false,
    ));
  }

  @override
  Future<Appointment> cancel(int id) async {
    cancelledId = id;
    return Appointment.fromJson(_appointmentJson(
      status: 'cancelled',
      statusLabel: 'Annulé',
      isConfirmable: false,
      isCancellable: false,
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
