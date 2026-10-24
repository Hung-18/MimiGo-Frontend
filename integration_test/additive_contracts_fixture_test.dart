import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';

import '../test/additive_onboarding_contract_test.dart' show EntryApi;
import '../test/parent_home_test.dart' show profile;
import 'live_auth_test.dart' show tap, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android MOCK AVAILABLE catalog cannot override PERMISSION_NOT_GRANTED learningEntry',
    (tester) async {
      final api = EntryApi()
        ..profiles = [profile('A')]
        ..entry = 'PERMISSION_NOT_GRANTED';
      await tester.pumpWidget(
        MimiGoApp(
          api: api,
          configuration: const ApiConfiguration(ApiMode.fixture, 'unused'),
        ),
      );
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(
        find.byKey(const Key('signInEmail')),
        'synthetic@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('signInPassword')),
        'synthetic-test-pass',
      );
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.byKey(const Key('parent-child-A')));
      await tap(tester, 'parent-child-A');
      await waitFor(tester, find.byKey(const Key('parentLearningEntry')));
      expect(
        find.textContaining('Eligible Free lessons available'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Learning entry is not permitted'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('parentEnterLearning')))
            .onPressed,
        isNull,
      );
      expect(find.byType(ChildHome), findsNothing);
      expect(find.textContaining('SECRET HISTORY'), findsNothing);
      expect(find.textContaining('PROTECTED-SESSION'), findsNothing);
      expect(
        api.calls.where(
          (c) => c.startsWith('curriculum:') || c.startsWith('lessons:'),
        ),
        isEmpty,
      );
      debugPrint(
        'ADDITIVE ANDROID MOCK PASS: permission-denied learningEntry blocks entry despite available catalog; no protected history or learning calls. Explicit synthetic double; no live permission mutation.',
      );
    },
  );
}
