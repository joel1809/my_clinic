import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_clinic/core/api_client.dart';
import 'package:my_clinic/core/api_exception.dart';

/// Client dont chaque requête renvoie la réponse fournie.
ApiClient clientReturning(String body, int status, {String? contentType}) =>
    ApiClient(
      httpClient: MockClient((_) async => http.Response(
            body,
            status,
            headers: {'content-type': contentType ?? 'application/json'},
          )),
    );

void main() {
  test('réponse HTML (tunnel arrêté) : NetworkException, pas une erreur brute',
      () async {
    final api = clientReturning(
      '<!DOCTYPE html><html><body>Tunnel not found</body></html>',
      404,
      contentType: 'text/html',
    );

    await expectLater(
      api.post('/auth/login'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('erreur de validation : message de l\'API conservé', () async {
    final api = clientReturning(
      jsonEncode({
        'message': 'Identifiants invalides.',
        'errors': {
          'email': ['Ces identifiants ne correspondent à aucun compte.']
        },
      }),
      422,
    );

    try {
      await api.post('/auth/login');
      fail('une ApiException était attendue');
    } on ApiException catch (e) {
      expect(e.statusCode, 422);
      expect(e.isValidation, isTrue);
      expect(
        e.displayMessage,
        'Ces identifiants ne correspondent à aucun compte.',
      );
    }
  });

  test('réponse JSON valide : corps décodé', () async {
    final api = clientReturning(jsonEncode({'token': 'abc'}), 200);

    final json = await api.post('/auth/login') as Map<String, dynamic>;
    expect(json['token'], 'abc');
  });

  test('corps vide sur succès : null', () async {
    final api = clientReturning('', 204);

    expect(await api.delete('/auth/logout'), isNull);
  });
}
