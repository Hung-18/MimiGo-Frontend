import 'user_messages.dart';

import 'package:flutter/material.dart';

import 'api_failure.dart';
import 'child_media_access.dart';
import 'child_media_player.dart';
import 'learning_models.dart';
import 'learning_session_memory.dart';
import 'mimigo_design.dart';

class LearningLabel extends StatelessWidget {
  const LearningLabel({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LearningError extends StatelessWidget {
  const LearningError(this.failure, {super.key});
  final ApiFailure failure;
  String get message => friendlyError(failure);
  @override
  Widget build(BuildContext context) =>
      UserError(failure, messageKey: const Key('learningError'));
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
                  CircularProgressIndicator(semanticsLabel: 'Đang tải bài học'),
                  Text('Đang tìm bài học phù hợp…'),
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
                  child: const Text('Thử lại'),
                ),
              ],
            );
          final response = snapshot.data!;
          // Eligibility and age are authoritative on the server. Only select the
          // requested Math domain from its returned Free results; no local ages.
          final math = response.items.where(
            (lesson) =>
                lesson.domainCode == 'MATH' &&
                {'FREE', 'CORE'}.contains(lesson.access),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (math.isEmpty) ...[
                const Text(
                  'Chưa có nội dung phù hợp',
                  key: Key('categoryEmpty'),
                ),
                Text(
                  response.emptyReason == 'CHILD_OUTSIDE_PROGRAM_AGE'
                      ? 'Chưa có bài học phù hợp với độ tuổi của bé.'
                      : 'Chưa có bài toán học phù hợp cho bé.',
                ),
                OutlinedButton(
                  key: const Key('lessonsRefresh'),
                  onPressed: reload,
                  child: const Text('Tìm bài học lại'),
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
                            Text(viState(lesson.access)),
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
  String? reachedMediaCue;

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
      reachedMediaCue = null;
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
          !{'FREE', 'CORE'}.contains(value.summary.access)) {
        throw const ApiInvalidResponse(
          'The service returned an unexpected lesson.',
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
          CircularProgressIndicator(semanticsLabel: 'Đang tải bài học'),
          Text('Đang tải bài học…'),
        ],
      );
    if (detailError != null)
      return Column(
        children: [
          LearningError(detailError!),
          OutlinedButton(
            key: const Key('lessonRetry'),
            onPressed: loadDetail,
            child: const Text('Thử lại'),
          ),
        ],
      );
    final lesson = detail!;
    final cues = List<LearningCue>.of(lesson.cues)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final media = widget.api is ChildMediaAccess
        ? widget.api as ChildMediaAccess
        : null;
    final hasMainVideo = lesson.assets.any(
      (asset) => asset.role == 'MAIN_VIDEO',
    );
    final playPrivateMedia =
        media != null &&
        media.childMediaEnabled &&
        hasMainVideo &&
        session?.state == 'IN_PROGRESS' &&
        !viewingHistory;
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
        Text(lesson.summary.objective),
        if (lesson.assets.isNotEmpty && !playPrivateMedia)
          const Text(
            'Video hiện chưa khả dụng. Bé vẫn có thể xem các câu hỏi của bài học bên dưới.',
          ),
        if (sessionError != null) LearningError(sessionError!),
        if (loadingSession)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(
              semanticsLabel: 'Đang tải lượt học và câu trả lời',
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
                    ? 'Bắt đầu hoặc tiếp tục học'
                    : 'Tải lại lượt học đã lưu',
              ),
            ),
          ),
        if (session != null) ...[
          if (playPrivateMedia)
            ChildMediaPlayer(
              key: ValueKey((
                'media',
                widget.childId,
                session!.sessionId,
                lesson.revisionId,
              )),
              access: media,
              childId: widget.childId,
              lesson: lesson,
              cues: cues,
              answeredCueIds: answers.map((answer) => answer.cueId).toSet(),
              onCueReached: (cueId) {
                if (mounted) setState(() => reachedMediaCue = cueId);
              },
            ),
          Text(
            'Lượt học: ${viState(session!.state)}',
            key: const Key('learningSessionState'),
          ),
          if (session!.state != 'IN_PROGRESS')
            Text(
              session!.state == 'COMPLETED'
                  ? 'Đây là câu trả lời đã lưu. Bé chọn Học lại để thử lượt mới nhé.'
                  : 'Lượt học này đã kết thúc. Bé quay lại chọn bài nhé.',
            ),
          if (memory.answering(widget.childId, session!.sessionId))
            const LinearProgressIndicator(
              semanticsLabel: 'Đang lưu câu trả lời, bé chờ nhé.',
            ),
          if (cues.isEmpty) const Text('Bài này chưa có câu hỏi tương tác.'),
          ...cues
              .where(
                (cue) =>
                    !playPrivateMedia ||
                    answers.any((answer) => answer.cueId == cue.cueId) ||
                    reachedMediaCue == cue.cueId,
              )
              .map((cue) => cueView(context, cue)),
          completionView(),
        ],
        if (!denied &&
            memory.completed(widget.childId, widget.lessonId).isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Những lượt đã hoàn thành vừa xem',
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
                          'Lượt học đã hoàn thành',
                          key: Key('history-${old.sessionId}'),
                        ),
                        Text('Kết thúc: ${viTime(old.endedAt)}'),
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
                          child: const Text('Xem lượt học đã lưu'),
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
                  semanticLabel: 'Đã xác nhận hoàn thành',
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Bé đã hoàn thành!',
                  key: Key('completionConfirmed'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                'Kết quả đã được lưu',
                key: const Key('completedSessionIdentity'),
              ),
              Text(
                'Kết thúc: ${viTime(current.endedAt)}',
                key: const Key('completedEndedAt'),
              ),
              if (replayFailure != null) LearningError(replayFailure),
              if (replaying)
                const LinearProgressIndicator(
                  semanticsLabel: 'Đang mở lượt học mới',
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: FilledButton(
                  key: const Key('replayLearning'),
                  onPressed: operationBusy || loadingSession ? null : replay,
                  child: Text(
                    replaying
                        ? 'Đang mở lượt học mới…'
                        : continuing
                        ? 'Tiếp tục lượt học mới'
                        : 'Học lại',
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
            const Text('Xem lời giải xong, bé chọn Hoàn thành bài học nhé.'),
            if (!allQuestionsRecorded)
              const Text('Bé trả lời từng câu hỏi trước khi hoàn thành nhé.'),
            if (error != null) LearningError(error),
            if (error?.code == 'SESSION_INCOMPLETE')
              const Text(
                'Còn câu hỏi chưa lưu được câu trả lời. Bé tải lại và trả lời trước khi hoàn thành nhé.',
              ),
            if (error?.code == 'SESSION_NOT_ACTIVE')
              const Text('Bé tải lại lượt học trước khi tiếp tục nhé.'),
            if (error != null &&
                error.code != 'SESSION_INCOMPLETE' &&
                error.code != 'SESSION_NOT_ACTIVE')
              const Text(
                'Chưa xác nhận được kết quả. Bé thử hoàn thành lại hoặc tải lại lượt học nhé.',
              ),
            if (completing)
              const LinearProgressIndicator(
                semanticsLabel: 'Đang xác nhận hoàn thành',
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
                      ? 'Đang lưu kết quả…'
                      : error == null
                      ? 'Hoàn thành bài học'
                      : 'Thử hoàn thành lại',
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
              'Câu hỏi ${cue.seq}',
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
            if (options.isEmpty) const Text('Chưa có lựa chọn trả lời.'),
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
                              '${chosen == option.optionId ? 'Đã chọn: ' : ''}${option.labelText}',
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
                'Câu trả lời chưa được xác nhận. Bé gửi lại lựa chọn vừa rồi nhé.',
              ),
            if (failure != null) LearningError(failure),
            if (blocked)
              const Text(
                'Chưa thể lưu lựa chọn này. Bé xem lại câu trả lời đã lưu trước khi tiếp tục nhé.',
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
                        ? 'Đang lưu câu trả lời…'
                        : pending != null
                        ? 'Gửi lại lựa chọn này'
                        : 'Gửi câu trả lời',
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
                        value.isCorrect == true
                            ? 'Đúng rồi! Mình cùng xem lời giải nhé.'
                            : 'Đã lưu câu trả lời. Mình cùng xem lời giải nhé.',
                      ),
                      Text(
                        'Lời giải (lần ${value.attemptNo}): ${value.feedbackText}',
                        key: Key('feedback-${cue.cueId}'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ...recorded.map(
              (answer) => Text(
                'Lần trả lời ${answer.attemptNo}: '
                '${options.firstWhere((option) => option.optionId == answer.optionId).labelText} — '
                '${switch (answer.isCorrect) {
                  true => 'Đúng',
                  false => 'Chưa đúng',
                  null => 'Chưa có nhận xét',
                }}',
                key: Key('recorded-${cue.cueId}-${answer.attemptNo}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
