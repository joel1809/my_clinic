import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/user.dart';

/// Résultat d'une connexion ou inscription : token + utilisateur.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;
}

/// Authentification Sanctum : inscription, connexion, profil.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Nom d'appareil rattaché au token Sanctum.
  static String get deviceName =>
      kIsWeb ? 'Navigateur web' : 'Appareil ${Platform.operatingSystem}';

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
      'device_name': deviceName,
    }) as Map<String, dynamic>;

    return AuthResult(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String gender,
    required String birthDate,
    required String password,
    required String passwordConfirmation,
    required String phone,
  }) async {
    final json = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'gender': gender,
      'birth_date': birthDate,
      // Demandé dès l'inscription : la clinique rappelle les patients sur ce
      // numéro, et la prise de rendez-vous l'exige de toute façon.
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': deviceName,
    }) as Map<String, dynamic>;

    return AuthResult(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Demande l'envoi par e-mail d'un code de réinitialisation à six chiffres.
  ///
  /// Le message renvoyé est le même que l'adresse soit inscrite ou non : l'API
  /// ne dit pas qui a un compte, et l'application ne doit pas le laisser
  /// deviner non plus.
  Future<String> forgotPassword({required String email}) async {
    final json = await _api.post('/auth/forgot-password', body: {
      'email': email,
    }) as Map<String, dynamic>;

    return json['message'] as String? ??
        'Si un compte correspond à cette adresse, un code vient de lui être '
            'envoyé par e-mail.';
  }

  /// Fixe un nouveau mot de passe à partir du code reçu par e-mail.
  ///
  /// Le serveur révoque au passage toutes les sessions du compte : il faut se
  /// reconnecter avec le nouveau mot de passe.
  Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final json = await _api.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    }) as Map<String, dynamic>;

    return json['message'] as String? ?? 'Votre mot de passe a été réinitialisé.';
  }

  Future<void> logout() => _api.post('/auth/logout');

  Future<User> currentUser() async {
    final json = await _api.get('/auth/user') as Map<String, dynamic>;
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Seuls les champs non nuls sont transmis (mise à jour partielle).
  Future<User> updateProfile(Map<String, dynamic> fields) async {
    final json =
        await _api.patch('/auth/profile', body: fields) as Map<String, dynamic>;
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }
}
