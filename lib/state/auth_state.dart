import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/session_store.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// Statut de la session au démarrage et pendant la vie de l'application.
enum AuthStatus { unknown, unauthenticated, authenticated }

/// Session utilisateur : conserve le token, expose l'utilisateur connecté
/// et notifie l'interface à chaque changement.
class AuthState extends ChangeNotifier {
  AuthState({
    required this._api,
    required this._repository,
    required this._store,
  }) {
    // Un 401 signifie que le token a été révoqué : retour à la connexion
    _api.onUnauthenticated = () => forceLogout();
  }

  final ApiClient _api;
  final AuthRepository _repository;
  final SessionStore _store;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Restaure la session enregistrée au lancement de l'application.
  Future<void> restore() async {
    final token = await _store.readToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _api.token = token;
    try {
      _user = await _repository.currentUser();
      _status = AuthStatus.authenticated;
    } catch (_) {
      // Token invalide ou serveur injoignable : session visiteur
      _api.token = null;
      await _store.clear();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);
    await _openSession(result);
  }

  Future<void> register({
    required String name,
    required String email,
    required String gender,
    required String birthDate,
    required String password,
    required String passwordConfirmation,
    required String phone,
  }) async {
    final result = await _repository.register(
      name: name,
      email: email,
      gender: gender,
      birthDate: birthDate,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
    );
    await _openSession(result);
  }

  /// Demande l'envoi d'un code de réinitialisation à l'adresse indiquée.
  ///
  /// La session n'est pas concernée : ce parcours s'adresse à quelqu'un qui
  /// n'arrive justement pas à se connecter. Renvoie le message de l'API, qui
  /// ne dit pas si l'adresse correspond à un compte.
  Future<String> requestPasswordResetCode({required String email}) =>
      _repository.forgotPassword(email: email);

  /// Fixe un nouveau mot de passe à partir du code reçu par e-mail.
  ///
  /// Le serveur révoque toutes les sessions du compte : il reste à se
  /// connecter avec le nouveau mot de passe.
  Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) =>
      _repository.resetPassword(
        email: email,
        code: code,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

  Future<void> _openSession(AuthResult result) async {
    _api.token = result.token;
    _user = result.user;
    await _store.saveToken(result.token);
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Même si l'appel échoue, la session locale est fermée
    }
    await forceLogout();
  }

  Future<void> forceLogout() async {
    _api.token = null;
    _user = null;
    await _store.clear();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    _user = await _repository.updateProfile(fields);
    notifyListeners();
  }

  /// Recharge le profil (ex. après réservation, le téléphone peut changer).
  Future<void> refreshUser() async {
    try {
      _user = await _repository.currentUser();
      notifyListeners();
    } catch (_) {}
  }
}
