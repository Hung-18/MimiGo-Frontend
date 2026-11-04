import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^r2_[a-z_]+$').hasMatch(name) || bytes.length < 1000)
      return false;
    final directory = Directory('reports/evidence/mobile_r2');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
    return true;
  },
  responseDataCallback: (_) async {},
);
