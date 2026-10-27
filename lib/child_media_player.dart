import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'child_media_access.dart';
import 'learning_models.dart';

/// The existing lesson view owns questions and answers. This widget supplies
/// only private video timing; it never treats player progress as an answer.
class ChildMediaPlayer extends StatefulWidget {
  const ChildMediaPlayer({
    super.key,
    required this.access,
    required this.childId,
    required this.lesson,
    required this.cues,
    required this.answeredCueIds,
    required this.onCueReached,
  });
  final ChildMediaAccess access;
  final String childId;
  final LessonDetail lesson;
  final List<LearningCue> cues;
  final Set<String> answeredCueIds;
  final ValueChanged<String> onCueReached;

  @override
  State<ChildMediaPlayer> createState() => ChildMediaPlayerState();
}

class ChildMediaPlayerState extends State<ChildMediaPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  ChildMediaSource? source;
  String? reachedCue;
  bool loading = false;
  bool failed = false;
  bool? lastPlaying, lastBuffering;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.access.mediaSessionChanges.addListener(checkSession);
    load();
  }

  @override
  void didUpdateWidget(covariant ChildMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId ||
        oldWidget.lesson.revisionId != widget.lesson.revisionId) {
      stop();
      load();
    } else if (reachedCue != null &&
        widget.answeredCueIds.contains(reachedCue)) {
      reachedCue = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller?.value.isInitialized == true) {
          checkCue();
          if (reachedCue == null) controller?.play();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stop();
      if (mounted) setState(() => failed = true);
    }
  }

  void checkSession() {
    final current = source;
    if (current != null &&
        !widget.access.mediaSessionIsCurrent(widget.childId, current.bearer)) {
      stop();
      if (mounted) setState(() => failed = true);
    }
  }

  void stop() {
    generation++;
    final previous = controller;
    controller = null;
    source = null;
    reachedCue = null;
    lastPlaying = null;
    lastBuffering = null;
    previous?.removeListener(checkCue);
    if (previous != null) {
      previous.pause();
      previous.dispose();
    }
  }

  Future<void> load() async {
    if (loading) return;
    stop();
    final run = generation;
    setState(() {
      loading = true;
      failed = false;
    });
    VideoPlayerController? next;
    try {
      final grant = await widget.access.childMediaSource(
        widget.childId,
        widget.lesson.summary.lessonId,
        widget.lesson.revisionId,
      );
      if (!mounted ||
          run != generation ||
          !widget.access.mediaSessionIsCurrent(widget.childId, grant.bearer))
        return;
      source = grant;
      next = VideoPlayerController.networkUrl(
        grant.uri,
        httpHeaders: {'Authorization': 'Bearer ${grant.bearer}'},
      );
      await next.initialize();
      if (!mounted || run != generation) return;
      controller = next;
      next.addListener(checkCue);
      setState(() {});
      checkCue();
      if (reachedCue == null) await next.play();
    } catch (_) {
      // Native errors can include request URLs or headers. Never render them.
      if (mounted && run == generation) setState(() => failed = true);
    } finally {
      if (next != null && !identical(next, controller)) await next.dispose();
      if (mounted && run == generation) setState(() => loading = false);
    }
  }

  void checkCue() {
    final player = controller;
    if (player == null || !player.value.isInitialized) return;
    final wasPlaying = lastPlaying;
    final wasBuffering = lastBuffering;
    if (player.value.hasError) {
      stop();
      if (mounted) setState(() => failed = true);
      return;
    }
    if (reachedCue != null) {
      if (player.value.isPlaying) player.pause();
      return;
    }
    for (final cue in widget.cues) {
      if (widget.answeredCueIds.contains(cue.cueId)) continue;
      if (player.value.position.inMilliseconds >= cue.pauseAtMs) {
        reachedCue = cue.cueId;
        player.pause();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && reachedCue == cue.cueId) {
            widget.onCueReached(cue.cueId);
          }
        });
      }
      break;
    }
    lastPlaying = player.value.isPlaying;
    lastBuffering = player.value.isBuffering;
    if (mounted &&
        (wasPlaying != lastPlaying ||
            wasBuffering != lastBuffering ||
            reachedCue != null))
      setState(() {});
  }

  Future<void> seek(Duration delta) async {
    final player = controller;
    if (player == null || !player.value.isInitialized || reachedCue != null)
      return;
    final nextCue = widget.cues.where(
      (c) => !widget.answeredCueIds.contains(c.cueId),
    );
    final limit = nextCue.isEmpty
        ? player.value.duration
        : Duration(milliseconds: nextCue.first.pauseAtMs);
    var target = player.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > limit) target = limit;
    await player.seekTo(target);
    checkCue();
  }

  @override
  void dispose() {
    widget.access.mediaSessionChanges.removeListener(checkSession);
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return Column(
      children: [
        if (loading)
          const CircularProgressIndicator(
            semanticsLabel: 'Loading private video',
          ),
        if (failed) ...[
          const Text(
            'Video is unavailable. Ask your parent for help or try again.',
          ),
          OutlinedButton(
            key: const Key('mediaRetry'),
            onPressed: loading ? null : load,
            child: const Text('Retry video'),
          ),
        ],
        if (player != null && player.value.isInitialized) ...[
          AspectRatio(
            aspectRatio: player.value.aspectRatio,
            child: VideoPlayer(player),
          ),
          if (player.value.isBuffering)
            const LinearProgressIndicator(semanticsLabel: 'Buffering video'),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                key: const Key('mediaRewind'),
                icon: const Icon(Icons.replay_10),
                tooltip: 'Rewind 10 seconds',
                onPressed: () => seek(const Duration(seconds: -10)),
              ),
              IconButton(
                key: const Key('mediaPlayPause'),
                icon: Icon(
                  player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                tooltip: player.value.isPlaying ? 'Pause video' : 'Play video',
                onPressed: reachedCue != null
                    ? null
                    : () => player.value.isPlaying
                          ? player.pause()
                          : player.play(),
              ),
              IconButton(
                key: const Key('mediaForward'),
                icon: const Icon(Icons.forward_10),
                tooltip: 'Forward 10 seconds',
                onPressed: () => seek(const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
