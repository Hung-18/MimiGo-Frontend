import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';

void main() {
  test('fixture supports registration-to-child retrieval flow', () async {
    final api = FixtureMimiGoApi();
    final reference = await api.onboardingReference();
    await api.register(
      Registration(
        'parent@example.test',
        'synthetic-pass',
        'SYN Parent',
        reference.terms!.id,
        true,
      ),
    );
    await api.verifyMockEmail(email: 'parent@example.test', otp: '123456');
    await api.login(email: 'parent@example.test', password: 'synthetic-pass');
    expect((await api.parentMe()).currentTermsAccepted, isTrue);
    final attempt = await api.beginOnboardingAttempt();
    final child = await api.createChild(
      CreateChildRequest(
        attemptId: attempt.id,
        idempotencyKey: 'fixture-test-001',
        childAlias: 'SYN-Bee',
        dateOfBirth: DateTime(2022, 10, 21),
        guardianAffirmed: true,
        stockAvatarKey: 'bear-blue',
        purposeChoices: attempt.notices
            .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
            .toList(),
      ),
    );
    expect((await api.listChildren()).single.id, child.id);
    expect((await api.getChild(child.id)).recordedDecisions, hasLength(2));
  });

  test('live configuration defaults to the Android Emulator host bridge', () {
    final config = ApiConfiguration.fromEnvironment();
    expect(config.baseUrl, contains('10.0.2.2'));
    expect(LiveMimiGoApi(Uri.parse(config.baseUrl)), isA<LiveMimiGoApi>());
  });

  testWidgets('terms and consent are unchecked and gate child input', (
    tester,
  ) async {
    await tester.pumpWidget(const MimiGoApp());
    await tester.tap(find.byKey(const Key('welcomeStart')));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
    await tester.tap(find.byKey(const Key('termsCheckbox')));
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otpCode')), '123456');
    await tester.tap(find.byKey(const Key('otpVerify')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loadAttempt')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
          .onPressed,
      isNull,
    );
    final decline = find.byKey(const Key('privacyDecline'));
    await tester.ensureVisible(decline);
    await tester.tap(decline);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No child alias, date of birth or profile was sent'),
      findsOneWidget,
    );
  });

  test('product age treats 29 February as 1 March in non-leap years', () {
    expect(productAge(DateTime(2020, 2, 29), DateTime(2025, 2, 28)), 4);
    expect(productAge(DateTime(2020, 2, 29), DateTime(2025, 3, 1)), 5);
  });
}
