import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_session_memory.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart';

void main() {
  test(
    'endedAt is required/nullable and is never manufactured from local time',
    () {
      expect(LearningSession.fromJson(sessionJson()).endedAt, isNull);
      final complete = LearningSession.fromJson(completedJson());
      expect(complete.endedAt, DateTime.parse(completedTime));
      expect(
        SessionDetail.fromSession(complete, []).endedAt,
        same(complete.endedAt),
      );
      for (final body in [
        sessionJson()..remove('endedAt'),
        {...completedJson(), 'endedAt': null},
        {...sessionJson(), 'endedAt': completedTime},
        {...completedJson(), 'endedAt': 'invalid'},
      ]) {
        expect(
          () => LearningSession.fromJson(body),
          throwsA(isA<ApiInvalidResponse>()),
        );
      }
    },
  );

  test('completion waits for server and coalesces in-flight and already confirmed duplicates', () async {
    final api = CompletionApi()..completeGate = Completer<LearningSession>();
    api.seedWrongAnswers(sessionId);
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    final first = state.complete(childId, sessionId);
    final second = state.complete(childId, sessionId);
    expect(second, same(first));
    expect(api.completionCalls, [sessionId]);
    expect(state.completing(childId, sessionId), isTrue);
    expect(state.session(childId, sessionId)!.state, 'IN_PROGRESS');
    api.completeGate!.complete(api.completeReply(sessionId));
    final result = await first;
    expect(result.state, 'COMPLETED');
    expect(result.endedAt, DateTime.parse(completedTime));
    expect(
      result.answers.single.isCorrect,
      isFalse,
      reason: 'Correctness is not completion eligibility.',
    );
    await state.complete(childId, sessionId);
    expect(api.completionCalls, [sessionId]);
    expect(state.completed(childId, lessonId).single.sessionId, sessionId);
    state.dispose();
  });

  test('lost completion acknowledgment retries the same identity and keeps stored endedAt', () async {
    final api = CompletionApi()..loseCompletionAck = true;
    api.seedWrongAnswers(sessionId);
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    await expectLater(
      state.complete(childId, sessionId),
      throwsA(isA<ApiFailure>()),
    );
    expect(state.session(childId, sessionId)!.state, 'IN_PROGRESS');
    expect(state.session(childId, sessionId)!.endedAt, isNull);
    final reply = await state.complete(childId, sessionId);
    expect(api.completionCalls, [sessionId, sessionId]);
    expect(reply.endedAt, DateTime.parse(completedTime));
    expect(state.completed(childId, lessonId), hasLength(1));
    state.dispose();
  });

  for (final failure in [
    const ApiFailure('Sign in.', code: 'UNAUTHENTICATED', status: 401),
    const ApiFailure('Denied.', code: 'PERMISSION_NOT_GRANTED', status: 403),
    const ApiFailure('Missing.', code: 'SESSION_NOT_FOUND', status: 404),
    const ApiFailure('Incomplete.', code: 'SESSION_INCOMPLETE', status: 409),
    const ApiFailure('Ended.', code: 'SESSION_NOT_ACTIVE', status: 409),
    const ApiFailure(
      'Unavailable.',
      code: 'DB_UNAVAILABLE',
      status: 503,
      retryable: true,
    ),
    const ApiFailure('Offline.', code: 'CONNECTIVITY', retryable: true),
  ]) {
    test('${failure.code} cannot manufacture a completion fact', () async {
      final api = CompletionApi()..completeFailure = failure;
      final state = LearningSessionMemory(api)
        ..remember(api.snapshot(sessionId));
      await expectLater(
        state.complete(childId, sessionId),
        throwsA(same(failure)),
      );
      expect(state.completed(childId, lessonId), isEmpty);
      expect(state.session(childId, sessionId)!.state, 'IN_PROGRESS');
      expect(state.completionError(childId, sessionId), same(failure));
      expect(state.completing(childId, sessionId), isFalse);
      state.dispose();
    });
  }

  for (final override in [
    {'sessionId': replaySessionId},
    {'childId': 'sibling'},
    {'lessonId': 'other-lesson'},
    {'revisionId': 'other-revision'},
    {'state': 'IN_PROGRESS', 'endedAt': null},
  ]) {
    test(
      'completion acknowledgment validates identity/state $override',
      () async {
        final api = CompletionApi()
          ..completionOverride = {...completedJson(), ...override};
        final state = LearningSessionMemory(api)
          ..remember(api.snapshot(sessionId));
        await expectLater(
          state.complete(childId, sessionId),
          throwsA(isA<ApiInvalidResponse>()),
        );
        expect(state.completed(childId, lessonId), isEmpty);
        state.dispose();
      },
    );
  }

  test('replay has a new identity and answers; completed readback/history is unchanged', () async {
    final api = CompletionApi();
    api.seedWrongAnswers(sessionId);
    api.completeReply(sessionId);
    final old = api.snapshot(sessionId);
    final state = LearningSessionMemory(api)..remember(old);
    final fresh = await state.replay(
      childId,
      sessionId,
      LessonDetail.fromJson(detailJson()),
    );
    expect(fresh.sessionId, replaySessionId);
    expect(fresh.state, 'IN_PROGRESS');
    expect(fresh.endedAt, isNull);
    expect(fresh.answers, isEmpty);
    expect(state.completed(childId, lessonId).single.endedAt, old.endedAt);
    expect(
      state.completed(childId, lessonId).single.answers.single.isCorrect,
      false,
    );
    final oldReadback = await api.learningSession(childId, sessionId);
    state.remember(oldReadback, activate: false);
    expect(state.resumeId(childId, lessonId), replaySessionId);
    expect(oldReadback.state, 'COMPLETED');
    expect(oldReadback.endedAt, old.endedAt);
    state.dispose();
  });

  test('replay start coalesces duplicates and recovers a lost start response without losing history', () async {
    final api = CompletionApi()..replayGate = Completer<LearningSession>();
    api.completeReply(sessionId);
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    final first = state.replay(
      childId,
      sessionId,
      LessonDetail.fromJson(detailJson()),
    );
    expect(
      state.replay(childId, sessionId, LessonDetail.fromJson(detailJson())),
      same(first),
    );
    expect(api.startBodies, [lessonId]);
    api.replayGate!.complete(api.prepareReplay());
    expect((await first).sessionId, replaySessionId);
    expect(state.completed(childId, lessonId).single.sessionId, sessionId);
    state.dispose();

    final lostApi = CompletionApi()..loseReplayAck = true;
    lostApi.completeReply(sessionId);
    final lostState = LearningSessionMemory(lostApi)
      ..remember(lostApi.snapshot(sessionId));
    await expectLater(
      lostState.replay(childId, sessionId, LessonDetail.fromJson(detailJson())),
      throwsA(isA<ApiFailure>()),
    );
    expect(lostState.completed(childId, lessonId).single.sessionId, sessionId);
    final retry = await lostState.replay(
      childId,
      sessionId,
      LessonDetail.fromJson(detailJson()),
    );
    expect(retry.sessionId, replaySessionId);
    expect(lostApi.startBodies, [lessonId, lessonId]);
    lostState.dispose();
  });

  test(
    'late readback cannot erase completion; changed endedAt is rejected',
    () async {
      final api = CompletionApi();
      final stale = api.snapshot(sessionId);
      api.completeReply(sessionId);
      final state = LearningSessionMemory(api)
        ..remember(api.snapshot(sessionId));
      expect(state.remember(stale).state, 'COMPLETED');
      expect(
        state.session(childId, sessionId)!.endedAt,
        DateTime.parse(completedTime),
      );
      expect(
        () => state.remember(
          SessionDetail.fromJson({
            ...completedJson(),
            'answers': [],
            'endedAt': '2026-10-23T13:00:00Z',
          }),
        ),
        throwsA(isA<ApiInvalidResponse>()),
      );
      state.dispose();
    },
  );

  test(
    'account clearing rejects late completion and removes child-scoped history',
    () async {
      final api = CompletionApi()..completeGate = Completer<LearningSession>();
      final state = LearningSessionMemory(api)
        ..remember(api.snapshot(sessionId));
      final outcome = expectLater(
        state.complete(childId, sessionId),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'UNAUTHENTICATED'),
        ),
      );
      state.clear();
      api.completeGate!.complete(api.completeReply(sessionId));
      await outcome;
      expect(state.completed(childId, lessonId), isEmpty);
      expect(state.resumeId(childId, lessonId), isNull);
      expect(state.completing(childId, sessionId), isFalse);
      state.dispose();
    },
  );

  test(
    'history is scoped to its child and does not expose sibling records',
    () {
      final state = LearningSessionMemory(CompletionApi());
      state.remember(
        SessionDetail.fromJson({
          ...completedJson(),
          'answers': [feedbackJson()],
        }),
      );
      expect(state.completed('sibling', lessonId), isEmpty);
      expect(state.session('sibling', sessionId), isNull);
      state.clear();
      expect(state.completed(childId, lessonId), isEmpty);
      state.dispose();
    },
  );
}
