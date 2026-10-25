import 'package:flutter/foundation.dart';

import 'api_failure.dart';
import 'learning_models.dart';

/// Authenticated-lifetime, child-scoped session identities/readbacks. Backend
/// remains authoritative; this is neither durable storage nor a progress index.
class LearningSessionMemory extends ChangeNotifier {
  LearningSessionMemory(this.api);
  final LearningApi api;
  final _sessions = <(String, String), SessionDetail>{};
  final _resume = <(String, String), String>{};
  final _completing = <(String, String), Future<SessionDetail>>{};
  final _replaying = <(String, String), Future<SessionDetail>>{};
  final _completeErrors = <(String, String), ApiFailure>{};
  final _replayErrors = <(String, String), ApiFailure>{};
  final _opening = <(String, String), Future<SessionDetail>>{};
  final _reading = <(String, String), Future<SessionDetail>>{};
  final _answering =
      <(String, String), (AnswerRequest, Future<AnswerFeedback>)>{};
  final _answerErrors = <(String, String), (String, ApiFailure)>{};
  final _accessEpoch = <(String, String), int>{};
  final _accessDenials = <(String, String), ApiFailure>{};
  int _generation = 0;

  bool opening(String childId, String lessonId) =>
      _opening.containsKey((childId, lessonId));
  bool answering(String childId, String sessionId) =>
      _answering.containsKey((childId, sessionId));
  String? sendingCue(String childId, String sessionId) =>
      _answering[(childId, sessionId)]?.$1.cueId;
  ApiFailure? answerError(String childId, String sessionId, String cueId) {
    final failure = _answerErrors[(childId, sessionId)];
    return failure?.$1 == cueId ? failure!.$2 : null;
  }

  ApiFailure? accessError(String childId, String sessionId, String lessonId) {
    for (final failure in [
      _accessDenials[(childId, lessonId)],
      _completeErrors[(childId, sessionId)],
      _replayErrors[(childId, lessonId)],
      _answerErrors[(childId, sessionId)]?.$2,
    ]) {
      if (_denied(failure)) return failure;
    }
    return null;
  }

  static bool _denied(ApiFailure? failure) =>
      {401, 403, 404}.contains(failure?.status);

  void _recordDenial(String childId, String lessonId, ApiFailure failure) {
    if (!_denied(failure)) return;
    final key = (childId, lessonId);
    _accessEpoch[key] = (_accessEpoch[key] ?? 0) + 1;
    _accessDenials[key] = failure;
  }

  /// Share start + readback across Back/reopen. A successful start identity is
  /// retained even if its GET fails, so retry reads that session, not a new one.
  Future<SessionDetail> open(String childId, LessonDetail lesson) {
    final key = (childId, lesson.summary.lessonId);
    if (_opening[key] case final pending?) return pending;
    final known = _resume[key];
    if (known != null) return read(childId, lesson, known);
    final future = _open(childId, lesson, _generation);
    _opening[key] = future;
    notifyListeners();
    return future;
  }

  Future<SessionDetail> _open(
    String childId,
    LessonDetail lesson,
    int generation,
  ) async {
    final key = (childId, lesson.summary.lessonId);
    try {
      final started = await api.startLearning(childId, lesson.summary.lessonId);
      _checkGeneration(generation);
      lesson.validateSession(started, childId);
      if (started.state != 'IN_PROGRESS') {
        throw const ApiInvalidResponse(
          'Start did not return an in-progress session.',
        );
      }
      _resume[key] = started.sessionId;
      return await read(childId, lesson, started.sessionId);
    } finally {
      if (generation == _generation) {
        _opening.remove(key);
        notifyListeners();
      }
    }
  }

  Future<SessionDetail> read(
    String childId,
    LessonDetail lesson,
    String sessionId, {
    bool activate = true,
  }) async {
    final key = (childId, sessionId);
    final generation = _generation;
    var future = _reading[key];
    if (future == null) {
      future = _read(childId, lesson, sessionId, generation);
      _reading[key] = future;
    }
    final result = await future;
    _checkGeneration(generation);
    // Each caller still validates its own expected lesson/revision.
    lesson.validateSession(result, childId);
    if (activate) {
      _resume[(childId, lesson.summary.lessonId)] = sessionId;
      notifyListeners();
    }
    return result;
  }

  Future<SessionDetail> _read(
    String childId,
    LessonDetail lesson,
    String sessionId,
    int generation,
  ) async {
    final key = (childId, sessionId);
    final accessKey = (childId, lesson.summary.lessonId);
    final accessEpoch = _accessEpoch[accessKey];
    try {
      final value = await api.learningSession(childId, sessionId);
      _checkGeneration(generation);
      // A read initiated before a newer access denial cannot clear that denial.
      // Only a fresh successful request may establish readable server state.
      if (_accessEpoch[accessKey] != accessEpoch &&
          _accessDenials[accessKey] != null)
        throw _accessDenials[accessKey]!;
      lesson.validateSession(value, childId);
      if (value.sessionId != sessionId) {
        throw const ApiInvalidResponse(
          'The service returned a different session.',
        );
      }
      final snapshot = remember(value, activate: false);
      _accessDenials.remove(accessKey);
      return snapshot;
    } on ApiFailure catch (failure) {
      if (generation == _generation)
        _recordDenial(childId, lesson.summary.lessonId, failure);
      rethrow;
    } finally {
      if (generation == _generation) _reading.remove(key);
    }
  }

  Future<AnswerFeedback> submit(
    String childId,
    String sessionId,
    AnswerRequest request,
  ) {
    final key = (childId, sessionId);
    if (_answering[key] case final pending?) {
      final original = pending.$1;
      if (original.clientEventId == request.clientEventId &&
          original.cueId == request.cueId &&
          original.optionId == request.optionId &&
          original.usedHint == request.usedHint)
        return pending.$2;
      return Future.error(const ApiFailure('Wait for the answer being sent.'));
    }
    if (_sessions[key]?.state != 'IN_PROGRESS' ||
        completing(childId, sessionId) ||
        (_completeErrors[key] != null &&
            _completeErrors[key]!.code != 'SESSION_INCOMPLETE')) {
      return Future.error(
        const ApiFailure('Refresh this session before answering.'),
      );
    }
    _answerErrors.remove(key);
    final future = _submit(childId, sessionId, request, _generation);
    _answering[key] = (request, future);
    notifyListeners();
    return future;
  }

  Future<AnswerFeedback> _submit(
    String childId,
    String sessionId,
    AnswerRequest request,
    int generation,
  ) async {
    final key = (childId, sessionId);
    try {
      final value = await api.submitAnswer(childId, sessionId, request);
      _checkGeneration(generation);
      if (value.sessionId != sessionId ||
          value.cueId != request.cueId ||
          value.optionId != request.optionId ||
          value.usedHint != request.usedHint) {
        throw const ApiInvalidResponse(
          'Answer acknowledgment did not match the submitted choice. Retry the same answer.',
        );
      }
      return value;
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        _answerErrors[key] = (request.cueId, failure);
        final lessonId = _sessions[key]?.lessonId;
        if (lessonId != null) _recordDenial(childId, lessonId, failure);
      }
      rethrow;
    } finally {
      if (generation == _generation) {
        _answering.remove(key);
        notifyListeners();
      }
    }
  }

  SessionDetail? session(String childId, String sessionId) =>
      _sessions[(childId, sessionId)];
  String? resumeId(String childId, String lessonId) =>
      _resume[(childId, lessonId)];
  bool completing(String childId, String sessionId) =>
      _completing.containsKey((childId, sessionId));
  bool replaying(String childId, String lessonId) =>
      _replaying.containsKey((childId, lessonId));
  ApiFailure? completionError(String childId, String sessionId) =>
      _completeErrors[(childId, sessionId)];
  ApiFailure? replayError(String childId, String lessonId) =>
      _replayErrors[(childId, lessonId)];
  List<SessionDetail> completed(String childId, String lessonId) =>
      List.unmodifiable(
        _sessions.values.where(
          (value) =>
              value.childId == childId &&
              value.lessonId == lessonId &&
              value.state == 'COMPLETED',
        ),
      );

  SessionDetail remember(
    SessionDetail value, {
    bool activate = true,
    bool clearError = true,
  }) {
    final key = (value.childId, value.sessionId);
    final prior = _sessions[key];
    if (prior != null &&
        (prior.lessonId != value.lessonId ||
            prior.revisionId != value.revisionId)) {
      throw const ApiInvalidResponse(
        'Session identity changed in the response.',
      );
    }
    // A late pre-completion readback must not erase a confirmed terminal fact.
    // Guarded readback may redact correctness; answer identities stay immutable
    // and a non-null correctness value cannot contradict another non-null value.
    if (prior?.state == 'COMPLETED') {
      if (value.state != 'COMPLETED') return prior!;
      if (prior!.endedAt != value.endedAt)
        throw const ApiInvalidResponse('Completed session endedAt changed.');
      for (final saved in prior.answers) {
        if (!value.answers.any(
          (answer) =>
              answer.cueId == saved.cueId &&
              answer.attemptNo == saved.attemptNo &&
              answer.optionId == saved.optionId &&
              answer.usedHint == saved.usedHint &&
              (answer.isCorrect == saved.isCorrect ||
                  answer.isCorrect == null ||
                  saved.isCorrect == null),
        )) {
          throw const ApiInvalidResponse(
            'Completed session recorded answers changed.',
          );
        }
      }
    }
    final snapshot = SessionDetail.fromSession(value, value.answers);
    _sessions[key] = snapshot;
    if (activate) _resume[(value.childId, value.lessonId)] = value.sessionId;
    if (clearError) {
      _completeErrors.remove(key);
      if (_answerErrors[key]?.$2.code != 'CLIENT_EVENT_CONFLICT')
        _answerErrors.remove(key);
      _replayErrors.remove((value.childId, value.lessonId));
    }
    notifyListeners();
    return snapshot;
  }

  Future<SessionDetail> complete(String childId, String sessionId) {
    final key = (childId, sessionId);
    if (_completing[key] case final existing?) return existing;
    if (answering(childId, sessionId))
      return Future.error(const ApiFailure('Wait for the answer being sent.'));
    final current = _sessions[key];
    if (current == null)
      return Future.error(
        const ApiInvalidResponse('Read the session before completing it.'),
      );
    if (current.state == 'COMPLETED') return Future.value(current);
    if (current.state != 'IN_PROGRESS')
      return Future.error(
        const ApiFailure(
          'Refresh the ended session.',
          code: 'SESSION_NOT_ACTIVE',
          status: 409,
        ),
      );
    _completeErrors.remove(key);
    final future = _complete(current, _generation);
    _completing[key] = future;
    notifyListeners();
    return future;
  }

  Future<SessionDetail> _complete(SessionDetail current, int generation) async {
    final key = (current.childId, current.sessionId);
    try {
      final reply = await api.completeLearning(
        current.childId,
        current.sessionId,
      );
      _checkGeneration(generation);
      if (reply.childId != current.childId ||
          reply.sessionId != current.sessionId ||
          reply.lessonId != current.lessonId ||
          reply.revisionId != current.revisionId ||
          reply.state != 'COMPLETED' ||
          reply.endedAt == null) {
        throw const ApiInvalidResponse(
          'Completion response did not confirm this completed session.',
        );
      }
      return remember(
        SessionDetail.fromSession(reply, _sessions[key]!.answers),
        activate: false,
      );
    } on ApiFailure catch (failure) {
      if (generation == _generation)
        _recordDenial(current.childId, current.lessonId, failure);
      if (generation == _generation &&
          (_denied(failure) || _sessions[key]?.state != 'COMPLETED'))
        _completeErrors[key] = failure;
      rethrow;
    } finally {
      if (generation == _generation) {
        _completing.remove(key);
        notifyListeners();
      }
    }
  }

  Future<SessionDetail> replay(
    String childId,
    String completedId,
    LessonDetail lesson,
  ) {
    final current = _sessions[(childId, completedId)];
    if (current?.state != 'COMPLETED')
      return Future.error(
        const ApiInvalidResponse(
          'Confirm completion before starting a replay.',
        ),
      );
    final key = (childId, current!.lessonId);
    if (_replaying[key] case final existing?) return existing;
    if (lesson.summary.lessonId != current.lessonId)
      return Future.error(
        const ApiInvalidResponse(
          'Replay lesson does not match the completed session.',
        ),
      );
    _replayErrors.remove(key);
    final future = _replay(current, lesson, _generation);
    _replaying[key] = future;
    notifyListeners();
    return future;
  }

  Future<SessionDetail> _replay(
    SessionDetail completed,
    LessonDetail lesson,
    int generation,
  ) async {
    final key = (completed.childId, completed.lessonId);
    try {
      final active = _resume[key];
      if (active != null &&
          active != completed.sessionId &&
          session(completed.childId, active)?.state == 'IN_PROGRESS') {
        return await read(completed.childId, lesson, active);
      }
      // The start endpoint creates a NEW session after completion, or reuses
      // an existing IN_PROGRESS replay if a previous start response was lost.
      final started = await api.startLearning(
        completed.childId,
        completed.lessonId,
      );
      _checkGeneration(generation);
      lesson.validateSession(started, completed.childId);
      if (started.childId != completed.childId ||
          started.lessonId != completed.lessonId ||
          started.sessionId == completed.sessionId ||
          started.state != 'IN_PROGRESS' ||
          started.endedAt != null) {
        throw const ApiInvalidResponse(
          'Replay did not return a new in-progress session.',
        );
      }
      final result = await read(
        completed.childId,
        lesson,
        started.sessionId,
        activate: false,
      );
      _checkGeneration(generation);
      if (result.revisionId != started.revisionId) {
        throw const ApiInvalidResponse(
          'Replay readback did not match the new session.',
        );
      }
      return remember(result);
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        _replayErrors[key] = failure;
        _recordDenial(completed.childId, completed.lessonId, failure);
      }
      rethrow;
    } finally {
      if (generation == _generation) {
        _replaying.remove(key);
        notifyListeners();
      }
    }
  }

  void _checkGeneration(int generation) {
    if (generation != _generation)
      throw const ApiFailure(
        'The local account session changed.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
  }

  void clear() {
    _generation++;
    _sessions.clear();
    _resume.clear();
    _completing.clear();
    _replaying.clear();
    _completeErrors.clear();
    _replayErrors.clear();
    _opening.clear();
    _reading.clear();
    _answering.clear();
    _answerErrors.clear();
    _accessEpoch.clear();
    _accessDenials.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
