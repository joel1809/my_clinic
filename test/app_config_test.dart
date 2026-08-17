import 'package:flutter_test/flutter_test.dart';

import 'package:my_clinic/core/app_config.dart';

/// Sur le poste de test, `AppConfig.baseUrl` vaut l'adresse locale du backend.
const _base = 'http://localhost:8000';

void main() {
  group('AppConfig.baseUrl', () {
    test('joint le backend local, sans slash final', () {
      expect(AppConfig.baseUrl, _base);
      expect(AppConfig.apiUrl, '$_base/api/v1');
    });

    test('ne réclame pas d\'URL explicite hors release', () {
      // Le contrôle ne vaut que pour une build de distribution : les replis de
      // développement restent utilisables sans --dart-define.
      expect(AppConfig.checkConfiguration, returnsNormally);
    });

    test('refuse une build de distribution sans API_BASE_URL', () {
      // La suite s'exécute sans --dart-define : c'est exactement la situation
      // d'un APK release construit sans dire à quel backend il s'adresse. Il
      // ne doit pas démarrer sur le tunnel de développement.
      expect(
        () => AppConfig.checkConfiguration(release: true),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        )),
      );
    });
  });

  group('AppConfig.mediaUri', () {
    test('résout un chemin relatif contre le backend', () {
      expect(
        AppConfig.mediaUri('/storage/documents/ordonnance.pdf?signature=abc')
            ?.toString(),
        '$_base/storage/documents/ordonnance.pdf?signature=abc',
      );
    });

    test('accepte une adresse absolue vers le backend', () {
      expect(
        AppConfig.mediaUri('$_base/storage/documents/scanner.pdf')?.toString(),
        '$_base/storage/documents/scanner.pdf',
      );
    });

    test('refuse un autre hôte', () {
      expect(AppConfig.mediaUri('https://exemple.test/ordonnance.pdf'), isNull);
      // Sans schéma : `resolve` reprend celui du backend, l'hôte change quand même.
      expect(AppConfig.mediaUri('//exemple.test/ordonnance.pdf'), isNull);
      // Hôte du backend placé en information d'utilisateur.
      expect(
        AppConfig.mediaUri('http://localhost:8000@exemple.test/x.pdf'),
        isNull,
      );
    });

    test('refuse un schéma qui n\'ouvrirait pas une page web', () {
      expect(AppConfig.mediaUri('file:///etc/passwd'), isNull);
      expect(AppConfig.mediaUri('intent://exemple.test#Intent;end'), isNull);
    });

    test('refuse une adresse illisible sans lever d\'exception', () {
      expect(AppConfig.mediaUri('http://localhost:8000.exemple.test/x'), isNull);
      expect(AppConfig.mediaUri('http://[oups/x'), isNull);
    });
  });

  group('AppConfig.resolveMediaUrl', () {
    test('ramène une image du backend à l\'hôte joignable', () {
      expect(
        AppConfig.resolveMediaUrl('http://127.0.0.1:8000/storage/logo.png'),
        '$_base/storage/logo.png',
      );
    });

    test('écarte une image hébergée ailleurs', () {
      expect(AppConfig.resolveMediaUrl('https://exemple.test/logo.png'), isNull);
    });

    test('écarte un hôte qui imite seulement celui du backend', () {
      // La réécriture d'hôte ne doit pas valoir autorisation.
      expect(
        AppConfig.resolveMediaUrl('http://localhost:8000.exemple.test/logo.png'),
        isNull,
      );
      expect(
        AppConfig.resolveMediaUrl(
            'https://exemple.test/proxy?u=http://localhost:8000/logo.png'),
        isNull,
      );
    });
  });

  group('AppConfig.linkUri', () {
    // La suite s'exécute sans --dart-define : la liste compilée est vide, et
    // les hôtes tiers sont fournis à l'appel comme le fait une build.
    const partners = {'partenaire.test'};

    test('accepte un lien vers le backend, comme un fichier', () {
      expect(
        AppConfig.linkUri('/rendez-vous')?.toString(),
        '$_base/rendez-vous',
      );
      expect(
        AppConfig.linkUri('$_base/actualites/3')?.toString(),
        '$_base/actualites/3',
      );
    });

    test('accepte un hôte tiers inscrit dans la liste', () {
      expect(
        AppConfig.linkUri('https://partenaire.test/campagne',
                allowedHosts: partners)
            ?.toString(),
        'https://partenaire.test/campagne',
      );
    });

    test('refuse un hôte absent de la liste', () {
      expect(
        AppConfig.linkUri('https://exemple.test/promo', allowedHosts: partners),
        isNull,
      );
    });

    test('n\'étend pas l\'autorisation aux sous-domaines', () {
      // Un sous-domaine oublié ou revendu suffirait sinon à passer.
      expect(
        AppConfig.linkUri('https://promo.partenaire.test/x',
            allowedHosts: partners),
        isNull,
      );
      // Suffixe en trompe-l'œil.
      expect(
        AppConfig.linkUri('https://partenaire.test.exemple.test/x',
            allowedHosts: partners),
        isNull,
      );
    });

    test('refuse un hôte autorisé joint en clair', () {
      expect(
        AppConfig.linkUri('http://partenaire.test/campagne',
            allowedHosts: partners),
        isNull,
      );
    });

    test('refuse un hôte autorisé placé en information d\'utilisateur', () {
      expect(
        AppConfig.linkUri('https://partenaire.test@exemple.test/x',
            allowedHosts: partners),
        isNull,
      );
    });

    test('refuse un schéma qui n\'ouvrirait pas une page web', () {
      for (final forged in [
        'tel:+237600000000',
        'intent://partenaire.test#Intent;end',
        'javascript:alert(1)',
        '//partenaire.test/x',
      ]) {
        expect(AppConfig.linkUri(forged, allowedHosts: partners), isNull,
            reason: forged);
      }
    });
  });

  group('AppConfig.malformedLinkHosts', () {
    test('accepte des noms d\'hôtes nus', () {
      expect(
        AppConfig.malformedLinkHosts('partenaire.test, sante.gouv.test'),
        isEmpty,
      );
      // Liste vide : rien à signaler, aucun hôte tiers autorisé.
      expect(AppConfig.malformedLinkHosts(''), isEmpty);
    });

    test('signale une entrée qui n\'autoriserait rien', () {
      // Chacune paraît juste et laisserait le lien masqué sans explication.
      expect(
        AppConfig.malformedLinkHosts(
            'https://partenaire.test,partenaire.test/promo,'
            'partenaire.test:443,*.partenaire.test,localhost'),
        hasLength(5),
      );
    });
  });
}
