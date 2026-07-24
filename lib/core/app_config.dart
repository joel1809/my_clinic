import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuration de l'application : URL du backend Laravel.
///
/// L'URL peut être surchargée au lancement :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
class AppConfig {
  AppConfig._();

  static const String _defined = String.fromEnvironment('API_BASE_URL');

  /// Domaine statique ngrok : tunnel HTTPS stable vers le backend local
  /// (php artisan serve sur le PC). L'URL ne change pas d'un lancement à
  /// l'autre, donc l'APK reste valable même hors du réseau Wi-Fi du PC.
  /// Lancer côté PC : ngrok http --domain=CE-DOMAINE 8000
  static const String _ngrokUrl =
      'https://delusion-obedient-banister.ngrok-free.dev';

  /// URL de base du backend (sans slash final).
  static String get baseUrl {
    if (_defined.isNotEmpty) return _defined;

    // Téléphone physique : passe par le tunnel ngrok public (HTTPS),
    // indépendant de l'IP locale du PC et du réseau. Surchargeable via
    // --dart-define=API_BASE_URL=http://<ip>:8000 pour un test en Wi-Fi local.
    if (!kIsWeb && Platform.isAndroid) return _ngrokUrl;

    // Bureau / web : backend joint en direct sur la même machine.
    return 'http://localhost:8000';
  }

  /// Racine de l'API v1.
  static String get apiUrl => '$baseUrl/api/v1';

  /// Les images renvoyées par l'API pointent vers APP_URL du backend
  /// (localhost) : on les réécrit vers l'hôte joignable depuis l'appareil.
  static String resolveMediaUrl(String url) {
    return url
        .replaceFirst('http://localhost:8000', baseUrl)
        .replaceFirst('http://127.0.0.1:8000', baseUrl);
  }
}
