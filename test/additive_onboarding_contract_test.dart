import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/onboarding_resume.dart';
import 'package:mimigo_frontend/parent_home.dart';
import 'package:mimigo_frontend/terms_reacceptance.dart';

import 'child_onboarding_test.dart'
    show
        ChildApi,
        noticeSnapshot,
        openChildOnboarding,
        affirmNotices,
        reviewChild;
import 'backend_modules_test.dart' show workspaceJson;
import 'parent_home_test.dart' show ParentApi, profile, signInHome;
import 'learning_widget_test.dart' show tapVisible;
import 'learning_api_test.dart' show Transport, Reply, authenticated;

Map<String, dynamic> attemptJson({String status = 'OPEN'}) => {
  'attemptId': 'attempt-1',
  'status': status,
  'expiresAt': '2030-01-01T00:00:00Z',
  'childId': status == 'ATTEMPT_ALREADY_CONSUMED' ? 'child-1' : null,
  'notices': noticeSnapshot()
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
      .toList(),
};

class ResumeApi extends ChildApi {
  String status = 'OPEN';
  int reads = 0;
  ApiFailure? readFailure;
  Completer<OnboardingAttemptStatus>? waiting;
  @override
  Future<OnboardingAttemptStatus> getOnboardingAttempt(String id) async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return waiting?.future ??
        OnboardingAttemptStatus.fromJson({
          ...attemptJson(status: status),
          'attemptId': id,
        });
  }
}

class EntryApi extends ParentApi {
  String? entry = 'READY';
  @override
  Future<ParentWorkspace> learningWorkspace() async {
    final json = workspaceJson();
    final child = (json['children'] as List).single;
    if (entry == null) {
      child.remove('learningEntry');
    } else {
      child['learningEntry'] = {'status': entry!};
    }
    return ParentWorkspace.fromJson(json);
  }
}

void main() {
  for (final status in [
    'OPEN',
    'ATTEMPT_ALREADY_CONSUMED',
    'PARENT_NOT_ACTIVE',
    'TERMS_ACCEPTANCE_REQUIRED',
    'ATTEMPT_EXPIRED',
    'ATTEMPT_NOTICES_INCOMPLETE',
    'NOTICE_CHANGED_REDISPLAY_REQUIRED',
  ]) {
    test(
      'resume GET decodes $status without a POST or expiry change',
      () async {
        final http = Transport()
          ..replies.add(Reply(attemptJson(status: status)));
        final api = await authenticated(http);
        final value = await api.getOnboardingAttempt('attempt-1');
        expect(value.status, status);
        expect(value.attempt.expiresAt, DateTime.utc(2030));
        expect(
          value.childId,
          status == 'ATTEMPT_ALREADY_CONSUMED' ? 'child-1' : null,
        );
        expect(http.requests.last.method, 'GET');
        expect(
          http.requests.last.uri.path,
          '/api/v1/children/onboarding-attempts/attempt-1',
        );
        expect(http.requests.last.body, isEmpty);
        expect(
          http.requests.last.headers.value('authorization'),
          'Bearer unit-token',
        );
        expect(
          http.requests,
          hasLength(2),
          reason: 'Only login and the read; never creates/extends/consumes.',
        );
      },
    );
  }

  for (final mutation in [
    'unknown-status',
    'missing-child',
    'consumed-without-child',
    'open-with-child',
  ]) {
    test('malformed resume $mutation cannot be treated as open or created', () {
      final json = attemptJson();
      switch (mutation) {
        case 'unknown-status':
          json['status'] = 'CREATED';
        case 'missing-child':
          json.remove('childId');
        case 'consumed-without-child':
          json['status'] = 'ATTEMPT_ALREADY_CONSUMED';
        case 'open-with-child':
          json['childId'] = 'other-child';
      }
      expect(
        () => OnboardingAttemptStatus.fromJson(json),
        throwsA(isA<ApiInvalidResponse>()),
      );
    });
  }

  test('resume busy/disposal ignores a late response; mismatched identity is rejected', () async {
    final api = ResumeApi()..waiting = Completer<OnboardingAttemptStatus>();
    final state = OnboardingResumeState(api, 'attempt-1');
    final pending = state.load();
    await state.load();
    expect(api.reads, 1);
    state.dispose();
    api.waiting!.complete(OnboardingAttemptStatus.fromJson(attemptJson()));
    await pending;
    expect(state.snapshot, isNull);
    api.waiting = Completer<OnboardingAttemptStatus>();
    final other = OnboardingResumeState(api, 'attempt-1');
    final read = other.load();
    api.waiting!.complete(
      OnboardingAttemptStatus.fromJson({
        ...attemptJson(),
        'attemptId': 'other-attempt',
      }),
    );
    await read;
    expect(other.snapshot, isNull);
    expect(other.error, isA<ApiInvalidResponse>());
    other.dispose();
  });

  for (final status in [401, 404, 503]) {
    test(
      'resume HTTP $status is not a resumable or consumed response',
      () async {
        final http = Transport()
          ..replies.add(
            Reply({
              'code': status == 404 ? 'ATTEMPT_NOT_FOUND' : 'UNAVAILABLE',
              'message': 'Synthetic failure',
              'requestId': 'test',
            }, statusCode: status),
          );
        final api = await authenticated(http);
        final state = OnboardingResumeState(api, 'attempt-1');
        await state.load();
        expect(state.error!.status, status);
        expect(state.snapshot, isNull);
        state.dispose();
      },
    );
  }

  testWidgets(
    'Góc phụ huynh resumes a known OPEN attempt with original notices and fresh unchecked choices',
    (tester) async {
      final api = ResumeApi();
      await openChildOnboarding(tester, api);
      await tapVisible(tester, 'guardianAssertion');
      await tapVisible(tester, 'privacyParentHome');
      await tapVisible(tester, 'parentResumeOnboarding');
      expect(find.text('Tình trạng: Đang xem xét'), findsOneWidget);
      expect(api.attempts, 1);
      await tapVisible(tester, 'resumeOpenAttempt');
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(tile.value, isFalse);
      }
      expect(find.byKey(const Key('childDob')), findsNothing);
      expect(
        find.byKey(const Key('noticeDocumentUnavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
      expect(api.requests, isEmpty);
      expect(api.attempts, 1, reason: 'A resume never creates a new attempt.');
    },
  );

  testWidgets(
    'read after lost creation acknowledgment finds consumed child without another creation',
    (tester) async {
      final api = ResumeApi()
        ..loseAck = true
        ..status = 'ATTEMPT_ALREADY_CONSUMED';
      await openChildOnboarding(tester, api);
      await affirmNotices(tester);
      await reviewChild(tester);
      await tapVisible(tester, 'createChild');
      await tapVisible(tester, 'checkCreationAttempt');
      expect(find.text('Tình trạng: Đã tạo hồ sơ'), findsOneWidget);
      expect(find.byKey(const Key('resumeOpenAttempt')), findsNothing);
      await tapVisible(tester, 'resumeConsumedHome');
      expect(find.byType(ParentArea), findsOneWidget);
      expect(find.text('SYN-Bee'), findsOneWidget);
      expect(find.byType(ChildHome), findsNothing);
      expect(api.requests, hasLength(1));
      expect(find.byKey(const Key('parentResumeOnboarding')), findsNothing);
    },
  );

  testWidgets(
    'OPEN read after failed creation preserves the identical locked request',
    (tester) async {
      final api = ResumeApi()
        ..createFailure = const ApiFailure(
          'offline',
          code: 'CONNECTIVITY',
          retryable: true,
        );
      await openChildOnboarding(tester, api);
      await affirmNotices(tester);
      await reviewChild(tester);
      await tapVisible(tester, 'createChild');
      final original = api.requests.single;
      await tapVisible(tester, 'checkCreationAttempt');
      await tapVisible(tester, 'resumeOpenAttempt');
      expect(find.byType(Review), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      api.createFailure = null;
      await tapVisible(tester, 'createChild');
      expect(api.requests.last, same(original));
      expect(api.attempts, 1);
    },
  );

  for (final status in [
    'ATTEMPT_EXPIRED',
    'ATTEMPT_NOTICES_INCOMPLETE',
    'NOTICE_CHANGED_REDISPLAY_REQUIRED',
  ]) {
    testWidgets(
      '$status requires a new privacy review rather than reusing notices',
      (tester) async {
        final api = ResumeApi()..status = status;
        await openChildOnboarding(tester, api);
        await tapVisible(tester, 'checkPrivacyAttempt');
        expect(find.byKey(const Key('resumeOpenAttempt')), findsNothing);
        await tapVisible(tester, 'resumeNewAttempt');
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
        expect(api.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'Terms-required status reaches only explicit existing account Terms flow',
    (tester) async {
      final api = ResumeApi()..status = 'TERMS_ACCEPTANCE_REQUIRED';
      await openChildOnboarding(tester, api);
      await tapVisible(tester, 'checkPrivacyAttempt');
      expect(find.byKey(const Key('resumeOpenAttempt')), findsNothing);
      await tapVisible(tester, 'resumeTerms');
      expect(find.byType(TermsReacceptance), findsOneWidget);
      expect(find.byKey(const Key('termsDocumentUnavailable')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('reacceptTermsSubmit')))
            .onPressed,
        isNull,
      );
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'account return forgets the known attempt and never exposes resume in Child Mode',
    (tester) async {
      final api = ResumeApi();
      await openChildOnboarding(tester, api);
      await tapVisible(tester, 'checkPrivacyAttempt');
      await tapVisible(tester, 'resumeAccountEntry');
      await tapVisible(tester, 'confirmAccountEntry');
      expect(find.byKey(const Key('parentResumeOnboarding')), findsNothing);
      expect(find.byType(OnboardingAttemptResume), findsNothing);
      expect(api.reads, 1);
    },
  );

  for (final entry in [
    'READY',
    'PERMISSION_NOT_GRANTED',
    'CHILD_NOT_ACTIVE',
    'CHILD_OUTSIDE_PROGRAM_AGE',
    'NO_ELIGIBLE_CONTENT',
  ]) {
    testWidgets(
      'Parent entry uses $entry independently from AVAILABLE catalog',
      (tester) async {
        final api = EntryApi()
          ..profiles = [profile('A')]
          ..entry = entry;
        await signInHome(tester, api);
        await tapVisible(tester, 'parent-child-A');
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('parentEnterLearning')),
              )
              .onPressed,
          {'READY', 'NO_ELIGIBLE_CONTENT'}.contains(entry) ? isNotNull : isNull,
        );
        expect(find.byKey(const Key('parentLearningEntry')), findsOneWidget);
        expect(find.textContaining('SECRET HISTORY'), findsNothing);
        expect(find.textContaining('PROTECTED-SESSION'), findsNothing);
      },
    );
  }

  for (final entry in [null, 'AVAILABLE']) {
    test(
      'missing/unknown learningEntry $entry fails closed with no catalog fallback',
      () {
        final json = workspaceJson();
        final child = (json['children'] as List).single;
        if (entry == null) {
          child.remove('learningEntry');
        } else {
          child['learningEntry'] = {'status': entry};
        }
        expect(
          () => ParentWorkspace.fromJson(json),
          throwsA(isA<ApiInvalidResponse>()),
        );
      },
    );
  }

  test(
    'entry refresh denial discards prior READY and selected child',
    () async {
      final api = EntryApi()..profiles = [profile('A')];
      final state = ParentHomeState(api);
      await state.refresh();
      await state.choose('A');
      expect(state.canEnter, isTrue);
      api.entry = null;
      await state.refresh();
      expect(state.canEnter, isFalse);
      expect(state.learningEntryStatuses, isEmpty);
      expect(state.selected, isNull);
      state.dispose();
    },
  );
}
