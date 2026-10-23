import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

import 'live_auth_test.dart' show TracedLiveApi, waitFor, tap;

class LearningLiveTrace extends TracedLiveApi {
  LearningLiveTrace(super.baseUri);
  LessonDetail? details;
  SessionDetail? readback;
  final sent = <AnswerRequest>[];
  final received = <AnswerFeedback>[];
  LearningSession? completed;
  int starts = 0;
  bool dropNextAck = true;
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async {
    details = await trace(
      'learning.detail',
      () => super.lesson(childId, lessonId),
    );
    return details!;
  }

  @override
  Future<LearningSession> startLearning(String childId, String lessonId) {
    starts++;
    return trace(
      'learning.start-or-reuse',
      () => super.startLearning(childId, lessonId),
    );
  }

  @override
  Future<SessionDetail> learningSession(
    String childId,
    String sessionId,
  ) async {
    readback = await trace(
      'learning.readback',
      () => super.learningSession(childId, sessionId),
    );
    return readback!;
  }

  @override
  Future<LearningSession> completeLearning(
    String childId,
    String sessionId,
  ) async {
    completed = await trace(
      'learning.complete',
      () => super.completeLearning(childId, sessionId),
    );
    return completed!;
  }

  @override
  Future<AnswerFeedback> submitAnswer(
    String childId,
    String sessionId,
    AnswerRequest request,
  ) async {
    sent.add(request);
    final reply = await trace(
      'learning.answer',
      () => super.submitAnswer(childId, sessionId, request),
    );
    received.add(reply);
    if (dropNextAck) {
      // Real server persisted the answer. Only this test wrapper drops its ack.
      dropNextAck = false;
      throw const ApiFailure(
        'Controlled test: answer response lost after server acknowledgment.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
    return reply;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'S2 Android live Math answer, completion, replay and preserved history',
    (tester) async {
      final config = ApiConfiguration.fromEnvironment();
      expect(config.mode, ApiMode.live);
      final api = LearningLiveTrace(Uri.parse(config.baseUrl));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 's2-$suffix@example.test';
      final password = 'SYN-${Random.secure().nextInt(1 << 30)}-$suffix';
      // Synthetic setup through the existing API only; no DB access or secrets.
      final reference = await api.onboardingReference();
      final registration = await api.register(
        Registration(
          email,
          password,
          'SYN S2 Parent',
          reference.terms!.id,
          true,
        ),
      );
      expect(registration.mockOtp, isNotNull);
      await api.verifyMockEmail(email: email, otp: registration.mockOtp!);
      await api.login(email: email, password: password);
      final attempt = await api.beginOnboardingAttempt();
      final child = await api.createChild(
        CreateChildRequest(
          attemptId: attempt.id,
          idempotencyKey: 's2-$suffix',
          childAlias: 'SYN-S2-$suffix',
          dateOfBirth: DateTime(DateTime.now().year - 3, 1, 1),
          stockAvatarKey: 'bear-blue',
          guardianAffirmed: true,
          purposeChoices: attempt.notices
              .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
              .toList(),
        ),
      );
      api.clearSession();
      await tester.pumpWidget(MimiGoApp(api: api, configuration: config));
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(find.byKey(const Key('signInEmail')), email);
      await tester.enterText(find.byKey(const Key('signInPassword')), password);
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.text(child.alias));
      await tester.tap(find.text(child.alias));
      await waitFor(tester, find.byKey(const Key('parentEnterLearning')));
      await tap(tester, 'parentEnterLearning');
      await waitFor(tester, find.text('Hi, ${child.alias}!'));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'category-math');
      await waitFor(tester, find.textContaining('SYN-MATH-001'));
      final listing = api.catalog!.items.singleWhere(
        (lesson) => lesson.lessonCode == 'SYN-MATH-001',
      );
      await tap(tester, 'lesson-${listing.lessonId}');
      await waitFor(tester, find.byKey(const Key('startLearning')));
      expect(find.byKey(const Key('learningError')), findsNothing);
      final cues = List<LearningCue>.of(api.details!.cues)
        ..sort((a, b) => a.seq.compareTo(b.seq));
      expect(cues, isNotEmpty);
      final cue = cues.first;
      expect(cue.options, isNotEmpty);
      expect(find.byKey(Key('feedback-${cue.cueId}')), findsNothing);
      await tap(tester, 'startLearning');
      await waitFor(
        tester,
        find.byKey(Key('option-${cue.options.first.optionId}')),
      );
      final sessionId = api.readback!.sessionId;
      await tap(tester, 'option-${cue.options.first.optionId}');
      await tap(tester, 'submit-${cue.cueId}');
      await waitFor(tester, find.text('Retry same answer'));
      expect(api.sent, hasLength(1));
      expect(api.received, hasLength(1));
      await tap(tester, 'lessonBack');
      await waitFor(tester, find.byKey(Key('lesson-${listing.lessonId}')));
      await tap(tester, 'lesson-${listing.lessonId}');
      await waitFor(tester, find.byKey(const Key('startLearning')));
      await tap(tester, 'startLearning');
      await waitFor(tester, find.byKey(Key('recorded-${cue.cueId}-1')));
      expect(api.readback!.sessionId, sessionId);
      expect(api.readback!.answers, hasLength(1));
      expect(
        find.byKey(Key('feedback-${cue.cueId}')),
        findsNothing,
        reason: 'Persisted readback has no explanatory feedback field.',
      );
      await tap(tester, 'submit-${cue.cueId}');
      await waitFor(tester, find.byKey(Key('feedback-${cue.cueId}')));
      expect(api.sent[1].toJson(), api.sent[0].toJson());
      expect(api.received[1].answerEventId, api.received[0].answerEventId);
      expect(find.textContaining(api.received[1].feedbackText), findsOneWidget);
      final latest = await api.learningSession(child.id, sessionId);
      expect(latest.answers, hasLength(1));
      expect(latest.state, 'IN_PROGRESS');
      for (final remaining in cues.skip(1)) {
        expect(remaining.options, isNotEmpty);
        await tap(tester, 'option-${remaining.options.first.optionId}');
        await tap(tester, 'submit-${remaining.cueId}');
        await waitFor(tester, find.byKey(Key('feedback-${remaining.cueId}')));
      }
      expect(api.completed, isNull, reason: 'Completion must be explicit.');
      await tap(tester, 'completeLearning');
      await waitFor(tester, find.byKey(const Key('completionConfirmed')));
      final completed = api.completed!;
      expect(completed.sessionId, sessionId);
      expect(completed.state, 'COMPLETED');
      expect(completed.endedAt, isNotNull);
      final repeated = await api.completeLearning(child.id, sessionId);
      expect(repeated.sessionId, sessionId);
      expect(repeated.endedAt, completed.endedAt);
      await tap(tester, 'lessonBack');
      await waitFor(tester, find.byKey(Key('lesson-${listing.lessonId}')));
      await tap(tester, 'lesson-${listing.lessonId}');
      await waitFor(tester, find.byKey(const Key('completionConfirmed')));
      expect(api.readback!.sessionId, sessionId);
      expect(api.readback!.endedAt, completed.endedAt);
      await tap(tester, 'replayLearning');
      await waitFor(tester, find.text('Session: IN_PROGRESS'));
      final replay = api.readback!;
      expect(replay.sessionId, isNot(sessionId));
      expect(replay.endedAt, isNull);
      expect(replay.answers, isEmpty);
      expect(find.byKey(const Key('completeLearning')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('completeLearning')))
            .onPressed,
        isNull,
        reason: 'Previous session answers cannot complete a replay.',
      );
      await tap(tester, 'readCompleted-$sessionId');
      await waitFor(tester, find.byKey(const Key('completionConfirmed')));
      expect(api.readback!.sessionId, sessionId);
      expect(api.readback!.endedAt, completed.endedAt);
      expect(api.readback!.answers.length, api.details!.cues.length);
      expect(find.byKey(Key('history-$sessionId')), findsOneWidget);
      final startsBeforeContinue = api.starts;
      await tap(tester, 'replayLearning');
      await waitFor(tester, find.text('Session: IN_PROGRESS'));
      expect(api.readback!.sessionId, replay.sessionId);
      expect(
        api.starts,
        startsBeforeContinue,
        reason: 'Continue replay reads its known ID; it must not start again.',
      );
      await tap(tester, 'lessonHome');
      await waitFor(tester, find.text('Hi, ${child.alias}!'));
      expect(find.byType(ParentArea), findsNothing);
      debugPrint(
        'S2 ANDROID LIVE PASS: server Math catalog/detail; exact answer retry; explicit completion with server endedAt; idempotent completion; completed readback; new replay session without inherited answers; completed history preserved. No media playback.',
      );
    },
  );
}
