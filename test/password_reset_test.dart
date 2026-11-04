import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/password_reset.dart';

import 'learning_api_test.dart' show Transport, Reply;

class RecoveryDouble implements PasswordResetApi {
  int requests = 0, confirmations = 0;
  ApiFailure? failure;
  Completer<int>? pending;
  @override
  Future<int> requestPasswordReset(String email) async {
    requests++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return 1;
  }

  @override
  Future<void> confirmPasswordReset(
    String email,
    String otp,
    String password,
  ) async {
    confirmations++;
    if (failure != null) throw failure!;
  }
}

DateTime testNow = DateTime(2026, 11, 4);
Future<void> open(WidgetTester t, RecoveryDouble api) async {
  await t.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.push<bool>(
            c,
            MaterialPageRoute(
              builder: (_) => PasswordResetScreen(api: api, now: () => testNow),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('resetEmail')), 'parent@example.test');
}

void main() {
  testWidgets(
    'login opens recovery with preserved email and returns after confirmed reset',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final api = RecoveryDouble();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SignIn(
                back: () {},
                submitted: (_, _) async {},
                recovery: api,
              ),
            ),
          ),
        ),
      );
      await t.enterText(
        find.byKey(const Key('signInEmail')),
        'parent@example.test',
      );
      await t.ensureVisible(find.byKey(const Key('forgotPassword')));
      await t.tap(find.byKey(const Key('forgotPassword')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('resetEmail')))
            .controller!
            .text,
        'parent@example.test',
      );
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('resetCode')), '123456');
      await t.enterText(
        find.byKey(const Key('resetPassword')),
        'new-test-password',
      );
      await t.enterText(
        find.byKey(const Key('resetConfirm')),
        'new-test-password',
      );
      await t.ensureVisible(find.byKey(const Key('resetSubmit')));
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('signInEmail')), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('signInEmail')))
            .controller!
            .text,
        'parent@example.test',
      );
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('signInPassword')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.text('Đã đổi mật khẩu. Ba mẹ đăng nhập bằng mật khẩu mới nhé.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending request prevents duplicate submissions and leaves no timer on dispose',
    (t) async {
      final api = RecoveryDouble()..pending = Completer<int>();
      await open(t, api);
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pump();
      expect(
        t.widget<FilledButton>(find.byKey(const Key('resetSubmit'))).onPressed,
        isNull,
      );
      expect(api.requests, 1);
      await t.pumpWidget(const SizedBox());
      api.pending!.complete(60);
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );
  test(
    'exact public reset routes, payloads, status and no bearer/proof',
    () async {
      final http = Transport()
        ..replies.addAll([
          Reply({
            'status': 'ACCEPTED',
            'resendCooldownSeconds': 60,
            'notice': 'safe',
            'mockOtp': '123456',
          }, statusCode: 202),
          Reply({'status': 'PASSWORD_RESET', 'notice': 'safe'}),
        ]);
      final api = LiveMimiGoApi(
        Uri.parse('https://unit.invalid/api/v1'),
        client: http,
      );
      expect(await api.requestPasswordReset('parent@example.test'), 60);
      await api.confirmPasswordReset(
        'parent@example.test',
        '123456',
        'new-test-password',
      );
      expect(http.requests[0].uri.path, '/api/v1/auth/password-reset/request');
      expect(jsonDecode(http.requests[0].body), {
        'email': 'parent@example.test',
      });
      expect(http.requests[1].uri.path, '/api/v1/auth/password-reset/confirm');
      expect(jsonDecode(http.requests[1].body), {
        'email': 'parent@example.test',
        'otp': '123456',
        'newPassword': 'new-test-password',
      });
      for (final r in http.requests) {
        expect(r.headers.value('authorization'), isNull);
        expect(r.headers.value('MimiGo-Parent-Proof'), isNull);
      }
    },
  );
  test(
    'malformed acknowledgments and wrong HTTP status cannot become success',
    () async {
      for (final reply in [
        Reply({
          'status': 'ACCEPTED',
          'resendCooldownSeconds': 60,
          'notice': 'safe',
        }),
        Reply({
          'status': 'ACCEPTED',
          'resendCooldownSeconds': -1,
          'notice': 'safe',
        }, statusCode: 202),
      ]) {
        final http = Transport()..replies.add(reply);
        await expectLater(
          LiveMimiGoApi(
            Uri.parse('https://unit.invalid/api/v1'),
            client: http,
          ).requestPasswordReset('parent@example.test'),
          throwsA(isA<ApiInvalidResponse>()),
        );
      }
      final http = Transport()
        ..replies.add(Reply({'status': 'ACCEPTED', 'notice': 'safe'}));
      await expectLater(
        LiveMimiGoApi(
          Uri.parse('https://unit.invalid/api/v1'),
          client: http,
        ).confirmPasswordReset(
          'parent@example.test',
          '123456',
          'new-test-password',
        ),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
  testWidgets('locked request never opens code form or claims email delivery', (
    t,
  ) async {
    final api = RecoveryDouble()
      ..failure = const ApiFailure(
        'internal',
        code: 'CLOUD_SURFACE_LOCKED',
        status: 503,
      );
    await open(t, api);
    await t.tap(find.byKey(const Key('resetSubmit')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('resetAccepted')), findsNothing);
    expect(find.byKey(const Key('resetCode')), findsNothing);
    expect(find.text('internal'), findsNothing);
    expect(api.requests, 1);
  });
  testWidgets(
    'accepted request, cooldown, validation, invalid code and confirmed return',
    (t) async {
      final api = RecoveryDouble();
      await open(t, api);
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('resetAccepted')), findsOneWidget);
      expect(
        t.widget<TextButton>(find.byKey(const Key('resetResend'))).onPressed,
        isNull,
      );
      await t.ensureVisible(find.byKey(const Key('resetSubmit')));
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pump();
      expect(api.confirmations, 0);
      await t.enterText(find.byKey(const Key('resetCode')), '123456');
      await t.enterText(
        find.byKey(const Key('resetPassword')),
        'new-test-password',
      );
      await t.enterText(
        find.byKey(const Key('resetConfirm')),
        'new-test-password',
      );
      api.failure = const ApiFailure(
        'internal',
        code: 'INVALID_RESET_CODE',
        status: 400,
      );
      await t.ensureVisible(find.byKey(const Key('resetSubmit')));
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('resetCode')), findsOneWidget);
      expect(api.confirmations, 1);
      api.failure = null;
      await t.ensureVisible(find.byKey(const Key('resetSubmit')));
      await t.tap(find.byKey(const Key('resetSubmit')));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(api.confirmations, 2);
    },
  );
  testWidgets('429 honors retry-after without advancing', (t) async {
    final api = RecoveryDouble()
      ..failure = const ApiFailure(
        'internal',
        code: 'RATE_LIMITED',
        status: 429,
        retryAfterSeconds: 5,
      );
    await open(t, api);
    await t.tap(find.byKey(const Key('resetSubmit')));
    await t.pump();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('resetSubmit'))).onPressed,
      isNull,
    );
    testNow = testNow.add(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 6));
    expect(
      t.widget<FilledButton>(find.byKey(const Key('resetSubmit'))).onPressed,
      isNotNull,
    );
    await t.pumpWidget(const SizedBox());
  });
}
