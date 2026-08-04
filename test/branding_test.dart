import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/models/branding.dart';
import 'package:my_clinic/repositories/branding_repository.dart';
import 'package:my_clinic/state/branding_state.dart';
import 'package:my_clinic/theme.dart';

/// Charge utile de `GET /api/v1/branding`.
Map<String, dynamic> payload({
  String version = 'v1',
  String primary = '#0EA5E9',
  String logo = 'http://localhost:8000/storage/settings/logo.png',
}) =>
    {
      'data': {
        'site_name': 'Clinique du Plateau',
        'logo_url': logo,
        'logo_dark_url': 'http://localhost:8000/storage/settings/logo-blanc.png',
        'favicon_url': 'http://localhost:8000/storage/settings/favicon.png',
        'logo_height': 32,
        'logo_dark_height': null,
        'colors': {
          'primary': primary,
          'heading': '#111827',
          'text': '#374151',
        },
        'version': version,
        'updated_at': '2026-08-01T10:00:00+00:00',
      },
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Repart de la charte par défaut : la palette est un état global.
    AppPalette.applyBrand();
  });

  group('Branding', () {
    test('lit les logos et les couleurs de la charte', () {
      final branding = Branding.fromJson(payload()['data']!);

      expect(branding.siteName, 'Clinique du Plateau');
      expect(branding.logoUrl, endsWith('/storage/settings/logo.png'));
      expect(branding.logoHeight, 32);
      expect(branding.logoDarkHeight, isNull);
      expect(branding.primaryColor, const Color(0xFF0EA5E9));
      expect(branding.headingColor, const Color(0xFF111827));
      expect(branding.version, 'v1');
      expect(branding.updatedAt, isNotNull);
    });

    test('ignore une couleur mal formée', () {
      final data = payload()['data'] as Map<String, dynamic>;
      (data['colors'] as Map<String, dynamic>)['primary'] = 'rouge vif';

      expect(Branding.fromJson(data).primaryColor, isNull);
    });

    test('accepte la forme courte #ABC', () {
      expect(Branding.parseHexColor('#0AF'), const Color(0xFF00AAFF));
    });

    test('se relit à l\'identique depuis le cache', () {
      final original = Branding.fromJson(payload()['data']!);
      final restored = Branding.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(restored.siteName, original.siteName);
      expect(restored.logoUrl, original.logoUrl);
      expect(restored.logoHeight, original.logoHeight);
      expect(restored.primaryColor, original.primaryColor);
      expect(restored.version, original.version);
    });
  });

  group('GET conditionnel', () {
    test('joint l\'ETag détenu et renvoie null sur 304', () async {
      String? sentEtag;
      final api = ApiClient(httpClient: MockClient((request) async {
        sentEtag = request.headers['If-None-Match'];
        return http.Response('', 304);
      }));

      expect(await api.getIfChanged('/branding', etag: '"abc"'), isNull);
      expect(sentEtag, '"abc"');
    });

    test('renvoie le corps et l\'ETag de la réponse', () async {
      final api = ApiClient(httpClient: MockClient((_) async => http.Response(
            jsonEncode(payload()),
            200,
            headers: {'content-type': 'application/json', 'etag': '"v1"'},
          )));

      final response = await api.getIfChanged('/branding');

      expect(response, isNotNull);
      expect(response!.etag, '"v1"');
      expect((response.body as Map)['data'], isA<Map>());
    });
  });

  group('BrandingState', () {
    /// Adresses purgées du cache d'images par le test en cours.
    late List<String> evicted;

    setUp(() => evicted = []);

    /// État branché sur une API qui répond selon [handler] ; le cache
    /// d'images est simulé (ses plugins n'existent pas sous `flutter test`).
    BrandingState stateWith(
            Future<http.Response> Function(http.Request) handler) =>
        BrandingState(
          BrandingRepository(ApiClient(httpClient: MockClient(handler))),
          evictImage: (url) async {
            evicted.add(url);
            return true;
          },
        );

    test('applique la charte reçue à la palette et la met en cache', () async {
      final state = stateWith((_) async => http.Response(
            jsonEncode(payload()),
            200,
            headers: {'content-type': 'application/json', 'etag': '"v1"'},
          ));

      await state.refresh();

      expect(AppPalette.primary, const Color(0xFF0EA5E9));
      expect(AppPalette.ink, const Color(0xFF111827));
      expect(state.siteName, 'Clinique du Plateau');

      // Un nouveau démarrage retrouve la charte sans réseau.
      AppPalette.applyBrand();
      final restored = stateWith((_) async => http.Response('', 500));
      await restored.loadCached();

      expect(AppPalette.primary, const Color(0xFF0EA5E9));
      expect(restored.version, 'v1');
    });

    test('renvoie l\'ETag mémorisé et conserve la charte sur 304', () async {
      var calls = 0;
      String? sentEtag;
      final state = stateWith((request) async {
        calls++;
        sentEtag = request.headers['If-None-Match'];
        return calls == 1
            ? http.Response(
                jsonEncode(payload()),
                200,
                headers: {'content-type': 'application/json', 'etag': '"v1"'},
              )
            : http.Response('', 304);
      });

      await state.refresh();
      await state.refresh();

      expect(sentEtag, '"v1"');
      expect(state.version, 'v1');
      expect(AppPalette.primary, const Color(0xFF0EA5E9));
    });

    test('adopte la nouvelle charte quand la version change', () async {
      var calls = 0;
      final state = stateWith((_) async {
        calls++;
        return http.Response(
          jsonEncode(calls == 1
              ? payload()
              : payload(version: 'v2', primary: '#B91C1C')),
          200,
          headers: {'content-type': 'application/json', 'etag': '"v$calls"'},
        );
      });

      await state.refresh();
      var notified = 0;
      state.addListener(() => notified++);
      await state.refresh();

      expect(state.version, 'v2');
      expect(AppPalette.primary, const Color(0xFFB91C1C));
      expect(notified, 1);
      // Les images de l'ancienne et de la nouvelle charte sont purgées : un
      // logo peut être remplacé sous le même nom de fichier.
      expect(evicted, contains(endsWith('/storage/settings/logo.png')));
    });

    test('hors ligne : la charte en cache reste en place', () async {
      SharedPreferences.setMockInitialValues({
        'branding_payload': jsonEncode(
            Branding.fromJson(payload()['data']!).toJson()),
        'branding_etag': '"v1"',
      });

      final state = stateWith((_) async => throw const SocketExceptionStub());
      await state.loadCached();
      await state.refresh();

      expect(state.version, 'v1');
      expect(AppPalette.primary, const Color(0xFF0EA5E9));
    });

    test('sans charte : les couleurs du système de design sont conservées',
        () async {
      final state = stateWith((_) async => http.Response('', 500));

      await state.loadCached();
      await state.refresh();

      expect(state.branding, isNull);
      expect(AppPalette.primary, AppPalette.defaultPrimary);
      expect(AppPalette.ink, AppPalette.defaultInk);
      expect(state.siteName, 'Medolia');
    });
  });
}

/// Panne réseau simulée (le client HTTP lève avant toute réponse).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
