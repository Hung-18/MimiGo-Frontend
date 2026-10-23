import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/child_content.dart';
import 'package:mimigo_frontend/main.dart';

import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;

class ControlledContent implements ChildContentSource {
  final pending = <Completer<List<DemoLesson>>>[];
  @override
  Future<List<DemoLesson>> loadCategory(LearningCategory category) {
    final request = Completer<List<DemoLesson>>();
    pending.add(request);
    return request.future;
  }
}

class SessionApi extends AuthApi {
  int cleared = 0;
  bool signedIn = false;
  @override
  Future<LoginSession> login({
    required String email,
    required String password,
  }) async {
    final session = await super.login(email: email, password: password);
    signedIn = true;
    return session;
  }

  @override
  void clearSession() {
    cleared++;
    signedIn = false;
    super.clearSession();
  }

  @override
  Future<ParentSummary> parentMe() async {
    if (!signedIn)
      throw const ApiFailure(
        'Sign in again.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    return super.parentMe();
  }
}

ChildSummary child() => ChildSummary(
  id: 'child-1',
  alias: 'SYN-Bee',
  dateOfBirth: DateTime(2022, 10, 21),
  ageYears: 4,
  withinProgramAgeRange: true,
  state: 'ACTIVE',
  createdAt: DateTime(2026),
);

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<SessionApi> openChild(
  WidgetTester tester, {
  bool fixture = false,
}) async {
  final api = SessionApi()..profiles = [child()];
  if (fixture) {
    await tester.pumpWidget(
      MimiGoApp(
        api: api,
        configuration: const ApiConfiguration(ApiMode.fixture, 'unused'),
      ),
    );
    await tapKey(tester, 'welcomeSignIn');
  } else {
    await openSignIn(tester, api);
  }
  await fillSignIn(tester);
  await submitSignIn(tester);
  await tester.ensureVisible(find.text('SYN-Bee'));
  await tester.tap(find.text('SYN-Bee'));
  await tester.pumpAndSettle();
  await tapKey(tester, 'parentEnterLearning');
  return api;
}

void main() {
  for (final category in LearningCategory.values) {
    testWidgets(
      'live ${category.label} opens an honest empty state and returns to Child Mode',
      (tester) async {
        final api = await openChild(tester);
        final calls = List<String>.of(api.calls);
        await tapKey(tester, 'category-${category.name}');
        expect(find.byKey(const Key('categoryEmpty')), findsOneWidget);
        expect(
          find.textContaining(
            category == LearningCategory.math
                ? 'No eligible Free Math'
                : 'current live service',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('openCircleDemo')), findsNothing);
        expect(find.byType(CircleDemo), findsNothing);
        expect(
          api.calls,
          category == LearningCategory.math
              ? [...calls, 'lessons:child-1']
              : calls,
          reason: 'Only Math requests the verified child-scoped catalog.',
        );
        await tapKey(tester, 'categoryBack');
        expect(find.text('Hi, SYN-Bee!'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'fixture Logic opens the original local game with feedback and back navigation',
    (tester) async {
      final api = await openChild(tester, fixture: true);
      final calls = List<String>.of(api.calls);
      await tapKey(tester, 'category-logic');
      expect(find.byKey(const Key('demoLabel')), findsOneWidget);
      await tapKey(tester, 'openCircleDemo');
      expect(find.byType(CircleDemo), findsOneWidget);
      expect(
        find.textContaining('No learning progress is saved or sent'),
        findsOneWidget,
      );
      await tapKey(tester, 'demoTriangle');
      expect(
        find.text('Try again: a triangle has three sides.'),
        findsOneWidget,
      );
      await tapKey(tester, 'demoCircle');
      expect(find.text('Nice noticing! A circle is round.'), findsOneWidget);
      await tapKey(tester, 'demoBack');
      expect(find.byKey(const Key('openCircleDemo')), findsOneWidget);
      await tapKey(tester, 'openCircleDemo');
      expect(find.byKey(const Key('gameFeedback')), findsNothing);
      await tapKey(tester, 'demoHome');
      expect(find.text('Hi, SYN-Bee!'), findsOneWidget);
      expect(
        api.calls,
        calls,
        reason: 'Demo feedback is never sent as progress.',
      );
    },
  );

  testWidgets('other fixture categories do not invent lessons', (tester) async {
    await openChild(tester, fixture: true);
    for (final category in LearningCategory.values.where(
      (value) => value != LearningCategory.logic,
    )) {
      await tapKey(tester, 'category-${category.name}');
      expect(find.byKey(const Key('categoryEmpty')), findsOneWidget);
      expect(find.byKey(const Key('openCircleDemo')), findsNothing);
      expect(find.byKey(const Key('demoLabel')), findsOneWidget);
      await tapKey(tester, 'categoryBack');
    }
  });

  testWidgets(
    'category loading, safe error, retry and empty result keep navigation available',
    (tester) async {
      final source = ControlledContent();
      var wentBack = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CategoryContent(
                  category: LearningCategory.logic,
                  source: source,
                  fixture: true,
                  openDemo: () {},
                ),
                TextButton(
                  onPressed: () => wentBack = true,
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Back'));
      expect(wentBack, isTrue);
      source.pending.single.completeError(
        Exception('internal diagnostic must not leak'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('categoryError')), findsOneWidget);
      expect(find.textContaining('internal diagnostic'), findsNothing);
      await tester.tap(find.byKey(const Key('categoryRetry')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.pending.last.complete([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('categoryEmpty')), findsOneWidget);
    },
  );

  testWidgets('late content completion cannot replace a newer category', (
    tester,
  ) async {
    final source = ControlledContent();
    Widget screen(LearningCategory category) => MaterialApp(
      home: Scaffold(
        body: CategoryContent(
          category: category,
          source: source,
          fixture: true,
          openDemo: () {},
        ),
      ),
    );
    await tester.pumpWidget(screen(LearningCategory.logic));
    await tester.pumpWidget(screen(LearningCategory.math));
    source.pending.first.complete([DemoLesson.findTheCircle]);
    await tester.pump();
    expect(find.byKey(const Key('openCircleDemo')), findsNothing);
    source.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No fixture lessons are available for Math.'),
      findsOneWidget,
    );
  });

  testWidgets('live category rejects a mistakenly supplied demo source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryContent(
            category: LearningCategory.logic,
            source: const FixtureChildContentSource(),
            fixture: false,
            openDemo: () => fail('Live mode must never open fixture content.'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryEmpty')), findsOneWidget);
    expect(find.byKey(const Key('openCircleDemo')), findsNothing);
  });

  testWidgets(
    'system Back returns through demo/category and cannot reveal Parent Area',
    (tester) async {
      await openChild(tester, fixture: true);
      await tapKey(tester, 'category-logic');
      await tapKey(tester, 'openCircleDemo');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('openCircleDemo')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hi, SYN-Bee!'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirmAccountEntry')), findsOneWidget);
      await tapKey(tester, 'cancelAccountEntry');
      expect(find.byType(ParentArea), findsNothing);
    },
  );

  testWidgets(
    'account entry confirmation clears local authentication and requires sign in',
    (tester) async {
      final api = await openChild(tester);
      await tapKey(tester, 'returnAccountEntry');
      await tapKey(tester, 'cancelAccountEntry');
      expect(api.cleared, 0);
      expect(find.text('Hi, SYN-Bee!'), findsOneWidget);
      await tapKey(tester, 'returnAccountEntry');
      await tapKey(tester, 'confirmAccountEntry');
      expect(api.cleared, 1);
      await expectLater(
        api.parentMe(),
        throwsA(
          isA<ApiFailure>().having(
            (value) => value.code,
            'code',
            'UNAUTHENTICATED',
          ),
        ),
      );
      expect(find.text('SYN-Bee'), findsNothing);
      expect(find.byType(ParentArea), findsNothing);
      await tapKey(tester, 'welcomeSignIn');
      expect(find.byType(SignIn), findsOneWidget);
      expect(find.byType(ParentArea), findsNothing);
      await fillSignIn(tester);
      await submitSignIn(tester);
      expect(find.byType(ParentArea), findsOneWidget);
    },
  );

  test(
    'fixture clearSession discards auth while preserving the demo account',
    () async {
      final api = FixtureMimiGoApi();
      final ref = await api.onboardingReference();
      await api.register(
        Registration(
          'parent@example.test',
          'synthetic-pass',
          'SYN Parent',
          ref.terms!.id,
          true,
        ),
      );
      await api.verifyMockEmail(email: 'parent@example.test', otp: '123456');
      await api.login(email: 'parent@example.test', password: 'synthetic-pass');
      api.clearSession();
      await expectLater(api.parentMe(), throwsA(isA<ApiFailure>()));
      await api.login(email: 'parent@example.test', password: 'synthetic-pass');
      expect((await api.parentMe()).email, 'parent@example.test');
    },
  );
}
