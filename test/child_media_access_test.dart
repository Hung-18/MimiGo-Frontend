import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';

import 'learning_test_data.dart';

void main() {
  const localHost = 'http://10.0.2.2:5198';
  LiveMimiGoApi api({
    bool gate = true,
    bool media = true,
    String host = localHost,
  }) => LiveMimiGoApi(
    Uri.parse('http://10.0.2.2:5197/api/v1'),
    parentGateEnabled: gate,
    childMediaEnabled: media,
    childMediaBaseUrl: host,
  );

  void adopt(
    LiveMimiGoApi api, {
    SessionMode mode = SessionMode.child,
    String child = childId,
  }) {
    api.gateSession!.current = DeviceSession(
      token: 'synthetic-child-token',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      refreshToken: 'synthetic-refresh',
      refreshExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      sessionId: sessionId,
      parentId: 'synthetic-parent',
      mode: mode,
      childId: mode == SessionMode.child ? child : null,
    );
  }

  test(
    'disabled/default and nonlocal media configurations fail closed',
    () async {
      final defaults = ApiConfiguration.fromEnvironment();
      expect(defaults.childMediaEnabled, true);
      expect(api(media: false).childMediaEnabled, false);
      expect(api(gate: false).childMediaEnabled, false);
      expect(api(host: 'https://media.example.test').childMediaEnabled, false);
      expect(api(host: '$localHost/redirect').childMediaEnabled, false);
      expect(api(host: '$localHost?token=bad').childMediaEnabled, false);
      expect(
        ApiConfiguration(
          ApiMode.fixture,
          localHost,
          parentGateEnabled: true,
          childMediaEnabled: true,
          childMediaBaseUrl: localHost,
        ).createClient(),
        isA<FixtureMimiGoApi>(),
      );
    },
  );

  test(
    'only matching Child Gate context builds selector-free private URL',
    () async {
      final client = api();
      adopt(client);
      final source = await client.childMediaSource(
        childId,
        lessonId,
        revisionId,
      );
      expect(
        source.uri.toString(),
        '$localHost/private/media/children/lessons/'
        '$lessonId/revisions/$revisionId/main-video',
      );
      expect(source.uri.toString(), isNot(contains(childId)));
      expect(source.uri.toString(), isNot(contains('synthetic-child-token')));
      expect(source.bearer, 'synthetic-child-token');
      expect(client.mediaSessionIsCurrent(childId, source.bearer), true);
      await expectLater(
        client.childMediaSource('other-child', lessonId, revisionId),
        throwsA(isA<ApiFailure>()),
      );
      client.gateSession!.invalidateMemory();
      expect(client.mediaSessionIsCurrent(childId, source.bearer), false);
      await expectLater(
        client.childMediaSource(childId, lessonId, revisionId),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test('Parent credentials cannot create Child media source', () async {
    final client = api();
    adopt(client, mode: SessionMode.parent);
    await expectLater(
      client.childMediaSource(childId, lessonId, revisionId),
      throwsA(isA<ApiFailure>()),
    );
  });
}
