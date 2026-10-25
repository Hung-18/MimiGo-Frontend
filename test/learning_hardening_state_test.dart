import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_session_memory.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart';

LessonDetail get lesson => LessonDetail.fromJson(detailJson());
const answer = AnswerRequest(
  clientEventId: eventId,
  cueId: cueId,
  optionId: optionId,
);

void main() {
  test('retained correctness can be redacted without changing completion or answer identity', () {
    final state = LearningSessionMemory(CompletionApi());
    final original = SessionDetail.fromJson({
      ...completedJson(),
      'answers': [feedbackJson()],
    });
    state.remember(original);
    final redacted = SessionDetail.fromJson({
      ...completedJson(),
      'answers': [
        {...feedbackJson(), 'isCorrect': null},
      ],
    });
    state.remember(redacted);
    final saved = state.session(childId, sessionId)!;
    expect(saved.answers.single.isCorrect, isNull);
    expect(saved.answers.single.optionId, optionId);
    expect(saved.endedAt, DateTime.parse(completedTime));
    expect(
      () => state.remember(
        SessionDetail.fromJson({
          ...completedJson(),
          'answers': [
            {...feedbackJson(), 'isCorrect': null, 'optionId': otherOptionId},
          ],
        }),
      ),
      throwsA(isA<ApiInvalidResponse>()),
    );
    state.dispose();
  });

  test('new answer acknowledgment cannot omit correctness and retained field must be present', () {
    expect(
      () => AnswerFeedback.fromJson({...feedbackJson(), 'isCorrect': null}),
      throwsA(isA<ApiInvalidResponse>()),
    );
    final missing = feedbackJson()..remove('isCorrect');
    expect(
      () => RecordedAnswer.fromJson(missing),
      throwsA(isA<ApiInvalidResponse>()),
    );
    expect(
      () => RecordedAnswer.fromJson({...feedbackJson(), 'isCorrect': 'false'}),
      throwsA(isA<ApiInvalidResponse>()),
    );
  });

  test('completed readback cannot erase or mutate a known answer; later discovered server attempts may enrich it', () {
    final api = CompletionApi()..seedWrongAnswers(sessionId);
    api.completeReply(sessionId);
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    for (final answers in [
      <Map<String, dynamic>>[],
      [
        {...feedbackJson(), 'optionId': otherOptionId},
      ],
      [
        {...feedbackJson(), 'isCorrect': true},
      ],
    ]) {
      expect(
        () => state.remember(
          SessionDetail.fromJson({...completedJson(), 'answers': answers}),
        ),
        throwsA(isA<ApiInvalidResponse>()),
      );
      expect(
        state.session(childId, sessionId)!.answers.single.optionId,
        optionId,
      );
      expect(
        state.session(childId, sessionId)!.endedAt,
        DateTime.parse(completedTime),
      );
    }
    state.remember(
      SessionDetail.fromJson({
        ...completedJson(),
        'answers': [
          feedbackJson(),
          {...feedbackJson(), 'attemptNo': 2, 'optionId': otherOptionId},
        ],
      }),
    );
    expect(state.session(childId, sessionId)!.answers, hasLength(2));
    state.dispose();
  });
  test('read started before an access denial cannot erase it; a fresh successful GET can reconcile', () async {
    final api = CompletionApi()
      ..completeGate = Completer<LearningSession>()
      ..readGate = Completer<SessionDetail>();
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    final completing = expectLater(
      state.complete(childId, sessionId),
      throwsA(isA<ApiFailure>()),
    );
    final reading = expectLater(
      state.read(childId, lesson, sessionId),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
    );
    api.completeGate!.completeError(
      const ApiFailure('Denied', code: 'PERMISSION_NOT_GRANTED', status: 403),
    );
    await completing;
    api.readGate!.complete(api.snapshot(sessionId));
    await reading;
    expect(state.accessError(childId, sessionId, lessonId)!.status, 403);
    api.readGate = null;
    await state.read(childId, lesson, sessionId);
    expect(state.accessError(childId, sessionId, lessonId), isNull);
    state.dispose();
  });
  test('start and concurrent readbacks coalesce; an interrupted read keeps the acknowledged identity', () async {
    final api = CompletionApi()..startGate = Completer<LearningSession>();
    final state = LearningSessionMemory(api);
    final first = state.open(childId, lesson);
    expect(state.open(childId, lesson), same(first));
    expect(api.starts, 1);
    api.readFailure = const ApiFailure(
      'Temporary',
      code: 'DB_UNAVAILABLE',
      status: 503,
    );
    final failed = expectLater(first, throwsA(isA<ApiFailure>()));
    api.startGate!.complete(LearningSession.fromJson(sessionJson()));
    await failed;
    expect(state.resumeId(childId, lessonId), sessionId);
    expect(state.session(childId, sessionId), isNull);
    api.readFailure = null;
    api.readGate = Completer<SessionDetail>();
    final retry = state.open(childId, lesson);
    final duplicate = state.open(childId, lesson);
    expect(api.starts, 1);
    expect(api.reads, 2);
    api.readGate!.complete(api.snapshot(sessionId));
    expect((await retry).sessionId, sessionId);
    expect((await duplicate).sessionId, sessionId);
    expect(state.opening(childId, lessonId), isFalse);
    state.dispose();
  });

  test('answer submission shares the exact event and blocks different concurrent choices and Complete', () async {
    final api = CompletionApi()..answerGate = Completer<AnswerFeedback>();
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    final first = state.submit(childId, sessionId, answer);
    expect(state.submit(childId, sessionId, answer), same(first));
    expect(state.sendingCue(childId, sessionId), cueId);
    await expectLater(
      state.submit(
        childId,
        sessionId,
        const AnswerRequest(
          clientEventId: 'different-event',
          cueId: cueId,
          optionId: otherOptionId,
        ),
      ),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      state.complete(childId, sessionId),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.submitted, hasLength(1));
    expect(api.completionCalls, isEmpty);
    api.answerGate!.complete(AnswerFeedback.fromJson(feedbackJson()));
    expect((await first).optionId, optionId);
    expect(state.answering(childId, sessionId), isFalse);
    state.dispose();
  });

  test(
    'an ambiguous Complete blocks answers until a server read reconciles it',
    () async {
      final api = CompletionApi()..loseCompletionAck = true;
      api.seedWrongAnswers(sessionId);
      final state = LearningSessionMemory(api)
        ..remember(api.snapshot(sessionId));
      await expectLater(
        state.complete(childId, sessionId),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        state.submit(childId, sessionId, answer),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.submitted, isEmpty);
      final saved = await state.read(childId, lesson, sessionId);
      expect(saved.state, 'COMPLETED');
      expect(saved.endedAt, DateTime.parse(completedTime));
      await expectLater(
        state.submit(childId, sessionId, answer),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.submitted, isEmpty);
      state.dispose();
    },
  );

  test(
    'Continue replay only reads the active identity; history stays immutable',
    () async {
      final api = CompletionApi()..seedWrongAnswers(sessionId);
      api.completeReply(sessionId);
      final state = LearningSessionMemory(api)
        ..remember(api.snapshot(sessionId));
      final fresh = await state.replay(childId, sessionId, lesson);
      state.remember(api.snapshot(sessionId), activate: false);
      final again = await state.replay(childId, sessionId, lesson);
      expect(again.sessionId, fresh.sessionId);
      expect(api.starts, 1);
      expect(api.readIds, [replaySessionId, replaySessionId]);
      expect(state.resumeId(childId, lessonId), replaySessionId);
      expect(
        state.completed(childId, lessonId).single.endedAt,
        DateTime.parse(completedTime),
      );
      state.dispose();
    },
  );

  for (final invalid in [
    {'cueId': 'unknown-cue'},
    {'optionId': 'unknown-option'},
  ]) {
    test(
      'malformed replay readback $invalid never enters session memory',
      () async {
        final api = CompletionApi()..completeReply(sessionId);
        final state = LearningSessionMemory(api)
          ..remember(api.snapshot(sessionId));
        api.readOverride = {
          ...sessionJson(),
          'sessionId': replaySessionId,
          'answers': [
            {...feedbackJson(), ...invalid},
          ],
        };
        await expectLater(
          state.replay(childId, sessionId, lesson),
          throwsA(isA<ApiInvalidResponse>()),
        );
        expect(state.session(childId, replaySessionId), isNull);
        expect(state.resumeId(childId, lessonId), sessionId);
        expect(
          state.completed(childId, lessonId).single.endedAt,
          DateTime.parse(completedTime),
        );
        state.dispose();
      },
    );
  }

  for (final operation in ['start', 'read', 'answer', 'replay']) {
    test(
      'account clear rejects late $operation without restoring identities or busy state',
      () async {
        final api = CompletionApi();
        final state = LearningSessionMemory(api);
        late Future<Object> pending;
        if (operation == 'start') {
          api.startGate = Completer<LearningSession>();
          pending = state.open(childId, lesson);
        } else if (operation == 'read') {
          api.readGate = Completer<SessionDetail>();
          pending = state.read(childId, lesson, sessionId);
        } else if (operation == 'answer') {
          state.remember(api.snapshot(sessionId));
          api.answerGate = Completer<AnswerFeedback>();
          pending = state.submit(childId, sessionId, answer);
        } else {
          api.completeReply(sessionId);
          state.remember(api.snapshot(sessionId));
          api.replayGate = Completer<LearningSession>();
          pending = state.replay(childId, sessionId, lesson);
        }
        final outcome = expectLater(
          pending,
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
        );
        state.clear();
        switch (operation) {
          case 'start':
            api.startGate!.complete(LearningSession.fromJson(sessionJson()));
          case 'read':
            api.readGate!.complete(api.snapshot(sessionId));
          case 'answer':
            api.answerGate!.complete(AnswerFeedback.fromJson(feedbackJson()));
          case 'replay':
            api.replayGate!.complete(api.prepareReplay());
        }
        await outcome;
        expect(state.resumeId(childId, lessonId), isNull);
        expect(state.session(childId, sessionId), isNull);
        expect(state.completed(childId, lessonId), isEmpty);
        expect(state.opening(childId, lessonId), isFalse);
        expect(state.answering(childId, sessionId), isFalse);
        expect(state.replaying(childId, lessonId), isFalse);
        state.dispose();
      },
    );
  }

  test('a persistent event conflict remains blocked after successful GET and navigation', () async {
    final api = CompletionApi()
      ..answerFailure = const ApiFailure(
        'Conflict',
        code: 'CLIENT_EVENT_CONFLICT',
        status: 409,
      );
    final state = LearningSessionMemory(api)..remember(api.snapshot(sessionId));
    await expectLater(
      state.submit(childId, sessionId, answer),
      throwsA(isA<ApiFailure>()),
    );
    await state.read(childId, lesson, sessionId);
    expect(
      state.answerError(childId, sessionId, cueId)!.code,
      'CLIENT_EVENT_CONFLICT',
    );
    state.dispose();
  });
}
