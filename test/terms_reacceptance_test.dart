import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/terms_reacceptance.dart';

import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;
import 'learning_widget_test.dart' show tapVisible;
import 'learning_api_test.dart' show Transport, Reply, authenticated;

const termsVersion = '99999999-1111-4111-8111-111111111111';

class TermsApi extends AuthApi {
  TermsApi() {
    termsAccepted = false;
  }
  bool requiredTerms = true,
      loseAck = false,
      wrongParent = false,
      wrongAck = false,
      staleParentReadback = false,
      rejectCreate = false;
  bool missingReference = false;
  String currentId = termsVersion, currentCode = 'R0_TEST_TERMS_V2';
  ApiFailure? termsFailure, referenceFailure;
  Completer<TermsAcceptance>? gate;
  Completer<OnboardingReference>? referenceGate;
  final acceptRequests = <(String, bool)>[];
  int createCalls = 0, referenceCalls = 0;
  @override
  Future<OnboardingReference> onboardingReference() async {
    referenceCalls++;
    if (referenceFailure != null) throw referenceFailure!;
    if (referenceGate != null) return referenceGate!.future;
    return OnboardingReference(
      missingReference
          ? null
          : TermsReference(
              currentId,
              currentCode,
              contentHash: List.filled(64, '0').join(),
              effectiveFrom: DateTime.utc(2026, 10, 24),
            ),
      const [],
      const [],
      'Synthetic Terms metadata; no production legal text.',
    );
  }

  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() async {
    calls.add('attempt');
    if (requiredTerms)
      throw const ApiFailure(
        'Accept Terms',
        code: 'TERMS_ACCEPTANCE_REQUIRED',
        status: 422,
      );
    return OnboardingAttempt('test-attempt', DateTime(2030), const [
      Notice('CHILD_PROFILE_AGE', 'age-v1', 'test'),
      Notice('LEARNING_PROGRESS', 'learning-v1', 'test'),
    ]);
  }

  @override
  Future<TermsAcceptance> acceptCurrentTerms(
    String id, {
    required bool termsAccepted,
  }) async {
    acceptRequests.add((id, termsAccepted));
    if (gate != null) return gate!.future;
    if (termsFailure != null) throw termsFailure!;
    this.termsAccepted = !staleParentReadback;
    requiredTerms = false;
    if (loseAck) {
      loseAck = false;
      throw const ApiFailure('Lost ack', code: 'CONNECTIVITY', retryable: true);
    }
    return TermsAcceptance(wrongAck ? 'wrong' : id, currentCode, true);
  }

  @override
  Future<ParentSummary> parentMe() async {
    final value = await super.parentMe();
    return wrongParent
        ? ParentSummary('other-parent', value.email, value.displayName, true)
        : value;
  }

  @override
  Future<ChildSummary> createChild(CreateChildRequest value) async {
    createCalls++;
    if (rejectCreate) {
      requiredTerms = true;
      termsAccepted = false;
      throw const ApiFailure(
        'Changed Terms',
        code: 'TERMS_ACCEPTANCE_REQUIRED',
        status: 422,
      );
    }
    throw const ApiFailure('Test does not create profiles.');
  }
}

Future<void> requiredScreen(WidgetTester tester, TermsApi api) async {
  await openSignIn(tester, api);
  await fillSignIn(tester);
  await submitSignIn(tester);
  expect(find.byType(TermsReacceptance), findsNothing);
  expect(api.referenceCalls, 0);
  await tapVisible(tester, 'addChild');
  await tapVisible(tester, 'loadAttempt');
}

void main() {
  test(
    'successful Terms POST cannot override unaccepted parent readback',
    () async {
      final api = TermsApi()..staleParentReadback = true;
      final model = TermsReacceptanceState(api, 'test-parent');
      await model.load();
      model.choose(true);
      expect(await model.accept(), isNull);
      expect(model.error!.code, 'TERMS_VERSION_NOT_CURRENT');
      expect(model.terms, isNull);
      expect(model.agreed, isFalse);
      model.dispose();
    },
  );

  testWidgets('expired Parent auth shows safe account entry guidance', (
    tester,
  ) async {
    final api = TermsApi()
      ..termsFailure = const ApiFailure(
        'PRIVATE SERVER DETAIL',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    await requiredScreen(tester, api);
    await tapVisible(tester, 'reacceptTermsCheckbox');
    await tapVisible(tester, 'reacceptTermsSubmit');
    expect(find.textContaining('Your parent sign-in expired'), findsOneWidget);
    expect(find.textContaining('PRIVATE SERVER DETAIL'), findsNothing);
    expect(find.textContaining('Return to Child Mode'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('reacceptTermsSubmit')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, 'termsAccountEntry');
    await tapVisible(tester, 'confirmAccountEntry');
    expect(find.byKey(const Key('welcomeSignIn')), findsOneWidget);
    expect(find.byType(TermsReacceptance), findsNothing);
  });

  test('unticked acceptance is inert; lost response retries exact version and never creates child consent', () async {
    final api = TermsApi()..loseAck = true;
    final model = TermsReacceptanceState(api, 'test-parent');
    await model.load();
    expect(await model.accept(), isNull);
    expect(api.acceptRequests, isEmpty);
    model.choose(true);
    expect(await model.accept(), isNull);
    expect(model.error!.code, 'CONNECTIVITY');
    final parent = await model.accept();
    expect(parent!.currentTermsAccepted, isTrue);
    expect(api.acceptRequests, [(termsVersion, true), (termsVersion, true)]);
    expect(api.createCalls, 0);
    expect(api.calls, ['me']);
    model.dispose();
  });

  test(
    'concurrent acceptance submits once; disposed context ignores late result',
    () async {
      final api = TermsApi()..gate = Completer<TermsAcceptance>();
      final model = TermsReacceptanceState(api, 'test-parent');
      await model.load();
      model.choose(true);
      final first = model.accept();
      expect(await model.accept(), isNull);
      expect(api.acceptRequests, hasLength(1));
      model.dispose();
      api.gate!.complete(TermsAcceptance(termsVersion, api.currentCode, true));
      expect(await first, isNull);
      expect(api.calls, isEmpty);
    },
  );

  for (final failure in [
    const ApiFailure('Expired', code: 'UNAUTHENTICATED', status: 401),
    const ApiFailure('Inactive', code: 'PARENT_NOT_ACTIVE', status: 403),
    const ApiFailure('Changed', code: 'TERMS_VERSION_NOT_CURRENT', status: 422),
    const ApiFailure(
      'Unavailable',
      code: 'DB_UNAVAILABLE',
      status: 503,
      retryable: true,
    ),
  ]) {
    test(
      '${failure.code} cannot claim acceptance; changed versions require fresh choice',
      () async {
        final api = TermsApi()..termsFailure = failure;
        final model = TermsReacceptanceState(api, 'test-parent');
        await model.load();
        model.choose(true);
        expect(await model.accept(), isNull);
        expect(model.error, same(failure));
        expect(api.termsAccepted, isFalse);
        expect(api.createCalls, 0);
        if (failure.code == 'TERMS_VERSION_NOT_CURRENT') {
          expect(model.terms, isNull);
          expect(model.agreed, isFalse);
          api.currentId = 'new-version';
          await model.load();
          expect(model.agreed, isFalse);
        }
        model.dispose();
      },
    );
  }

  for (final invalid in ['missing-reference', 'wrong-ack', 'wrong-parent']) {
    test('$invalid cannot finish acceptance', () async {
      final api = TermsApi()
        ..missingReference = invalid == 'missing-reference'
        ..wrongAck = invalid == 'wrong-ack'
        ..wrongParent = invalid == 'wrong-parent';
      final model = TermsReacceptanceState(api, 'test-parent');
      await model.load();
      model.choose(true);
      expect(await model.accept(), isNull);
      expect(model.error, isA<ApiInvalidResponse>());
      model.dispose();
    });
  }

  testWidgets(
    'server-required Terms UI is explicit; success returns to separate unchecked child consent',
    (tester) async {
      final api = TermsApi();
      await requiredScreen(tester, api);
      expect(find.textContaining('R0_TEST_TERMS_V2'), findsNWidgets(2));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('reacceptTermsCheckbox')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('reacceptTermsSubmit')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'reacceptTermsCheckbox');
      await tapVisible(tester, 'reacceptTermsSubmit');
      expect(find.byType(TermsReacceptance), findsNothing);
      expect(find.byKey(const Key('loadAttempt')), findsOneWidget);
      expect(api.acceptRequests, [(termsVersion, true)]);
      expect(api.createCalls, 0);
      await tapVisible(tester, 'loadAttempt');
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      ))
        expect(tile.value, isFalse);
    },
  );

  testWidgets(
    'cancel and fresh reload never accept; version changes erase the checked choice',
    (tester) async {
      final api = TermsApi()
        ..termsFailure = const ApiFailure(
          'Version changed',
          code: 'TERMS_VERSION_NOT_CURRENT',
          status: 422,
        );
      await requiredScreen(tester, api);
      await tapVisible(tester, 'reacceptTermsCheckbox');
      await tapVisible(tester, 'reacceptTermsSubmit');
      expect(find.textContaining('TERMS_VERSION_NOT_CURRENT'), findsOneWidget);
      expect(find.byKey(const Key('reacceptTermsCheckbox')), findsNothing);
      api.currentCode = 'R0_TEST_TERMS_V3';
      api.currentId = 'new-version';
      await tapVisible(tester, 'reloadCurrentTerms');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('reacceptTermsCheckbox')),
            )
            .value,
        isFalse,
      );
      await tapVisible(tester, 'cancelTerms');
      expect(find.byType(ParentArea), findsOneWidget);
      expect(api.acceptRequests, hasLength(1));
    },
  );

  testWidgets(
    'required Terms during create discards pending child form and rechecks notices separately',
    (tester) async {
      final api = TermsApi()
        ..requiredTerms = false
        ..termsAccepted = true
        ..rejectCreate = true;
      await openSignIn(tester, api);
      await fillSignIn(tester);
      await submitSignIn(tester);
      await tapVisible(tester, 'addChild');
      await tapVisible(tester, 'loadAttempt');
      await tapVisible(tester, 'guardianAssertion');
      await tapVisible(tester, 'consent-CHILD_PROFILE_AGE');
      await tapVisible(tester, 'consent-LEARNING_PROGRESS');
      await tapVisible(tester, 'privacyContinue');
      await tester.enterText(find.byKey(const Key('childName')), 'SYN-Terms');
      await tester.enterText(find.byKey(const Key('childDob')), '2023-01-01');
      await tapVisible(tester, 'childContinue');
      await tapVisible(tester, 'createChild');
      expect(find.byType(TermsReacceptance), findsOneWidget);
      expect(find.byKey(const Key('childName')), findsNothing);
      await tapVisible(tester, 'reacceptTermsCheckbox');
      await tapVisible(tester, 'reacceptTermsSubmit');
      expect(
        api.createCalls,
        1,
        reason: 'No automatic child creation replay after Terms acceptance.',
      );
      expect(find.byKey(const Key('loadAttempt')), findsOneWidget);
    },
  );

  for (final status in [200, 201]) {
    test(
      'Terms repository accepts $status and sends only exact authenticated Terms fields',
      () async {
        final http = Transport()
          ..replies.add(
            Reply({
              'termsVersionId': termsVersion,
              'code': 'R0_TEST_TERMS_V2',
              'currentTermsAccepted': true,
            }, statusCode: status),
          );
        final api = await authenticated(http);
        final result = await api.acceptCurrentTerms(
          termsVersion,
          termsAccepted: true,
        );
        expect(result.id, termsVersion);
        expect(
          http.requests.last.uri.path,
          '/api/v1/parents/me/terms-acceptances',
        );
        expect(http.requests.last.method, 'POST');
        expect(
          http.requests.last.headers.value('authorization'),
          'Bearer unit-token',
        );
        expect(
          http.requests.last.body,
          '{"termsVersionId":"$termsVersion","termsAccepted":true}',
        );
      },
    );
  }
}
