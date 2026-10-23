import 'package:flutter/material.dart';

import 'api_failure.dart';
import 'learning_models.dart';

class LearningLabel extends StatelessWidget {
  const LearningLabel({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'DEVELOPMENT / DEMO · synthetic Free learning content. Not production approved.',
    ),
  );
}

class LearningError extends StatelessWidget {
  const LearningError(this.failure, {super.key});
  final ApiFailure failure;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '${failure.code ?? 'REQUEST_FAILED'}${failure.status == null ? '' : ' (HTTP ${failure.status})'}: ${failure.message}'
      '${failure.requestId == null ? '' : '\nRequest: ${failure.requestId}'}'
      '${failure.status == 401 ? '\nReturn to Child Mode and account entry to sign in again.' : ''}',
      key: const Key('learningError'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class MathLessonCatalog extends StatefulWidget {
  const MathLessonCatalog({
    super.key,
    required this.api,
    required this.childId,
    required this.openLesson,
  });
  final LearningApi api;
  final String childId;
  final ValueChanged<String> openLesson;
  @override
  State<MathLessonCatalog> createState() => _MathLessonCatalogState();
}

class _MathLessonCatalogState extends State<MathLessonCatalog> {
  late Future<LessonList> result;
  @override
  void initState() {
    super.initState();
    result = widget.api.lessons(widget.childId);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LearningLabel(),
      FutureBuilder<LessonList>(
        future: result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  Text('Loading eligible lessons…'),
                ],
              ),
            );
          if (snapshot.hasError)
            return Column(
              children: [
                LearningError(
                  snapshot.error is ApiFailure
                      ? snapshot.error! as ApiFailure
                      : const ApiInvalidResponse('Could not read lesson list.'),
                ),
                OutlinedButton(
                  key: const Key('lessonsRetry'),
                  onPressed: () => setState(() {
                    result = widget.api.lessons(widget.childId);
                  }),
                  child: const Text('Try again'),
                ),
              ],
            );
          final response = snapshot.data!;
          // Eligibility and age are authoritative on the server. Only select the
          // requested Math domain from its returned Free results; no local ages.
          final math = response.items.where(
            (lesson) => lesson.domainCode == 'MATH' && lesson.access == 'FREE',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(response.disclaimer),
              if (math.isEmpty) ...[
                const Text(
                  'Content not available yet',
                  key: Key('categoryEmpty'),
                ),
                Text(
                  response.emptyReason == 'CHILD_OUTSIDE_PROGRAM_AGE'
                      ? 'The service returned no eligible lessons for this child’s age.'
                      : 'No eligible Free Math lessons were returned for this child.',
                ),
                if (response.emptyReason != null) Text(response.emptyReason!),
              ] else
                ...math.map(
                  (lesson) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton(
                      key: Key('lesson-${lesson.lessonId}'),
                      onPressed: () => widget.openLesson(lesson.lessonId),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(lesson.title),
                            Text(
                              '${lesson.lessonCode} · Free · development/demo',
                            ),
                            Text(lesson.objective),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class LearningLessonView extends StatefulWidget {
  const LearningLessonView({
    super.key,
    required this.api,
    required this.childId,
    required this.lessonId,
    required this.pending,
  });
  final LearningApi api;
  final String childId, lessonId;
  final PendingLearningAnswers pending;
  @override
  State<LearningLessonView> createState() => _LearningLessonViewState();
}

class _LearningLessonViewState extends State<LearningLessonView> {
  LessonDetail? detail;
  SessionDetail? session;
  List<RecordedAnswer> answers = [];
  ApiFailure? detailError, sessionError;
  final answerErrors = <String, ApiFailure>{};
  final selected = <String, String>{};
  final feedback = <String, AnswerFeedback>{};
  bool loadingDetail = true, loadingSession = false;
  String? sendingCue;

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  Future<void> loadDetail() async {
    setState(() {
      loadingDetail = true;
      detailError = null;
    });
    try {
      final value = await widget.api.lesson(widget.childId, widget.lessonId);
      if (value.summary.lessonId != widget.lessonId ||
          value.summary.domainCode != 'MATH' ||
          value.summary.access != 'FREE') {
        throw const ApiInvalidResponse(
          'The service returned an unexpected Math lesson.',
        );
      }
      if (mounted) setState(() => detail = value);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => detailError = failure);
    } finally {
      if (mounted) setState(() => loadingDetail = false);
    }
  }

  void validateSession(LearningSession value) {
    if (value.childId != widget.childId ||
        value.lessonId != widget.lessonId ||
        value.revisionId != detail!.revisionId) {
      throw const ApiInvalidResponse(
        'Session and loaded lesson revision do not match. Return to Math and reopen the lesson.',
      );
    }
  }

  Future<void> loadSession() async {
    if (loadingSession || sendingCue != null) return;
    setState(() {
      loadingSession = true;
      sessionError = null;
    });
    try {
      final started =
          session ??
          await widget.api.startLearning(widget.childId, widget.lessonId);
      validateSession(started);
      final value = await widget.api.learningSession(
        widget.childId,
        started.sessionId,
      );
      validateSession(value);
      if (value.sessionId != started.sessionId)
        throw const ApiInvalidResponse(
          'The service returned a different session.',
        );
      for (final answer in value.answers) {
        if (!detail!.cues.any(
          (cue) =>
              cue.cueId == answer.cueId &&
              cue.options.any((option) => option.optionId == answer.optionId),
        )) {
          throw const ApiInvalidResponse(
            'Recorded answers do not match this lesson revision.',
          );
        }
      }
      if (mounted)
        setState(() {
          session = value;
          answers = List.of(value.answers);
        });
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(() {
          sessionError = failure;
          session = null;
        });
    } finally {
      if (mounted) setState(() => loadingSession = false);
    }
  }

  Future<void> send(LearningCue cue) async {
    final current = session;
    if (sendingCue != null ||
        loadingSession ||
        current == null ||
        current.state != 'IN_PROGRESS')
      return;
    final pending = widget.pending.find(
      widget.childId,
      current.sessionId,
      cue.cueId,
    );
    final optionId = pending?.optionId ?? selected[cue.cueId];
    if (optionId == null) return;
    final request =
        pending ??
        widget.pending.prepare(
          widget.childId,
          current.sessionId,
          cue.cueId,
          optionId,
        );
    setState(() {
      sendingCue = cue.cueId;
      answerErrors.remove(cue.cueId);
    });
    try {
      final value = await widget.api.submitAnswer(
        widget.childId,
        current.sessionId,
        request,
      );
      if (value.sessionId != current.sessionId ||
          value.cueId != request.cueId ||
          value.optionId != request.optionId ||
          value.usedHint != request.usedHint) {
        throw const ApiInvalidResponse(
          'Answer acknowledgment did not match the submitted choice. Retry the same answer.',
        );
      }
      // If the screen was left before its response arrived, keep the exact
      // event for a visible replay. This also avoids racing a revisited view.
      if (mounted) {
        widget.pending.acknowledge(widget.childId, current.sessionId, request);
        setState(() {
          feedback[cue.cueId] = value;
          selected.remove(cue.cueId);
          answers.removeWhere(
            (answer) =>
                answer.cueId == value.cueId &&
                answer.attemptNo == value.attemptNo,
          );
          answers.add(value);
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(() {
          answerErrors[cue.cueId] = failure;
          if (failure.status == 401 ||
              failure.status == 403 ||
              failure.status == 404 ||
              failure.code == 'SESSION_NOT_ACTIVE') {
            sessionError = failure;
            session = null;
          }
        });
    } finally {
      if (mounted) setState(() => sendingCue = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingDetail)
      return const Column(
        children: [
          LearningLabel(),
          CircularProgressIndicator(),
          Text('Loading lesson…'),
        ],
      );
    if (detailError != null)
      return Column(
        children: [
          LearningError(detailError!),
          OutlinedButton(
            key: const Key('lessonRetry'),
            onPressed: loadDetail,
            child: const Text('Try again'),
          ),
        ],
      );
    final lesson = detail!;
    final cues = List<LearningCue>.of(lesson.cues)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LearningLabel(),
        Text(
          lesson.summary.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(lesson.summary.lessonCode),
        Text(lesson.summary.objective),
        Text(lesson.disclaimer),
        if (lesson.assets.isNotEmpty)
          const Text(
            'Media references are metadata only. Playback is not available in this development slice.',
          ),
        if (sessionError != null) LearningError(sessionError!),
        if (loadingSession)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          )
        else
          OutlinedButton(
            key: const Key('startLearning'),
            onPressed: sendingCue == null ? loadSession : null,
            child: Text(
              session == null
                  ? 'Start or revisit session'
                  : 'Refresh recorded answers',
            ),
          ),
        if (session != null) ...[
          Text(
            'Session: ${session!.state}',
            key: const Key('learningSessionState'),
          ),
          if (session!.state != 'IN_PROGRESS')
            const Text('This session cannot accept answers.'),
          if (cues.isEmpty)
            const Text('No interactive questions were returned.'),
          ...cues.map((cue) => cueView(context, cue)),
        ],
      ],
    );
  }

  Widget cueView(BuildContext context, LearningCue cue) {
    final current = session!;
    final pending = widget.pending.find(
      widget.childId,
      current.sessionId,
      cue.cueId,
    );
    final chosen = pending?.optionId ?? selected[cue.cueId];
    final options = List<CueOption>.of(cue.options)
      ..sort((a, b) => a.position.compareTo(b.position));
    final recorded =
        answers.where((answer) => answer.cueId == cue.cueId).toList()
          ..sort((a, b) => a.attemptNo.compareTo(b.attemptNo));
    final failure = answerErrors[cue.cueId];
    final blocked = failure?.status == 409;
    final canAnswer =
        current.state == 'IN_PROGRESS' && !loadingSession && sendingCue == null;
    return Card(
      key: Key('cue-${cue.cueId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              cue.promptText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (options.isEmpty) const Text('No answer options were returned.'),
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    key: Key('option-${option.optionId}'),
                    onPressed: canAnswer && pending == null
                        ? () => setState(
                            () => selected[cue.cueId] = option.optionId,
                          )
                        : null,
                    child: Text(
                      '${chosen == option.optionId ? 'Selected: ' : ''}${option.labelText}',
                    ),
                  ),
                ),
              ),
            ),
            if (pending != null)
              const Text(
                'A pending answer needs confirmation. Retry sends the same choice and event ID.',
              ),
            if (failure != null) LearningError(failure),
            if (blocked)
              const Text(
                'The server rejected this event. Revisit recorded answers; the event ID will not be replaced automatically.',
              ),
            SizedBox(
              height: 64,
              child: FilledButton(
                key: Key('submit-${cue.cueId}'),
                onPressed: canAnswer && chosen != null && !blocked
                    ? () => send(cue)
                    : null,
                child: Text(
                  sendingCue == cue.cueId
                      ? 'Sending answer…'
                      : pending != null
                      ? 'Retry same answer'
                      : 'Submit answer',
                ),
              ),
            ),
            if (feedback[cue.cueId] case final value?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Server feedback (attempt ${value.attemptNo}): ${value.feedbackText}',
                  key: Key('feedback-${cue.cueId}'),
                ),
              ),
            ...recorded.map(
              (answer) => Text(
                'Recorded attempt ${answer.attemptNo}: '
                '${options.firstWhere((option) => option.optionId == answer.optionId).labelText} — '
                '${answer.isCorrect ? 'Correct' : 'Incorrect'}',
                key: Key('recorded-${cue.cueId}-${answer.attemptNo}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
