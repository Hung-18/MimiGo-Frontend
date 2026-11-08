import 'dart:math';

import 'api_failure.dart';

abstract class LearningApi {
  Future<CurriculumCatalog> curriculum(String childId);
  Future<LessonList> lessons(String childId);
  Future<LessonDetail> lesson(String childId, String lessonId);
  Future<LearningSession> startLearning(String childId, String lessonId);
  Future<SessionDetail> learningSession(String childId, String sessionId);
  Future<LearningSession> completeLearning(String childId, String sessionId);
  Future<AnswerFeedback> submitAnswer(
    String childId,
    String sessionId,
    AnswerRequest request,
  );
}

/// The 0079/0080 Cloud contract. Legacy fixture learning stays on LearningApi.
abstract interface class InteractiveLearningApi {
  Future<CueStates> cueStates(String childId, String sessionId);
  Future<PlaybackState> playbackState(String childId, String sessionId);
  Future<PlaybackVerdict> playbackEvent(
    String childId,
    String sessionId,
    PlaybackEventRequest request,
  );
}

class CueState {
  CueState.fromJson(Map<String, dynamic> json)
    : cueId = _text(json, 'cueId'),
      seq = _integer(json, 'seq'),
      state = _text(json, 'state'),
      attemptsUsed = _integer(json, 'attemptsUsed'),
      attemptsRemaining = _integer(json, 'attemptsRemaining'),
      resolved = _boolean(json, 'resolved'),
      resumePoint = _boolean(json, 'resumePoint'),
      correctOptionId = _optionalText(json, 'correctOptionId'),
      feedbackText = _optionalText(json, 'feedbackText'),
      feedbackAssetId = _optionalText(json, 'feedbackAssetId'),
      explanationText = _optionalText(json, 'explanationText'),
      explanationAssetId = _optionalText(json, 'explanationAssetId') {
    if (!{'PENDING', 'RETRY_AVAILABLE', 'CORRECT', 'EXHAUSTED'}.contains(state) ||
        attemptsUsed < 0 || attemptsUsed > 2 ||
        attemptsRemaining != 2 - attemptsUsed ||
        (state == 'PENDING' && attemptsUsed != 0) ||
        (state == 'RETRY_AVAILABLE' && attemptsUsed != 1) ||
        (state == 'EXHAUSTED' && attemptsUsed != 2) ||
        (state == 'CORRECT' && attemptsUsed == 0) ||
        resolved != {'CORRECT', 'EXHAUSTED'}.contains(state) ||
        (resolved && correctOptionId == null) ||
        (!resolved && correctOptionId != null)) {
      throw const ApiInvalidResponse('Invalid authoritative cue state.');
    }
  }
  final String cueId, state;
  final int seq, attemptsUsed, attemptsRemaining;
  final bool resolved, resumePoint;
  final String? correctOptionId, feedbackText, feedbackAssetId;
  final String? explanationText, explanationAssetId;
}

class CueStates {
  CueStates.fromJson(Map<String, dynamic> json)
    : sessionId = _text(json, 'sessionId'),
      cues = _items(json, 'cues', CueState.fromJson) {
    if (cues.map((c) => c.cueId).toSet().length != cues.length ||
        cues.where((c) => c.resumePoint).length > 1 ||
        (cues.any((c) => !c.resolved) &&
            cues.where((c) => c.resumePoint).length != 1) ||
        (cues.every((c) => c.resolved) && cues.any((c) => c.resumePoint))) {
      throw const ApiInvalidResponse('Invalid cue resume point.');
    }
  }
  final String sessionId;
  final List<CueState> cues;
  CueState? get resumePoint => cues.where((c) => c.resumePoint).firstOrNull;
  bool get resolved => cues.isNotEmpty && cues.every((c) => c.resolved);
}

class PlaybackState {
  PlaybackState.fromJson(Map<String, dynamic> json)
    : sessionId = _text(json, 'sessionId'),
      durationMs = json['durationMs'] == null ? null : _integer(json, 'durationMs'),
      frontierMs = _integer(json, 'frontierMs'),
      resumePositionMs = _integer(json, 'resumePositionMs'),
      playState = _text(json, 'playState'),
      nextSeq = _integer(json, 'nextSeq'),
      videoEndAccepted = _boolean(json, 'videoEndAccepted'),
      videoEndRequired = _boolean(json, 'videoEndRequired'),
      heartbeatIntervalMs = _integer(json, 'heartbeatIntervalMs') {
    if (!{'PLAYING', 'PAUSED'}.contains(playState) || nextSeq < 1 ||
        frontierMs < 0 || resumePositionMs < 0 ||
        heartbeatIntervalMs < 1000 || heartbeatIntervalMs > 30000) {
      throw const ApiInvalidResponse('Invalid playback state.');
    }
  }
  final String sessionId, playState;
  final int? durationMs;
  final int frontierMs, resumePositionMs, nextSeq, heartbeatIntervalMs;
  final bool videoEndAccepted, videoEndRequired;
}

class PlaybackEventRequest {
  const PlaybackEventRequest(this.eventId, this.seq, this.kind, this.positionMs);
  final String eventId, kind;
  final int seq, positionMs;
  Map<String, Object> toJson() => {
    'eventId': eventId,
    'seq': seq,
    'kind': kind,
    'positionMs': positionMs,
  };
}

class PlaybackVerdict {
  PlaybackVerdict.fromJson(Map<String, dynamic> json)
    : verdict = _text(json, 'verdict'),
      reason = _optionalText(json, 'reason'),
      replayed = _boolean(json, 'replayed'),
      acceptedPositionMs = json['acceptedPositionMs'] == null
          ? null : _integer(json, 'acceptedPositionMs'),
      frontierMs = _integer(json, 'frontierMs'),
      resumePositionMs = _integer(json, 'resumePositionMs'),
      durationMs = json['durationMs'] == null ? null : _integer(json, 'durationMs'),
      videoEndAccepted = _boolean(json, 'videoEndAccepted') {
    if (!{'ACCEPTED', 'CLAMPED', 'REJECTED'}.contains(verdict) ||
        frontierMs < 0 || resumePositionMs < 0 ||
        (verdict == 'REJECTED' && acceptedPositionMs != null)) {
      throw const ApiInvalidResponse('Invalid playback verdict.');
    }
  }
  final String verdict;
  final String? reason;
  final bool replayed, videoEndAccepted;
  final int? acceptedPositionMs, durationMs;
  final int frontierMs, resumePositionMs;
}

/// An ambiguous POST keeps the exact identity, sequence and payload.
class PlaybackEventLedger {
  PlaybackEventLedger(this.nextSeq);
  int nextSeq;
  PlaybackEventRequest? pending;
  PlaybackEventRequest prepare(String kind, int positionMs) =>
      pending ??= PlaybackEventRequest(_uuid(), nextSeq, kind, positionMs);
  void acknowledge() {
    if (pending != null) nextSeq = pending!.seq + 1;
    pending = null;
  }
  void reconcile(PlaybackState state) {
    nextSeq = state.nextSeq;
    pending = null;
  }
}

class CurriculumTopicData {
  CurriculumTopicData.fromJson(Map<String, dynamic> json)
    : code = _text(json, 'topicCode'),
      name = _text(json, 'name'),
      sortOrder = _integer(json, 'sortOrder'),
      lessons = _items(json, 'lessons', LessonSummary.fromJson) {
    if (lessons.isEmpty ||
        lessons.any(
          (lesson) =>
              lesson.topicCode != code ||
              !{'FREE', 'CORE'}.contains(lesson.access),
        ) ||
        lessons.map((lesson) => lesson.lessonId).toSet().length !=
            lessons.length)
      throw const ApiInvalidResponse('Invalid eligible topic lessons.');
  }
  final String code, name;
  final int sortOrder;
  final List<LessonSummary> lessons;
}

class CurriculumDomainData {
  CurriculumDomainData.fromJson(Map<String, dynamic> json)
    : code = _text(json, 'domainCode'),
      name = _text(json, 'name'),
      sortOrder = _integer(json, 'sortOrder'),
      topics = _items(json, 'topics', CurriculumTopicData.fromJson) {
    if (topics.isEmpty ||
        topics.any(
          (topic) => topic.lessons.any((lesson) => lesson.domainCode != code),
        ) ||
        topics.map((topic) => topic.code).toSet().length != topics.length)
      throw const ApiInvalidResponse('Invalid eligible curriculum domain.');
  }
  final String code, name;
  final int sortOrder;
  final List<CurriculumTopicData> topics;
}

class CurriculumCatalog {
  const CurriculumCatalog(this.domains, this.emptyReason, this.disclaimer);
  factory CurriculumCatalog.fromJson(Map<String, dynamic> json) {
    final domains = _items(json, 'domains', CurriculumDomainData.fromJson);
    if (domains.map((domain) => domain.code).toSet().length != domains.length)
      throw const ApiInvalidResponse('Duplicate curriculum domains.');
    return CurriculumCatalog(
      domains,
      _optionalText(json, 'emptyReason'),
      _text(json, 'disclaimer'),
    );
  }
  final List<CurriculumDomainData> domains;
  final String? emptyReason;
  final String disclaimer;
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

bool? _recordedCorrectness(Map<String, dynamic> json) {
  if (!json.containsKey('isCorrect'))
    throw const ApiInvalidResponse('Missing recorded correctness.');
  return json['isCorrect'] == null ? null : _boolean(json, 'isCorrect');
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
      labelText = _text(json, 'labelText'),
      imageAssetId = _optionalText(json, 'imageAssetId'),
      audioAssetId = _optionalText(json, 'audioAssetId');
  final String optionId, labelText;
  final String? imageAssetId, audioAssetId;
  final int position;
}

class LearningCue {
  LearningCue.fromJson(Map<String, dynamic> json)
    : cueId = _text(json, 'cueId'),
      seq = _integer(json, 'seq'),
      pauseAtMs = _integer(json, 'pauseAtMs'),
      promptText = _text(json, 'promptText'),
      promptAssetId = _optionalText(json, 'promptAssetId'),
      hintText = _optionalText(json, 'hintText'),
      hintAssetId = _optionalText(json, 'hintAssetId'),
      options = _items(json, 'options', CueOption.fromJson);
  final String cueId, promptText;
  final String? promptAssetId, hintText, hintAssetId;
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

  void validateSession(LearningSession value, String childId) {
    if (value.childId != childId ||
        value.lessonId != summary.lessonId ||
        value.revisionId != revisionId) {
      throw const ApiInvalidResponse(
        'Session and loaded lesson revision do not match. Return to the lesson list and reopen the lesson.',
      );
    }
    if (value is SessionDetail) {
      for (final answer in value.answers) {
        if (!cues.any(
          (cue) =>
              cue.cueId == answer.cueId &&
              cue.options.any((option) => option.optionId == answer.optionId),
        )) {
          throw const ApiInvalidResponse(
            'Recorded answers do not match this lesson revision.',
          );
        }
      }
    }
  }
}

class LearningSession {
  LearningSession.fromJson(Map<String, dynamic> json)
    : sessionId = _text(json, 'sessionId'),
      childId = _text(json, 'childId'),
      lessonId = _text(json, 'lessonId'),
      revisionId = _text(json, 'revisionId'),
      state = _text(json, 'state'),
      startedAt = _date(json, 'startedAt'),
      lastActivityAt = _date(json, 'lastActivityAt'),
      endedAt = _endedAt(json) {
    if (!{'IN_PROGRESS', 'COMPLETED', 'ABANDONED'}.contains(state) ||
        (state == 'COMPLETED' && endedAt == null) ||
        (state == 'IN_PROGRESS' && endedAt != null)) {
      throw const ApiInvalidResponse('Invalid session state or endedAt.');
    }
  }
  LearningSession.copy(LearningSession value)
    : sessionId = value.sessionId,
      childId = value.childId,
      lessonId = value.lessonId,
      revisionId = value.revisionId,
      state = value.state,
      startedAt = value.startedAt,
      lastActivityAt = value.lastActivityAt,
      endedAt = value.endedAt;
  final String sessionId, childId, lessonId, revisionId, state;
  final DateTime startedAt, lastActivityAt;
  final DateTime? endedAt;
}

DateTime? _endedAt(Map<String, dynamic> json) {
  if (!json.containsKey('endedAt'))
    throw const ApiInvalidResponse('Session response is missing endedAt.');
  return json['endedAt'] == null ? null : _date(json, 'endedAt');
}

class RecordedAnswer {
  RecordedAnswer.fromJson(Map<String, dynamic> json)
    : cueId = _text(json, 'cueId'),
      optionId = _text(json, 'optionId'),
      attemptNo = _integer(json, 'attemptNo'),
      usedHint = _boolean(json, 'usedHint'),
      isCorrect = _recordedCorrectness(json);
  final String cueId, optionId;
  final int attemptNo;
  final bool usedHint;
  final bool? isCorrect;
}

class SessionDetail extends LearningSession {
  SessionDetail.fromJson(super.json)
    : answers = _items(json, 'answers', RecordedAnswer.fromJson),
      super.fromJson();
  SessionDetail.fromSession(super.value, Iterable<RecordedAnswer> recorded)
    : answers = List.unmodifiable(recorded),
      super.copy();
  final List<RecordedAnswer> answers;
}

class AnswerFeedback extends RecordedAnswer {
  AnswerFeedback.fromJson(super.json)
    : answerEventId = _integer(json, 'answerEventId'),
      sessionId = _text(json, 'sessionId'),
      feedbackText = _text(json, 'feedbackText'),
      feedbackAssetId = _optionalText(json, 'feedbackAssetId'),
      recordedAt = _date(json, 'recordedAt'),
      super.fromJson() {
    if (isCorrect == null)
      throw const ApiInvalidResponse(
        'Answer acknowledgment needs correctness.',
      );
  }
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
