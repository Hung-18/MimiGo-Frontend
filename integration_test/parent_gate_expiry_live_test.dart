import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';

import 'live_auth_test.dart' show tap, waitFor;

// Uses the Backend's documented BE_TEST_SHORT disposable-session policy.
// The operator must activate it in the owned throwaway DB before this test;
// this Android test never changes schema, policy or server time itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Parent Gate LIVE server-clock idle expiry fails closed', (
    tester,
  ) async {
    const authorized = bool.fromEnvironment(
      'MIMIGO_PARENT_GATE_E2E_AUTHORIZED',
    );
    const shortPolicy = bool.fromEnvironment(
      'MIMIGO_PARENT_GATE_E2E_SHORT_SESSION',
    );
    const database = String.fromEnvironment('MIMIGO_PARENT_GATE_E2E_DATABASE');
    const address = String.fromEnvironment('MIMIGO_API_BASE_URL');
    expect(authorized && shortPolicy, isTrue);
    expect(RegExp(r'^mimigo_conc_[a-z0-9_]+$').hasMatch(database), isTrue);
    expect(address.isNotEmpty, isTrue);
    final configuration = ApiConfiguration.fromEnvironment();
    expect(configuration.mode, ApiMode.live);
    expect(configuration.parentGateEnabled, isTrue);
    const vault = PlatformCredentialVault();
    // Boolean assertions prevent a failed precondition from printing a bundle.
    expect(
      await vault.read() == null,
      isTrue,
      reason: 'Use an empty disposable app vault; never overwrite credentials.',
    );
    final uri = Uri.parse(address);
    final api = LiveMimiGoApi(uri, parentGateEnabled: true);
    final random = Random.secure();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'pg-expiry-$stamp@example.test';
    final password = 'SYN-${random.nextInt(1 << 30)}-$stamp';
    final client = HttpClient();
    try {
      final reference = await api.onboardingReference();
      final registration = await api.register(
        Registration(
          email,
          password,
          'SYN Expiry Parent',
          reference.terms!.id,
          true,
        ),
      );
      expect(registration.mockOtp != null, isTrue);
      await api.verifyMockEmail(email: email, otp: registration.mockOtp!);
      await tester.pumpWidget(
        MimiGoApp(api: api, configuration: configuration),
      );
      await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(find.byKey(const Key('signInEmail')), email);
      await tester.enterText(find.byKey(const Key('signInPassword')), password);
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.byKey(const Key('manageParentPin')));
      final session = api.gateSession!.current!;
      expect(
        session.refreshExpiresAt.difference(DateTime.now()).inSeconds <= 2,
        isTrue,
        reason: 'Requires actual Backend BE_TEST_SHORT session policy.',
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      // Access token is still cryptographically valid, but AP-3 checks the real
      // database session clock. The denial must hide UI and clear native vault.
      await expectLater(
        api.beginOnboardingAttempt(),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.code,
            'code',
            'SESSION_REVOKED',
          ),
        ),
      );
      await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
      expect(api.gateSession!.current == null, isTrue);
      expect(await vault.read() == null, isTrue);
      expect(find.byKey(const Key('manageParentPin')), findsNothing);
      for (final command in [
        ('children/onboarding-attempts', <String, Object?>{}),
        (
          'auth/sessions/refresh',
          <String, Object?>{'refreshToken': session.refreshToken},
        ),
      ]) {
        final request = await client.postUrl(
          uri.replace(path: '${uri.path}/${command.$1}'),
        );
        request.headers.contentType = ContentType.json;
        if (!command.$1.endsWith('/refresh')) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer ${session.token}',
          );
        }
        request.write(jsonEncode(command.$2));
        final response = await request.close();
        expect(response.statusCode, 401);
        final json =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;
        expect(json['code'], 'SESSION_REVOKED');
      }
      debugPrint(
        'PARENT GATE ANDROID LIVE EXPIRY PASS: real server-clock idle expiry; AP-3 and refresh rejected; account UI and native vault cleared. No token mocks or clock edits.',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      try {
        await api.gateSession!.logout();
      } catch (_) {}
      api.gateSession!.dispose();
      client.close(force: true);
      await vault.clear();
    }
  });
}
