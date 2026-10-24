import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';

import 'live_auth_test.dart' show tap, waitFor;

Future<void> affirmFreshNotices(WidgetTester tester) async {
  await tap(tester, 'loadAttempt');
  await waitFor(tester, find.byKey(const Key('guardianAssertion')));
  expect(find.byKey(const Key('childDob')), findsNothing);
  for (final element in find.byType(CheckboxListTile).evaluate().toList()) {
    final tile = element.widget as CheckboxListTile;
    expect(tile.value, isFalse);
    await tap(tester, (tile.key! as ValueKey<String>).value);
  }
  await tap(tester, 'privacyContinue');
  await waitFor(tester, find.byKey(const Key('childDob')));
  expect(
    tester
        .widget<TextField>(find.byKey(const Key('childDob')))
        .controller!
        .text,
    isEmpty,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android FIXTURE full parent onboarding, independent children and locked entry',
    (tester) async {
      final api = FixtureMimiGoApi();
      await tester.pumpWidget(
        MimiGoApp(
          api: api,
          configuration: const ApiConfiguration(ApiMode.fixture, 'unused'),
        ),
      );
      await tap(tester, 'welcomeStart');
      await waitFor(tester, find.byKey(const Key('termsCheckbox')));
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await tap(tester, 'termsCheckbox');
      await tap(tester, 'registerSubmit');
      await waitFor(tester, find.byKey(const Key('otpCode')));
      await tester.enterText(find.byKey(const Key('otpCode')), '123456');
      await tap(tester, 'otpVerify');
      await waitFor(tester, find.byKey(const Key('loadAttempt')));
      await tap(tester, 'loadAttempt');
      await waitFor(tester, find.byKey(const Key('guardianAssertion')));
      await tap(tester, 'privacyDecline');
      expect(await api.listChildren(), isEmpty);
      await tap(tester, 'refusalParentHome');
      await waitFor(tester, find.byKey(const Key('addChild')));
      await tap(tester, 'addChild');
      await affirmFreshNotices(tester);
      await tester.enterText(
        find.byKey(const Key('childName')),
        'SYN-Fixture-One',
      );
      await tester.enterText(find.byKey(const Key('childDob')), '2023-01-01');
      await tap(tester, 'avatar-bee-yellow');
      await tap(tester, 'childContinue');
      await tap(tester, 'createChild');
      await waitFor(tester, find.byKey(const Key('createdChildAlias')));
      expect(find.byType(ChildHome), findsNothing);
      await tap(tester, 'createdAddAnother');
      await affirmFreshNotices(tester);
      await tester.enterText(
        find.byKey(const Key('childName')),
        'SYN-Fixture-Outside',
      );
      await tester.enterText(find.byKey(const Key('childDob')), '2000-02-29');
      await tap(tester, 'childContinue');
      await tap(tester, 'createChild');
      await waitFor(tester, find.byKey(const Key('createdChildAlias')));
      expect(
        find.textContaining('outside the program age range'),
        findsOneWidget,
      );
      await tap(tester, 'createdParentHome');
      await waitFor(tester, find.text('SYN-Fixture-Outside'));
      await tester.ensureVisible(find.text('SYN-Fixture-Outside'));
      await tester.tap(find.text('SYN-Fixture-Outside'));
      await waitFor(tester, find.byKey(const Key('parentEnterLearning')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('parentEnterLearning')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'parentChooseAnother');
      await waitFor(tester, find.text('SYN-Fixture-One'));
      await tester.ensureVisible(find.text('SYN-Fixture-One'));
      await tester.tap(find.text('SYN-Fixture-One'));
      await tap(tester, 'parentEnterLearning');
      await waitFor(tester, find.text('Hi, SYN-Fixture-One!'));
      for (final key in ['childSwitchGate', 'childParentGate']) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull,
        );
      }
      expect(find.text('SYN-Fixture-Outside'), findsNothing);
      await tap(tester, 'openCurriculum');
      await waitFor(tester, find.byKey(const Key('explorerEmpty')));
      await tap(tester, 'explorerHome');
      await tap(tester, 'returnAccountEntry');
      await tap(tester, 'confirmAccountEntry');
      await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
      debugPrint(
        'R0 ANDROID FIXTURE ONBOARDING PASS: explicit Terms, verification, refusal, independent children, leap-day profile, age entry block and fail-closed Parent controls. Memory-only mock; no Backend or legal approval.',
      );
    },
  );
}
