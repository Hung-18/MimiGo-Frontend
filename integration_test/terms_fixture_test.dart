import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/terms_reacceptance.dart';

import '../test/terms_reacceptance_test.dart' show TermsApi, termsVersion;
import 'live_auth_test.dart' show tap, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android MOCK Terms requirement, explicit acceptance and separate child consent',
    (tester) async {
      final api = TermsApi();
      await tester.pumpWidget(
        MimiGoApp(
          api: api,
          configuration: const ApiConfiguration(ApiMode.fixture, 'unused'),
        ),
      );
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(
        find.byKey(const Key('signInEmail')),
        'synthetic-parent@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('signInPassword')),
        'synthetic-test-pass',
      );
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.byKey(const Key('addChild')));
      expect(find.byType(TermsReacceptance), findsNothing);
      expect(api.referenceCalls, 0);
      await tap(tester, 'addChild');
      await tap(tester, 'loadAttempt');
      await waitFor(tester, find.byKey(const Key('reacceptTermsCheckbox')));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('reacceptTermsCheckbox')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('reacceptTermsSubmit')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'reacceptTermsCheckbox');
      await tap(tester, 'reacceptTermsSubmit');
      await waitFor(tester, find.byKey(const Key('loadAttempt')));
      expect(api.acceptRequests, [(termsVersion, true)]);
      expect(api.createCalls, 0);
      await tap(tester, 'loadAttempt');
      await waitFor(tester, find.byKey(const Key('guardianAssertion')));
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      ))
        expect(tile.value, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
      debugPrint(
        'S2 TERMS ANDROID MOCK PASS: 422 requirement; explicit version acceptance; parent verification; no automatic child consent. No live Backend used.',
      );
    },
  );
}
