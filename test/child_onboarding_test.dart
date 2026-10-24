import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_onboarding.dart';

import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;
import 'learning_widget_test.dart' show tapVisible;
import 'learning_api_test.dart' show Transport, Reply, authenticated;

List<Notice> noticeSnapshot() => [
  for (final code in ['CHILD_PROFILE_AGE', 'LEARNING_PROGRESS'])
    Notice(
      code,
      '$code-version',
      'SYN_NOTICE_V1',
      contentHash: List.filled(64, 'a').join(),
      effectiveFrom: DateTime.utc(2026, 1, 1),
      isApprovedForRealUsers: false,
    ),
];

class ChildApi extends AuthApi {
  int attempts = 0;
  bool eligible = true, loseAck = false, wrongChild = false;
  int reportedAge = 3;
  ApiFailure? createFailure, attemptFailure;
  Completer<ChildSummary>? pendingCreation;
  final requests = <CreateChildRequest>[];
  final results = <String, ChildSummary>{};
  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() async {
    attempts++;
    if (attemptFailure != null) throw attemptFailure!;
    return OnboardingAttempt(
      'attempt-$attempts',
      DateTime(2030),
      noticeSnapshot(),
    );
  }

  @override
  Future<ChildSummary> createChild(CreateChildRequest request) async {
    requests.add(request);
    if (pendingCreation != null) return pendingCreation!.future;
    if (createFailure != null) throw createFailure!;
    final child = results.putIfAbsent(request.idempotencyKey, () {
      final value = ChildSummary(
        id: 'child-${results.length + 1}',
        alias: wrongChild ? 'SYN-Wrong' : request.childAlias,
        dateOfBirth: request.dateOfBirth,
        stockAvatarKey: request.stockAvatarKey,
        ageYears: reportedAge,
        withinProgramAgeRange: eligible,
        state: 'ACTIVE',
        createdAt: DateTime(2030),
      );
      profiles.add(value);
      return value;
    });
    if (loseAck) {
      loseAck = false;
      throw const ApiFailure(
        'Lost response',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
    return child;
  }
}

CreateChildRequest childRequest({String key = 'synthetic-create-1'}) =>
    CreateChildRequest(
      attemptId: 'attempt-1',
      idempotencyKey: key,
      childAlias: 'SYN-Bee',
      dateOfBirth: DateTime(2023, 2, 28),
      stockAvatarKey: 'bear-blue',
      guardianAffirmed: true,
      purposeChoices: noticeSnapshot()
          .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
          .toList(),
    );

Future<void> openChildOnboarding(WidgetTester tester, ChildApi api) async {
  await openSignIn(tester, api);
  await fillSignIn(tester);
  await submitSignIn(tester);
  await tapVisible(tester, 'addChild');
  await tapVisible(tester, 'loadAttempt');
}

Future<void> affirmNotices(WidgetTester tester) async {
  for (final key in [
    'guardianAssertion',
    'consent-CHILD_PROFILE_AGE',
    'consent-LEARNING_PROGRESS',
  ]) {
    await tapVisible(tester, key);
  }
  await tapVisible(tester, 'privacyContinue');
}

Future<void> reviewChild(
  WidgetTester tester, {
  String alias = 'SYN-Bee',
  String dob = '2023-02-28',
}) async {
  await tester.enterText(find.byKey(const Key('childName')), alias);
  await tester.enterText(find.byKey(const Key('childDob')), dob);
  await tapVisible(tester, 'childContinue');
}

void main() {
  test('creation lost acknowledgment retains exact payload/key and one child identity', () async {
    final api = ChildApi()..loseAck = true;
    final request = childRequest();
    final model = ChildCreationState(api, request);
    expect(await model.submit(), isNull);
    expect(model.canEdit, isFalse);
    expect(model.canSubmit, isTrue);
    final child = await model.submit();
    expect(child!.id, 'child-1');
    expect(api.requests, [same(request), same(request)]);
    expect(api.profiles, hasLength(1));
    expect(await model.submit(), isNull);
    expect(api.requests, hasLength(2));
    model.dispose();
  });

  test(
    'creation busy/disposed state cannot submit twice or accept a late result',
    () async {
      final api = ChildApi()..pendingCreation = Completer<ChildSummary>();
      final model = ChildCreationState(api, childRequest());
      final pending = model.submit();
      expect(await model.submit(), isNull);
      expect(api.requests, hasLength(1));
      model.dispose();
      api.pendingCreation!.complete(
        ChildSummary(
          id: 'child-1',
          alias: 'SYN-Bee',
          dateOfBirth: DateTime(2023, 2, 28),
          ageYears: 3,
          withinProgramAgeRange: true,
          state: 'ACTIVE',
          createdAt: DateTime(2030),
          stockAvatarKey: 'bear-blue',
        ),
      );
      expect(await pending, isNull);
      expect(model.result, isNull);
    },
  );

  for (final code in [
    'ATTEMPT_EXPIRED',
    'ATTEMPT_NOT_FOUND',
    'NOTICE_CHANGED_REDISPLAY_REQUIRED',
    'CORE_PERMISSION_REQUIRED',
    'ATTEMPT_ALREADY_CONSUMED',
    'IDEMPOTENCY_CONFLICT',
    'UNAUTHENTICATED',
    'PARENT_NOT_ACTIVE',
  ]) {
    test('$code stops creation and exposes no successful child', () async {
      final status = switch (code) {
        'UNAUTHENTICATED' => 401,
        'PARENT_NOT_ACTIVE' => 403,
        'ATTEMPT_NOT_FOUND' => 404,
        'ATTEMPT_ALREADY_CONSUMED' ||
        'IDEMPOTENCY_CONFLICT' ||
        'NOTICE_CHANGED_REDISPLAY_REQUIRED' => 409,
        _ => 422,
      };
      final api = ChildApi()
        ..createFailure = ApiFailure('PRIVATE', code: code, status: status);
      final model = ChildCreationState(api, childRequest());
      expect(await model.submit(), isNull);
      expect(model.result, isNull);
      expect(model.canSubmit, isFalse);
      expect(api.profiles, isEmpty);
      model.dispose();
    });
  }

  test('wrong child response is not a confirmed creation', () async {
    final model = ChildCreationState(
      ChildApi()..wrongChild = true,
      childRequest(),
    );
    expect(await model.submit(), isNull);
    expect(model.error, isA<ApiInvalidResponse>());
    expect(model.result, isNull);
    model.dispose();
  });

  testWidgets(
    'notice metadata precedes DOB and independent required choices; refusal returns to Parent Home',
    (tester) async {
      final api = ChildApi();
      await openChildOnboarding(tester, api);
      expect(find.byKey(const Key('childDob')), findsNothing);
      expect(find.textContaining('Content hash:'), findsNWidgets(2));
      expect(
        find.textContaining('not a production legal consent flow'),
        findsOneWidget,
      );
      await tapVisible(tester, 'guardianAssertion');
      await tapVisible(tester, 'consent-CHILD_PROFILE_AGE');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'privacyDecline');
      expect(api.requests, isEmpty);
      await tapVisible(tester, 'refusalParentHome');
      expect(find.byType(ParentArea), findsOneWidget);
      expect(api.profiles, isEmpty);
    },
  );

  testWidgets(
    'fresh notices erase prior choices and first-child success uses service eligibility before entry',
    (tester) async {
      final api = ChildApi()
        ..reportedAge = 7
        ..eligible = false;
      await openChildOnboarding(tester, api);
      await tapVisible(tester, 'guardianAssertion');
      await tapVisible(tester, 'consent-CHILD_PROFILE_AGE');
      await tapVisible(tester, 'reloadPrivacyNotices');
      expect(api.attempts, 2);
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(tile.value, isFalse);
      }
      await affirmNotices(tester);
      await tapVisible(tester, 'avatar-bee-yellow');
      await reviewChild(tester, dob: '2020-02-29');
      await tapVisible(tester, 'createChild');
      expect(find.byType(ChildCreated), findsOneWidget);
      expect(find.byType(ChildHome), findsNothing);
      expect(find.textContaining('Age returned by service: 7'), findsOneWidget);
      expect(
        find.textContaining('outside the program age range'),
        findsOneWidget,
      );
      expect(api.requests.single.stockAvatarKey, 'bee-yellow');
      expect(api.requests.single.attemptId, 'attempt-2');
      await tapVisible(tester, 'createdParentHome');
      expect(find.byType(ParentArea), findsOneWidget);
      expect(find.text('SYN-Bee'), findsOneWidget);
    },
  );

  testWidgets(
    'expired creation restarts privacy, clears DOB and requires new independent choices',
    (tester) async {
      final api = ChildApi()
        ..createFailure = const ApiFailure(
          'PRIVATE',
          code: 'ATTEMPT_EXPIRED',
          status: 422,
        );
      await openChildOnboarding(tester, api);
      await affirmNotices(tester);
      await reviewChild(tester);
      await tapVisible(tester, 'createChild');
      expect(find.byType(ChildCreated), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await tapVisible(tester, 'restartChildPrivacy');
      expect(find.byKey(const Key('childDob')), findsNothing);
      await tapVisible(tester, 'loadAttempt');
      expect(api.attempts, 2);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('guardianAssertion')),
            )
            .value,
        isFalse,
      );
      expect(api.requests, hasLength(1));
    },
  );

  testWidgets(
    'unknown creation outcome locks edits and system Back; retry keeps identity',
    (tester) async {
      final api = ChildApi()..loseAck = true;
      await openChildOnboarding(tester, api);
      await affirmNotices(tester);
      await reviewChild(tester);
      await tapVisible(tester, 'createChild');
      expect(find.byType(BackButton), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Review), findsOneWidget);
      await tapVisible(tester, 'createChild');
      expect(find.byType(ChildCreated), findsOneWidget);
      expect(api.requests[0].toJson(), api.requests[1].toJson());
      expect(api.profiles, hasLength(1));
    },
  );

  test('onboarding repository displays exact snapshot metadata before echoing version choices', () async {
    final notices = noticeSnapshot()
        .map(
          (n) => {
            'purposeCode': n.purposeCode,
            'noticeVersionId': n.versionId,
            'versionLabel': n.label,
            'contentHash': n.contentHash,
            'effectiveFrom': n.effectiveFrom!.toIso8601String(),
            'isApprovedForRealUsers': false,
          },
        )
        .toList();
    final request = childRequest();
    final body = {
      'childId': 'child-1',
      'childAlias': request.childAlias,
      'dateOfBirth': dateText(request.dateOfBirth),
      'stockAvatarKey': request.stockAvatarKey,
      'ageYears': 3,
      'withinProgramAgeRange': true,
      'state': 'ACTIVE',
      'createdAt': '2026-10-24T00:00:00Z',
    };
    final http = Transport()
      ..replies.addAll([
        Reply({
          'attemptId': 'attempt-1',
          'expiresAt': '2030-01-01T00:00:00Z',
          'notices': notices,
        }, statusCode: 201),
        Reply(body, statusCode: 201),
        Reply(body),
      ]);
    final api = await authenticated(http);
    final attempt = await api.beginOnboardingAttempt();
    expect(http.requests.last.uri.path, '/api/v1/children/onboarding-attempts');
    expect(http.requests.last.body, isEmpty);
    expect(attempt.notices.first.contentHash, notices.first['contentHash']);
    expect(attempt.notices.first.isApprovedForRealUsers, isFalse);
    expect(
      (await api.createChild(request)).id,
      (await api.createChild(request)).id,
    );
    expect(http.requests.last.uri.path, '/api/v1/children');
    expect(
      http.requests.last.headers.value('authorization'),
      'Bearer unit-token',
    );
    expect(jsonDecode(http.requests.last.body), request.toJson());
    expect(jsonDecode(http.requests.last.body), isNot(contains('ageYears')));
  });

  test(
    'invalid notice metadata fails closed instead of allowing DOB collection',
    () async {
      final http = Transport()
        ..replies.add(
          Reply({
            'attemptId': 'attempt-1',
            'expiresAt': '2030-01-01T00:00:00Z',
            'notices': [
              {
                'purposeCode': 'CHILD_PROFILE_AGE',
                'noticeVersionId': 'notice',
                'versionLabel': 'v1',
              },
            ],
          }),
        );
      final api = await authenticated(http);
      await expectLater(
        api.beginOnboardingAttempt(),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
}
