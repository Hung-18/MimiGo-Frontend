import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart';
import 'learning_widget_test.dart' show lessonScreen, rootMath, tapVisible;

Future<void> press(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> answer(WidgetTester tester, String cue, String option) async {
  await tapVisible(tester, 'option-$option');
  await tapVisible(tester, 'submit-$cue');
}

FilledButton completeButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('completeLearning')));

Future<void> answeredScreen(WidgetTester tester, CompletionApi api) async {
  api.seedWrongAnswers(sessionId);
  await lessonScreen(tester, api);
  await tapVisible(tester, 'startLearning');
}

void main() {
  testWidgets(
    'final explanation precedes explicit Complete; only server acknowledgment completes',
    (tester) async {
      final api = CompletionApi(twoCues: true)
        ..completeGate = Completer<LearningSession>();
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(completeButton(tester).onPressed, isNull);
      expect(find.textContaining('Incorrect'), findsNothing);
      await answer(tester, cueId, optionId);
      expect(completeButton(tester).onPressed, isNull);
      await answer(tester, secondCueId, secondOptionId);
      expect(find.textContaining('Final server explanation'), findsOneWidget);
      expect(api.completionCalls, isEmpty);
      expect(completeButton(tester).onPressed, isNotNull);
      await press(tester, 'completeLearning');
      expect(api.completionCalls, [sessionId]);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      expect(completeButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('option-$optionId')))
            .onPressed,
        isNull,
      );
      await press(tester, 'completeLearning');
      expect(api.completionCalls, [sessionId]);
      api.completeGate!.complete(api.completeReply(sessionId));
      await tester.pumpAndSettle();
      expect(find.text('Session: COMPLETED'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('completedSessionIdentity')))
            .data,
        contains(sessionId),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('completedEndedAt'))).data,
        contains('2026-10-23T12:05:00.000Z'),
      );
      expect(find.byKey(const Key('submit-$cueId')), findsNothing);
      expect(find.byKey(const Key('completeLearning')), findsNothing);
    },
  );

  testWidgets(
    'replay starts a new session; history stays read-only and active replay remains resumable',
    (tester) async {
      final api = CompletionApi();
      await answeredScreen(tester, api);
      await tapVisible(tester, 'completeLearning');
      api.replayGate = Completer<LearningSession>();
      await press(tester, 'replayLearning');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('replayLearning')))
            .onPressed,
        isNull,
      );
      expect(api.startBodies, [lessonId, lessonId]);
      api.replayGate!.complete(api.prepareReplay());
      await tester.pumpAndSettle();
      expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsNothing);
      expect(find.byKey(const Key('feedback-$cueId')), findsNothing);
      expect(completeButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('history-$sessionId')), findsOneWidget);
      await answer(tester, cueId, optionId);
      expect(api.events[replaySessionId], hasLength(1));
      expect(api.events[sessionId], hasLength(1));
      await tapVisible(tester, 'readCompleted-$sessionId');
      expect(api.readIds.last, sessionId);
      expect(find.text('Session: COMPLETED'), findsOneWidget);
      expect(find.text('Continue replay session'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('option-$optionId')))
            .onPressed,
        isNull,
      );
      api.replayGate = null;
      await tapVisible(tester, 'replayLearning');
      expect(api.readIds.last, replaySessionId);
      expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      expect(api.snapshot(sessionId).endedAt, DateTime.parse(completedTime));
    },
  );

  testWidgets(
    'Back and reopen read completed identity without implicitly starting a replay; Parent Gate remains locked',
    (tester) async {
      final api = CompletionApi()..seedWrongAnswers(sessionId);
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'completeLearning');
      await tapVisible(tester, 'lessonBack');
      await tapVisible(tester, 'lesson-$lessonId');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(api.starts, 1);
      expect(api.readIds.last, sessionId);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-$lessonId')), findsOneWidget);
      await tapVisible(tester, 'categoryBack');
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'completion acknowledgment arriving after Back is retained on revisit without a duplicate',
    (tester) async {
      final api = CompletionApi()..completeGate = Completer<LearningSession>();
      api.seedWrongAnswers(sessionId);
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await press(tester, 'completeLearning');
      await press(tester, 'lessonBack');
      await tester.pumpAndSettle();
      await press(tester, 'lesson-$lessonId');
      await tester.pump();
      expect(completeButton(tester).onPressed, isNull);
      expect(api.completionCalls, [sessionId]);
      api.completeGate!.complete(api.completeReply(sessionId));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(api.completionCalls, [sessionId]);
    },
  );

  for (final code in ['SESSION_INCOMPLETE', 'SESSION_NOT_ACTIVE']) {
    testWidgets(
      '$code never optimistically completes and reconciles through GET',
      (tester) async {
        final api = CompletionApi()
          ..completeFailure = ApiFailure(
            'Safe conflict.',
            code: code,
            status: 409,
          );
        await answeredScreen(tester, api);
        await tapVisible(tester, 'completeLearning');
        expect(find.textContaining(code), findsOneWidget);
        expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
        expect(find.byKey(const Key('completionConfirmed')), findsNothing);
        expect(
          completeButton(tester).onPressed,
          code == 'SESSION_NOT_ACTIVE' ? isNull : isNotNull,
        );
        if (code == 'SESSION_NOT_ACTIVE') {
          api.completeReply(sessionId);
        } else {
          api.events[sessionId]!.clear();
        }
        api.completeFailure = null;
        await tapVisible(tester, 'startLearning');
        if (code == 'SESSION_NOT_ACTIVE') {
          expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
        } else {
          expect(completeButton(tester).onPressed, isNull);
          await answer(tester, cueId, optionId);
          await tapVisible(tester, 'completeLearning');
          expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
        }
      },
    );
  }

  for (final status in [401, 403, 404]) {
    testWidgets(
      'completion HTTP $status hides interaction without faking success',
      (tester) async {
        final api = CompletionApi()
          ..completeFailure = ApiFailure(
            'Safe denial.',
            code: 'DENIED_$status',
            status: status,
          );
        await answeredScreen(tester, api);
        await tapVisible(tester, 'completeLearning');
        expect(find.textContaining('DENIED_$status'), findsOneWidget);
        expect(find.byKey(const Key('completionConfirmed')), findsNothing);
        expect(find.byKey(const Key('option-$optionId')), findsNothing);
        expect(find.text('Known completed sessions'), findsNothing);
        expect(find.byKey(const Key('startLearning')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'lost completion response leaves IN_PROGRESS; retry confirms the same server identity and endedAt',
    (tester) async {
      final api = CompletionApi()..loseCompletionAck = true;
      await answeredScreen(tester, api);
      await tapVisible(tester, 'completeLearning');
      expect(find.textContaining('CONNECTIVITY'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('option-$optionId')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'completeLearning');
      expect(api.completionCalls, [sessionId, sessionId]);
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(api.snapshot(sessionId).endedAt, DateTime.parse(completedTime));
    },
  );

  testWidgets(
    'temporary completion failure and invalid acknowledgment never invent endedAt',
    (tester) async {
      final api = CompletionApi()
        ..completeFailure = const ApiFailure(
          'Try later.',
          code: 'DB_UNAVAILABLE',
          status: 503,
          retryable: true,
        );
      await answeredScreen(tester, api);
      await tapVisible(tester, 'completeLearning');
      expect(find.textContaining('DB_UNAVAILABLE'), findsOneWidget);
      expect(find.byKey(const Key('completedEndedAt')), findsNothing);
      api.completeFailure = null;
      api.completionOverride = {
        ...completedJson(),
        'sessionId': replaySessionId,
      };
      await tapVisible(tester, 'completeLearning');
      expect(find.textContaining('INVALID_RESPONSE'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      api.completionOverride = null;
      await tapVisible(tester, 'completeLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
    },
  );

  testWidgets(
    'lost replay response preserves completed history; retry reuses the new session',
    (tester) async {
      final api = CompletionApi()..loseReplayAck = true;
      await answeredScreen(tester, api);
      await tapVisible(tester, 'completeLearning');
      await tapVisible(tester, 'replayLearning');
      expect(find.textContaining('CONNECTIVITY'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(find.byKey(const Key('history-$sessionId')), findsOneWidget);
      await tapVisible(tester, 'replayLearning');
      expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
      expect(api.activeId, replaySessionId);
      expect(api.data, hasLength(2));
      expect(api.snapshot(sessionId).endedAt, DateTime.parse(completedTime));
    },
  );

  testWidgets(
    'an unacknowledged answer must be retried before Complete is enabled',
    (tester) async {
      final api = CompletionApi()..seedWrongAnswers(sessionId);
      final pending = PendingLearningAnswers();
      pending.prepare(childId, sessionId, cueId, optionId);
      await lessonScreen(tester, api, pending: pending);
      await tapVisible(tester, 'startLearning');
      expect(completeButton(tester).onPressed, isNull);
      await tapVisible(tester, 'submit-$cueId');
      expect(pending.find(childId, sessionId, cueId), isNull);
      expect(completeButton(tester).onPressed, isNotNull);
    },
  );
}
