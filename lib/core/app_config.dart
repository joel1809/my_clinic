import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuration de l'application : URL du backend Laravel.
///
/// L'URL se fournit au lancement :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
///
/// Elle est facultative en développement — des replis pratiques prennent le
/// relais — et **obligatoire** dès qu'on construit en `--release`, y compris
/// pour un APK de test (voir [checkConfiguration]).
class AppConfig {
  AppConfig._();

  static const String _defined = String.fromEnvironment('API_BASE_URL');

  /// Domaine statique ngrok : tunnel HTTPS stable vers le backend local
  /// (php artisan serve sur le PC). L'URL ne change pas d'un lancement à
  /// l'autre, donc l'application reste joignable même hors du réseau Wi-Fi
  /// du PC. Lancer côté PC : ngrok http --domain=CE-DOMAINE 8000
  ///
  /// Réservé au développement, et jamais un repli en release : le tunnel
  /// déchiffre le trafic qui le traverse et aboutit à un poste de
  /// développement. Une application distribuée qui l'emprunterait ferait
  /// transiter dossiers médicaux et jetons de session par un tiers, quelles
  /// que soient les précautions prises par ailleurs sur l'appareil.
  static const String _devTunnelUrl =
      'https://delusion-obedient-banister.ngrok-free.dev';

  /// URL de base du backend (sans slash final).
  static String get baseUrl {
    if (_defined.isNotEmpty) return _withoutTrailingSlash(_defined);

    // Aucune URL fournie : en release c'est un défaut de construction, jamais
    // un motif de repli. [checkConfiguration] le signale au démarrage ; ce
    // garde-fou couvre les chemins qui ne passeraient pas par elle.
    if (kReleaseMode) throw StateError(_missingUrlMessage);

    // Téléphone physique : passe par le tunnel de développement (HTTPS),
    // indépendant de l'IP locale du PC et du réseau. Surchargeable via
    // --dart-define=API_BASE_URL=http://<ip>:8000 pour un test en Wi-Fi local.
    if (!kIsWeb && Platform.isAndroid) return _devTunnelUrl;

    // Bureau / web : backend joint en direct sur la même machine.
    return 'http://localhost:8000';
  }

  /// Racine de l'API v1.
  static String get apiUrl => '$baseUrl/api/v1';

  /// Vérifie, avant le premier écran, que l'application sait à quel backend
  /// s'adresser. Sans effet hors release.
  ///
  /// Une build de distribution doit désigner explicitement un backend HTTPS :
  /// à défaut, elle partirait avec le tunnel de développement (voir
  /// [_devTunnelUrl]). L'échec est volontairement immédiat et bruyant — une
  /// erreur de construction ne doit pas se déguiser en panne réseau, où elle
  /// passerait inaperçue jusque chez les patients.
  ///
  /// [release] n'est là que pour les tests, qui s'exécutent toujours en mode
  /// débogage : les appelants s'en remettent au mode de compilation.
  static void checkConfiguration({bool release = kReleaseMode}) {
    if (!release) return;

    if (_defined.isEmpty) throw StateError(_missingUrlMessage);

    if (Uri.tryParse(_defined)?.scheme != 'https') {
      throw StateError(
        'API_BASE_URL doit être une adresse HTTPS pour une build de '
        'distribution (reçu : $_defined).',
      );
    }
  }

  static const String _missingUrlMessage =
      'API_BASE_URL est obligatoire pour une build de distribution.\n'
      'Construire avec :\n'
      '  flutter build apk --release '
      '--dart-define=API_BASE_URL=https://api.exemple.test';

  /// Slash final toléré dans la valeur fournie : les chemins de l'API
  /// commencent tous par « / ».
  static String _withoutTrailingSlash(String url) =>
      url.replaceFirst(RegExp(r'/+$'), '');

  /// Construit l'adresse d'un fichier servi par le backend, et refuse tout ce
  /// qui pointerait ailleurs.
  ///
  /// Le chemin provient de l'API. Sans cette vérification, une réponse forgée
  /// ou un backend compromis pourrait faire ouvrir à l'utilisateur une adresse
  /// choisie par l'attaquant — voire, avec un schéma comme `intent://` ou
  /// `file://`, déclencher autre chose qu'une page web.
  ///
  /// Renvoie `null` si l'adresse obtenue sort de l'hôte du backend.
  static Uri? mediaUri(String path) {
    final base = Uri.parse(baseUrl);
    // Adresse illisible (port invalide, caractères interdits) : `tryParse`
    // rend `null` là où `Uri.parse` lèverait, et la lecture de la réponse ne
    // doit pas échouer sur une adresse mal formée.
    final parsed = Uri.tryParse(_reachableHost(path));
    if (parsed == null) return null;

    // `resolveUri` accepte un chemin relatif comme une URL absolue ; dans le
    // second cas l'hôte change, et la comparaison ci-dessous le rejette.
    final uri = base.resolveUri(parsed);

    if (uri.scheme != base.scheme ||
        uri.host != base.host ||
        uri.port != base.port) {
      return null;
    }
    return uri;
  }

  /// Adresse d'une image renvoyée par l'API, ramenée à l'hôte joignable depuis
  /// l'appareil — ou `null` si elle désigne un autre hôte.
  ///
  /// Les images passent par le même contrôle que les documents : elles sont
  /// chargées, et mises en cache sur disque, sans intervention de
  /// l'utilisateur. Une réponse forgée ferait sinon émettre à l'application une
  /// requête vers l'hôte de son choix.
  static String? resolveMediaUrl(String url) => mediaUri(url)?.toString();

  /// Les images renvoyées par l'API pointent vers APP_URL du backend
  /// (localhost) : on les réécrit vers l'hôte joignable depuis l'appareil.
  ///
  /// La réécriture ne vaut pas autorisation : `mediaUri` vérifie ensuite
  /// l'hôte obtenu, ce qui écarte les adresses où « localhost:8000 »
  /// n'apparaît qu'en trompe-l'œil (`http://localhost:8000.exemple.test`,
  /// `https://exemple.test/?u=http://localhost:8000`).
  static String _reachableHost(String url) => url
      .replaceFirst('http://localhost:8000', baseUrl)
      .replaceFirst('http://127.0.0.1:8000', baseUrl);
}
