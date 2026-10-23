import 'dart:math';

import 'api_failure.dart';

abstract class LearningApi {
  Future<LessonList> lessons(String childId);
  Future<LessonDetail> lesson(String childId, String lessonId);
  Future<LearningSession> startLearning(String childId, String lessonId);
  Future<SessionDetail> learningSession(String childId, String sessionId);
  Future<AnswerFeedback> submitAnswer(
    String childId,
    String sessionId,
    AnswerRequest request,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>)
    throw const ApiInvalidResponse('Invalid learning response object.');
  return value;
}

String _text(Map<String, dynamic> json, String key) {
  if (json[key] is! String)
    throw ApiInvalidResponse('Invalid learning field: $key.');
  return json[key] as String;
}

String? _optionalText(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _text(json, key);
int _integer(Map<String, dynamic> json, String key) {
  if (json[key] is! int)
    throw ApiInvalidResponse('Invalid learning field: $key.');
  return json[key] as int;
}

bool _boolean(Map<String, dynamic> json, String key) {
  if (json[key] is! bool)
    throw ApiInvalidResponse('Invalid learning field: $key.');
  return json[key] as bool;
}

DateTime _date(Map<String, dynamic> json, String key) =>
    DateTime.tryParse(_text(json, key)) ??
    (throw ApiInvalidResponse('Invalid learning date: $key.'));
List<T> _items<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) throw ApiInvalidResponse('Invalid learning list: $key.');
  return List.unmodifiable(value.map((item) => parse(_object(item))));
}

class LessonSummary {
  const LessonSummary({
    required this.lessonId,
    required this.lessonCode,
    required this.revisionNo,
    required this.title,
    required this.objective,
    required this.domainCode,
    required this.topicCode,
    required this.primarySkill,
    required this.access,
  });
  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    lessonId: _text(json, 'lessonId'),
    lessonCode: _text(json, 'lessonCode'),
    revisionNo: _integer(json, 'revisionNo'),
    title: _text(json, 'title'),
    objective: _text(json, 'objective'),
    domainCode: _text(json, 'domainCode'),
    topicCode: _text(json, 'topicCode'),
    primarySkill: _text(json, 'primarySkill'),
    access: _text(json, 'access'),
  );
  final String lessonId,
      lessonCode,
      title,
      objective,
      domainCode,
      topicCode,
      primarySkill,
      access;
  final int revisionNo;
}

class LessonList {
  const LessonList(this.items, this.emptyReason, this.disclaimer);
  factory LessonList.fromJson(Map<String, dynamic> json) => LessonList(
    _items(json, 'items', LessonSummary.fromJson),
    _optionalText(json, 'emptyReason'),
    _text(json, 'disclaimer'),
  );
  final List<LessonSummary> items;
  final String? emptyReason;
  final String disclaimer;
}

class LessonAsset {
  LessonAsset.fromJson(Map<String, dynamic> json)
    : assetId = _text(json, 'assetId'),
      kind = _text(json, 'kind'),
      role = _text(json, 'role'),
      mimeType = _text(json, 'mimeType'),
      contentHash = _text(json, 'contentHash'),
      storageRef = _text(json, 'storageRef'),
      rightsStatus = _text(json, 'rightsStatus');
  final String assetId,
      kind,
      role,
      mimeType,
      contentHash,
      storageRef,
      rightsStatus;
}

// No correctness or feedback fields exist on lesson options.
class CueOption {
  CueOption.fromJson(Map<String, dynamic> json)
    : optionId = _text(json, 'optionId'),
      position = _integer(json, 'position'),
      labelText = _text(json, 'labelText');
  final String optionId, labelText;
  final int position;
}

class LearningCue {
  LearningCue.fromJson(Map<String, dynamic> json)
    : cueId = _text(json, 'cueId'),
      seq = _integer(json, 'seq'),
      pauseAtMs = _integer(json, 'pauseAtMs'),
      promptText = _text(json, 'promptText'),
      promptAssetId = _optionalText(json, 'promptAssetId'),
      options = _items(json, 'options', CueOption.fromJson);
  final String cueId, promptText;
  final String? promptAssetId;
  final int seq, pauseAtMs;
  final List<CueOption> options;
}

class LessonDetail {
  LessonDetail.fromJson(Map<String, dynamic> json)
    : summary = LessonSummary.fromJson(json),
      revisionId = _text(json, 'revisionId'),
      assets = _items(json, 'assets', LessonAsset.fromJson),
      cues = _items(json, 'cues', LearningCue.fromJson),
      disclaimer = _text(json, 'disclaimer');
  final LessonSummary summary;
  final String revisionId, disclaimer;
  final List<LessonAsset> assets;
  final List<LearningCue> cues;
}

class LearningSession {
  LearningSession.fromJson(Map<String, dynamic> json)
    : sessionId = _text(json, 'sessionId'),
      childId = _text(json, 'childId'),
      lessonId = _text(json, 'lessonId'),
      revisionId = _text(json, 'revisionId'),
      state = _text(json, 'state'),
      startedAt = _date(json, 'startedAt'),
      lastActivityAt = _date(json, 'lastActivityAt');
  final String sessionId, childId, lessonId, revisionId, state;
  final DateTime startedAt, lastActivityAt;
}

class RecordedAnswer {
  RecordedAnswer.fromJson(Map<String, dynamic> json)
    : cueId = _text(json, 'cueId'),
      optionId = _text(json, 'optionId'),
      attemptNo = _integer(json, 'attemptNo'),
      usedHint = _boolean(json, 'usedHint'),
      isCorrect = _boolean(json, 'isCorrect');
  final String cueId, optionId;
  final int attemptNo;
  final bool usedHint, isCorrect;
}

class SessionDetail extends LearningSession {
  SessionDetail.fromJson(super.json)
    : answers = _items(json, 'answers', RecordedAnswer.fromJson),
      super.fromJson();
  final List<RecordedAnswer> answers;
}

class AnswerFeedback extends RecordedAnswer {
  AnswerFeedback.fromJson(super.json)
    : answerEventId = _integer(json, 'answerEventId'),
      sessionId = _text(json, 'sessionId'),
      feedbackText = _text(json, 'feedbackText'),
      feedbackAssetId = _optionalText(json, 'feedbackAssetId'),
      recordedAt = _date(json, 'recordedAt'),
      super.fromJson();
  final int answerEventId;
  final String sessionId, feedbackText;
  final String? feedbackAssetId;
  final DateTime recordedAt;
}

class AnswerRequest {
  const AnswerRequest({
    required this.clientEventId,
    required this.cueId,
    required this.optionId,
    this.usedHint = false,
  });
  final String clientEventId, cueId, optionId;
  final bool usedHint;
  Map<String, Object> toJson() => {
    'clientEventId': clientEventId,
    'cueId': cueId,
    'optionId': optionId,
    'usedHint': usedHint,
  };
}

/// In-memory, child/session/cue-scoped retry payloads. Never persist credentials
/// or invent a new event ID to work around a failed or ambiguous answer.
class PendingLearningAnswers {
  final _pending = <(String, String, String), AnswerRequest>{};
  AnswerRequest? find(String childId, String sessionId, String cueId) =>
      _pending[(childId, sessionId, cueId)];
  AnswerRequest prepare(
    String childId,
    String sessionId,
    String cueId,
    String optionId,
  ) => _pending.putIfAbsent(
    (childId, sessionId, cueId),
    () =>
        AnswerRequest(clientEventId: _uuid(), cueId: cueId, optionId: optionId),
  );
  void acknowledge(String childId, String sessionId, AnswerRequest request) {
    final key = (childId, sessionId, request.cueId);
    if (identical(_pending[key], request)) _pending.remove(key);
  }

  void clear() => _pending.clear();
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
