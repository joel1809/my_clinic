// Reprend l'identité visuelle du site dans les images embarquées de
// l'application : les logos de repli et surtout l'icône de lancement, celle
// qui apparaît dans la liste des applications du téléphone.
//
// L'icône fait partie du paquet installé : contrairement aux logos affichés
// dans l'application, elle ne peut pas suivre l'API à chaud. Il faut la
// régénérer puis reconstruire l'APK / l'IPA. Ce script automatise la première
// moitié :
//
//   dart run tool/update_brand_assets.dart
//   dart run tool/update_brand_assets.dart --url=http://192.168.100.12:8000
//
// Puis reconstruire l'application (flutter build apk, ou `flutter run`).
//
// Le backend doit être joignable (php artisan serve).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Côté de l'icône de lancement, taille attendue par flutter_launcher_icons.
const _iconSize = 1024;

/// Part de l'image d'avant-plan occupée par l'emblème (icône adaptative
/// Android). Le générateur applique par-dessus une marge de 16 % et le
/// système rogne les bords avec son masque (cercle, écusson…) : l'emblème
/// occupe au final près de 62 % de l'icône, soit la zone sûre du centre.
const _foregroundScale = .90;

/// Part occupée sur l'icône classique, qui n'est pas rognée.
const _iconScale = .84;

Future<void> main(List<String> args) async {
  final baseUrl = _option(args, 'url') ?? 'http://localhost:8000';

  stdout.writeln('Identité visuelle : $baseUrl/api/v1/branding');

  final Map<String, dynamic> branding;
  try {
    branding = await _fetchBranding(baseUrl);
  } catch (e) {
    stderr.writeln('Échec : $e');
    stderr.writeln('Le backend est-il démarré (php artisan serve) ?');
    exit(1);
  }

  final siteName = branding['site_name'];
  if (siteName is String && siteName.isNotEmpty) {
    stdout.writeln('Clinique : $siteName');
  }

  // Logos de repli : affichés le temps que l'API réponde, et au tout premier
  // lancement hors ligne. Ils doivent donc être ceux du site.
  await _download(baseUrl, branding['logo_url'], 'assets/images/logo.png');
  await _download(
      baseUrl, branding['logo_dark_url'], 'assets/images/logo_white.png');

  // Icône de lancement : l'emblème carré du site (favicon), à défaut le logo.
  final emblem = await _read(
      baseUrl, branding['favicon_url'] ?? branding['logo_url'], 'emblème');

  _writeIcon(emblem, 'assets/icon/icon.png',
      scale: _iconScale, background: img.ColorRgba8(255, 255, 255, 255));
  _writeIcon(emblem, 'assets/icon/icon_foreground.png',
      scale: _foregroundScale);

  stdout.writeln(
    '\nIl reste à générer les icônes natives puis à reconstruire :\n'
    '  dart run flutter_launcher_icons\n'
    '  flutter run   (ou flutter build apk)',
  );
}

Future<Map<String, dynamic>> _fetchBranding(String baseUrl) async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/v1/branding'),
    headers: const {
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    },
  ).timeout(const Duration(seconds: 20));

  if (response.statusCode != 200) {
    throw 'l\'API a répondu ${response.statusCode}';
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return (json['data'] as Map).cast<String, dynamic>();
}

/// Télécharge une image de la charte et l'enregistre telle quelle.
Future<void> _download(String baseUrl, Object? url, String path) async {
  final bytes = await _fetchBytes(baseUrl, url, path);
  if (bytes == null) return;

  File(path).writeAsBytesSync(bytes);
  stdout.writeln('✓ $path (${(bytes.length / 1024).round()} Ko)');
}

/// Télécharge et décode une image de la charte.
Future<img.Image> _read(String baseUrl, Object? url, String label) async {
  final bytes = await _fetchBytes(baseUrl, url, label);
  final decoded = bytes == null ? null : img.decodePng(bytes);

  if (decoded == null) throw 'image illisible ($label)';
  return decoded;
}

/// Argument de la forme `--nom=valeur`.
String? _option(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

Future<Uint8List?> _fetchBytes(String baseUrl, Object? url, String label) async {
  if (url is! String || url.isEmpty) {
    stderr.writeln('… $label : aucune image dans la charte, ignoré');
    return null;
  }

  // Les adresses renvoyées pointent vers l'APP_URL du backend, qui n'est pas
  // forcément l'hôte joignable depuis ce poste.
  final resolved = url
      .replaceFirst('http://localhost:8000', baseUrl)
      .replaceFirst('http://127.0.0.1:8000', baseUrl);

  final response = await http.get(
    Uri.parse(resolved),
    headers: const {'ngrok-skip-browser-warning': 'true'},
  ).timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw '$label : téléchargement impossible (${response.statusCode})';
  }
  return response.bodyBytes;
}

/// Dessine l'emblème centré sur un carré de 1024 px.
void _writeIcon(
  img.Image emblem,
  String path, {
  required double scale,
  img.Color? background,
}) {
  final canvas = img.Image(width: _iconSize, height: _iconSize, numChannels: 4);
  if (background != null) {
    img.fill(canvas, color: background);
  }

  final box = (_iconSize * scale).round();
  final ratio = emblem.width / emblem.height;
  final width = ratio >= 1 ? box : (box * ratio).round();
  final height = ratio >= 1 ? (box / ratio).round() : box;

  final resized = img.copyResize(
    emblem,
    width: width,
    height: height,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    canvas,
    resized,
    dstX: ((_iconSize - width) / 2).round(),
    dstY: ((_iconSize - height) / 2).round(),
  );

  File(path).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('✓ $path ($_iconSize×$_iconSize)');
}
