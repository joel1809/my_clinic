import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuration de l'application : URL du backend Laravel.
///
/// L'URL peut être surchargée au lancement :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
class AppConfig {
  AppConfig._();

  static const String _defined = String.fromEnvironment('API_BASE_URL');

  /// URL de base du backend (sans slash final).
  static String get baseUrl {
    if (_defined.isNotEmpty) return _defined;

    // Téléphone physique : le backend est joint via l'IP locale du PC
    // sur le même réseau Wi-Fi. Si l'IP du PC change, mettez-la à jour ici
    // ou lancez avec --dart-define=API_BASE_URL=http://<nouvelle-ip>:8000
    if (!kIsWeb && Platform.isAndroid) return 'http://192.168.1.24:8000';

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
