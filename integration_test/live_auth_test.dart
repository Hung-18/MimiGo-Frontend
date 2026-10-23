import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_content.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';

/// Opt-in Android test. Creates synthetic rows in the configured Development API.
/// Run with MIMIGO_API_MODE=live; never supply real family data or credentials.
class TracedLiveApi extends LiveMimiGoApi {
  TracedLiveApi(super.baseUri);
  final calls = <String>[];
  LessonList? catalog;
  @override
  Future<LessonList> lessons(String childId) async {
    catalog = await trace('lessons', () => super.lessons(childId));
    return catalog!;
  }

  RegistrationResult? registration;
  CreateChildRequest? createdRequest;
  ChildSummary? createdChild;
  String? registeredEmail,
      registeredPassword,
      lastLoginEmail,
      lastLoginPassword;

  Future<T> trace<T>(String operation, Future<T> Function() action) async {
    try {
      final result = await action();
      calls.add(operation);
      debugPrint('VS023 $operation OK');
      return result;
    } on ApiFailure catch (failure) {
      debugPrint(
        'VS023 $operation ${failure.status ?? '-'} ${failure.code} requestId=${failure.requestId ?? '-'}',
      );
      rethrow;
    }
  }

  @override
  Future<OnboardingReference> onboardingReference() =>
      trace('reference', super.onboardingReference);
  @override
  Future<RegistrationResult> register(Registration value) async {
    registeredEmail = value.email;
    registeredPassword = value.password;
    registration = await trace('register', () => super.register(value));
    return registration!;
  }

  @override
  Future<void> verifyMockEmail({required String email, required String otp}) =>
      trace('verify', () => super.verifyMockEmail(email: email, otp: otp));
  @override
  Future<LoginSession> login({
    required String email,
    required String password,
  }) {
    lastLoginEmail = email;
    lastLoginPassword = password;
    return trace('login', () => super.login(email: email, password: password));
  }

  @override
  Future<ParentSummary> parentMe() => trace('me', super.parentMe);
  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() =>
      trace('attempt', super.beginOnboardingAttempt);
  @override
  Future<ChildSummary> createChild(CreateChildRequest value) async {
    final result = await trace('create', () => super.createChild(value));
    createdRequest = value;
    createdChild = result;
    return result;
  }

  @override
  Future<List<ChildSummary>> listChildren() =>
      trace('list', super.listChildren);
  @override
  Future<ChildDetail> getChild(String childId) =>
      trace('detail', () => super.getChild(childId));
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live registration, consent, returning-parent authentication and profiles',
    (tester) async {
      final config = ApiConfiguration.fromEnvironment();
      expect(
        config.mode,
        ApiMode.live,
        reason: 'This integration test requires explicit live mode.',
      );
      final api = TracedLiveApi(Uri.parse(config.baseUrl));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'vs023-$suffix@example.test';
      final password = 'SYN-${Random.secure().nextInt(1 << 30)}-$suffix';
      final alias = 'SYN-Android-$suffix';

      await tester.pumpWidget(MimiGoApp(api: api, configuration: config));
      await tap(tester, 'welcomeStart');
      await waitFor(tester, find.byKey(const Key('registerEmail')));
      await tester.enterText(find.byKey(const Key('registerEmail')), email);
      final registrationPassword = find
          .descendant(
            of: find.byType(Register),
            matching: find.byType(TextField),
          )
          .last;
      await tester.ensureVisible(registrationPassword);
      await tester.enterText(registrationPassword, password);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await tap(tester, 'termsCheckbox');
      await tap(tester, 'registerSubmit');
      await waitFor(tester, find.byKey(const Key('otpCode')));
      expect(
        api.registeredEmail == email,
        isTrue,
        reason: 'Registration submits the entered synthetic email.',
      );
      expect(
        api.registeredPassword == password,
        isTrue,
        reason: 'Registration submits the entered synthetic password.',
      );
      expect(
        api.registration!.mockOtp,
        isNotNull,
        reason: 'Development must expose its mock OTP for this test.',
      );
      await tester.enterText(
        find.byKey(const Key('otpCode')),
        api.registration!.mockOtp!,
      );
      await tap(tester, 'otpVerify');
      await waitFor(tester, find.byKey(const Key('loadAttempt')));
      expect(
        api.calls,
        containsAllInOrder(['register', 'verify', 'login', 'me']),
      );
      await tap(tester, 'loadAttempt');
      await waitFor(tester, find.byKey(const Key('guardianAssertion')));
      final consentTiles = find.byType(CheckboxListTile);
      expect(consentTiles.evaluate().length, greaterThan(1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
      for (final element in consentTiles.evaluate().toList()) {
        final tile = element.widget as CheckboxListTile;
        expect(tile.value, isFalse);
        await tap(tester, (tile.key! as ValueKey<String>).value);
      }
      await tap(tester, 'privacyContinue');
      await waitFor(tester, find.byKey(const Key('childName')));
      await tester.enterText(find.byKey(const Key('childName')), alias);
      await tester.enterText(find.byKey(const Key('childDob')), '2022-10-21');
      await tap(tester, 'childContinue');
      await waitFor(tester, find.byKey(const Key('createChild')));
      await tap(tester, 'createChild');
      await waitFor(tester, find.text('Hi, $alias!'));
      // Replay is tested at the live Dart adapter on this Android device.
      final request = api.createdRequest!;
      final child = api.createdChild!;
      final replay = await api.createChild(request);
      expect(replay.id, child.id);
      expect(
        (await api.listChildren()).where((value) => value.id == child.id),
        hasLength(1),
      );
      await expectLater(
        api.createChild(
          CreateChildRequest(
            attemptId: request.attemptId,
            idempotencyKey: request.idempotencyKey,
            childAlias: 'SYN-Changed',
            dateOfBirth: request.dateOfBirth,
            guardianAffirmed: request.guardianAffirmed,
            stockAvatarKey: request.stockAvatarKey,
            purposeChoices: request.purposeChoices,
          ),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'code',
            'IDEMPOTENCY_CONFLICT',
          ),
        ),
      );

      // Recreate the app with a fresh live adapter: no previous token is reused.
      await tester.pumpWidget(const SizedBox.shrink());
      final returning = TracedLiveApi(Uri.parse(config.baseUrl));
      await tester.pumpWidget(MimiGoApp(api: returning, configuration: config));
      await tap(tester, 'welcomeSignIn');
      await waitFor(tester, find.byKey(const Key('signInEmail')));
      await tester.enterText(find.byKey(const Key('signInEmail')), email);
      await tester.enterText(
        find.byKey(const Key('signInPassword')),
        'wrong-$suffix',
      );
      await tap(tester, 'signInSubmit');
      await waitFor(
        tester,
        find.textContaining('Email or password is incorrect.'),
      );
      expect(find.byType(ParentArea), findsNothing);
      // Refocus after submit dismissed the Android keyboard, then wait for the
      // platform text-input connection before replacing the failed password.
      await tester.ensureVisible(find.byKey(const Key('signInPassword')));
      await tester.tap(find.byKey(const Key('signInPassword')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('signInPassword')), password);
      await tester.pumpAndSettle();
      expect(
        tester
                .widget<TextFormField>(find.byKey(const Key('signInPassword')))
                .controller!
                .text ==
            password,
        isTrue,
        reason: 'Retry controller contains the corrected password.',
      );
      await tap(tester, 'signInSubmit');
      expect(
        returning.lastLoginEmail == email,
        isTrue,
        reason: 'Returning login submits the entered email.',
      );
      expect(
        returning.lastLoginPassword == password,
        isTrue,
        reason: 'Returning login submits the corrected password.',
      );
      await waitFor(tester, find.byType(ParentArea));
      expect(returning.calls, ['login', 'me', 'list']);
      await tester.ensureVisible(find.text(alias));
      await tester.tap(find.text(alias));
      await waitFor(tester, find.byKey(const Key('parentEnterLearning')));
      await tap(tester, 'parentEnterLearning');
      await waitFor(tester, find.text('Hi, $alias!'));
      expect(returning.calls.last, 'detail');
      final authenticatedCalls = List<String>.of(returning.calls);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
      for (final category in LearningCategory.values) {
        await tap(tester, 'category-${category.name}');
        if (category == LearningCategory.math) {
          await waitFor(tester, find.byType(MathLessonCatalog));
          expect(returning.catalog, isNotNull);
          expect(find.byKey(const Key('learningError')), findsNothing);
        } else {
          await waitFor(tester, find.byKey(const Key('categoryEmpty')));
        }
        expect(find.byKey(const Key('openCircleDemo')), findsNothing);
        expect(find.byType(CircleDemo), findsNothing);
        expect(find.byType(ParentArea), findsNothing);
        await tap(tester, 'categoryBack');
        await waitFor(tester, find.text('Hi, $alias!'));
      }
      expect(
        returning.calls,
        [...authenticatedCalls, 'lessons'],
        reason: 'Only Math fetches the verified catalog; no speculative endpoints or progress writes.',
      );
      await tap(tester, 'returnAccountEntry');
      await tap(tester, 'cancelAccountEntry');
      expect(find.text('Hi, $alias!'), findsOneWidget);
      await tap(tester, 'returnAccountEntry');
      await tap(tester, 'confirmAccountEntry');
      await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
      await expectLater(
        returning.parentMe(),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'local session',
            'UNAUTHENTICATED',
          ),
        ),
      );
      await tap(tester, 'welcomeSignIn');
      await waitFor(tester, find.byKey(const Key('signInEmail')));
      expect(find.byType(ParentArea), findsNothing);
      await tester.enterText(find.byKey(const Key('signInEmail')), email);
      await tester.enterText(find.byKey(const Key('signInPassword')), password);
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.byType(ParentArea));
      debugPrint(
        'VS023 LIVE CHILD NAV PASS: Math catalog; five unavailable categories; back; local session cleared; parent required fresh login.',
      );
      debugPrint(
        'VS023 ANDROID LIVE AUTH FLOW PASS; replay same child; changed payload rejected; no secrets logged.',
      );
    },
  );
}
