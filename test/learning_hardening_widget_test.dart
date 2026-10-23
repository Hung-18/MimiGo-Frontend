import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart';
import 'learning_widget_test.dart' show lessonScreen, rootMath, tapVisible;
import 'learning_completion_widget_test.dart' show press;

void main() {
  testWidgets(
    'Back/reopen during initial start performs one POST and one validated GET',
    (tester) async {
      final api = CompletionApi()..startGate = Completer<LearningSession>();
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await press(tester, 'startLearning');
      await press(tester, 'lessonBack');
      await tester.pumpAndSettle();
      await press(tester, 'lesson-$lessonId');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(api.starts, 1);
      api.startGate!.complete(LearningSession.fromJson(sessionJson()));
      await tester.pumpAndSettle();
      expect(api.starts, 1);
      expect(api.reads, 1);
      expect(find.byKey(const Key('option-$optionId')), findsOneWidget);
    },
  );

  testWidgets(
    'Back/reopen cannot send a second answer while the first request is in flight',
    (tester) async {
      final api = CompletionApi()..answerGate = Completer<AnswerFeedback>();
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await press(tester, 'submit-$cueId');
      final original = api.submitted.single;
      await press(tester, 'lessonBack');
      await tester.pumpAndSettle();
      await press(tester, 'lesson-$lessonId');
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit-$cueId')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('completeLearning')))
            .onPressed,
        isNull,
      );
      expect(api.submitted, hasLength(1));
      api.events[sessionId]![original.clientEventId] = feedbackJson();
      api.answerGate!.complete(AnswerFeedback.fromJson(feedbackJson()));
      await tester.pumpAndSettle();
      api.answerGate = null;
      await tapVisible(tester, 'submit-$cueId');
      expect(api.submitted.last.toJson(), original.toJson());
      expect(api.events[sessionId], hasLength(1));
      expect(find.byKey(const Key('feedback-$cueId')), findsOneWidget);
    },
  );

  for (final operation in ['answer', 'complete', 'replay']) {
    for (final status in [401, 403, 404]) {
      testWidgets(
        'late $operation HTTP $status hides revisited interaction and history',
        (tester) async {
          final api = CompletionApi()..seedWrongAnswers(sessionId);
          if (operation == 'answer')
            api.answerGate = Completer<AnswerFeedback>();
          if (operation == 'complete')
            api.completeGate = Completer<LearningSession>();
          if (operation == 'replay')
            api.replayGate = Completer<LearningSession>();
          await rootMath(tester, api);
          await tapVisible(tester, 'lesson-$lessonId');
          await tapVisible(tester, 'startLearning');
          if (operation == 'answer') {
            await tapVisible(tester, 'option-$optionId');
            await press(tester, 'submit-$cueId');
          } else if (operation == 'complete') {
            await press(tester, 'completeLearning');
          } else {
            await tapVisible(tester, 'completeLearning');
            await press(tester, 'replayLearning');
          }
          await press(tester, 'lessonBack');
          await tester.pumpAndSettle();
          await press(tester, 'lesson-$lessonId');
          await tester.pump();
          final failure = ApiFailure(
            'Internal details must stay hidden',
            code: 'DENIED_$status',
            status: status,
          );
          switch (operation) {
            case 'answer':
              api.answerGate!.completeError(failure);
            case 'complete':
              api.completeGate!.completeError(failure);
            case 'replay':
              api.replayGate!.completeError(failure);
          }
          await tester.pumpAndSettle();
          expect(find.textContaining('DENIED_$status'), findsOneWidget);
          expect(find.textContaining('Internal details'), findsNothing);
          expect(find.byKey(const Key('option-$optionId')), findsNothing);
          expect(find.text('Known completed sessions'), findsNothing);
          expect(find.byKey(const Key('replayLearning')), findsNothing);
          expect(find.byKey(const Key('completeLearning')), findsNothing);
          expect(find.byKey(const Key('lessonBack')), findsOneWidget);
        },
      );
    }
  }

  testWidgets(
    'invalid replay options show a safe response error rather than crashing or caching history',
    (tester) async {
      final api = CompletionApi()..seedWrongAnswers(sessionId);
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'completeLearning');
      api.readOverride = {
        ...sessionJson(),
        'sessionId': replaySessionId,
        'answers': [
          {...feedbackJson(), 'optionId': 'unknown-option'},
        ],
      };
      await tapVisible(tester, 'replayLearning');
      expect(tester.takeException(), isNull);
      expect(find.textContaining('INVALID_RESPONSE'), findsOneWidget);
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(find.byKey(const Key('history-$replaySessionId')), findsNothing);
      expect(api.snapshot(sessionId).endedAt, DateTime.parse(completedTime));
    },
  );

  testWidgets(
    'terminal answer response after Back requires readback before showing saved completion',
    (tester) async {
      final api = CompletionApi()..answerGate = Completer<AnswerFeedback>();
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await press(tester, 'submit-$cueId');
      await press(tester, 'lessonBack');
      await tester.pumpAndSettle();
      await press(tester, 'lesson-$lessonId');
      await tester.pump();
      api.answerGate!.completeError(
        const ApiFailure('Ended', code: 'SESSION_NOT_ACTIVE', status: 409),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SESSION_NOT_ACTIVE'), findsOneWidget);
      expect(find.byKey(const Key('option-$optionId')), findsNothing);
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      api.seedWrongAnswers(sessionId);
      api.completeReply(sessionId);
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(api.starts, 1);
      expect(api.completionCalls, isEmpty);
    },
  );

  testWidgets(
    'refresh removes an explanation when its recorded answer is absent from server readback',
    (tester) async {
      final api = CompletionApi();
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await tapVisible(tester, 'submit-$cueId');
      expect(find.byKey(const Key('feedback-$cueId')), findsOneWidget);
      api.events[sessionId]!.clear();
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('feedback-$cueId')), findsNothing);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('completeLearning')))
            .onPressed,
        isNull,
      );
      expect(api.completionCalls, isEmpty);
    },
  );

  testWidgets(
    'catalog repeated taps open once and empty refresh issues one request',
    (tester) async {
      final api = CompletionApi();
      var opened = 0;
      Future<void> catalog() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MathLessonCatalog(
              api: api,
              childId: childId,
              openLesson: (_) => opened++,
            ),
          ),
        ),
      );
      await catalog();
      await tester.pumpAndSettle();
      final action = tester
          .widget<OutlinedButton>(find.byKey(const Key('lesson-$lessonId')))
          .onPressed!;
      action();
      action();
      await tester.pump();
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      api.emptyReason = 'NO_ELIGIBLE_CONTENT';
      await catalog();
      await tester.pumpAndSettle();
      final before = api.calls.where((c) => c == 'catalog:$childId').length;
      api.catalogGate = Completer<LessonList>();
      final reload = tester
          .widget<OutlinedButton>(find.byKey(const Key('lessonsRefresh')))
          .onPressed!;
      reload();
      reload();
      await tester.pump();
      expect(
        api.calls.where((c) => c == 'catalog:$childId').length,
        before + 1,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      api.catalogGate!.complete(
        LessonList([LessonSummary.fromJson(summaryJson())], null, 'Synthetic'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-$lessonId')), findsOneWidget);
    },
  );

  testWidgets(
    'zero-cue and optionless lessons remain honest empty states without Complete',
    (tester) async {
      final api = CompletionApi()
        ..lessonOverride = {...detailJson(), 'cues': []};
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(
        find.text('No interactive questions were returned.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('completeLearning')))
            .onPressed,
        isNull,
      );
      expect(api.completionCalls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      api.lessonOverride = detailJson();
      ((api.lessonOverride!['cues'] as List).first as Map)['options'] = [];
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(find.text('No answer options were returned.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit-$cueId')))
            .onPressed,
        isNull,
      );
      expect(api.submitted, isEmpty);
    },
  );

  testWidgets(
    'narrow screen and large text expand choices; selection and feedback are accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final api = CompletionApi()..lessonOverride = detailJson();
        final label = List.filled(8, 'Synthetic long answer').join(' ');
        ((((api.lessonOverride!['cues'] as List).first as Map)['options']
                        as List)
                    .first
                as Map)['labelText'] =
            label;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LearningLessonView(
                  api: api,
                  childId: childId,
                  lessonId: lessonId,
                  pending: PendingLearningAnswers(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, 'startLearning');
        final button = find.byKey(const Key('option-$optionId'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        // A long, scaled choice can be taller than the viewport. Tap its visible
        // portion as a user would, rather than a center outside the screen.
        final visible = tester
            .getRect(button)
            .intersect(const Rect.fromLTWH(0, 0, 320, 740));
        expect(visible.height, greaterThan(0));
        await tester.tapAt(visible.center);
        await tester.pumpAndSettle();
        expect(tester.getSize(button).height, greaterThan(100));
        final selected = tester.getSemantics(
          find.byKey(const Key('choice-semantics-$optionId')),
        );
        expect(selected.flagsCollection.isSelected, Tristate.isTrue);
        expect(selected.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, 'submit-$cueId');
        expect(find.textContaining('Your answer is saved.'), findsOneWidget);
        final feedback = tester.getSemantics(
          find.byKey(const Key('feedback-announcement-$cueId')),
        );
        expect(feedback.flagsCollection.isLiveRegion, isTrue);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'repeated account-entry actions open one dialog and preserve Parent Gate',
    (tester) async {
      await rootMath(tester, CompletionApi());
      await tapVisible(tester, 'categoryBack');
      final entry = tester
          .widget<TextButton>(find.byKey(const Key('returnAccountEntry')))
          .onPressed!;
      entry();
      entry();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancelAccountEntry')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Hi, SYN-Math!'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
    },
  );
}
