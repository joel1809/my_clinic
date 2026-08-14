import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/models/popup.dart';

Map<String, dynamic> _json({Object? storageKey, Object? imageUrl}) => {
      'id': 7,
      'title': 'Campagne de vaccination',
      'content': '<p>Ouverture du centre <strong>lundi</strong>.</p>',
      'frequency': 'once',
      'image_url': imageUrl,
      'storage_key': storageKey,
    };

void main() {
  group('Popup.storageKey', () {
    test('reprend l\'empreinte de version renvoyée par l\'API', () {
      final popup = Popup.fromJson(_json(storageKey: 'popup-7-a1b2c3'));

      expect(popup.storageKey, 'popup-7-a1b2c3');
      expect(popup.storageKey, startsWith(popup.storagePrefix));
    });

    test('confine une clé forgée sous le préfixe du pop-up', () {
      // Sans cela, l'API choisirait l'entrée des préférences à écraser.
      for (final forged in ['auth_token', 'branding_payload', '../auth_token']) {
        final popup = Popup.fromJson(_json(storageKey: forged));

        expect(popup.storageKey, startsWith('popup-7-'));
        expect(popup.storageKey, isNot(contains('..')));
      }
    });

    test('garde une clé exploitable quand l\'empreinte manque', () {
      expect(Popup.fromJson(_json()).storageKey, 'popup-7-v');
      expect(Popup.fromJson(_json(storageKey: '!!!')).storageKey, 'popup-7-v');
    });

    test('borne la longueur de la clé', () {
      final popup = Popup.fromJson(_json(storageKey: 'a' * 500));

      expect(popup.storageKey, 'popup-7-${'a' * 64}');
    });
  });

  group('Popup.fromJson', () {
    test('écarte une illustration hébergée hors du backend', () {
      final popup = Popup.fromJson(_json(imageUrl: 'https://exemple.test/x.png'));

      expect(popup.imageUrl, isNull);
    });

    test('garde une illustration du backend', () {
      final popup = Popup.fromJson(
          _json(imageUrl: 'http://localhost:8000/storage/popups/x.png'));

      expect(popup.imageUrl, endsWith('/storage/popups/x.png'));
    });

    test('rend le contenu lisible en texte brut', () {
      expect(Popup.fromJson(_json()).plainContent,
          'Ouverture du centre lundi.');
    });
  });
}
