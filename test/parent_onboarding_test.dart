import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_onboarding.dart';

import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;
import 'learning_widget_test.dart' show tapVisible;
import 'learning_api_test.dart' show Transport, Reply;

class RegistrationApi extends AuthApi {
  ApiFailure? referenceFailure, registerFailure, verifyFailure;
  Completer<OnboardingReference>? referenceWait;
  Completer<void>? verificationWait;
  final registrations = <Registration>[];
  int referenceCalls = 0, verifies = 0;
  bool recoverVerification = false;
  @override
  Future<OnboardingReference> onboardingReference() async {
    referenceCalls++;
    if (referenceFailure != null) throw referenceFailure!;
    if (referenceWait != null) return referenceWait!.future;
    final ref = await super.onboardingReference();
    // Explicit test-only legal content exercises the future adapter seam;
    // the real metadata parser never supplies this object.
    return OnboardingReference(
      TermsReference(
        ref.terms!.id,
        'ACCOUNT_TERMS_V1',
        contentHash: ref.terms!.contentHash,
        effectiveFrom: ref.terms!.effectiveFrom,
        document: ApprovedLegalDocument(
          versionId: ref.terms!.id,
          contentHash: ref.terms!.contentHash!,
          title: 'Điều khoản kiểm thử',
          body: 'Nội dung đầy đủ chỉ dùng để kiểm thử giao diện.',
          approved: true,
        ),
      ),
      ref.purposes,
      ref.notices,
      ref.disclaimer,
    );
  }

  @override
  Future<RegistrationResult> register(Registration value) async {
    registrations.add(value);
    if (registerFailure != null) throw registerFailure!;
    return RegistrationResult(
      'test-parent',
      DateTime.utc(2026, 1, 1),
      'R0: no real email sent.',
      '123456',
    );
  }

  @override
  Future<void> verifyMockEmail({
    required String email,
    required String otp,
  }) async {
    verifies++;
    if (verificationWait != null) await verificationWait!.future;
    if (verifyFailure != null) throw verifyFailure!;
    if (recoverVerification) loginFailure = null;
  }
}

Future<void> beginRegistration(WidgetTester tester, RegistrationApi api) async {
  await tester.pumpWidget(
    MimiGoApp(
      api: api,
      configuration: const ApiConfiguration(ApiMode.live, 'unused'),
    ),
  );
  await tapVisible(tester, 'welcomeStart');
}

Future<void> fillRegistration(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('registerEmail')),
    'new-parent@example.test',
  );
  await tester.enterText(
    find.byKey(const Key('registerPassword')),
    'synthetic-test-pass',
  );
  await tester.enterText(
    find.byKey(const Key('registerPasswordConfirmation')),
    'synthetic-test-pass',
  );
  await tester.enterText(
    find.byKey(const Key('registerDisplayName')),
    'SYN New Parent',
  );
}

void main() {
  testWidgets(
    'launch reference loading coalesces taps and failed reference can retry',
    (tester) async {
      final api = RegistrationApi()
        ..referenceWait = Completer<OnboardingReference>();
      await tester.pumpWidget(MimiGoApp(api: api));
      await tester.ensureVisible(find.byKey(const Key('welcomeStart')));
      await tester.tap(find.byKey(const Key('welcomeStart')));
      await tester.tap(find.byKey(const Key('welcomeStart')));
      await tester.pump();
      expect(api.referenceCalls, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      api.referenceWait!.completeError(
        const ApiFailure('PRIVATE', code: 'CONNECTIVITY'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byKey(const Key('onboardingError')), findsOneWidget);
      api.referenceWait = null;
      await tapVisible(tester, 'welcomeStart');
      expect(find.byType(Register), findsOneWidget);
    },
  );

  testWidgets(
    'live registration has blank credentials, validates fields and requires explicit Terms',
    (tester) async {
      final api = RegistrationApi();
      await beginRegistration(tester, api);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registerPassword')))
            .controller!
            .text,
        isEmpty,
      );
      await tapVisible(tester, 'registerSubmit');
      expect(api.registrations, isEmpty);
      expect(find.text('Mật khẩu cần có từ 10 đến 128 ký tự.'), findsOneWidget);
      await fillRegistration(tester);
      await tapVisible(tester, 'registerSubmit');
      expect(api.registrations, isEmpty);
      await tapVisible(tester, 'termsCheckbox');
      await tapVisible(tester, 'registerSubmit');
      expect(api.registrations.single.termsAccepted, isTrue);
      expect(find.byType(Otp), findsOneWidget);
      expect(find.textContaining('01/01/2026'), findsOneWidget);
      expect(
        api.calls,
        isEmpty,
        reason: 'Registration never authorizes a parent or creates a child.',
      );
    },
  );

  testWidgets(
    'registration server failure stays inline; changed Terms require reload and fresh choice',
    (tester) async {
      final api = RegistrationApi()
        ..registerFailure = const ApiFailure(
          'PRIVATE',
          code: 'TERMS_VERSION_NOT_CURRENT',
          status: 422,
        );
      await beginRegistration(tester, api);
      await fillRegistration(tester);
      await tapVisible(tester, 'termsCheckbox');
      await tapVisible(tester, 'registerSubmit');
      expect(find.byType(Register), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('registerSubmit')))
            .onPressed,
        isNull,
      );
      api.registerFailure = null;
      await tapVisible(tester, 'reloadRegistrationTerms');
      await tapVisible(tester, 'registerSubmit');
      expect(api.registrations, hasLength(1));
      await tapVisible(tester, 'termsCheckbox');
      await tapVisible(tester, 'registerSubmit');
      expect(api.registrations, hasLength(2));
      expect(find.byType(Otp), findsOneWidget);
    },
  );

  for (final code in ['INVALID_OTP', 'RATE_LIMITED', 'CONNECTIVITY']) {
    test('$code does not mark verification successful or call login', () async {
      final api = RegistrationApi()
        ..verifyFailure = ApiFailure(
          'PRIVATE',
          code: code,
          status: code == 'RATE_LIMITED' ? 429 : 400,
        );
      final state = EmailVerificationState(api, 'synthetic@example.test');
      var logins = 0;
      expect(
        await state.submit('123456', () async {
          logins++;
        }),
        isFalse,
      );
      expect(state.verified, isFalse);
      expect(logins, 0);
      expect(state.error!.code, code);
      state.dispose();
    });
  }

  test(
    'OTP validation, duplicate guard and disposal prevent extra authentication',
    () async {
      final api = RegistrationApi()..verificationWait = Completer<void>();
      final state = EmailVerificationState(api, 'synthetic@example.test');
      var logins = 0;
      expect(
        await state.submit('12', () async {
          logins++;
        }),
        isFalse,
      );
      expect(api.verifies, 0);
      final pending = state.submit('123456', () async {
        logins++;
      });
      expect(
        await state.submit('123456', () async {
          logins++;
        }),
        isFalse,
      );
      expect(api.verifies, 1);
      state.dispose();
      api.verificationWait!.complete();
      expect(await pending, isFalse);
      expect(logins, 0);
    },
  );

  test(
    'lost login response retries authentication without re-verifying email',
    () async {
      final api = RegistrationApi();
      final state = EmailVerificationState(api, 'synthetic@example.test');
      expect(
        await state.submit('123456', () async {
          throw const ApiFailure('offline', code: 'CONNECTIVITY');
        }),
        isFalse,
      );
      expect(state.verified, isTrue);
      expect(await state.submit('', () async {}), isTrue);
      expect(api.verifies, 1);
      state.dispose();
    },
  );

  testWidgets(
    'existing unverified parent can recover verification and reach Góc phụ huynh',
    (tester) async {
      final api = RegistrationApi()
        ..loginFailure = const ApiFailure(
          'Unverified',
          code: 'EMAIL_NOT_VERIFIED',
          status: 403,
        )
        ..recoverVerification = true;
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      await tapVisible(tester, 'resumeEmailVerification');
      expect(find.byType(Otp), findsOneWidget);
      expect(
        find.textContaining('Ba mẹ kiểm tra email và nhập mã xác nhận'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('otpCode')), '123456');
      await tapVisible(tester, 'otpVerify');
      expect(find.byType(ParentArea), findsOneWidget);
      expect(api.calls, ['login', 'login', 'me', 'workspace']);
      expect(api.registrations, isEmpty);
    },
  );

  test('registration and verification repository use exact public contract and validate acknowledgment', () async {
    final http = Transport()
      ..replies.addAll([
        Reply({
          'parentId': 'synthetic-parent',
          'status': 'PENDING_VERIFICATION',
          'otpExpiresAt': '2026-10-24T00:00:00Z',
          'notice': 'R0 only',
        }, statusCode: 201),
        Reply({'parentId': 'synthetic-parent', 'status': 'ACTIVE'}),
        Reply({
          'parentId': 'synthetic-parent',
          'status': 'PENDING_VERIFICATION',
        }),
      ]);
    final api = LiveMimiGoApi(
      Uri.parse('http://10.0.2.2:5187/api/v1'),
      client: http,
    );
    await api.register(
      const Registration(
        'synthetic@example.test',
        'synthetic-test-pass',
        'SYN Parent',
        'version-id',
        true,
      ),
    );
    expect(http.requests.last.uri.path, '/api/v1/auth/register');
    expect(
      http.requests.last.body,
      '{"email":"synthetic@example.test","password":"synthetic-test-pass","displayName":"SYN Parent","termsVersionId":"version-id","termsAccepted":true}',
    );
    expect(http.requests.last.headers.value('authorization'), isNull);
    await api.verifyMockEmail(email: 'synthetic@example.test', otp: '123456');
    expect(http.requests.last.uri.path, '/api/v1/auth/mock-email/verify');
    expect(
      http.requests.last.body,
      '{"email":"synthetic@example.test","otp":"123456"}',
    );
    await expectLater(
      api.verifyMockEmail(email: 'synthetic@example.test', otp: '123456'),
      throwsA(isA<ApiInvalidResponse>()),
    );
  });
}
