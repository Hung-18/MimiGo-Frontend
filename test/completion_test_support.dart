import 'dart:async';

import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

import 'learning_widget_test.dart' show LearningTestApi;
import 'learning_test_data.dart';

const replaySessionId = '99999999-9999-4999-8999-999999999999';
const completedTime = '2026-10-23T12:05:00Z';
const secondCueId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const secondOptionId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Map<String, dynamic> completedJson({String id = sessionId}) => {
  ...sessionJson(),
  'sessionId': id,
  'state': 'COMPLETED',
  'endedAt': completedTime,
};

class CompletionApi extends LearningTestApi {
  CompletionApi({this.twoCues = false}) {
    data[sessionId] = sessionJson();
    events[sessionId] = {};
  }
  final bool twoCues;
  final data = <String, Map<String, dynamic>>{};
  final events = <String, Map<String, Map<String, dynamic>>>{};
  final completionCalls = <String>[];
  final startBodies = <String>[];
  final readIds = <String>[];
  String activeId = sessionId;
  ApiFailure? completeFailure, replayFailure;
  Completer<LearningSession>? completeGate, replayGate;
  Completer<LearningSession>? startGate;
  Completer<SessionDetail>? readGate;
  Map<String, dynamic>? completionOverride, lessonOverride, readOverride;
  bool loseCompletionAck = false, loseReplayAck = false;

  Map<String, dynamic> lessonBody() {
    if (lessonOverride != null) return lessonOverride!;
    final body = detailJson();
    if (twoCues)
      (body['cues'] as List).add({
        'cueId': secondCueId,
        'seq': 2,
        'pauseAtMs': 2000,
        'promptText': 'Final synthetic question',
        'options': [
          {
            'optionId': secondOptionId,
            'position': 1,
            'labelText': 'Final option',
          },
        ],
      });
    return body;
  }

  @override
  Future<LessonDetail> lesson(String child, String id) async =>
      LessonDetail.fromJson(lessonBody());

  LearningSession completeReply(String id) {
    data[id] = {...data[id]!, 'state': 'COMPLETED', 'endedAt': completedTime};
    return LearningSession.fromJson(data[id]!);
  }

  LearningSession prepareReplay() {
    activeId = replaySessionId;
    data.putIfAbsent(activeId, () => {...sessionJson(), 'sessionId': activeId});
    events.putIfAbsent(activeId, () => {});
    return LearningSession.fromJson(data[activeId]!);
  }

  void seedWrongAnswers(String id) {
    final cues = lessonBody()['cues'] as List;
    for (final cue in cues) {
      final cueMap = cue as Map<String, dynamic>;
      events[id]!['seed-${cueMap['cueId']}'] = {
        ...feedbackJson(),
        'sessionId': id,
        'cueId': cueMap['cueId'],
        'optionId': (cueMap['options'] as List).first['optionId'],
      };
    }
  }

  SessionDetail snapshot(String id) => SessionDetail.fromJson({
    ...data[id]!,
    'answers': events[id]!.values.toList(),
  });

  @override
  Future<LearningSession> startLearning(String child, String id) async {
    starts++;
    startBodies.add(id);
    if (startFailure != null) throw startFailure!;
    if (startGate != null) return startGate!.future;
    if (data[activeId]!['state'] != 'IN_PROGRESS') {
      if (replayFailure != null) throw replayFailure!;
      if (replayGate != null) return replayGate!.future;
      prepareReplay();
      if (loseReplayAck) {
        loseReplayAck = false;
        throw const ApiFailure(
          'Replay response lost.',
          code: 'CONNECTIVITY',
          retryable: true,
        );
      }
    }
    return LearningSession.fromJson(data[activeId]!);
  }

  @override
  Future<SessionDetail> learningSession(String child, String id) async {
    reads++;
    readIds.add(id);
    if (readFailure != null) throw readFailure!;
    if (readGate != null) return readGate!.future;
    if (readOverride != null) return SessionDetail.fromJson(readOverride!);
    if (!data.containsKey(id))
      throw const ApiFailure(
        'Missing session.',
        code: 'SESSION_NOT_FOUND',
        status: 404,
      );
    return snapshot(id);
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
    if (data[id]!['state'] != 'IN_PROGRESS')
      throw const ApiFailure(
        'Ended session.',
        code: 'SESSION_NOT_ACTIVE',
        status: 409,
      );
    final body = events[id]!.putIfAbsent(
      request.clientEventId,
      () => {
        ...feedbackJson(),
        'sessionId': id,
        'cueId': request.cueId,
        'optionId': request.optionId,
        'feedbackText': request.cueId == secondCueId
            ? 'Final server explanation'
            : 'First server explanation',
      },
    );
    return AnswerFeedback.fromJson(body);
  }

  @override
  Future<LearningSession> completeLearning(String child, String id) async {
    completionCalls.add(id);
    if (completeFailure != null) throw completeFailure!;
    if (completionOverride != null)
      return LearningSession.fromJson(completionOverride!);
    if (completeGate != null) return completeGate!.future;
    if (data[id]!['state'] == 'COMPLETED')
      return LearningSession.fromJson(data[id]!);
    final cues = lessonBody()['cues'] as List;
    if (cues.isEmpty ||
        cues.any(
          (cue) => !events[id]!.values.any(
            (answer) => answer['cueId'] == cue['cueId'],
          ),
        )) {
      throw const ApiFailure(
        'Record every question first.',
        code: 'SESSION_INCOMPLETE',
        status: 409,
      );
    }
    final reply = completeReply(id);
    if (loseCompletionAck) {
      loseCompletionAck = false;
      throw const ApiFailure(
        'Completion response lost.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
    return reply;
  }
}
