import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_content.dart';

import 'live_auth_test.dart' show waitFor, tap;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android fixture categories, local shape feedback and secure account return',
    (tester) async {
      // Seed a process-memory fixture account only; the UI still authenticates it.
      final api = FixtureMimiGoApi();
      final ref = await api.onboardingReference();
      await api.register(
        Registration(
          'fixture@example.test',
          'synthetic-pass',
          'SYN Parent',
          ref.terms!.id,
          true,
        ),
      );
      await api.verifyMockEmail(email: 'fixture@example.test', otp: '123456');
      await api.login(
        email: 'fixture@example.test',
        password: 'synthetic-pass',
      );
      final attempt = await api.beginOnboardingAttempt();
      await api.createChild(
        CreateChildRequest(
          attemptId: attempt.id,
          idempotencyKey: 'fixture-child-nav',
          childAlias: 'SYN-Bee',
          dateOfBirth: DateTime(2022, 10, 21),
          guardianAffirmed: true,
          purposeChoices: attempt.notices
              .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
              .toList(),
        ),
      );
      await tester.pumpWidget(
        MimiGoApp(
          api: api,
          configuration: const ApiConfiguration(ApiMode.fixture, 'unused'),
        ),
      );
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(
        find.byKey(const Key('signInEmail')),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('signInPassword')),
        'synthetic-pass',
      );
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.text('SYN-Bee'));
      await tester.tap(find.text('SYN-Bee'));
      await waitFor(tester, find.byKey(const Key('parentEnterLearning')));
      await tap(tester, 'parentEnterLearning');
      await waitFor(tester, find.text('Hi, SYN-Bee!'));
      for (final category in LearningCategory.values) {
        await tap(tester, 'category-${category.name}');
        if (category == LearningCategory.logic) {
          await waitFor(tester, find.byKey(const Key('openCircleDemo')));
          await tap(tester, 'openCircleDemo');
          await waitFor(tester, find.byType(CircleDemo));
          expect(find.byKey(const Key('demoLabel')), findsOneWidget);
          await tap(tester, 'demoTriangle');
          expect(
            find.text('Try again: a triangle has three sides.'),
            findsOneWidget,
          );
          await tap(tester, 'demoCircle');
          expect(
            find.text('Nice noticing! A circle is round.'),
            findsOneWidget,
          );
          await tester.binding.handlePopRoute();
          await waitFor(tester, find.byKey(const Key('openCircleDemo')));
        } else {
          await waitFor(tester, find.byKey(const Key('categoryEmpty')));
        }
        await tap(tester, 'categoryBack');
        await waitFor(tester, find.text('Hi, SYN-Bee!'));
      }
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'returnAccountEntry');
      await tap(tester, 'confirmAccountEntry');
      await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
      await expectLater(
        api.parentMe(),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'local auth cleared',
            'UNAUTHENTICATED',
          ),
        ),
      );
      debugPrint(
        'VS023 ANDROID FIXTURE CHILD NAV PASS: Logic demo; five empty categories; no remote content or progress.',
      );
    },
  );
}
