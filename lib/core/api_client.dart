import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'app_config.dart';

/// Client HTTP vers l'API Laravel : en-têtes JSON, token Sanctum,
/// décodage des réponses et conversion des erreurs en exceptions typées.
class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Token Sanctum de la session courante (null si visiteur).
  String? token;

  /// Appelé quand l'API répond 401 : permet de forcer la déconnexion.
  void Function()? onUnauthenticated;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // Évite la page d'avertissement HTML de ngrok (plan gratuit) qui,
        // sinon, remplacerait le JSON attendu. Sans effet hors ngrok.
        'ngrok-skip-browser-warning': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiUrl}$path')
          .replace(queryParameters: query?.isEmpty ?? true ? null : query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  /// GET conditionnel : joint l'[etag] détenu localement et renvoie `null`
  /// quand le serveur répond 304, c'est-à-dire quand ce que l'application a
  /// déjà en cache est encore à jour (aucune charge utile retéléchargée).
  Future<ConditionalResponse?> getIfChanged(
    String path, {
    String? etag,
  }) async {
    final response = await _perform(() => _http.get(
          _uri(path),
          headers: {
            ..._headers,
            if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
          },
        ));

    if (response.statusCode == HttpStatus.notModified) return null;

    return ConditionalResponse(
      _decode(response),
      etag: response.headers['etag'],
    );
  }

  Future<dynamic> post(String path, {Object? body}) => _send(() =>
      _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, {Object? body}) => _send(() =>
      _http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async =>
      _decode(await _perform(request));

  /// Exécute la requête et ramène toute panne de transport (tunnel coupé,
  /// Wi-Fi perdu, délai dépassé) à une [NetworkException].
  Future<http.Response> _perform(
      Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const NetworkException();
    } on HttpException {
      throw const NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const NetworkException();
    }
  }

  /// Corps décodé d'une réponse, ou exception typée si l'API a refusé.
  dynamic _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Réponse non-JSON : page HTML d'un proxy (tunnel arrêté), portail
      // Wi-Fi captif, erreur serveur brute... L'API n'a pas répondu.
      throw const NetworkException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      onUnauthenticated?.call();
    }

    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final errors = <String, List<String>>{};
    if (map['errors'] is Map<String, dynamic>) {
      (map['errors'] as Map<String, dynamic>).forEach((field, messages) {
        errors[field] = (messages as List).map((m) => m.toString()).toList();
      });
    }

    // Plafond de requêtes de l'API : le serveur annonce le délai d'attente
    // en secondes, que le message affiché reprend.
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');

    throw ApiException(
      response.statusCode,
      (map['message'] as String?) ?? 'Une erreur est survenue (${response.statusCode}).',
      errors: errors,
      retryAfter: retryAfter == null ? null : Duration(seconds: retryAfter),
    );
  }
}

/// Réponse d'un GET conditionnel : le corps décodé et l'ETag à renvoyer au
/// prochain appel pour obtenir un 304 tant que rien n'a changé.
class ConditionalResponse {
  const ConditionalResponse(this.body, {this.etag});

  final dynamic body;
  final String? etag;
}
