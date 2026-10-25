// Test-only visual fixtures. Reuses existing synthetic Learning response data.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mimigo_design.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart' as data;

const visualChild = ChildSummary(
  id: data.childId,
  alias: 'SYN-Design',
  dateOfBirth: null,
  ageYears: null,
  createdAt: null,
  withinProgramAgeRange: true,
  state: 'ACTIVE',
  stockAvatarKey: 'bear-blue',
);

CompletionApi visualLearningApi() => CompletionApi()..profiles = [visualChild];

Future<void> loadDesignFonts() async {
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('Baloo2')
        ..addFont(rootBundle.load('assets/fonts/baloo2/Baloo2-Variable.ttf')))
      .load();
  await (FontLoader('Nunito')
        ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
      .load();
}

Widget visualApp(Widget child, {double scale = 1}) => MaterialApp(
  key: UniqueKey(),
  theme: mimiTheme(),
  debugShowCheckedModeBanner: false,
  builder: (context, value) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: value!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: RepaintBoundary(
        key: const Key('publicVisualSurface'),
        child: Column(
          children: [
            Expanded(child: child),
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                'VISUAL TEST / FIXTURE · no network',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
