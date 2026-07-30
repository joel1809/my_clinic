import '../core/api_client.dart';
import '../models/popup.dart';

/// Pop-ups informationnels diffusés par la clinique.
class PopupRepository {
  PopupRepository(this._api);

  final ApiClient _api;

  /// Pop-up à afficher au démarrage de l'application, ou null si aucun
  /// n'est actuellement diffusé.
  Future<Popup?> current() async {
    final json = await _api.get('/popups/current') as Map<String, dynamic>;
    final data = json['data'];
    return data is Map<String, dynamic> ? Popup.fromJson(data) : null;
  }
}
