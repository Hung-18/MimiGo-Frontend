import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_session_memory.dart';

import 'learning_api_test.dart' show Transport, Reply, authenticated;
import 'learning_test_data.dart';
import 'completion_test_support.dart';

class HeldReply extends Reply {
  HeldReply(super.value);
  final release = Completer<void>();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromFuture(release.future.then((_) => bytes)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  test('Complete uses the exact authenticated bodyless route; duplicate completion preserves endedAt', () async {
    final http = Transport()
      ..replies.addAll([
        Reply(completedJson()),
        Reply(completedJson()),
        Reply({
          ...completedJson(),
          'answers': [feedbackJson()],
        }),
        Reply({
          ...sessionJson(),
          'sessionId': replaySessionId,
        }, statusCode: 201),
      ]);
    final api = await authenticated(http);
    final first = await api.completeLearning(childId, sessionId);
    final repeat = await api.completeLearning(childId, sessionId);
    expect(first.state, 'COMPLETED');
    expect(repeat.sessionId, first.sessionId);
    expect(repeat.endedAt, first.endedAt);
    for (final call in http.requests.skip(1).take(2)) {
      expect(call.method, 'POST');
      expect(
        call.uri.path,
        '/api/v1/children/$childId/learning-sessions/$sessionId/complete',
      );
      expect(call.headers.value('authorization'), 'Bearer unit-token');
      expect(call.body, isEmpty);
    }
    final readback = await api.learningSession(childId, sessionId);
    expect(readback.endedAt, DateTime.parse(completedTime));
    expect(readback.answers, hasLength(1));
    final replay = await api.startLearning(childId, lessonId);
    expect(replay.sessionId, replaySessionId);
    expect(replay.endedAt, isNull);
    expect(http.requests.last.body, '{"lessonId":"$lessonId"}');
  });
  for (final outcome in <(int, String)>[
    (401, 'UNAUTHENTICATED'),
    (403, 'PERMISSION_NOT_GRANTED'),
    (404, 'SESSION_NOT_FOUND'),
    (409, 'SESSION_INCOMPLETE'),
    (409, 'SESSION_NOT_ACTIVE'),
    (503, 'DB_UNAVAILABLE'),
  ]) {
    test(
      'repository preserves completion ${outcome.$2}, status and request ID',
      () async {
        final http = Transport()
          ..replies.add(
            Reply({
              'code': outcome.$2,
              'message': 'Safe error',
              'requestId': 'completion-request',
            }, statusCode: outcome.$1),
          );
        final api = await authenticated(http);
        await expectLater(
          api.completeLearning(childId, sessionId),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.code, 'code', outcome.$2)
                .having((e) => e.status, 'status', outcome.$1)
                .having((e) => e.requestId, 'requestId', 'completion-request'),
          ),
        );
      },
    );
  }
  test('malformed successful completion is not a completed session', () async {
    final http = Transport()
      ..replies.add(Reply({...completedJson(), 'endedAt': null}));
    final api = await authenticated(http);
    await expectLater(
      api.completeLearning(childId, sessionId),
      throwsA(isA<ApiInvalidResponse>()),
    );
  });
  for (final failure in [
    const SocketException('Synthetic offline'),
    TimeoutException('Synthetic timeout'),
  ]) {
    test(
      'completion transport ${failure.runtimeType} is safely retryable',
      () async {
        final http = Transport()..replies.add(failure);
        final api = await authenticated(http);
        await expectLater(
          api.completeLearning(childId, sessionId),
          throwsA(
            isA<ApiFailure>().having((e) => e.retryable, 'retryable', isTrue),
          ),
        );
      },
    );
  }
  test('repository start requests coalesce across views without changing the contract', () async {
    final start = HeldReply(sessionJson());
    final http = Transport()..replies.addAll([start, Reply(sessionJson())]);
    final api = await authenticated(http);
    final state = LearningSessionMemory(api);
    final lesson = LessonDetail.fromJson(detailJson());
    final first = state.open(childId, lesson);
    expect(state.open(childId, lesson), same(first));
    await Future<void>.delayed(Duration.zero);
    expect(http.requests, hasLength(2)); // login + one start
    start.release.complete();
    expect((await first).sessionId, sessionId);
    expect(http.requests.map((r) => r.method), ['POST', 'POST', 'GET']);
    expect(http.requests[1].body, '{"lessonId":"$lessonId"}');
    expect(
      http.requests.last.uri.path,
      '/api/v1/children/$childId/learning-sessions/$sessionId',
    );
    state.dispose();
  });

  test('repository answer duplicate sends one immutable authenticated event body', () async {
    final response = HeldReply(feedbackJson());
    final http = Transport()..replies.add(response);
    final api = await authenticated(http);
    final state = LearningSessionMemory(api)
      ..remember(SessionDetail.fromJson(sessionJson()));
    const request = AnswerRequest(
      clientEventId: eventId,
      cueId: cueId,
      optionId: optionId,
    );
    final first = state.submit(childId, sessionId, request);
    expect(state.submit(childId, sessionId, request), same(first));
    await Future<void>.delayed(Duration.zero);
    expect(http.requests, hasLength(2));
    expect(
      http.requests.last.headers.value('authorization'),
      'Bearer unit-token',
    );
    expect(
      http.requests.last.body,
      '{"clientEventId":"$eventId","cueId":"$cueId","optionId":"$optionId","usedHint":false}',
    );
    response.release.complete();
    expect((await first).optionId, optionId);
    state.dispose();
  });

  test('repository rejects unrenderable readback and retries GET using the acknowledged start ID', () async {
    final http = Transport()
      ..replies.addAll([
        Reply(sessionJson(), statusCode: 201),
        Reply(
          sessionJson(
            answers: [
              {...feedbackJson(), 'optionId': 'unknown-option'},
            ],
          ),
        ),
        Reply(sessionJson()),
      ]);
    final api = await authenticated(http);
    final state = LearningSessionMemory(api);
    final lesson = LessonDetail.fromJson(detailJson());
    await expectLater(
      state.open(childId, lesson),
      throwsA(isA<ApiInvalidResponse>()),
    );
    expect(state.resumeId(childId, lessonId), sessionId);
    expect(state.session(childId, sessionId), isNull);
    expect((await state.open(childId, lesson)).sessionId, sessionId);
    expect(http.requests.map((r) => r.method), ['POST', 'POST', 'GET', 'GET']);
    state.dispose();
  });
}
