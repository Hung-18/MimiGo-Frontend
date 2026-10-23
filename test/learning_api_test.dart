import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

import 'learning_test_data.dart';

class Headers extends Fake implements HttpHeaders {
  final fields = <String, String>{};
  @override
  set contentType(ContentType? value) {
    fields['content-type'] = value.toString();
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    fields[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => fields[name.toLowerCase()];
}

class Reply extends Stream<List<int>> implements HttpClientResponse {
  Reply(Object value, {this.statusCode = 200, bool raw = false})
    : bytes = utf8.encode(raw ? value as String : jsonEncode(value));
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  final Headers headers = Headers()..set('x-request-id', 'unit-request');
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request extends Fake implements HttpClientRequest {
  Request(this.method, this.uri, this.reply);
  @override
  final String method;
  @override
  final Uri uri;
  final Reply reply;
  String body = '';
  @override
  final Headers headers = Headers();
  @override
  void write(Object? value) {
    body += value.toString();
  }

  @override
  Future<HttpClientResponse> close() async => reply;
}

class Transport extends Fake implements HttpClient {
  final replies = <Object>[];
  final requests = <Request>[];
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final reply = replies.removeAt(0);
    if (reply is! Reply) throw reply;
    final request = Request(method, url, reply);
    requests.add(request);
    return request;
  }
}

Future<LiveMimiGoApi> authenticated(Transport transport) async {
  transport.replies.insert(
    0,
    Reply({
      'accessToken': 'unit-token',
      'tokenType': 'Bearer',
      'expiresAt': '2030-01-01T00:00:00Z',
      'parentId': childId,
    }),
  );
  final api = LiveMimiGoApi(
    Uri.parse('http://unit.invalid/api/v1/'),
    client: transport,
  );
  await api.login(email: 'parent@example.test', password: 'synthetic-pass');
  return api;
}

const request = AnswerRequest(
  clientEventId: eventId,
  cueId: cueId,
  optionId: optionId,
);

void main() {
  test(
    'start/reuse accepts both 201 and 200 with the same lesson-only body',
    () async {
      final http = Transport()
        ..replies.addAll([
          Reply(sessionJson(), statusCode: 201),
          Reply(sessionJson()),
        ]);
      final api = await authenticated(http);
      final first = await api.startLearning(childId, lessonId);
      final reused = await api.startLearning(childId, lessonId);
      expect(reused.sessionId, first.sessionId);
      expect(http.requests[1].body, http.requests[2].body);
      expect(jsonDecode(http.requests[2].body), {'lessonId': lessonId});
    },
  );
  test('an empty HTTP 404 retains status and request ID rather than becoming a fixture list', () async {
    final http = Transport()
      ..replies.add(Reply('', raw: true, statusCode: 404));
    final api = await authenticated(http);
    await expectLater(
      api.lessons(childId),
      throwsA(
        isA<ApiInvalidResponse>()
            .having((error) => error.status, 'HTTP status', 404)
            .having((error) => error.requestId, 'request ID', 'unit-request'),
      ),
    );
  });
  test('all five Learning paths reuse the authenticated client and exact JSON contract', () async {
    final http = Transport()
      ..replies.addAll([
        Reply({
          'items': [summaryJson()],
          'emptyReason': null,
          'disclaimer': 'Synthetic',
        }),
        Reply(detailJson()),
        Reply(sessionJson(), statusCode: 201),
        Reply(sessionJson()),
        Reply(feedbackJson(), statusCode: 201),
        Reply(feedbackJson()),
      ]);
    final api = await authenticated(http);
    expect(
      (await api.lessons(childId)).items.single.lessonCode,
      'SYN-MATH-001',
    );
    final lesson = await api.lesson(childId, lessonId);
    expect(lesson.assets.single.storageRef, contains('not-playable.invalid'));
    expect(lesson.cues.single.options, hasLength(2));
    expect((await api.startLearning(childId, lessonId)).state, 'IN_PROGRESS');
    expect((await api.learningSession(childId, sessionId)).answers, isEmpty);
    final answer = await api.submitAnswer(childId, sessionId, request);
    final replay = await api.submitAnswer(childId, sessionId, request);
    expect(answer.feedbackText, 'Server explanation for A');
    expect(replay.answerEventId, answer.answerEventId);
    expect(http.requests.skip(1).map((r) => '${r.method} ${r.uri.path}'), [
      'GET /api/v1/children/$childId/lessons',
      'GET /api/v1/children/$childId/lessons/$lessonId',
      'POST /api/v1/children/$childId/learning-sessions',
      'GET /api/v1/children/$childId/learning-sessions/$sessionId',
      'POST /api/v1/children/$childId/learning-sessions/$sessionId/answers',
      'POST /api/v1/children/$childId/learning-sessions/$sessionId/answers',
    ]);
    for (final call in http.requests.skip(1)) {
      expect(call.headers.value('authorization'), 'Bearer unit-token');
    }
    expect(jsonDecode(http.requests[3].body), {'lessonId': lessonId});
    expect(jsonDecode(http.requests[5].body), request.toJson());
    expect(http.requests[6].body, http.requests[5].body);
    api.clearSession();
    await expectLater(
      api.lessons(childId),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'auth', 'UNAUTHENTICATED'),
      ),
    );
    expect(http.requests, hasLength(7));
  });

  for (final status in [401, 403, 404, 409, 503]) {
    test(
      'Learning HTTP $status preserves safe code, message and request ID without fixture fallback',
      () async {
        final http = Transport()
          ..replies.add(
            Reply({
              'code': 'TEST_$status',
              'message': 'Safe denial',
              'requestId': 'server-request',
            }, statusCode: status),
          );
        final api = await authenticated(http);
        await expectLater(
          api.submitAnswer(childId, sessionId, request),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.code, 'code', 'TEST_$status')
                .having((e) => e.requestId, 'requestId', 'server-request'),
          ),
        );
      },
    );
  }
  for (final error in [
    const SocketException('offline'),
    TimeoutException('late'),
  ]) {
    test('Learning transport ${error.runtimeType} is retryable', () async {
      final http = Transport()..replies.add(error);
      final api = await authenticated(http);
      await expectLater(
        api.lessons(childId),
        throwsA(
          isA<ApiFailure>().having((e) => e.retryable, 'retryable', true),
        ),
      );
    });
  }
  test(
    'invalid JSON, missing lists and malformed response fields fail safely',
    () async {
      final http = Transport()
        ..replies.addAll([
          Reply('not-json', raw: true),
          Reply({'disclaimer': 'Synthetic'}),
          Reply({...feedbackJson(), 'isCorrect': 'true'}),
        ]);
      final api = await authenticated(http);
      await expectLater(
        api.lessons(childId),
        throwsA(isA<ApiInvalidResponse>()),
      );
      await expectLater(
        api.lessons(childId),
        throwsA(isA<ApiInvalidResponse>()),
      );
      await expectLater(
        api.submitAnswer(childId, sessionId, request),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
  test('empty reasons, session readback and option-only models follow the contract', () {
    expect(
      LessonList.fromJson({
        'items': [],
        'emptyReason': 'CHILD_OUTSIDE_PROGRAM_AGE',
        'disclaimer': 'Synthetic',
      }).emptyReason,
      'CHILD_OUTSIDE_PROGRAM_AGE',
    );
    final data = detailJson();
    ((data['cues'] as List).single['options'] as List).first['isCorrect'] =
        true;
    final option = LessonDetail.fromJson(data).cues.single.options.first;
    expect(
      option.labelText,
      'Option A',
    ); // Model exposes no correctness/feedback.
    expect(
      SessionDetail.fromJson(sessionJson(answers: [feedbackJson()]))
          .answers
          .single
          .isCorrect,
      false,
    );
    expect(
      () =>
          LearningSession.fromJson({...sessionJson(), 'startedAt': 'invalid'}),
      throwsA(isA<ApiInvalidResponse>()),
    );
  });
}
