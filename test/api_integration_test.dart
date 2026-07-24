@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/repositories/appointment_repository.dart';
import 'package:my_clinic/repositories/article_repository.dart';
import 'package:my_clinic/repositories/auth_repository.dart';
import 'package:my_clinic/repositories/catalog_repository.dart';

/// Test d'intégration contre l'API réelle : nécessite le backend démarré
/// (php artisan serve) et sa base de données accessible.
///
///   flutter test --tags integration test/api_integration_test.dart
///
/// Il crée un compte patient jetable et un rendez-vous immédiatement annulé.
void main() {
  final api = ApiClient();
  final auth = AuthRepository(api);
  final catalog = CatalogRepository(api);
  final appointments = AppointmentRepository(api);
  final articles = ArticleRepository(api);

  test('parcours complet : compte, catalogue, réservation, annulation',
      () async {
    // Inscription d'un patient jetable
    final email =
        'flutter.test.${DateTime.now().millisecondsSinceEpoch}@example.com';
    final result = await auth.register(
      name: 'Test Flutter',
      email: email,
      gender: 'male',
      birthDate: '1995-01-15',
      password: 'Password!123',
      passwordConfirmation: 'Password!123',
      phone: '+221770000000',
    );
    expect(result.token, isNotEmpty);
    expect(result.user.role, 'patient');
    api.token = result.token;

    // Catalogue public
    final specialties = await catalog.specialties();
    expect(specialties, isNotEmpty);

    final doctors = await catalog.doctors(specialtyId: specialties.first.id);
    final allDoctors = await catalog.doctors();
    expect(allDoctors, isNotEmpty);
    final doctor = (doctors.isNotEmpty ? doctors : allDoctors).first;

    final detail = await catalog.doctor(doctor.id);
    expect(detail.fullName, doctor.fullName);

    // Articles publics
    final page = await articles.list();
    if (page.items.isNotEmpty) {
      final article = await articles.show(page.items.first.slug);
      expect(article.body, isNotNull);
    }

    // Disponibilités puis réservation + annulation si possible
    final days = await catalog.days(detail.id);
    final openDay = days.where((d) => d.available).firstOrNull;
    if (openDay != null) {
      final slots = await catalog.slots(detail.id, openDay.date);
      final openSlot = slots.where((s) => s.available).firstOrNull;
      if (openSlot != null && detail.specialty != null) {
        final booked = await appointments.book(
          specialtyId: detail.specialty!.id,
          doctorId: detail.id,
          scheduledDate: openDay.date,
          startTime: openSlot.start,
          phone: '+221770000000',
          reason: 'Test automatique — annulé aussitôt.',
        );
        expect(booked.status, 'pending');

        final list = await appointments.list();
        expect(list.items.map((a) => a.id), contains(booked.id));

        final shown = await appointments.show(booked.id);
        expect(shown.isCancellable, isTrue);

        final cancelled = await appointments.cancel(booked.id);
        expect(cancelled.status, 'cancelled');
      }
    }

    // Profil et déconnexion
    final me = await auth.currentUser();
    expect(me.email, email);

    final updated = await auth.updateProfile({'address': 'Adresse de test'});
    expect(updated.patient?.address, 'Adresse de test');

    await auth.logout();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
