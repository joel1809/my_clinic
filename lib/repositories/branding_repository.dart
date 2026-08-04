import '../core/api_client.dart';
import '../models/branding.dart';

/// Identité visuelle de la clinique exposée par l'API (`GET /branding`).
class BrandingRepository {
  BrandingRepository(this._api);

  final ApiClient _api;

  /// Charte courante accompagnée de son ETag, ou `null` si le serveur répond
  /// 304 : l'identité détenue localement est encore la bonne.
  Future<({Branding branding, String? etag})?> fetch({String? etag}) async {
    final response = await _api.getIfChanged('/branding', etag: etag);
    if (response == null) return null;

    final json = response.body as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;

    return (branding: Branding.fromJson(data), etag: response.etag);
  }
}
