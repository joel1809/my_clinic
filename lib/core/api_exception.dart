/// Erreur renvoyée par l'API Laravel.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.errors = const {}});

  final int statusCode;
  final String message;

  /// Erreurs de validation Laravel : champ -> liste de messages (statut 422).
  final Map<String, List<String>> errors;

  bool get isUnauthenticated => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// Premier message de validation pour un champ donné, s'il existe.
  String? firstError(String field) {
    final messages = errors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  /// Message le plus utile à afficher à l'utilisateur.
  String get displayMessage {
    if (errors.isNotEmpty) {
      final first = errors.values.first;
      if (first.isNotEmpty) return first.first;
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Le serveur est injoignable (réseau coupé, backend arrêté...).
class NetworkException implements Exception {
  const NetworkException();

  @override
  String toString() =>
      'Impossible de joindre le serveur. Vérifiez votre connexion.';
}
