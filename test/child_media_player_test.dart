import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/child_media_access.dart';
import 'package:mimigo_frontend/child_media_player.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'learning_test_data.dart';
import 'learning_widget_test.dart' show LearningTestApi;

class MediaLearningApi extends LearningTestApi implements ChildMediaAccess {
  final changes = ValueNotifier<int>(0);
  @override
  bool get childMediaEnabled => true;
  @override
  Listenable get mediaSessionChanges => changes;
  @override
  bool mediaSessionIsCurrent(String child, String bearer) =>
      child == childId && bearer == 'child-only';
  @override
  Future<ChildMediaSource> childMediaSource(
    String child,
    String lesson,
    String revision,
  ) async => ChildMediaSource(
    Uri.parse(
      'http://10.0.2.2:5198/private/media/children/lessons/'
      '$lesson/revisions/$revision/main-video',
    ),
    'child-only',
  );
}

class TestMediaAccess extends ChangeNotifier implements ChildMediaAccess {
  TestMediaAccess({this.signed = false});
  final bool signed;
  bool current = true;
  @override
  bool get childMediaEnabled => true;
  @override
  Listenable get mediaSessionChanges => this;
  @override
  bool mediaSessionIsCurrent(String child, String bearer) =>
      current && child == childId && bearer == 'child-only';
  @override
  Future<ChildMediaSource> childMediaSource(
    String child,
    String lesson,
    String revision,
  ) async => ChildMediaSource(
    Uri.parse(
      'http://10.0.2.2:5198/private/media/children/lessons/'
      '$lesson/revisions/$revision/main-video',
    ),
    'child-only',
    sendBearer: !signed,
  );
  void revoke() {
    current = false;
    notifyListeners();
  }
}

class TestVideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final seeks = <Duration>[];
  int pauses = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    streams[id] = StreamController<VideoEvent>();
    scheduleMicrotask(
      () => streams[id]?.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(640, 360),
          duration: const Duration(seconds: 20),
        ),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => streams[id]!.stream;
  @override
  Future<void> dispose(int id) async {
    await streams[id]?.close();
  }

  @override
  Future<void> play(int id) async {}
  @override
  Future<void> pause(int id) async {
    pauses++;
  }

  @override
  Future<void> seekTo(int id, Duration value) async {
    seeks.add(value);
    positions[id] = value;
  }

  @override
  Future<Duration> getPosition(int id) async => positions[id] ?? Duration.zero;
  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform original;
  setUp(() => original = VideoPlayerPlatform.instance);
  tearDown(() => VideoPlayerPlatform.instance = original);

  testWidgets(
    'signed playback never sends API bearer to native storage player',
    (tester) async {
      final platform = TestVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final access = TestMediaAccess(signed: true);
      final lesson = LessonDetail.fromJson(detailJson());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildMediaPlayer(
              access: access,
              childId: childId,
              lesson: lesson,
              cues: lesson.cues,
              answeredCueIds: const {},
              onCueReached: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(platform.sources.single.httpHeaders, isEmpty);
      access.revoke();
      await tester.pump();
      expect(find.byKey(const Key('mediaRetry')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
    },
  );

  testWidgets(
    'native source carries Child header; seek stops at cue and revocation stops',
    (tester) async {
      final platform = TestVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final access = TestMediaAccess();
      final lesson = LessonDetail.fromJson(detailJson());
      final reached = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildMediaPlayer(
              access: access,
              childId: childId,
              lesson: lesson,
              cues: lesson.cues,
              answeredCueIds: const {},
              onCueReached: reached.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(platform.sources, hasLength(1));
      expect(
        platform.sources.single.httpHeaders['Authorization'],
        'Bearer child-only',
      );
      expect(
        platform.sources.single.uri,
        contains('/lessons/$lessonId/revisions/$revisionId/'),
      );
      expect(platform.sources.single.uri, isNot(contains(childId)));
      await tester.tap(find.byKey(const Key('mediaForward')));
      await tester.pump();
      await tester.pump();
      expect(platform.seeks.last, const Duration(seconds: 1));
      expect(reached, [cueId]);
      expect(platform.pauses, greaterThan(0));
      access.revoke();
      await tester.pump();
      expect(find.byKey(const Key('mediaRetry')), findsOneWidget);
      expect(find.textContaining('child-only'), findsNothing);
      access.dispose();
    },
  );

  testWidgets(
    'lesson keeps cue hidden until video pause and records server answer',
    (tester) async {
      final platform = TestVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final api = MediaLearningApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningLessonView(
                api: api,
                childId: childId,
                lessonId: lessonId,
                pending: PendingLearningAnswers(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('startLearning')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('cue-$cueId')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('mediaForward')));
      await tester.tap(find.byKey(const Key('mediaForward')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cue-$cueId')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('option-$optionId')));
      await tester.tap(find.byKey(const Key('option-$optionId')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('submit-$cueId')));
      await tester.tap(find.byKey(const Key('submit-$cueId')));
      await tester.pump();
      await tester.pump();
      expect(api.submitted, hasLength(1));
      expect(find.byKey(const Key('recorded-$cueId-1')), findsOneWidget);
      expect(
        platform.sources.single.httpHeaders['Authorization'],
        'Bearer child-only',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byKey(const Key('mediaRetry')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      api.changes.dispose();
    },
  );
}
