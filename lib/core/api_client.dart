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

  Future<dynamic> post(String path, {Object? body}) => _send(() =>
      _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, {Object? body}) => _send(() =>
      _http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const NetworkException();
    } on HttpException {
      throw const NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const NetworkException();
    }

    final dynamic decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

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

    throw ApiException(
      response.statusCode,
      (map['message'] as String?) ?? 'Une erreur est survenue (${response.statusCode}).',
      errors: errors,
    );
  }
}
