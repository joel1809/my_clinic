/// Erreur renvoyée par l'API Laravel.
class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.message, {
    this.errors = const {},
    this.retryAfter,
  });

  final int statusCode;
  final String message;

  /// Erreurs de validation Laravel : champ -> liste de messages (statut 422).
  final Map<String, List<String>> errors;

  /// Délai annoncé par l'en-tête `Retry-After` avant de pouvoir réessayer,
  /// quand le plafond de requêtes est atteint (statut 429).
  final Duration? retryAfter;

  bool get isUnauthenticated => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// Plafond de requêtes atteint : l'API compte les appels par compte
  /// connecté et par adresse IP pour les visiteurs.
  bool get isRateLimited => statusCode == 429;

  /// Premier message de validation pour un champ donné, s'il existe.
  String? firstError(String field) {
    final messages = errors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  /// Message le plus utile à afficher à l'utilisateur.
  String get displayMessage {
    // Le plafond de requêtes répond en anglais (« Too Many Attempts. ») :
    // on lui substitue une phrase lisible, avec le délai s'il est annoncé.
    if (isRateLimited) return _rateLimitMessage;

    if (errors.isNotEmpty) {
      final first = errors.values.first;
      if (first.isNotEmpty) return first.first;
    }
    return message;
  }

  /// Invitation à patienter, formulée en secondes ou en minutes selon le
  /// délai restant.
  String get _rateLimitMessage {
    const prefix = 'Trop de requêtes envoyées.';
    final seconds = retryAfter?.inSeconds ?? 0;

    if (seconds <= 0) {
      return '$prefix Patientez un instant avant de réessayer.';
    }
    if (seconds < 60) {
      return '$prefix Réessayez dans $seconds seconde${seconds > 1 ? 's' : ''}.';
    }

    final minutes = (seconds / 60).ceil();
    return '$prefix Réessayez dans $minutes minute${minutes > 1 ? 's' : ''}.';
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
