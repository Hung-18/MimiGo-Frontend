import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_onboarding.dart';
import 'package:mimigo_frontend/parent_home.dart';

import 'child_onboarding_test.dart'
    show ChildApi, openChildOnboarding, affirmNotices, reviewChild;
import 'sign_in_test.dart' show openSignIn, fillSignIn, submitSignIn;
import 'learning_widget_test.dart' show tapVisible;

ChildSummary serverProfile(String id, {bool eligible = true, int age = 3}) =>
    ChildSummary(
      id: id,
      alias: 'SYN-$id',
      dateOfBirth: DateTime(2023, 1, 1),
      ageYears: age,
      withinProgramAgeRange: eligible,
      state: 'ACTIVE',
      createdAt: DateTime(2030),
    );

void main() {
  testWidgets(
    'invalid or today DOB and oversized alias never leave the child form',
    (tester) async {
      ChildDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildInput(back: () {}, next: (value) => draft = value),
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('childName')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byKey(const Key('childName')), 'SYN-Entered');
      for (final value in [
        '2023-02-29',
        '2024-2-29',
        dateText(vietnamToday()),
      ]) {
        await tester.enterText(find.byKey(const Key('childDob')), value);
        await tapVisible(tester, 'childContinue');
        expect(draft, isNull);
        expect(find.byKey(const Key('safeError')), findsOneWidget);
      }
      await tester.enterText(find.byKey(const Key('childDob')), '2024-02-29');
      await tester.enterText(
        find.byKey(const Key('childName')),
        'SYN-${List.filled(40, 'X').join()}',
      );
      await tapVisible(tester, 'childContinue');
      expect(draft, isNull);
    },
  );

  testWidgets(
    'profile form and predefined avatars remain usable on a narrow screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ChildDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ChildInput(back: () {}, next: (value) => draft = value),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('childName')), 'SYN-Entered');
      await tester.enterText(find.byKey(const Key('childDob')), '2024-02-29');
      await tapVisible(tester, 'avatar-bee-yellow');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('avatar-bee-yellow')))
            .selected,
        isTrue,
      );
      await tapVisible(tester, 'childContinue');
      expect(draft!.avatar, 'bee-yellow');
      expect(draft!.dob, DateTime(2024, 2, 29));
      expect(tester.takeException(), isNull);
    },
  );

  test('Vietnam date boundary and strict leap-day/DOB limits follow the documented calendar', () {
    expect(
      vietnamToday(DateTime.utc(2026, 10, 23, 16, 59)),
      DateTime(2026, 10, 23),
    );
    expect(
      vietnamToday(DateTime.utc(2026, 10, 23, 17)),
      DateTime(2026, 10, 24),
    );
    expect(parseDate('2023-02-29'), isNull);
    expect(parseDate('2024-2-29'), isNull);
    expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
    expect(
      acceptableChildDob(DateTime(1900, 1, 1), DateTime(2026, 10, 24)),
      isTrue,
    );
    expect(
      acceptableChildDob(DateTime(1899, 12, 31), DateTime(2026, 10, 24)),
      isFalse,
    );
    expect(
      acceptableChildDob(DateTime(2026, 10, 24), DateTime(2026, 10, 24)),
      isFalse,
    );
    expect(
      acceptableChildDob(DateTime(2026, 10, 25), DateTime(2026, 10, 24)),
      isFalse,
    );
    expect(productAge(DateTime(2020, 2, 29), DateTime(2025, 2, 28)), 4);
    expect(productAge(DateTime(2020, 2, 29), DateTime(2025, 3, 1)), 5);
  });

  for (final status in [
    'PERMISSION_NOT_GRANTED',
    'CHILD_NOT_ACTIVE',
    'CHILD_OUTSIDE_PROGRAM_AGE',
    'UNKNOWN',
  ]) {
    test(
      '$status cannot enter Child Mode despite a selectable profile',
      () async {
        final api = ChildApi()..profiles = [serverProfile('A')];
        final model = ParentHomeState(api)
          ..seedWorkspace(
            ParentWorkspace([
              WorkspaceChildMetadata(api.profiles.single, status, 'READY'),
            ], 'Synthetic'),
          );
        await model.choose('A');
        expect(model.canEnter, isFalse);
        model.dispose();
      },
    );
  }

  test(
    'entry trusts server eligibility flag rather than recomputing age from DOB',
    () async {
      final api = ChildApi()
        ..profiles = [
          serverProfile('A', eligible: false),
          serverProfile('B', age: 99),
        ];
      final model = ParentHomeState(api)
        ..seedWorkspace(
          ParentWorkspace(
            api.profiles
                .map(
                  (child) =>
                      WorkspaceChildMetadata(child, 'AVAILABLE', 'READY'),
                )
                .toList(),
            'Synthetic',
          ),
        );
      await model.choose('A');
      expect(model.canEnter, isFalse);
      await model.choose('B');
      expect(model.selected!.ageYears, 99);
      expect(
        model.canEnter,
        isTrue,
        reason: 'The returned Boolean and authenticated metadata decide eligibility; no client age policy overrides them.',
      );
      model.dispose();
    },
  );

  testWidgets(
    'additional child starts independently and both owned identities survive roster selection',
    (tester) async {
      final api = ChildApi();
      await openChildOnboarding(tester, api);
      await affirmNotices(tester);
      await reviewChild(tester, alias: 'SYN-First');
      await tapVisible(tester, 'createChild');
      await tapVisible(tester, 'createdAddAnother');
      await tapVisible(tester, 'loadAttempt');
      expect(api.attempts, 2);
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(tile.value, isFalse);
      }
      expect(find.byKey(const Key('childDob')), findsNothing);
      await affirmNotices(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('childDob')))
            .controller!
            .text,
        isEmpty,
      );
      await reviewChild(tester, alias: 'SYN-Second', dob: '2024-02-29');
      await tapVisible(tester, 'createChild');
      await tapVisible(tester, 'createdParentHome');
      expect(find.text('SYN-First'), findsOneWidget);
      expect(find.text('SYN-Second'), findsOneWidget);
      expect(api.requests[0].attemptId, isNot(api.requests[1].attemptId));
      expect(
        api.requests[0].idempotencyKey,
        isNot(api.requests[1].idempotencyKey),
      );
      await tapVisible(tester, 'parent-child-child-1');
      expect(find.text('Đã chọn: SYN-First'), findsOneWidget);
      await tapVisible(tester, 'parentChooseAnother');
      await tapVisible(tester, 'parent-child-child-2');
      expect(find.text('Đã chọn: SYN-Second'), findsOneWidget);
      await tapVisible(tester, 'parentEnterLearning');
      expect(find.text('Hi, SYN-Second!'), findsOneWidget);
      await tapVisible(tester, 'openCurriculum');
      expect(api.calls.last, 'curriculum:child-2');
      expect(api.calls, isNot(contains('curriculum:child-1')));
    },
  );

  testWidgets(
    'ineligible profile stays manageable without Child Mode or unauthorized lesson calls',
    (tester) async {
      final api = ChildApi()
        ..profiles = [serverProfile('Outside', eligible: false, age: 10)];
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      expect(
        find.textContaining('Ngoài độ tuổi của chương trình'),
        findsOneWidget,
      );
      await tapVisible(tester, 'parent-child-Outside');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('parentEnterLearning')))
            .onPressed,
        isNull,
      );
      expect(find.byType(ChildHome), findsNothing);
      expect(
        api.calls.where(
          (call) =>
              call.startsWith('curriculum:') || call.startsWith('lessons:'),
        ),
        isEmpty,
      );
      await tapVisible(tester, 'addChild');
      expect(find.byKey(const Key('loadAttempt')), findsOneWidget);
    },
  );

  testWidgets(
    'Child Mode exposes locked switch control and no PIN or sibling profile bypass',
    (tester) async {
      final api = ChildApi()
        ..profiles = [serverProfile('A'), serverProfile('B')];
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      await tapVisible(tester, 'parent-child-A');
      await tapVisible(tester, 'parentEnterLearning');
      for (final key in ['childSwitchGate', 'childParentGate']) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull,
        );
      }
      expect(find.text('SYN-B'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('addChild')), findsNothing);
      expect(find.textContaining('2023-01-01'), findsNothing);
      await tapVisible(tester, 'returnAccountEntry');
      await tapVisible(tester, 'confirmAccountEntry');
      expect(find.byType(ParentArea), findsNothing);
      expect(find.byKey(const Key('welcomeSignIn')), findsOneWidget);
    },
  );

  test('fixture preserves seven independent profiles, age boundaries and exact creation replay', () async {
    final api = FixtureMimiGoApi();
    final reference = await api.onboardingReference();
    await api.register(
      Registration(
        'multi@example.test',
        'synthetic-test-pass',
        'SYN Parent',
        reference.terms!.id,
        true,
      ),
    );
    await expectLater(
      api.login(email: 'multi@example.test', password: 'synthetic-test-pass'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED'),
      ),
    );
    await api.verifyMockEmail(email: 'multi@example.test', otp: '123456');
    await api.login(
      email: 'multi@example.test',
      password: 'synthetic-test-pass',
    );
    for (var index = 0; index < 7; index++) {
      final attempt = await api.beginOnboardingAttempt();
      final request = CreateChildRequest(
        attemptId: attempt.id,
        idempotencyKey: 'synthetic-child-$index',
        childAlias: 'SYN-$index',
        dateOfBirth: DateTime(2000, 2, 29),
        guardianAffirmed: true,
        purposeChoices: attempt.notices
            .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
            .toList(),
      );
      final child = await api.createChild(request);
      expect(child.withinProgramAgeRange, isFalse);
      expect((await api.createChild(request)).id, child.id);
    }
    expect((await api.listChildren()).map((c) => c.id).toSet(), hasLength(7));
    final deniedAttempt = await api.beginOnboardingAttempt();
    await expectLater(
      api.createChild(
        CreateChildRequest(
          attemptId: deniedAttempt.id,
          idempotencyKey: 'synthetic-denied',
          childAlias: 'SYN-Denied',
          dateOfBirth: DateTime(2023),
          guardianAffirmed: true,
          purposeChoices: [],
        ),
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CORE_PERMISSION_REQUIRED',
        ),
      ),
    );
    expect(await api.listChildren(), hasLength(7));
  });
}
