import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

class AuthApi extends FixtureMimiGoApi {
  @override
  Future<LessonList> lessons(String childId) async {
    calls.add('lessons:$childId');
    return const LessonList([], 'NO_ELIGIBLE_CONTENT', 'Synthetic widget test');
  }

  final calls = <String>[];
  ApiFailure? loginFailure, parentFailure, listFailure;
  Completer<LoginSession>? pendingLogin;
  bool termsAccepted = true;
  List<ChildSummary> profiles = [];

  @override
  Future<void> verifyMockEmail({
    required String email,
    required String otp,
  }) async {
    calls.add('verify');
  }

  @override
  Future<LoginSession> login({
    required String email,
    required String password,
  }) async {
    calls.add('login');
    if (loginFailure != null) throw loginFailure!;
    return pendingLogin?.future ??
        LoginSession('test-token', DateTime(2030), 'test-parent');
  }

  @override
  Future<ParentSummary> parentMe() async {
    calls.add('me');
    if (parentFailure != null) throw parentFailure!;
    return ParentSummary(
      'test-parent',
      'parent@example.test',
      'SYN Parent',
      termsAccepted,
    );
  }

  @override
  Future<List<ChildSummary>> listChildren() async {
    calls.add('children');
    if (listFailure != null) throw listFailure!;
    return profiles;
  }

  @override
  Future<ChildDetail> getChild(String childId) async {
    calls.add('detail:$childId');
    final child = profiles.singleWhere((value) => value.id == childId);
    return ChildDetail(
      id: child.id,
      alias: child.alias,
      dateOfBirth: child.dateOfBirth,
      ageYears: child.ageYears,
      withinProgramAgeRange: child.withinProgramAgeRange,
      state: child.state,
      createdAt: child.createdAt,
      recordedDecisions: const [],
      disclaimer: 'Synthetic test',
    );
  }
}

Future<void> openSignIn(WidgetTester tester, AuthApi api) async {
  await tester.pumpWidget(
    MimiGoApp(
      api: api,
      configuration: const ApiConfiguration(
        ApiMode.live,
        'http://10.0.2.2:5187/api/v1',
      ),
    ),
  );
  expect(find.byKey(const Key('welcomeStart')), findsOneWidget);
  await tester.tap(find.byKey(const Key('welcomeSignIn')));
  await tester.pumpAndSettle();
}

Future<void> fillSignIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('signInEmail')),
    ' parent@example.test ',
  );
  await tester.enterText(
    find.byKey(const Key('signInPassword')),
    'synthetic-pass',
  );
  await tester.ensureVisible(find.byKey(const Key('signInSubmit')));
}

Future<void> submitSignIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('signInSubmit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'verified email retries a failed authentication check without reusing the OTP',
    (tester) async {
      final api = AuthApi();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Otp(
              api: api,
              email: 'parent@example.test',
              mockOtp: null,
              back: () {},
              done: () async {
                attempts++;
                if (attempts == 1)
                  throw const ApiFailure(
                    'Could not reach the service.',
                    code: 'CONNECTIVITY',
                  );
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('otpCode')), '123456');
      await tester.tap(find.byKey(const Key('otpVerify')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not reach the service.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('otpVerify')));
      await tester.pumpAndSettle();
      expect(api.calls, ['verify']);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'landing offers sign in and validates empty/invalid input before API calls',
    (tester) async {
      final api = AuthApi();
      await openSignIn(tester, api);
      await submitSignIn(tester);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('signInEmail')), 'invalid');
      await submitSignIn(tester);
      expect(api.calls, isEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated parent with no children sees an empty list and can start consent',
    (tester) async {
      final api = AuthApi();
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      expect(api.calls, ['login', 'me', 'children']);
      expect(find.text('Authenticated Parent Area'), findsOneWidget);
      expect(find.text('No child profiles returned.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('addChild')));
      await tester.tap(find.byKey(const Key('addChild')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loadAttempt')), findsOneWidget);
      expect(find.byKey(const Key('childName')), findsNothing);
    },
  );

  testWidgets(
    'returning parent sees existing profiles and selects through authenticated detail',
    (tester) async {
      final api = AuthApi()
        ..profiles = [
          ChildSummary(
            id: 'child-1',
            alias: 'SYN-Bee',
            dateOfBirth: DateTime(2022, 10, 21),
            ageYears: 4,
            withinProgramAgeRange: true,
            state: 'ACTIVE',
            createdAt: DateTime(2026),
          ),
        ];
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      await tester.tap(find.text('SYN-Bee'));
      await tester.pumpAndSettle();
      expect(api.calls, ['login', 'me', 'children', 'detail:child-1']);
      expect(find.text('Hi, SYN-Bee!'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'loading disables duplicate submission and waits for parent verification',
    (tester) async {
      final api = AuthApi()..pendingLogin = Completer<LoginSession>();
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await tester.tap(find.byKey(const Key('signInSubmit')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('signInSubmit')))
            .onPressed,
        isNull,
      );
      expect(api.calls, ['login']);
      expect(find.byType(ParentArea), findsNothing);
      api.parentFailure = const ApiFailure(
        'Session rejected.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
      api.pendingLogin!.complete(
        LoginSession('test-token', DateTime(2030), 'test-parent'),
      );
      await tester.pumpAndSettle();
      expect(api.calls, ['login', 'me']);
      expect(find.byType(ParentArea), findsNothing);
      expect(find.textContaining('Session rejected.'), findsOneWidget);
    },
  );

  testWidgets('wrong password stays on sign in and can be corrected', (
    tester,
  ) async {
    final api = AuthApi()
      ..loginFailure = const ApiFailure(
        'Rejected',
        code: 'INVALID_CREDENTIALS',
        status: 401,
        requestId: 'test-request',
      );
    await openSignIn(tester, api);
    await fillSignIn(tester);
    await submitSignIn(tester);
    expect(
      find.textContaining('Email or password is incorrect.'),
      findsOneWidget,
    );
    expect(find.textContaining('test-request'), findsOneWidget);
    expect(api.calls, ['login']);
    api.loginFailure = null;
    await submitSignIn(tester);
    expect(find.byType(ParentArea), findsOneWidget);
  });

  for (final failure in [
    const ApiFailure(
      'Verify your email before signing in.',
      code: 'EMAIL_NOT_VERIFIED',
      status: 403,
    ),
    const ApiFailure(
      'Service unavailable.',
      code: 'DB_UNAVAILABLE',
      status: 503,
    ),
    const ApiFailure(
      'Could not reach the service.',
      code: 'CONNECTIVITY',
      retryable: true,
    ),
    const ApiFailure(
      'The service did not respond in time.',
      code: 'TIMEOUT',
      retryable: true,
    ),
    const ApiInvalidResponse('Login response is missing accessToken.'),
  ]) {
    testWidgets(
      '${failure.code} keeps sign in available without authenticated navigation',
      (tester) async {
        final api = AuthApi()..loginFailure = failure;
        await openSignIn(tester, api);
        await fillSignIn(tester);
        await submitSignIn(tester);
        expect(find.textContaining(failure.message), findsOneWidget);
        expect(find.byType(SignIn), findsOneWidget);
        expect(find.byType(ParentArea), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('signInSubmit')))
              .onPressed,
          isNotNull,
        );
        expect(api.calls, ['login']);
      },
    );
  }

  testWidgets('list failure does not present an empty successful result', (
    tester,
  ) async {
    final api = AuthApi()
      ..listFailure = const ApiFailure(
        'Profiles unavailable.',
        code: 'DB_UNAVAILABLE',
        status: 503,
      );
    await openSignIn(tester, api);
    await fillSignIn(tester);
    await submitSignIn(tester);
    expect(api.calls, ['login', 'me', 'children']);
    expect(find.byType(SignIn), findsOneWidget);
    expect(find.textContaining('Profiles unavailable.'), findsOneWidget);
    expect(find.text('No child profiles returned.'), findsNothing);
  });

  testWidgets(
    'outdated terms block adding a child without inventing re-acceptance',
    (tester) async {
      final api = AuthApi()..termsAccepted = false;
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      expect(find.byType(ParentArea), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('addChild')))
            .onPressed,
        isNull,
      );
    },
  );
}
