import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    // Acceptance here means capture integrity only. Reference comparison and
    // PARTIAL/BLOCKED decisions are recorded separately, never inferred here.
    if (!RegExp(r'^public_[0-9]+x[0-9]+_[A-Za-z0-9_]+$').hasMatch(name) ||
        bytes.length < 1000 ||
        bytes[0] != 137 ||
        bytes[1] != 80 ||
        bytes[2] != 78 ||
        bytes[3] != 71)
      return false;
    final directory = Directory('reports/evidence/ui_fidelity');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
    return true;
  },
  responseDataCallback: (_) async {},
);
