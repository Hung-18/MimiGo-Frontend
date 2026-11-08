import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/api_failure.dart';
import 'package:mimigo_frontend/child_media_access.dart';
import 'package:mimigo_frontend/interactive_learning.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/main.dart' show LiveMimiGoApi;
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'child_media_player_test.dart' show TestVideoPlatform;
import 'learning_api_test.dart' show Transport, Reply, authenticated;
import 'learning_test_data.dart' as data;
import 'learning_widget_test.dart' show LearningTestApi;

class InteractiveTestApi extends LearningTestApi
    implements InteractiveLearningApi, ChildLearningMediaAccess {
  InteractiveTestApi({this.resolved = false});
  final bool resolved;
  final events = <PlaybackEventRequest>[];
  int nextSeq = 3;
  final changes = ValueNotifier<int>(0);
  @override
  bool get childMediaEnabled => true;
  @override
  Listenable get mediaSessionChanges => changes;
  @override
  bool mediaSessionIsCurrent(String child, String bearer) =>
      child == data.childId && bearer == 'child-test';
  @override
  Future<ChildMediaSource> childMediaSource(
      String child, String lesson, String revision) async => ChildMediaSource(
      Uri.parse('https://unit.invalid/video'), 'child-test', sendBearer: false,
      expiresAt: DateTime(2030));
  @override
  Future<ChildMediaSource> childLearningAsset(String child, String lesson,
      String session, String asset, String kind) async =>
      throw StateError('Missing required media must block before a grant.');
  @override
  Future<CueStates> cueStates(String child, String session) async =>
      CueStates.fromJson({'sessionId': data.sessionId,
        'cues': [state(resolved ? 'CORRECT' : 'PENDING',
            resolved ? 1 : 0, resume: !resolved)]});
  @override
  Future<PlaybackState> playbackState(String child, String session) async =>
      PlaybackState.fromJson({
        ...playback(), 'resumePositionMs': resolved ? 0 : 1000,
        'nextSeq': nextSeq,
      });
  @override
  Future<PlaybackVerdict> playbackEvent(String child, String session,
      PlaybackEventRequest request) async {
    events.add(request);
    nextSeq++;
    return PlaybackVerdict.fromJson({
      'verdict': 'ACCEPTED', 'replayed': false,
      'acceptedPositionMs': request.positionMs,
      'frontierMs': request.positionMs,
      'resumePositionMs': request.positionMs,
      'videoEndAccepted': false,
    });
  }
}

Map<String, dynamic> state(String status, int used, {bool resume = true}) => {
  'cueId': data.cueId, 'seq': 1, 'state': status,
  'attemptsUsed': used, 'attemptsRemaining': 2 - used,
  'resolved': status == 'CORRECT' || status == 'EXHAUSTED',
  'resumePoint': resume,
  'correctOptionId': status == 'CORRECT' || status == 'EXHAUSTED'
      ? data.otherOptionId : null,
  'feedbackText': status == 'EXHAUSTED' ? 'Try again next time' : null,
  'explanationText': status == 'EXHAUSTED' ? 'The second picture' : null,
};

Map<String, dynamic> playback() => {
  'sessionId': data.sessionId, 'durationMs': 60000,
  'frontierMs': 1000, 'resumePositionMs': 1000,
  'playState': 'PAUSED', 'nextSeq': 3,
  'videoEndAccepted': false, 'videoEndRequired': true,
  'heartbeatIntervalMs': 5000,
};

void main() {
  testWidgets('video start uses the server sequence and cannot complete early',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = TestVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final api = InteractiveTestApi(resolved: true);
    addTearDown(api.changes.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SingleChildScrollView(child: InteractiveLearningView(
        api: api, interactive: api, childId: data.childId,
        lessonId: data.lessonId, domainCode: 'MATH',
        pending: PendingLearningAnswers(),
      )),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(tester.widget<FilledButton>(
      find.byKey(const Key('interactiveComplete'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('interactiveVideoControl')));
    await tester.pump();
    await tester.pump();
    expect(api.events.single.kind, 'START');
    expect(api.events.single.seq, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a reached checkpoint with missing audio/images blocks choices',
      (tester) async {
    final original = VideoPlayerPlatform.instance;
    final platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final api = InteractiveTestApi();
    addTearDown(api.changes.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SingleChildScrollView(child: InteractiveLearningView(
        api: api, interactive: api, childId: data.childId,
        lessonId: data.lessonId, domainCode: 'MATH',
        pending: PendingLearningAnswers(),
      )),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byKey(const Key('interactiveMediaBlocked')), findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const Key('interactiveSubmit'))).onPressed, isNull);
    expect(platform.sources.single.httpHeaders, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('server states own the retry and EXHAUSTED answer disclosure', () {
    final retry = CueStates.fromJson({
      'sessionId': data.sessionId,
      'cues': [state('RETRY_AVAILABLE', 1)],
    });
    expect(retry.resumePoint!.attemptsRemaining, 1);
    expect(retry.resumePoint!.correctOptionId, isNull);
    final exhausted = CueStates.fromJson({
      'sessionId': data.sessionId,
      'cues': [state('EXHAUSTED', 2, resume: false)],
    });
    expect(exhausted.resolved, isTrue);
    expect(exhausted.cues.single.correctOptionId, data.otherOptionId);
    expect(exhausted.cues.single.explanationText, 'The second picture');
    expect(() => CueStates.fromJson({
      'sessionId': data.sessionId,
      'cues': [state('RETRY_AVAILABLE', 2)],
    }), throwsA(isA<ApiInvalidResponse>()));
  });

  test('an ambiguous playback POST keeps its event identity and sequence', () {
    final ledger = PlaybackEventLedger(3);
    final first = ledger.prepare('PAUSE', 1000);
    expect(identical(ledger.prepare('PAUSE', 1000), first), isTrue);
    expect(first.toJson(), {
      'eventId': first.eventId, 'seq': 3,
      'kind': 'PAUSE', 'positionMs': 1000,
    });
    ledger.acknowledge();
    expect(ledger.prepare('START', 1000).seq, 4);
    ledger.reconcile(PlaybackState.fromJson(playback()));
    expect(ledger.pending, isNull);
    expect(ledger.nextSeq, 3);
  });

  test('required question audio and every answer image fail closed', () {
    final json = data.detailJson();
    final cue = (json['cues'] as List).single as Map<String, dynamic>;
    final assets = json['assets'] as List;
    const audio = '99999999-9999-4999-8999-999999999999';
    const imageA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const imageB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    Map<String, String> asset(String id, String role, String kind) => {
      'assetId': id, 'kind': kind, 'role': role,
      'mimeType': kind == 'AUDIO' ? 'audio/mpeg' : 'image/png',
      'contentHash': 'synthetic', 'storageRef': 'opaque',
      'rightsStatus': 'CLEARED',
    };
    final options = cue['options'] as List;
    (options[0] as Map)['imageAssetId'] = imageA;
    (options[1] as Map)['imageAssetId'] = imageB;
    assets.add(asset(imageA, 'OPTION_IMAGE', 'IMAGE'));
    assets.add(asset(imageB, 'OPTION_IMAGE', 'IMAGE'));
    expect(cueHasRequiredInteractiveMedia(
        LessonDetail.fromJson(json), LessonDetail.fromJson(json).cues.single),
        isFalse);
    cue['promptAssetId'] = audio;
    assets.add(asset(audio, 'CUE_AUDIO', 'AUDIO'));
    final detail = LessonDetail.fromJson(json);
    expect(cueHasRequiredInteractiveMedia(detail, detail.cues.single), isTrue);
    assets.removeLast();
    final missing = LessonDetail.fromJson(json);
    expect(cueHasRequiredInteractiveMedia(missing, missing.cues.single), isFalse);
  });

  test('Cloud routes use the Child learning path and exact event body', () async {
    final transport = Transport();
    final api = await authenticated(transport);
    transport.replies.add(Reply({
      'sessionId': data.sessionId,
      'cues': [state('RETRY_AVAILABLE', 1)],
    }));
    transport.replies.add(Reply(playback()));
    transport.replies.add(Reply({
      'verdict': 'ACCEPTED', 'replayed': false,
      'acceptedPositionMs': 1000, 'frontierMs': 1000,
      'resumePositionMs': 1000, 'durationMs': 60000,
      'videoEndAccepted': false,
    }));
    await api.cueStates(data.childId, data.sessionId);
    await api.playbackState(data.childId, data.sessionId);
    final request = PlaybackEventRequest(data.eventId, 3, 'PAUSE', 1000);
    await api.playbackEvent(data.childId, data.sessionId, request);
    expect(transport.requests.map((r) => r.uri.path).toList(), [
      '/api/v1/auth/login',
      '/api/v1/children/${data.childId}/learning-sessions/${data.sessionId}/cue-states',
      '/api/v1/children/${data.childId}/learning-sessions/${data.sessionId}/playback-state',
      '/api/v1/children/${data.childId}/learning-sessions/${data.sessionId}/playback-events',
    ]);
    expect(jsonDecode(transport.requests.last.body), request.toJson());
  });

  test('0081 asset grant is session-scoped and storage gets no bearer', () async {
    final transport = Transport();
    final api = LiveMimiGoApi(
      Uri.parse('https://unit.invalid/api/v1'), client: transport,
      parentGateEnabled: true, childMediaEnabled: true,
    );
    api.gateSession!.current = DeviceSession(
      token: 'child-token', expiresAt: DateTime(2030),
      refreshToken: 'refresh-test', refreshExpiresAt: DateTime(2031),
      sessionId: data.sessionId, parentId: 'parent-test',
      mode: SessionMode.child, childId: data.childId,
    );
    transport.replies.add(Reply({
      'assetId': data.eventId, 'kind': 'AUDIO',
      'mimeType': 'audio/mpeg', 'url': 'https://storage.invalid/fresh',
      'expiresAt': '2030-01-01T00:00:00Z',
    }));
    final source = await api.childLearningAsset(data.childId, data.lessonId,
        data.sessionId, data.eventId, 'AUDIO');
    expect(transport.requests.single.uri.queryParameters['sessionId'],
        data.sessionId);
    expect(transport.requests.single.headers.value('authorization'),
        'Bearer child-token');
    expect(source.httpHeaders, isEmpty);
    expect(source.uri.host, 'storage.invalid');
    transport.replies.add(Reply({
      'code': 'MEDIA_NOT_AVAILABLE',
      'message': 'Unavailable', 'requestId': 'unit-request',
    }, statusCode: 404));
    await expectLater(
      api.childLearningAsset(data.childId, data.lessonId,
          data.sessionId, data.eventId, 'AUDIO'),
      throwsA(isA<ApiFailure>().having((e) => e.code,
          'code', 'MEDIA_NOT_AVAILABLE')),
    );
    expect(transport.requests, hasLength(2),
        reason: 'Every asset request must recheck current access.');
  });
}
