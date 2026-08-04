import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/branding.dart';
import '../repositories/branding_repository.dart';
import '../theme.dart';

/// Identité visuelle appliquée à l'application : logos et couleurs de la
/// clinique, tels qu'administrés sur le site.
///
/// La charte reçue est conservée localement et rechargée avant le premier
/// écran : l'application démarre donc déjà aux couleurs de la clinique, sans
/// attendre le réseau. Elle est ensuite revalidée en tâche de fond avec
/// l'ETag renvoyé par l'API, qui répond 304 tant que rien n'a changé.
class BrandingState extends ChangeNotifier {
  BrandingState(this._repository, {EvictImage? evictImage})
      : _evictImage = evictImage ?? CachedNetworkImage.evictFromCache;

  static const _brandingKey = 'branding_payload';
  static const _etagKey = 'branding_etag';

  final BrandingRepository _repository;

  /// Purge d'une image du cache disque, injectable pour les tests.
  final EvictImage _evictImage;

  Branding? _branding;
  String? _etag;

  Branding? get branding => _branding;

  /// Empreinte de la charte appliquée, ou `null` tant que l'application
  /// utilise les couleurs par défaut de son système de design.
  String? get version => _branding?.version;

  /// Nom de la clinique, avec repli sur le nom de l'application.
  String get siteName {
    final name = _branding?.siteName;
    return (name == null || name.isEmpty) ? 'Medolia' : name;
  }

  /// Relit la dernière charte connue. À appeler avant le premier rendu pour
  /// que l'application s'ouvre directement aux bonnes couleurs.
  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();

    _etag = prefs.getString(_etagKey);
    final payload = prefs.getString(_brandingKey);
    if (payload == null) return;

    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return;
      _apply(Branding.fromJson(json));
    } on FormatException {
      // Cache illisible (format d'une ancienne version) : on repart de zéro.
      await prefs.remove(_brandingKey);
      await prefs.remove(_etagKey);
    }
  }

  /// Revalide la charte auprès de l'API.
  ///
  /// Sans effet visible si rien n'a changé (304) ; en cas de panne réseau, la
  /// charte en cache reste en place — l'identité visuelle n'est jamais un
  /// motif d'erreur affichée à l'utilisateur.
  Future<void> refresh() async {
    try {
      final result = await _repository.fetch(etag: _etag);
      if (result == null) return;

      final previous = _branding;
      final next = result.branding;

      _etag = result.etag;
      if (previous?.version == next.version) {
        // Même charte, ETag renouvelé : rien à reconstruire.
        await _persist();
        return;
      }

      // Un logo peut être remplacé sans changer de nom de fichier : le cache
      // d'images garderait alors l'ancienne version indéfiniment.
      await _evictImages(previous);
      await _evictImages(next);

      _apply(next);
      await _persist();
      notifyListeners();
    } catch (_) {
      // Hors ligne ou API indisponible : on garde la charte connue.
    }
  }

  void _apply(Branding branding) {
    _branding = branding;
    AppPalette.applyBrand(
      primary: branding.primaryColor,
      heading: branding.headingColor,
      text: branding.textColor,
    );
  }

  Future<void> _persist() async {
    final branding = _branding;
    if (branding == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandingKey, jsonEncode(branding.toJson()));

    final etag = _etag;
    if (etag == null) {
      await prefs.remove(_etagKey);
    } else {
      await prefs.setString(_etagKey, etag);
    }
  }

  Future<void> _evictImages(Branding? branding) async {
    for (final url in branding?.imageUrls ?? const <String>[]) {
      try {
        // Un cache d'images récalcitrant ne doit pas retenir la nouvelle
        // charte : au pire l'ancien logo reste affiché jusqu'au prochain
        // lancement.
        await _evictImage(url).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }
}

/// Purge d'une image du cache disque.
typedef EvictImage = Future<bool> Function(String url);
