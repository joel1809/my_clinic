import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Pilote des captures d'écran : reçoit les images prises sur le téléphone et
/// les enregistre dans `captures/` à la racine du projet.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? _]) async {
      final file = File('captures/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('capture → ${file.path} (${bytes.length ~/ 1024} Ko)');
      return true;
    },
  );
}
