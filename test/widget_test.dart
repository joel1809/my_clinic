import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/models/appointment.dart';
import 'package:my_clinic/models/article.dart';
import 'package:my_clinic/models/doctor.dart';
import 'package:my_clinic/models/paginated.dart';
import 'package:my_clinic/models/user.dart';

void main() {
  group('Modèles API', () {
    test('User.fromJson lit le profil patient imbriqué', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Awa Diop',
        'email': 'awa@example.com',
        'phone': '+221 77 000 00 00',
        'role': 'patient',
        'patient': {
          'id': 4,
          'gender': 'female',
          'birth_date': '1990-05-12',
          'address': 'Dakar',
        },
      });

      expect(user.name, 'Awa Diop');
      expect(user.patient?.gender, 'female');
      expect(user.patient?.genderLabel, 'Femme');
    });

    test('Appointment.fromJson lit le médecin et le statut', () {
      // Demain, pour que le rendez-vous reste « à venir » quel que soit le
      // jour où le test s'exécute.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date = '${tomorrow.year}-'
          '${tomorrow.month.toString().padLeft(2, '0')}-'
          '${tomorrow.day.toString().padLeft(2, '0')}';

      final appointment = Appointment.fromJson({
        'id': 10,
        'scheduled_date': date,
        'start_time': '09:00',
        'end_time': '09:30',
        'reason': 'Contrôle annuel',
        'status': 'pending',
        'status_label': 'En attente',
        'is_cancellable': true,
        'doctor': {
          'id': 2,
          'full_name': 'Dr Ndiaye',
          'appointment_duration': 30,
          'specialty': {
            'id': 3,
            'name': 'Cardiologie',
            'slug': 'cardiologie',
          },
        },
      });

      expect(appointment.isUpcoming, isTrue);
      expect(appointment.isCancellable, isTrue);
      expect(appointment.doctor?.fullName, 'Dr Ndiaye');
      expect(appointment.doctor?.specialty?.name, 'Cardiologie');
    });

    test('Paginated.fromJson lit la pagination Laravel', () {
      final page = Paginated.fromJson({
        'data': [
          {'id': 1, 'full_name': 'Dr A', 'appointment_duration': 20},
          {'id': 2, 'full_name': 'Dr B', 'appointment_duration': 30},
        ],
        'meta': {'current_page': 1, 'last_page': 3},
      }, Doctor.fromJson);

      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
    });

    test('Article.plainBody nettoie le HTML basique', () {
      final article = Article.fromJson({
        'id': 1,
        'title': 'Bien dormir',
        'slug': 'bien-dormir',
        'body': '<p>Premier paragraphe.</p><p>Second &amp; dernier.</p>',
      });

      expect(article.plainBody, 'Premier paragraphe.\n\nSecond & dernier.');
    });
  });
}
