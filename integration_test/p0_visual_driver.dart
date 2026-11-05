import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final phase = Platform.environment['MIMIGO_VISUAL_PHASE'] ?? 'after';
    if (!['before', 'after'].contains(phase) ||
        !RegExp(r'^pilot_[a-z_]+$').hasMatch(name) ||
        bytes.length < 1000)
      return false;
    final directory = Directory('reports/evidence/visual_p0/$phase');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
    return true;
  },
  responseDataCallback: (data) async {
    final timing = data?['frameTiming'];
    final phase = Platform.environment['MIMIGO_VISUAL_PHASE'] ?? 'after';
    if (timing is Map && ['before', 'after'].contains(phase)) {
      final directory = Directory('reports/evidence/visual_p0/$phase');
      await directory.create(recursive: true);
      await File('${directory.path}/frame_timing.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(timing)}\n',
      );
    }
  },
);
