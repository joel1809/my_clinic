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

  /// Hôtes tiers vers lesquels un lien renvoyé par l'API a le droit de pointer,
  /// en plus du backend. Séparés par des virgules, fournis à la construction :
  ///   --dart-define=ALLOWED_LINK_HOSTS=partenaire.test,sante.gouv.test
  ///
  /// La liste est compilée dans l'application, jamais reçue de l'API — c'est
  /// tout son intérêt. Une liste servie par le backend ne protégerait de rien :
  /// la réponse qui désigne l'hôte à ouvrir désignerait aussi les hôtes
  /// autorisés à l'être.
  static const String _allowedLinkHosts =
      String.fromEnvironment('ALLOWED_LINK_HOSTS');

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

    final malformed = malformedLinkHosts();
    if (malformed.isNotEmpty) {
      throw StateError(
        'ALLOWED_LINK_HOSTS n\'accepte que des noms d\'hôtes nus, séparés par '
        'des virgules — « partenaire.test », sans schéma, port ni chemin '
        '(reçu : ${malformed.join(', ')}).',
      );
    }
  }

  /// Entrées d'[_allowedLinkHosts] qui ne sont pas des noms d'hôtes nus.
  ///
  /// Une entrée mal formée n'autorise rien — [allowedLinkHosts] l'écarte — mais
  /// elle trahit une intention déçue : « https://partenaire.test » ne couvre
  /// pas partenaire.test, et le lien resterait masqué sans qu'on sache
  /// pourquoi. [checkConfiguration] en fait donc une erreur de construction.
  ///
  /// [value] n'est là que pour les tests, qui ne peuvent pas fournir de
  /// `--dart-define` ; les appelants s'en remettent à la liste compilée.
  static Iterable<String> malformedLinkHosts([String value = _allowedLinkHosts]) =>
      _splitHosts(value).where((entry) => !_isBareHost(entry));

  /// Hôtes tiers autorisés, en minuscules.
  static Set<String> get allowedLinkHosts =>
      _splitHosts(_allowedLinkHosts).where(_isBareHost).toSet();

  static Iterable<String> _splitHosts(String value) => value
      .split(',')
      .map((entry) => entry.trim().toLowerCase())
      .where((entry) => entry.isNotEmpty);

  /// Un nom d'hôte nu : des étiquettes alphanumériques séparées par des points,
  /// au moins deux. Ni schéma, ni port, ni chemin, ni joker.
  ///
  /// La comparaison se fait ensuite sur l'égalité exacte : « partenaire.test »
  /// n'ouvre pas « promo.partenaire.test », qu'un sous-domaine oublié ou
  /// revendu suffirait sinon à faire passer.
  static bool _isBareHost(String entry) => RegExp(
        r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$',
      ).hasMatch(entry);

  static const String _missingUrlMessage =
      'API_BASE_URL est obligatoire pour une build de distribution.\n'
      'Construire avec :\n'
      '  flutter build apk --release '
      '--dart-define=API_BASE_URL=https://api.exemple.test';

  /// Slash final toléré dans la valeur fournie : les chemins de l'API
  /// commencent tous par « / ».
  static String _withoutTrailingSlash(String url) =>
      url.replaceFirst(RegExp(r'/+$'), '');

  /// Construit l'adresse d'une ressource servie par le backend — fichier joint,
  /// image, page vers laquelle un lien pointe — et refuse tout ce qui
  /// pointerait ailleurs.
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

  /// Construit l'adresse d'un lien renvoyé par l'API — le bouton d'un pop-up —
  /// ou `null` si elle ne mène ni au backend, ni à un hôte inscrit dans
  /// [allowedLinkHosts].
  ///
  /// Un lien s'ouvre d'un tap dans le navigateur du téléphone, sur un patient
  /// qui vient d'ouvrir l'application de sa clinique : c'est une position de
  /// confiance dont une réponse forgée ferait un hameçonnage crédible. Le
  /// contrôle porte donc sur l'hôte, et la liste des hôtes tiers est fixée à
  /// la construction plutôt que reçue avec la réponse.
  ///
  /// [allowedHosts] n'est là que pour les tests, qui ne peuvent pas fournir de
  /// `--dart-define` ; les appelants s'en remettent à la liste compilée.
  static Uri? linkUri(String url, {Set<String>? allowedHosts}) {
    final pinned = mediaUri(url);
    if (pinned != null) return pinned;

    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) return null;

    // Hors backend, seul HTTPS : le contrôle d'hôte ne dit rien de qui répond
    // au bout d'une liaison en clair. `hasAuthority` écarte au passage les
    // formes sans hôte (« https:/promo »), dont `host` serait vide.
    if (parsed.scheme != 'https' || !parsed.hasAuthority) return null;

    return allowedLinkHosts.union(allowedHosts ?? const {}).contains(parsed.host)
        ? parsed
        : null;
  }

  /// Adresse d'un lien renvoyé par l'API, ou `null` s'il pointe ailleurs que
  /// vers un hôte autorisé. Voir [linkUri].
  static String? resolveLinkUrl(String url, {Set<String>? allowedHosts}) =>
      linkUri(url, allowedHosts: allowedHosts)?.toString();

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
