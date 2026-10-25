import 'package:flutter/material.dart';

import 'api_failure.dart';
import 'learning_models.dart';
import 'learning_session_memory.dart';
import 'mimigo_design.dart';

class LearningLabel extends StatelessWidget {
  const LearningLabel({super.key});
  @override
  Widget build(BuildContext context) => const MimiNotice(
    icon: Icons.science_outlined,
    child: Text(
      'DEVELOPMENT / DEMO · synthetic Free learning content. Not production approved.',
    ),
  );
}

class LearningError extends StatelessWidget {
  const LearningError(this.failure, {super.key});
  final ApiFailure failure;
  String get message {
    if (failure.status == 401)
      return 'A parent needs to sign in again. Return to Child Mode and account entry to sign in again.';
    if (failure.status == 403)
      return 'Learning is not available for this account. Ask your parent for help.';
    if (failure.status == 404)
      return failure.code == 'CHILD_NOT_FOUND'
          ? 'This child profile is unavailable. Ask your parent for help.'
          : 'This lesson or session is unavailable. Go back to the lesson list.';
    if (failure.code == 'SESSION_INCOMPLETE')
      return 'Some questions still need a saved answer. Refresh the session before trying again.';
    if (failure.code == 'SESSION_NOT_ACTIVE')
      return 'This session is no longer active. Refresh to see its saved state.';
    if (failure.status == 409)
      return 'The answer could not be accepted. Refresh the session; your pending choice will be kept.';
    if (failure.code == 'CONNECTIVITY' || failure.code == 'TIMEOUT')
      return 'We could not reach the learning service. Check your connection and try again.';
    if ((failure.status ?? 0) >= 500)
      return 'The learning service is unavailable. Please try again later.';
    // Only locally constructed validation messages are safe to display verbatim.
    if (failure is ApiInvalidResponse) return failure.message;
    return 'The request could not be confirmed. Please try again.';
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MimiNotice(
      icon: Icons.cloud_off_outlined,
      color: MimiColors.rose,
      child: Text(
        '$message\n${failure.code ?? 'REQUEST_FAILED'}${failure.status == null ? '' : ' (HTTP ${failure.status})'}'
        '${failure.requestId == null ? '' : '\nRequest: ${failure.requestId}'}',
        key: const Key('learningError'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
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
  bool opening = false;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    result = widget.api.lessons(widget.childId);
  }

  void reload() {
    if (loading) return;
    setState(() {
      loading = true;
      result = widget.api.lessons(widget.childId);
    });
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
                  CircularProgressIndicator(semanticsLabel: 'Loading lessons'),
                  Text('Loading eligible lessons…'),
                ],
              ),
            );
          loading = false;
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
                  onPressed: reload,
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
                OutlinedButton(
                  key: const Key('lessonsRefresh'),
                  onPressed: reload,
                  child: const Text('Check for lessons again'),
                ),
              ] else
                ...math.map(
                  (lesson) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton(
                      key: Key('lesson-${lesson.lessonId}'),
                      onPressed: opening
                          ? null
                          : () {
                              if (opening) return;
                              setState(() => opening = true);
                              widget.openLesson(lesson.lessonId);
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              lesson.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
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
    this.sessions,
    this.domainCode = 'MATH',
  });
  final LearningApi api;
  final String childId, lessonId;
  final PendingLearningAnswers pending;
  final LearningSessionMemory? sessions;
  final String domainCode;
  @override
  State<LearningLessonView> createState() => _LearningLessonViewState();
}

class _LearningLessonViewState extends State<LearningLessonView> {
  late final memory = widget.sessions ?? LearningSessionMemory(widget.api);
  LessonDetail? detail;
  SessionDetail? session;
  List<RecordedAnswer> answers = [];
  ApiFailure? detailError, sessionError;
  final answerErrors = <String, ApiFailure>{};
  final selected = <String, String>{};
  final feedback = <String, AnswerFeedback>{};
  bool loadingDetail = false, loadingSession = false;
  String? sendingCue;
  String? viewedSessionId;
  bool viewingHistory = false;

  bool get completing =>
      viewedSessionId != null &&
      memory.completing(widget.childId, viewedSessionId!);
  bool get replaying => memory.replaying(widget.childId, widget.lessonId);
  bool get operationBusy =>
      completing ||
      replaying ||
      (viewedSessionId != null &&
          memory.answering(widget.childId, viewedSessionId!));
  bool get denied => {401, 403, 404}.contains(sessionError?.status);
  ApiFailure? get completionError => viewedSessionId == null
      ? null
      : memory.completionError(widget.childId, viewedSessionId!);
  bool get answerReconciliationRequired =>
      completionError != null && completionError!.code != 'SESSION_INCOMPLETE';

  @override
  void initState() {
    super.initState();
    memory.addListener(syncMemory);
    loadDetail();
  }

  @override
  void dispose() {
    memory.removeListener(syncMemory);
    if (widget.sessions == null) memory.dispose();
    super.dispose();
  }

  void syncMemory() {
    if (!mounted) return;
    setState(() {
      final current = session;
      if (current != null) {
        final access = memory.accessError(
          widget.childId,
          current.sessionId,
          widget.lessonId,
        );
        if (access != null) {
          sessionError = access;
          session = null;
          return;
        }
        for (final cue in detail?.cues ?? <LearningCue>[]) {
          final failure = memory.answerError(
            widget.childId,
            current.sessionId,
            cue.cueId,
          );
          if (failure?.code == 'SESSION_NOT_ACTIVE') {
            sessionError = failure;
            session = null;
            return;
          }
        }
        final stored = memory.session(widget.childId, current.sessionId);
        if (stored != null) {
          session = stored;
          answers = List.of(stored.answers);
        }
      }
    });
  }

  void showSession(SessionDetail value) {
    if (session?.sessionId != value.sessionId) {
      selected.clear();
      feedback.clear();
      answerErrors.clear();
    } else {
      answerErrors.removeWhere((cue, failure) => failure.status != 409);
      feedback.removeWhere(
        (cue, response) => !value.answers.any(
          (answer) =>
              answer.cueId == cue &&
              answer.optionId == response.optionId &&
              answer.attemptNo == response.attemptNo &&
              answer.isCorrect == response.isCorrect,
        ),
      );
    }
    session = value;
    viewedSessionId = value.sessionId;
    answers = List.of(value.answers);
  }

  Future<void> loadDetail() async {
    if (loadingDetail) return;
    setState(() {
      loadingDetail = true;
      detailError = null;
    });
    try {
      final value = await widget.api.lesson(widget.childId, widget.lessonId);
      if (value.summary.lessonId != widget.lessonId ||
          value.summary.domainCode != widget.domainCode ||
          value.summary.access != 'FREE') {
        throw const ApiInvalidResponse(
          'The service returned an unexpected Free lesson.',
        );
      }
      if (mounted) {
        setState(() => detail = value);
        final known = memory.resumeId(widget.childId, widget.lessonId);
        if (memory.opening(widget.childId, widget.lessonId)) {
          await loadSession();
        } else if (known != null) {
          await loadSession(id: known);
        }
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => detailError = failure);
    } finally {
      if (mounted) setState(() => loadingDetail = false);
    }
  }

  void validateSession(LearningSession value) {
    detail!.validateSession(value, widget.childId);
  }

  Future<void> loadSession({String? id, bool? history}) async {
    if (loadingSession || sendingCue != null) return;
    setState(() {
      loadingSession = true;
      sessionError = null;
    });
    try {
      if (history != null) viewingHistory = history;
      final target = id ?? viewedSessionId;
      final value = target == null
          ? await memory.open(widget.childId, detail!)
          : await memory.read(
              widget.childId,
              detail!,
              target,
              activate: !viewingHistory,
            );
      if (mounted) {
        setState(() => showSession(value));
      }
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(() {
          sessionError = failure;
          session = null;
          viewedSessionId ??= memory.resumeId(widget.childId, widget.lessonId);
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
        current.state != 'IN_PROGRESS' ||
        operationBusy ||
        answerReconciliationRequired)
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
      final value = await memory.submit(
        widget.childId,
        current.sessionId,
        request,
      );
      // If the screen was left before its response arrived, keep the exact
      // event for a visible replay. This also avoids racing a revisited view.
      if (mounted) {
        widget.pending.acknowledge(widget.childId, current.sessionId, request);
        final updated = List<RecordedAnswer>.of(answers)
          ..removeWhere(
            (answer) =>
                answer.cueId == value.cueId &&
                answer.attemptNo == value.attemptNo,
          )
          ..add(value);
        final stored = memory.remember(
          SessionDetail.fromSession(current, updated),
          activate: !viewingHistory,
          clearError: false,
        );
        setState(() {
          feedback[cue.cueId] = value;
          selected.remove(cue.cueId);
          session = stored;
          answers = List.of(stored.answers);
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

  bool get allQuestionsRecorded =>
      detail!.cues.isNotEmpty &&
      detail!.cues.every(
        (cue) =>
            answers.any((answer) => answer.cueId == cue.cueId) &&
            widget.pending.find(
                  widget.childId,
                  session!.sessionId,
                  cue.cueId,
                ) ==
                null,
      );

  Future<void> finish() async {
    final current = session;
    if (current == null ||
        current.state != 'IN_PROGRESS' ||
        !allQuestionsRecorded ||
        operationBusy ||
        loadingSession ||
        sendingCue != null)
      return;
    try {
      await memory.complete(widget.childId, current.sessionId);
    } on ApiFailure catch (failure) {
      if (mounted && {401, 403, 404}.contains(failure.status))
        setState(() {
          sessionError = failure;
          session = null;
        });
    }
  }

  Future<void> replay() async {
    final current = session;
    if (current == null ||
        current.state != 'COMPLETED' ||
        operationBusy ||
        loadingSession ||
        sendingCue != null)
      return;
    try {
      final value = await memory.replay(
        widget.childId,
        current.sessionId,
        detail!,
      );
      validateSession(value);
      if (mounted)
        setState(() {
          viewingHistory = false;
          sessionError = null;
          showSession(value);
        });
    } on ApiFailure catch (failure) {
      if (mounted && {401, 403, 404}.contains(failure.status)) {
        setState(() {
          sessionError = failure;
          session = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingDetail)
      return const Column(
        children: [
          LearningLabel(),
          CircularProgressIndicator(semanticsLabel: 'Loading lesson'),
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
        Semantics(
          header: true,
          child: Text(
            lesson.summary.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading session and saved answers',
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: OutlinedButton(
              key: const Key('startLearning'),
              onPressed: sendingCue == null && !operationBusy
                  ? loadSession
                  : null,
              child: Text(
                session == null && viewedSessionId == null
                    ? 'Start or revisit session'
                    : 'Refresh session and recorded answers',
              ),
            ),
          ),
        if (session != null) ...[
          Text(
            'Session: ${session!.state}',
            key: const Key('learningSessionState'),
          ),
          if (session!.state != 'IN_PROGRESS')
            Text(
              session!.state == 'COMPLETED'
                  ? 'Your saved answers are read-only. Choose Replay lesson to try again.'
                  : 'This session has ended and cannot accept answers. Go back to the lesson list.',
            ),
          if (memory.answering(widget.childId, session!.sessionId))
            const LinearProgressIndicator(
              semanticsLabel: 'Sending answer. Please wait.',
            ),
          if (cues.isEmpty)
            const Text('No interactive questions were returned.'),
          ...cues.map((cue) => cueView(context, cue)),
          completionView(),
        ],
        if (!denied &&
            memory.completed(widget.childId, widget.lessonId).isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Known completed sessions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...memory
              .completed(widget.childId, widget.lessonId)
              .map(
                (old) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Session: ${old.sessionId}',
                          key: Key('history-${old.sessionId}'),
                        ),
                        Text(
                          'Ended: ${old.endedAt!.toUtc().toIso8601String()}',
                        ),
                        OutlinedButton(
                          key: Key('readCompleted-${old.sessionId}'),
                          onPressed:
                              !operationBusy &&
                                  !loadingSession &&
                                  sendingCue == null &&
                                  session?.sessionId != old.sessionId
                              ? () => loadSession(
                                  id: old.sessionId,
                                  history: true,
                                )
                              : null,
                          child: const Text('View recorded session'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget completionView() {
    final current = session!;
    final error = completionError;
    final replayFailure = memory.replayError(widget.childId, widget.lessonId);
    if (current.state == 'COMPLETED') {
      final active = memory.resumeId(widget.childId, widget.lessonId);
      final continuing =
          active != null &&
          active != current.sessionId &&
          memory.session(widget.childId, active)?.state == 'IN_PROGRESS';
      return Card(
        color: const Color(0xFFF0F8F1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Color(0xFF246335),
                  semanticLabel: 'Server-confirmed completion',
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Session completed',
                  key: Key('completionConfirmed'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                'Session ID: ${current.sessionId}',
                key: const Key('completedSessionIdentity'),
              ),
              Text(
                'Ended: ${current.endedAt!.toUtc().toIso8601String()}',
                key: const Key('completedEndedAt'),
              ),
              if (replayFailure != null) LearningError(replayFailure),
              if (replaying)
                const LinearProgressIndicator(
                  semanticsLabel: 'Starting replay',
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: FilledButton(
                  key: const Key('replayLearning'),
                  onPressed: operationBusy || loadingSession ? null : replay,
                  child: Text(
                    replaying
                        ? 'Starting replay…'
                        : continuing
                        ? 'Continue replay session'
                        : 'Replay lesson',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (current.state != 'IN_PROGRESS') return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'After reading the final explanation, choose Complete lesson.',
            ),
            if (!allQuestionsRecorded)
              const Text(
                'Record an answer for each question before completing the lesson.',
              ),
            if (error != null) LearningError(error),
            if (error?.code == 'SESSION_INCOMPLETE')
              const Text(
                'The server still needs a recorded answer. Refresh the session, answer the missing question, then try Complete again.',
              ),
            if (error?.code == 'SESSION_NOT_ACTIVE')
              const Text(
                'Refresh this session to read its server state before continuing.',
              ),
            if (error != null &&
                error.code != 'SESSION_INCOMPLETE' &&
                error.code != 'SESSION_NOT_ACTIVE')
              const Text(
                'Completion has not been confirmed. Retry Complete or refresh the session before answering again.',
              ),
            if (completing)
              const LinearProgressIndicator(
                semanticsLabel: 'Confirming completion',
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: FilledButton(
                key: const Key('completeLearning'),
                onPressed:
                    allQuestionsRecorded &&
                        !operationBusy &&
                        !loadingSession &&
                        sendingCue == null &&
                        error?.code != 'SESSION_NOT_ACTIVE'
                    ? finish
                    : null,
                child: Text(
                  completing
                      ? 'Completing…'
                      : error == null
                      ? 'Complete lesson'
                      : 'Retry Complete',
                ),
              ),
            ),
          ],
        ),
      ),
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
    final failure =
        answerErrors[cue.cueId] ??
        memory.answerError(widget.childId, current.sessionId, cue.cueId);
    final blocked = failure?.status == 409;
    final canAnswer =
        current.state == 'IN_PROGRESS' &&
        !loadingSession &&
        sendingCue == null &&
        !operationBusy &&
        !answerReconciliationRequired;
    return Card(
      key: Key('cue-${cue.cueId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${cue.seq}',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: MimiColors.action),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                cue.promptText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (options.isEmpty) const Text('No answer options were returned.'),
            const SizedBox(height: 12),
            MimiTileGrid(
              minimumWidth: 210,
              children: options
                  .map(
                    (option) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Semantics(
                          key: Key('choice-semantics-${option.optionId}'),
                          selected: chosen == option.optionId,
                          inMutuallyExclusiveGroup: true,
                          child: OutlinedButton(
                            key: Key('option-${option.optionId}'),
                            style: chosen == option.optionId
                                ? OutlinedButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            onPressed: canAnswer && pending == null
                                ? () => setState(
                                    () => selected[cue.cueId] = option.optionId,
                                  )
                                : null,
                            child: Text(
                              '${chosen == option.optionId ? 'Selected: ' : ''}${option.labelText}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (pending != null && current.state == 'IN_PROGRESS')
              const Text(
                'Your answer needs confirmation. Try the same choice again.',
              ),
            if (failure != null) LearningError(failure),
            if (blocked)
              const Text(
                'The server rejected this event. Revisit recorded answers; the event ID will not be replaced automatically.',
              ),
            if (current.state == 'IN_PROGRESS')
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: FilledButton(
                  key: Key('submit-${cue.cueId}'),
                  onPressed: canAnswer && chosen != null && !blocked
                      ? () => send(cue)
                      : null,
                  child: Text(
                    (sendingCue ??
                                memory.sendingCue(
                                  widget.childId,
                                  current.sessionId,
                                )) ==
                            cue.cueId
                        ? 'Sending answer…'
                        : pending != null
                        ? 'Retry same answer'
                        : 'Submit answer',
                  ),
                ),
              ),
            if (feedback[cue.cueId] case final value?)
              Semantics(
                key: Key('feedback-announcement-${cue.cueId}'),
                container: true,
                liveRegion: true,
                child: MimiNotice(
                  icon: Icons.chat_bubble_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        value.isCorrect
                            ? 'That is right. Let’s look at the explanation.'
                            : 'Your answer is saved. Let’s look at the explanation.',
                      ),
                      Text(
                        'Explanation (attempt ${value.attemptNo}): ${value.feedbackText}',
                        key: Key('feedback-${cue.cueId}'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
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
