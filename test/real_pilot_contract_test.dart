import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_onboarding.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';

import 'learning_api_test.dart' show Transport, Reply;
import 'learning_test_data.dart';
import 'child_onboarding_test.dart' show childRequest;
import 'learning_api_test.dart' show authenticated;

void main() {
  test(
    'PUBLIC_PILOT: approved legal bodies validate through actual client',
    () async {
      final transport = HttpClient();
      final client = LiveMimiGoApi(
        Uri.parse(ApiConfiguration.fromEnvironment().baseUrl),
        client: transport,
      );
      addTearDown(() => transport.close(force: true));
      final reference = await client.onboardingReference();
      expect(reference.terms?.hasApprovedDocument, isTrue);
      for (final purpose in ['CHILD_PROFILE_AGE', 'LEARNING_PROGRESS']) {
        expect(
          reference.notices
              .singleWhere((n) => n.purposeCode == purpose)
              .hasApprovedDocument,
          isTrue,
        );
      }
    },
    skip: !const bool.fromEnvironment('MIMIGO_VERIFY_PUBLIC_PILOT'),
    timeout: const Timeout(Duration(seconds: 100)),
  );

  test(
    'Cloud creation confirms identity without DOB or withheld age',
    () async {
      final request = childRequest();
      final transport = Transport()
        ..replies.add(
          Reply({
            'childId': childId,
            'childAlias': request.childAlias,
            'stockAvatarKey': request.stockAvatarKey,
            'withinProgramAgeRange': false,
            'state': 'ACTIVE',
            'createdAt': '2026-11-07T00:00:00Z',
          }, statusCode: 201),
        );
      final state = ChildCreationState(await authenticated(transport), request);
      addTearDown(state.dispose);
      final child = await state.submit();
      expect(child?.id, childId);
      expect(child?.dateOfBirth, isNull);
      expect(child?.ageYears, isNull);
      expect(state.error, isNull);
    },
  );

  Map<String, dynamic> grant() => {
    'assetId': 'asset-one',
    'kind': 'VIDEO',
    'mimeType': 'video/mp4',
    'url': 'https://private.invalid/video?signature=ephemeral',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 3))
        .toIso8601String(),
  };
  LiveMimiGoApi api(Transport transport) {
    final api = LiveMimiGoApi(
      Uri.parse('https://pilot.invalid/api/v1'),
      client: transport,
      parentGateEnabled: true,
      childMediaEnabled: true,
    );
    api.gateSession!.current = DeviceSession(
      token: 'child-only',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      refreshToken: 'refresh',
      refreshExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      sessionId: sessionId,
      parentId: 'parent',
      mode: SessionMode.child,
      childId: childId,
    );
    addTearDown(api.gateSession!.dispose);
    return api;
  }

  test('normal entry targets pilot and enables authenticated media', () {
    final config = ApiConfiguration.fromEnvironment();
    expect(config.baseUrl, 'https://mimigo-api-pilot.onrender.com/api/v1');
    expect(config.childMediaEnabled, isTrue);
    expect(config.parentGateEnabled, isTrue);
  });
  test(
    'fresh child-authenticated grant per playback; no bearer to storage',
    () async {
      final transport = Transport()
        ..replies.addAll([Reply(grant()), Reply(grant())]);
      final client = api(transport);
      for (var i = 0; i < 2; i++) {
        final source = await client.childMediaSource(
          childId,
          lessonId,
          revisionId,
        );
        expect(source.httpHeaders, isEmpty);
        expect(source.expiresAt, isNotNull);
        expect(client.mediaSessionIsCurrent(childId, source.bearer), isTrue);
      }
      expect(transport.requests.length, 2);
      for (final request in transport.requests) {
        expect(request.method, 'GET');
        expect(
          request.uri.path,
          '/api/v1/children/$childId/lessons/$lessonId/media',
        );
        expect(request.headers.value('authorization'), 'Bearer child-only');
      }
      await expectLater(
        client.childMediaSource('sibling', lessonId, revisionId),
        throwsA(isA<ApiFailure>()),
      );
      expect(transport.requests.length, 2);
    },
  );
  test('malformed, expired and unsafe playback grants fail closed', () async {
    for (final change in [
      {'url': 'http://private.invalid/video'},
      {'url': 'https://user:password@private.invalid/video'},
      {'expiresAt': '2020-01-01T00:00:00Z'},
      {'kind': 'AUDIO'},
      {'mimeType': 'text/html'},
    ]) {
      final transport = Transport()
        ..replies.add(Reply({...grant(), ...change}));
      await expectLater(
        api(transport).childMediaSource(childId, lessonId, revisionId),
        throwsA(isA<ApiInvalidResponse>()),
      );
    }
  });
  test('media denials remain server denials without fallback', () async {
    for (final code in [
      'MEDIA_NOT_AVAILABLE',
      'MEDIA_STORAGE_UNAVAILABLE',
      'PERMISSION_NOT_GRANTED',
    ]) {
      final transport = Transport()
        ..replies.add(
          Reply({
            'code': code,
          }, statusCode: code == 'MEDIA_STORAGE_UNAVAILABLE' ? 503 : 403),
        );
      await expectLater(
        api(transport).childMediaSource(childId, lessonId, revisionId),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', code)),
      );
      expect(transport.requests.length, 1);
    }
  });
  test('real nicknames accepted; contact data rejected', () {
    for (final name in ['B? Na', 'Mimi', 'S?c']) {
      expect(acceptableChildNickname(name), isTrue);
    }
    for (final name in [
      '',
      'a@b',
      'www.test',
      'https:foo',
      '012345',
      'a/b',
      r'a\b',
      '<name>',
      'x' * 31,
    ]) {
      expect(acceptableChildNickname(name), isFalse, reason: name);
    }
  });
}
