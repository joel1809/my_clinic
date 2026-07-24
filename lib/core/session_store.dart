import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage local du token Sanctum entre deux lancements.
///
/// Le token est conservé dans le stockage sécurisé de la plateforme
/// (Keystore Android / Keychain iOS), chiffré au repos — et non dans les
/// SharedPreferences, lisibles en clair sur un appareil compromis.
class SessionStore {
  static const _tokenKey = 'auth_token';

  static const _storage = FlutterSecureStorage();

  Future<String?> readToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) return token;

    // Migration : les anciennes versions stockaient le token en clair dans
    // les SharedPreferences. On le déplace vers le stockage sécurisé.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null) {
      await _storage.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
    }
    return legacy;
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
