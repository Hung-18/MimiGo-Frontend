import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';

import 'learning_test_data.dart';
import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;

class LearningTestApi extends AuthApi {
  @override
  Future<CurriculumCatalog> curriculum(String child) async {
    final list = await lessons(child);
    return CurriculumCatalog.fromJson(
      curriculumJson(
        list.items.map(
          (item) => {
            ...summaryJson(),
            'lessonId': item.lessonId,
            'domainCode': item.domainCode,
            'topicCode': item.topicCode,
          },
        ),
        emptyReason: list.emptyReason,
      ),
    );
  }

  ApiFailure? catalogFailure,
      detailFailure,
      startFailure,
      readFailure,
      answerFailure;
  Completer<LessonList>? catalogGate;
  Completer<AnswerFeedback>? answerGate;
  String? emptyReason;
  bool dropAck = false, mismatchedRevision = false;
  final submitted = <AnswerRequest>[];
  final saved = <String, Map<String, dynamic>>{};
  int starts = 0, reads = 0;

  @override
  Future<LessonList> lessons(String child) async {
    calls.add('catalog:$child');
    if (catalogFailure != null) throw catalogFailure!;
    if (catalogGate != null) return catalogGate!.future;
    return LessonList(
      emptyReason == null ? [LessonSummary.fromJson(summaryJson())] : [],
      emptyReason,
      'Synthetic development only',
    );
  }

  @override
  Future<LessonDetail> lesson(String child, String id) async {
    calls.add('lesson:$child:$id');
    if (detailFailure != null) throw detailFailure!;
    return LessonDetail.fromJson(detailJson());
  }

  @override
  Future<LearningSession> startLearning(String child, String id) async {
    starts++;
    if (startFailure != null) throw startFailure!;
    return LearningSession.fromJson({
      ...sessionJson(),
      if (mismatchedRevision) 'revisionId': 'other-revision',
    });
  }

  @override
  Future<SessionDetail> learningSession(String child, String id) async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return SessionDetail.fromJson(sessionJson(answers: saved.values.toList()));
  }

  @override
  Future<AnswerFeedback> submitAnswer(
    String child,
    String id,
    AnswerRequest request,
  ) async {
    submitted.add(request);
    if (answerFailure != null) throw answerFailure!;
    if (answerGate != null) return answerGate!.future;
    final body = saved.putIfAbsent(
      request.clientEventId,
      () => {
        ...feedbackJson(),
        'optionId': request.optionId,
        'attemptNo': saved.length + 1,
      },
    );
    if (dropAck) {
      dropAck = false;
      throw const ApiFailure(
        'Response lost.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
    return AnswerFeedback.fromJson(body);
  }
}

Future<void> tapVisible(
  WidgetTester tester,
  String key, {
  bool settle = true,
}) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> lessonScreen(
  WidgetTester tester,
  LearningTestApi api, {
  PendingLearningAnswers? pending,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LearningLessonView(
            api: api,
            childId: childId,
            lessonId: lessonId,
            pending: pending ?? PendingLearningAnswers(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> rootMath(WidgetTester tester, LearningTestApi api) async {
  api.profiles = [
    ChildSummary(
      id: childId,
      alias: 'SYN-Math',
      dateOfBirth: DateTime(2023, 1, 1),
      ageYears: 3,
      withinProgramAgeRange: true,
      state: 'ACTIVE',
      createdAt: DateTime(2026),
    ),
  ];
  await openSignIn(tester, api);
  await fillSignIn(tester);
  await submitSignIn(tester);
  await tester.tap(find.text('SYN-Math'));
  await tester.pumpAndSettle();
  await tapVisible(tester, 'parentEnterLearning');
  await tapVisible(tester, 'category-math');
}

void main() {
  testWidgets(
    'an acknowledgment arriving after Back remains replayable on revisit',
    (tester) async {
      final api = LearningTestApi()..answerGate = Completer<AnswerFeedback>();
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await tapVisible(tester, 'submit-$cueId', settle: false);
      final original = api.submitted.single;
      await tapVisible(tester, 'lessonBack', settle: false);
      api.saved[original.clientEventId] = feedbackJson();
      api.answerGate!.complete(AnswerFeedback.fromJson(feedbackJson()));
      await tester.pumpAndSettle();
      api.answerGate = null;
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      expect(find.text('Retry same answer'), findsOneWidget);
      await tapVisible(tester, 'submit-$cueId');
      expect(api.submitted.last.toJson(), original.toJson());
      expect(api.saved, hasLength(1));
      expect(find.textContaining('Server explanation for A'), findsOneWidget);
    },
  );
  testWidgets(
    'Math fetches only the selected child catalog and opens details with working Back',
    (tester) async {
      final api = LearningTestApi();
      await rootMath(tester, api);
      expect(api.calls, contains('catalog:$childId'));
      expect(find.textContaining('SYN-MATH-001'), findsOneWidget);
      await tapVisible(tester, 'lesson-$lessonId');
      expect(api.calls, contains('lesson:$childId:$lessonId'));
      expect(find.text('Synthetic Math'), findsOneWidget);
      expect(find.textContaining('Server feedback'), findsNothing);
      expect(find.byKey(const Key('option-$optionId')), findsNothing);
      expect(find.textContaining('Playback is not available'), findsOneWidget);
      expect(find.textContaining('not-playable.invalid'), findsNothing);
      expect(find.byType(Image), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-$lessonId')), findsOneWidget);
      await tapVisible(tester, 'categoryBack');
      expect(find.text('Hi, SYN-Math!'), findsOneWidget);
    },
  );

  for (final reason in ['NO_ELIGIBLE_CONTENT', 'CHILD_OUTSIDE_PROGRAM_AGE']) {
    testWidgets('Math displays authoritative empty reason $reason', (
      tester,
    ) async {
      final api = LearningTestApi()..emptyReason = reason;
      await rootMath(tester, api);
      expect(find.byKey(const Key('categoryEmpty')), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      expect(find.byKey(const Key('lesson-$lessonId')), findsNothing);
    });
  }
  testWidgets('catalog loading and safe retry do not substitute fixtures', (
    tester,
  ) async {
    final api = LearningTestApi()..catalogGate = Completer<LessonList>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MathLessonCatalog(
            api: api,
            childId: childId,
            openLesson: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.catalogGate!.completeError(
      const ApiFailure('Unavailable', code: 'DB_UNAVAILABLE', status: 503),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('DB_UNAVAILABLE'), findsOneWidget);
    expect(find.textContaining('Find the circle'), findsNothing);
    api.catalogGate = null;
    await tapVisible(tester, 'lessonsRetry');
    expect(find.textContaining('SYN-MATH-001'), findsOneWidget);
  });
  for (final status in [401, 403, 404]) {
    testWidgets(
      'lesson detail HTTP $status is visible without starting a session',
      (tester) async {
        final api = LearningTestApi()
          ..detailFailure = ApiFailure(
            'Safe lesson denial',
            code: 'DENIED_$status',
            status: status,
            requestId: 'request-id',
          );
        await lessonScreen(tester, api);
        expect(find.textContaining('DENIED_$status'), findsOneWidget);
        expect(find.textContaining('request-id'), findsOneWidget);
        expect(find.byKey(const Key('startLearning')), findsNothing);
        expect(api.starts, 0);
      },
    );
  }
  testWidgets(
    'start and readback failures leave a safe retry and no answer options',
    (tester) async {
      final api = LearningTestApi()
        ..startFailure = const ApiFailure(
          'Permission missing',
          code: 'PERMISSION_NOT_GRANTED',
          status: 403,
        );
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(find.textContaining('PERMISSION_NOT_GRANTED'), findsOneWidget);
      expect(find.byKey(const Key('option-$optionId')), findsNothing);
      api.startFailure = null;
      api.readFailure = const ApiFailure(
        'Session missing',
        code: 'SESSION_NOT_FOUND',
        status: 404,
      );
      await tapVisible(tester, 'startLearning');
      expect(find.textContaining('SESSION_NOT_FOUND'), findsOneWidget);
      api.readFailure = null;
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('option-$optionId')), findsOneWidget);
    },
  );
  testWidgets(
    'a mismatched revision never presents questions from the wrong session',
    (tester) async {
      final api = LearningTestApi()..mismatchedRevision = true;
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(find.textContaining('revision do not match'), findsOneWidget);
      expect(find.byKey(const Key('option-$optionId')), findsNothing);
    },
  );
  testWidgets(
    'answer loading prevents duplicate sends and feedback only follows acknowledgment',
    (tester) async {
      final api = LearningTestApi()..answerGate = Completer<AnswerFeedback>();
      await lessonScreen(tester, api);
      await tapVisible(tester, 'startLearning');
      expect(api.starts, 1);
      expect(api.reads, 1);
      expect(find.textContaining('Correct'), findsNothing);
      await tapVisible(tester, 'option-$optionId');
      await tester.ensureVisible(find.byKey(const Key('submit-$cueId')));
      await tester.tap(find.byKey(const Key('submit-$cueId')));
      await tester.pump();
      expect(find.text('Sending answer…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit-$cueId')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Server explanation'), findsNothing);
      expect(api.submitted, hasLength(1));
      api.answerGate!.complete(AnswerFeedback.fromJson(feedbackJson()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Server explanation for A'), findsOneWidget);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      expect(api.submitted.single.usedHint, false);
    },
  );
  testWidgets(
    'lost answer acknowledgment survives Back/revisit and retries the exact event/body',
    (tester) async {
      final api = LearningTestApi()..dropAck = true;
      await rootMath(tester, api);
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await tapVisible(tester, 'submit-$cueId');
      final original = api.submitted.single;
      expect(find.text('Retry same answer'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('option-$otherOptionId')),
            )
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'lessonBack');
      await tapVisible(tester, 'lesson-$lessonId');
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      expect(
        find.textContaining('Server explanation'),
        findsNothing,
        reason: 'Readback has no feedbackText; it must not be invented.',
      );
      await tapVisible(tester, 'submit-$cueId');
      expect(api.submitted.last.toJson(), original.toJson());
      expect(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(original.clientEventId),
        isTrue,
      );
      expect(find.textContaining('Server explanation for A'), findsOneWidget);
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      expect(api.saved, hasLength(1));
      await tapVisible(tester, 'lessonHome');
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    '409 retains the original pending event and does not silently generate another',
    (tester) async {
      final pending = PendingLearningAnswers();
      final api = LearningTestApi()
        ..answerFailure = const ApiFailure(
          'Conflict',
          code: 'CLIENT_EVENT_CONFLICT',
          status: 409,
        );
      await lessonScreen(tester, api, pending: pending);
      await tapVisible(tester, 'startLearning');
      await tapVisible(tester, 'option-$optionId');
      await tapVisible(tester, 'submit-$cueId');
      expect(find.textContaining('CLIENT_EVENT_CONFLICT'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit-$cueId')))
            .onPressed,
        isNull,
      );
      expect(
        pending.find(childId, sessionId, cueId),
        same(api.submitted.single),
      );
      expect(api.submitted, hasLength(1));
    },
  );
  for (final status in [401, 403, 404]) {
    testWidgets(
      'answer denial $status hides session interaction and preserves the pending body',
      (tester) async {
        final pending = PendingLearningAnswers();
        final api = LearningTestApi()
          ..answerFailure = ApiFailure(
            'Denied',
            code: 'DENIED_$status',
            status: status,
          );
        await lessonScreen(tester, api, pending: pending);
        await tapVisible(tester, 'startLearning');
        await tapVisible(tester, 'option-$optionId');
        await tapVisible(tester, 'submit-$cueId');
        expect(find.textContaining('DENIED_$status'), findsOneWidget);
        expect(find.byKey(const Key('submit-$cueId')), findsNothing);
        expect(pending.find(childId, sessionId, cueId), isNotNull);
      },
    );
  }
  test('retry queue isolates children and cues; new event only after acknowledgment', () {
    final pending = PendingLearningAnswers();
    final a = pending.prepare(childId, sessionId, cueId, optionId);
    expect(pending.prepare(childId, sessionId, cueId, otherOptionId), same(a));
    final sibling = pending.prepare('sibling', sessionId, cueId, optionId);
    expect(sibling.clientEventId, isNot(a.clientEventId));
    pending.acknowledge(childId, sessionId, a);
    expect(pending.find('sibling', sessionId, cueId), same(sibling));
    expect(
      pending.prepare(childId, sessionId, cueId, optionId).clientEventId,
      isNot(a.clientEventId),
    );
    pending.clear();
    expect(pending.find('sibling', sessionId, cueId), isNull);
  });
}
