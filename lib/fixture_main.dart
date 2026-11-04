// Explicit regression entry only. Never selected by lib/main.dart or a mode define.
import 'package:flutter/material.dart';

import 'main.dart';
import 'mimigo_design.dart';

void main() {
  registerMimiFontLicenses();
  runApp(
    const MimiGoApp(configuration: ApiConfiguration(ApiMode.fixture, 'unused')),
  );
}
