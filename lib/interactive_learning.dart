import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'api_failure.dart';
import 'child_media_access.dart';
import 'learning_models.dart';
import 'user_messages.dart';

bool cueHasRequiredInteractiveMedia(LessonDetail lesson, LearningCue cue) {
  bool linked(String? id, String role, String kind) => id != null &&
      lesson.assets.any((a) =>
          a.assetId == id && a.role == role && a.kind == kind);
  return linked(cue.promptAssetId, 'CUE_AUDIO', 'AUDIO') &&
      cue.options.isNotEmpty && cue.options.every((o) =>
          linked(o.imageAssetId, 'OPTION_IMAGE', 'IMAGE'));
}

/// Cloud 0079-0081 learning. Nothing here infers attempts or video credit from
/// local taps/player time; both are re-read from the Child-scoped service.
class InteractiveLearningView extends StatefulWidget {
  const InteractiveLearningView({
    super.key,
    required this.api,
    required this.interactive,
    required this.childId,
    required this.lessonId,
    required this.domainCode,
    required this.pending,
  });
  final LearningApi api;
  final InteractiveLearningApi interactive;
  final String childId, lessonId, domainCode;
  final PendingLearningAnswers pending;

  @override
  State<InteractiveLearningView> createState() => _InteractiveLearningViewState();
}

class _InteractiveLearningViewState extends State<InteractiveLearningView>
    with WidgetsBindingObserver {
  LessonDetail? lesson;
  SessionDetail? session;
  CueStates? cues;
  PlaybackState? playback;
  PlaybackEventLedger? ledger;
  VideoPlayerController? video, audio;
  ChildMediaSource? videoSource;
  final images = <String, ChildMediaSource>{};
  ChildMediaSource? questionAudio;
  ApiFailure? error;
  String? blockedMessage, reachedCue, selectedOption, answeredFeedback;
  bool busy = false, eventBusy = false, loadingAssets = false, videoEnded = false;
  bool endAttempted = false;
  bool backgrounded = false;
  Timer? heartbeat;
  int generation = 0;

  ChildLearningMediaAccess? get media => widget.api is ChildLearningMediaAccess
      ? widget.api as ChildLearningMediaAccess : null;
  CueState? get activeState => cues?.resumePoint;
  LearningCue? get activeCue {
    final state = activeState;
    if (state == null || lesson == null) return null;
    for (final cue in lesson!.cues) {
      if (cue.cueId == state.cueId) return cue;
    }
    return null;
  }
  bool get mediaCurrent => videoSource != null &&
      media?.mediaSessionIsCurrent(widget.childId, videoSource!.bearer) == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    media?.mediaSessionChanges.addListener(checkMediaSession);
    load();
  }

  @override
  void didUpdateWidget(covariant InteractiveLearningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.childId != widget.childId ||
        oldWidget.lessonId != widget.lessonId) {
      oldWidget.api is ChildLearningMediaAccess
          ? (oldWidget.api as ChildLearningMediaAccess)
              .mediaSessionChanges.removeListener(checkMediaSession)
          : null;
      media?.mediaSessionChanges.addListener(checkMediaSession);
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      backgrounded = false;
    } else {
      backgrounded = true;
      video?.pause();
      audio?.pause();
      heartbeat?.cancel();
      if (session != null && video != null) {
        unawaited(sendEvent('BACKGROUND',
            video!.value.position.inMilliseconds));
      }
    }
  }

  void checkMediaSession() {
    if (videoSource != null && !mediaCurrent) {
      stopMedia();
      if (mounted) setState(() => blockedMessage =
          'Phiên học đã thay đổi. Bé nhờ ba mẹ mở lại bài học nhé.');
    }
  }

  void stopMedia() {
    heartbeat?.cancel();
    heartbeat = null;
    final oldVideo = video;
    final oldAudio = audio;
    video = audio = null;
    videoSource = questionAudio = null;
    images.clear();
    oldVideo?.removeListener(videoTick);
    if (oldVideo != null) {
      unawaited(oldVideo.pause().then((_) => oldVideo.dispose()));
    }
    if (oldAudio != null) {
      unawaited(oldAudio.pause().then((_) => oldAudio.dispose()));
    }
  }

  @override
  void dispose() {
    generation++;
    media?.mediaSessionChanges.removeListener(checkMediaSession);
    WidgetsBinding.instance.removeObserver(this);
    stopMedia();
    super.dispose();
  }

  Future<void> load({bool replay = false}) async {
    final run = ++generation;
    stopMedia();
    setState(() {
      busy = true;
      error = null;
      blockedMessage = null;
      reachedCue = selectedOption = answeredFeedback = null;
      videoEnded = false;
      endAttempted = false;
      lesson = null;
      session = null;
      cues = null;
      playback = null;
      ledger = null;
    });
    try {
      final detail = await widget.api.lesson(widget.childId, widget.lessonId);
      if (detail.summary.lessonId != widget.lessonId ||
          detail.summary.domainCode != widget.domainCode) {
        throw const ApiInvalidResponse('Unexpected lesson identity.');
      }
      final started = await widget.api.startLearning(widget.childId, widget.lessonId);
      detail.validateSession(started, widget.childId);
      final saved = await widget.api.learningSession(widget.childId, started.sessionId);
      detail.validateSession(saved, widget.childId);
      final states = await widget.interactive.cueStates(widget.childId, saved.sessionId);
      final progress = await widget.interactive.playbackState(widget.childId, saved.sessionId);
      validateSnapshot(detail, saved, states, progress);
      if (!mounted || run != generation) return;
      setState(() {
        lesson = detail;
        session = saved;
        cues = states;
        playback = progress;
        ledger = PlaybackEventLedger(progress.nextSeq);
        videoEnded = progress.videoEndAccepted;
      });
      if (saved.state == 'IN_PROGRESS') await loadVideo(run);
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) setState(() => error = failure);
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  void validateSnapshot(LessonDetail detail, SessionDetail saved,
      CueStates states, PlaybackState progress) {
    if (states.sessionId != saved.sessionId ||
        progress.sessionId != saved.sessionId ||
        states.cues.length != detail.cues.length ||
        states.cues.any((s) => !detail.cues.any(
            (c) => c.cueId == s.cueId && c.seq == s.seq &&
                (s.correctOptionId == null || c.options.any(
                    (o) => o.optionId == s.correctOptionId)))) ||
        (saved.state == 'IN_PROGRESS' && media == null)) {
      throw const ApiInvalidResponse('Learning resume state does not match the lesson.');
    }
  }

  Future<void> loadVideo(int run) async {
    final access = media!;
    VideoPlayerController? next;
    try {
      final source = await access.childMediaSource(
          widget.childId, widget.lessonId, lesson!.revisionId);
      if (!mounted || run != generation ||
          !access.mediaSessionIsCurrent(widget.childId, source.bearer)) return;
      next = VideoPlayerController.networkUrl(source.uri,
          httpHeaders: source.httpHeaders);
      await next.initialize();
      if (!mounted || run != generation) return;
      videoSource = source;
      video = next;
      next.addListener(videoTick);
      await next.seekTo(Duration(milliseconds: playback!.resumePositionMs));
      final cue = activeCue;
      if (cue != null && playback!.resumePositionMs >= cue.pauseAtMs) {
        reachedCue = cue.cueId;
        await loadCueAssets(cue);
      }
      if (mounted) setState(() {});
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) setState(() => error = failure);
    } catch (_) {
      if (mounted && run == generation) setState(() => blockedMessage =
          'Chưa mở được video riêng tư. Bé thử lại cùng ba mẹ nhé.');
    } finally {
      if (next != null && !identical(next, video)) await next.dispose();
    }
  }

  Future<PlaybackVerdict?> sendEvent(String kind, int positionMs) async {
    if (eventBusy || session == null || ledger == null) return null;
    if (ledger!.pending != null &&
        (ledger!.pending!.kind != kind ||
            ledger!.pending!.positionMs != positionMs)) return null;
    final run = generation;
    eventBusy = true;
    final request = ledger!.prepare(kind, positionMs.clamp(0, 86400000));
    try {
      final verdict = await widget.interactive.playbackEvent(
          widget.childId, session!.sessionId, request);
      if (!mounted || run != generation) return null;
      ledger!.acknowledge();
      final state = await widget.interactive.playbackState(
          widget.childId, session!.sessionId);
      if (!mounted || run != generation || state.sessionId != session!.sessionId)
        return null;
      ledger!.reconcile(state);
      setState(() {
        playback = state;
        videoEnded = state.videoEndAccepted;
        error = null;
      });
      if (verdict.verdict != 'ACCEPTED') {
        await video?.pause();
        await video?.seekTo(Duration(milliseconds: verdict.resumePositionMs));
      }
      return verdict;
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) {
        await video?.pause();
        heartbeat?.cancel();
        if (failure.code == 'PLAYBACK_OUT_OF_ORDER') {
          try {
            final state = await widget.interactive.playbackState(
                widget.childId, session!.sessionId);
            ledger?.reconcile(state);
            if (mounted) setState(() => playback = state);
          } on ApiFailure catch (_) { /* Retain the visible error. */ }
        }
        setState(() => error = failure);
        if (failure.code == 'MEDIA_NOT_AVAILABLE' ||
            {401, 403}.contains(failure.status)) stopMedia();
      }
      return null;
    } finally {
      eventBusy = false;
      if (mounted && backgrounded && kind != 'BACKGROUND' &&
          ledger?.pending == null && video != null) {
        unawaited(sendEvent('BACKGROUND',
            video!.value.position.inMilliseconds));
      } else if (mounted) {
        videoTick();
      }
    }
  }

  Future<void> playVideo() async {
    if (video == null || !mediaCurrent || eventBusy || busy ||
        reachedCue != null || ledger?.pending != null) return;
    if (videoSource!.expiresAt case final expiry?) {
      if (!expiry.isAfter(DateTime.now())) {
        await load();
        return;
      }
    }
    if (video!.value.isPlaying) {
      await video!.pause();
      heartbeat?.cancel();
      await sendEvent('PAUSE', video!.value.position.inMilliseconds);
      if (mounted) setState(() {});
      return;
    }
    final verdict = await sendEvent('START', video!.value.position.inMilliseconds);
    if (verdict?.verdict != 'ACCEPTED' || !mounted || !mediaCurrent) return;
    await video!.play();
    heartbeat?.cancel();
    heartbeat = Timer.periodic(
      Duration(milliseconds: playback!.heartbeatIntervalMs),
      (_) {
        if (video?.value.isPlaying == true && !eventBusy) {
          unawaited(sendEvent('PROGRESS',
              video!.value.position.inMilliseconds));
        }
      },
    );
    if (mounted) setState(() {});
  }

  void videoTick() {
    final player = video;
    if (player == null || !mounted || eventBusy || reachedCue != null ||
        !player.value.isInitialized) return;
    if (player.value.hasError) {
      player.pause();
      setState(() => blockedMessage = 'Video bị gián đoạn. Bé thử mở lại nhé.');
      return;
    }
    if (!videoEnded && !endAttempted && activeCue == null &&
        player.value.duration > Duration.zero &&
        player.value.position >= player.value.duration -
            const Duration(milliseconds: 300)) {
      unawaited(endVideo());
      return;
    }
    if (!player.value.isPlaying) return;
    final cue = activeCue;
    if (cue != null && player.value.position.inMilliseconds >= cue.pauseAtMs) {
      unawaited(reachCue(cue));
      return;
    }
  }

  Future<void> endVideo() async {
    if (eventBusy || videoEnded || endAttempted || video == null) return;
    endAttempted = true;
    await video!.pause();
    heartbeat?.cancel();
    final verdict = await sendEvent('ENDED', video!.value.position.inMilliseconds);
    if (mounted && verdict != null && !verdict.videoEndAccepted) {
      setState(() => blockedMessage =
          'Chưa xác nhận được đoạn cuối video. Bé thử tải lại bài học nhé.');
    }
  }

  Future<void> reachCue(LearningCue cue) async {
    if (reachedCue != null || video == null) return;
    reachedCue = cue.cueId;
    await video!.pause();
    heartbeat?.cancel();
    final verdict = await sendEvent('PAUSE',
        video!.value.position.inMilliseconds);
    if (verdict == null || verdict.verdict == 'REJECTED' ||
        playback!.resumePositionMs < cue.pauseAtMs) {
      reachedCue = null;
      return;
    }
    await loadCueAssets(cue);
  }

  Future<void> retryPendingEvent() async {
    final pending = ledger?.pending;
    if (pending == null) return;
    final verdict = await sendEvent(pending.kind, pending.positionMs);
    final cue = activeCue;
    if (verdict != null && verdict.verdict != 'REJECTED' &&
        pending.kind == 'PAUSE' && cue != null &&
        playback!.resumePositionMs >= cue.pauseAtMs &&
        reachedCue == null) {
      reachedCue = cue.cueId;
      await loadCueAssets(cue);
    }
  }

  bool hasRole(String? id, String role, String kind) =>
      id != null && lesson!.assets.any((asset) =>
          asset.assetId == id && asset.role == role && asset.kind == kind);

  Future<void> loadCueAssets(LearningCue cue) async {
    final run = generation;
    setState(() {
      loadingAssets = true;
      blockedMessage = null;
      images.clear();
      questionAudio = null;
    });
    try {
      if (!cueHasRequiredInteractiveMedia(lesson!, cue)) {
        throw const ApiFailure('Required question media is missing.',
            code: 'MEDIA_NOT_AVAILABLE', status: 404);
      }
      final access = media!;
      final question = await access.childLearningAsset(widget.childId,
          widget.lessonId, session!.sessionId, cue.promptAssetId!, 'AUDIO');
      final loaded = <String, ChildMediaSource>{};
      for (final option in cue.options) {
        loaded[option.optionId] = await access.childLearningAsset(widget.childId,
            widget.lessonId, session!.sessionId, option.imageAssetId!, 'IMAGE');
      }
      if (!mounted || run != generation) return;
      if (!access.mediaSessionIsCurrent(widget.childId, question.bearer) ||
          loaded.values.any((s) => !access.mediaSessionIsCurrent(
              widget.childId, s.bearer))) {
        throw const ApiFailure('Child session changed.', status: 403);
      }
      for (final source in loaded.values) {
        await precacheImage(NetworkImage(source.uri.toString(),
            headers: source.httpHeaders), context);
      }
      if (!mounted || run != generation) return;
      setState(() {
        questionAudio = question;
        images.addAll(loaded);
      });
      await playAudio(cue.promptAssetId!, 'CUE_AUDIO');
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) setState(() {
        error = failure;
        blockedMessage = 'Thiếu âm thanh câu hỏi hoặc hình đáp án. '
            'Bé chưa thể trả lời câu này; hãy thử tải lại cùng ba mẹ.';
      });
    } catch (_) {
      if (mounted && run == generation) setState(() => blockedMessage =
          'Chưa tải được hình đáp án. Bé thử lại cùng ba mẹ nhé.');
    } finally {
      if (mounted && run == generation) setState(() => loadingAssets = false);
    }
  }

  Future<void> playAudio(String assetId, String role) async {
    if (session == null || lesson == null || media == null ||
        !hasRole(assetId, role, 'AUDIO')) return;
    final run = generation;
    VideoPlayerController? next;
    try {
      // A new authorized URL is requested for every replay. The storage request
      // receives no Child bearer and the grant is never persisted.
      final source = await media!.childLearningAsset(widget.childId,
          widget.lessonId, session!.sessionId, assetId, 'AUDIO');
      if (!mounted || run != generation ||
          !media!.mediaSessionIsCurrent(widget.childId, source.bearer)) return;
      next = VideoPlayerController.networkUrl(source.uri,
          httpHeaders: source.httpHeaders);
      await next.initialize();
      if (!mounted || run != generation) return;
      final old = audio;
      audio = next;
      if (old != null) unawaited(old.dispose());
      await next.play();
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) setState(() {
        error = failure;
        if (role == 'CUE_AUDIO') blockedMessage =
            'Chưa phát được âm thanh câu hỏi. Bé thử lại cùng ba mẹ nhé.';
      });
    } catch (_) {
      if (mounted && run == generation) setState(() {
        if (role == 'CUE_AUDIO') blockedMessage =
            'Chưa phát được âm thanh câu hỏi. Bé thử lại cùng ba mẹ nhé.';
      });
    } finally {
      if (next != null && !identical(next, audio)) await next.dispose();
    }
  }

  Future<void> answer(LearningCue cue) async {
    final state = activeState;
    if (busy || state == null || state.cueId != cue.cueId ||
        state.resolved || state.attemptsRemaining == 0 ||
        selectedOption == null || blockedMessage != null ||
        loadingAssets || questionAudio == null ||
        images.length != cue.options.length || session == null) return;
    if (questionAudio!.expiresAt?.isAfter(DateTime.now()) == false ||
        images.values.any((s) =>
            s.expiresAt?.isAfter(DateTime.now()) == false)) {
      await loadCueAssets(cue);
      return;
    }
    final run = generation;
    final request = widget.pending.find(widget.childId, session!.sessionId,
        cue.cueId) ?? widget.pending.prepare(widget.childId, session!.sessionId,
        cue.cueId, selectedOption!);
    setState(() { busy = true; error = null; });
    try {
      final response = await widget.api.submitAnswer(
          widget.childId, session!.sessionId, request);
      if (!mounted || run != generation) return;
      widget.pending.acknowledge(widget.childId, session!.sessionId, request);
      final states = await widget.interactive.cueStates(
          widget.childId, session!.sessionId);
      final saved = await widget.api.learningSession(
          widget.childId, session!.sessionId);
      validateSnapshot(lesson!, saved, states, playback!);
      if (!mounted || run != generation) return;
      setState(() {
        cues = states;
        session = saved;
        answeredFeedback = response.feedbackText;
        selectedOption = null;
        if (states.resumePoint?.cueId != cue.cueId) {
          reachedCue = null;
          images.clear();
          questionAudio = null;
        }
      });
    } on ApiFailure catch (failure) {
      if (!mounted || run != generation) return;
      if ({'CUE_ALREADY_CORRECT', 'ATTEMPT_LIMIT_REACHED',
           'CHECKPOINT_OUT_OF_ORDER'}.contains(failure.code)) {
        widget.pending.acknowledge(widget.childId, session!.sessionId, request);
        try {
          final states = await widget.interactive.cueStates(
              widget.childId, session!.sessionId);
          if (mounted) setState(() => cues = states);
        } on ApiFailure catch (_) { /* Preserve the refusal. */ }
      }
      if (failure.code == 'MEDIA_NOT_AVAILABLE' ||
          {401, 403, 404}.contains(failure.status)) {
        stopMedia();
        blockedMessage = 'Bài học hiện không còn khả dụng. '
            'Bé nhờ ba mẹ mở lại bài học nhé.';
      }
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  Future<void> complete() async {
    if (busy || session == null || cues?.resolved != true ||
        (playback?.videoEndRequired == true && !videoEnded)) return;
    final run = generation;
    setState(() { busy = true; error = null; });
    try {
      final result = await widget.api.completeLearning(
          widget.childId, session!.sessionId);
      if (!mounted || run != generation) return;
      if (result.sessionId != session!.sessionId || result.state != 'COMPLETED'
          || result.endedAt == null) {
        throw const ApiInvalidResponse('Completion was not confirmed.');
      }
      stopMedia();
      setState(() => session = SessionDetail.fromSession(result, session!.answers));
    } on ApiFailure catch (failure) {
      if (mounted && run == generation) {
        if (failure.code == 'MEDIA_NOT_AVAILABLE' ||
            {401, 403}.contains(failure.status)) {
          stopMedia();
          blockedMessage = 'Nội dung hiện không còn khả dụng. '
              'Bé nhờ ba mẹ mở lại bài học nhé.';
        }
        setState(() => error = failure);
      }
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = activeCue;
    final state = activeState;
    final canAnswer = cue != null && reachedCue == cue.cueId &&
        !loadingAssets && blockedMessage == null && questionAudio != null &&
        images.length == cue.options.length && !busy &&
        state != null && !state.resolved && state.attemptsRemaining > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (busy) const LinearProgressIndicator(),
      if (lesson != null) Text(lesson!.summary.title,
          style: Theme.of(context).textTheme.headlineSmall),
      if (error != null) UserError(error!),
      if (blockedMessage != null) Text(blockedMessage!,
          key: const Key('interactiveMediaBlocked')),
      if (lesson == null || error != null || blockedMessage != null)
        OutlinedButton(key: const Key('interactiveRetry'),
            onPressed: busy ? null : load, child: const Text('Thử tải lại bài học')),
      if (session?.state == 'COMPLETED')
        Column(children: [
          const Text('Bé đã hoàn thành!', key: Key('interactiveCompleted')),
          Text('Kết thúc: ${session!.endedAt}'),
          FilledButton(key: const Key('interactiveReplay'),
              onPressed: busy ? null : load,
              child: const Text('Học lại')),
        ]),
      if (video != null && session?.state == 'IN_PROGRESS') ...[
        AspectRatio(aspectRatio: video!.value.aspectRatio,
            child: VideoPlayer(video!)),
        IconButton(key: const Key('interactiveVideoControl'),
            tooltip: video!.value.isPlaying ? 'Tạm dừng video' : 'Phát video',
            icon: Icon(video!.value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: busy || blockedMessage != null || reachedCue != null
                ? null : playVideo),
        if (ledger?.pending != null)
          OutlinedButton(key: const Key('interactiveRetryEvent'),
              onPressed: eventBusy ? null : retryPendingEvent,
              child: const Text('Thử xác nhận video lại')),
      ],
      if (cue != null && reachedCue == cue.cueId) ...[
        Text(cue.promptText, style: Theme.of(context).textTheme.titleLarge),
        IconButton(key: const Key('replayQuestionAudio'),
            tooltip: 'Nghe lại câu hỏi', icon: const Icon(Icons.volume_up),
            onPressed: loadingAssets || blockedMessage != null
                ? null : () => playAudio(cue.promptAssetId!, 'CUE_AUDIO')),
        if (cue.hintText != null) Text(cue.hintText!),
        if (cue.hintAssetId != null &&
            hasRole(cue.hintAssetId, 'CUE_HINT_AUDIO', 'AUDIO'))
          IconButton(key: const Key('playHintAudio'),
              tooltip: 'Nghe gợi ý', icon: const Icon(Icons.lightbulb_outline),
              onPressed: () => playAudio(cue.hintAssetId!, 'CUE_HINT_AUDIO')),
        if (loadingAssets) const LinearProgressIndicator(),
        for (final option in cue.options) ...[
          OutlinedButton(key: Key('interactiveOption-${option.optionId}'),
            onPressed: canAnswer ? () => setState(() =>
                selectedOption = option.optionId) : null,
            child: Column(children: [
              if (images[option.optionId] case final source?)
                Image.network(source.uri.toString(), height: 120,
                  headers: source.httpHeaders,
                  errorBuilder: (_, _, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && blockedMessage == null) setState(() =>
                        blockedMessage = 'Chưa tải được hình đáp án. Bé thử lại nhé.');
                    });
                    return const Icon(Icons.broken_image_outlined);
                  }),
              Text(option.labelText),
              if (selectedOption == option.optionId)
                const Icon(Icons.check_circle_outline),
            ])),
          if (option.audioAssetId != null &&
              hasRole(option.audioAssetId, 'OPTION_AUDIO', 'AUDIO'))
            IconButton(key: Key('optionAudio-${option.optionId}'),
              tooltip: 'Nghe đáp án', icon: const Icon(Icons.volume_up),
              onPressed: () => playAudio(option.audioAssetId!,
                  'OPTION_AUDIO')),
        ],
        Text('Còn ${state?.attemptsRemaining ?? 0} lượt trả lời'),
        FilledButton(key: const Key('interactiveSubmit'),
            onPressed: canAnswer && selectedOption != null
                ? () => answer(cue) : null,
            child: const Text('Chọn đáp án')),
        if (answeredFeedback != null) Text(answeredFeedback!),
      ],
      if (cues != null && cues!.cues.isNotEmpty) ...[
        for (final resolved in cues!.cues.where((c) => c.resolved))
          Card(child: Column(children: [
            Text(resolved.state == 'EXHAUSTED'
                ? 'Mimi sẽ chỉ đáp án đúng nhé.' : 'Đúng rồi!'),
            if (resolved.feedbackText != null) Text(resolved.feedbackText!),
            if (resolved.explanationText != null)
              Text(resolved.explanationText!),
            if (resolved.correctOptionId != null && lesson != null)
              Text('Đáp án đúng: ${lesson!.cues.firstWhere(
                (c) => c.cueId == resolved.cueId).options.firstWhere(
                (o) => o.optionId == resolved.correctOptionId).labelText}'),
          ])),
      ],
      if (session?.state == 'IN_PROGRESS' && cues?.resolved == true) ...[
        if (playback?.videoEndRequired == true && !videoEnded)
          const Text('Bé xem hết video trước khi hoàn thành nhé.'),
        FilledButton(key: const Key('interactiveComplete'),
            onPressed: busy ||
                (playback?.videoEndRequired == true && !videoEnded)
                ? null : complete,
            child: const Text('Hoàn thành bài học')),
      ],
    ]);
  }
}
