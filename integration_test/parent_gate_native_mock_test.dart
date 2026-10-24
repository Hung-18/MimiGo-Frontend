import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';

import '../test/parent_gate_test_backend.dart';
import '../test/learning_test_data.dart' as lesson;
import 'live_auth_test.dart' show tap, waitFor;

Future<void> nativePin(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('gatePin')));
  expect(
    await GateScreenSecurity.channel.invokeMethod<bool>('screenProtected'),
    isTrue,
  );
  await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
  await tap(tester, 'gateSubmit');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android NATIVE secure refresh vault and independent FLAG_SECURE leases',
    (tester) async {
      const vault = PlatformCredentialVault();
      expect(
        await vault.read(),
        isNull,
        reason: 'Use a disposable emulator app profile; never overwrite an existing credential.',
      );
      final bundle = jsonEncode({
        'refreshToken': 'synthetic-native-test-only',
        'refreshExpiresAt': '2030-01-01T00:00:00Z',
        'sessionId': 'synthetic-session',
        'parentId': 'synthetic-parent',
        'apiScope': 'synthetic-test',
      });
      try {
        await vault.write(bundle);
        expect(await vault.read(), bundle);
      } finally {
        await vault.clear();
      }
      expect(await vault.read(), isNull);
      final first = GateScreenSecurity(), second = GateScreenSecurity();
      await first.protect();
      await second.protect();
      await first.release();
      expect(
        await GateScreenSecurity.channel.invokeMethod<bool>('screenProtected'),
        isTrue,
      );
      await second.release();
      expect(
        await GateScreenSecurity.channel.invokeMethod<bool>('screenProtected'),
        isFalse,
      );
      debugPrint(
        'PARENT GATE ANDROID NATIVE PASS: Keystore refresh-vault round trip/delete and independent FLAG_SECURE leases. Synthetic values only.',
      );
    },
  );
  testWidgets(
    'Android MOCK complete Parent Gate UI, child-token lesson completion/replay, switch, exit and revocation',
    (tester) async {
      const vault = PlatformCredentialVault();
      expect(await vault.read(), isNull);
      final backend = GateTestBackend();
      final api = LiveMimiGoApi(
        Uri.parse('http://mock.invalid/api/v1'),
        client: backend,
        parentGateEnabled: true,
        vault: vault,
      );
      try {
        await tester.pumpWidget(
          MimiGoApp(
            api: api,
            configuration: const ApiConfiguration(
              ApiMode.fixture,
              'unused',
              parentGateEnabled: true,
            ),
          ),
        );
        await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
        await tap(tester, 'welcomeSignIn');
        await tester.enterText(
          find.byKey(const Key('signInEmail')),
          'synthetic@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('signInPassword')),
          syntheticPassword,
        );
        await tap(tester, 'signInSubmit');
        await waitFor(tester, find.byKey(const Key('manageParentPin')));
        expect(find.textContaining('Date of birth'), findsNothing);
        expect(find.textContaining('Age returned'), findsNothing);
        await tap(tester, 'manageParentPin');
        await waitFor(tester, find.byKey(const Key('gatePin')));
        expect(
          await GateScreenSecurity.channel.invokeMethod<bool>(
            'screenProtected',
          ),
          isTrue,
        );
        await tester.enterText(
          find.byKey(const Key('gatePassword')),
          syntheticPassword,
        );
        await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
        await tester.enterText(
          find.byKey(const Key('gatePinConfirmation')),
          syntheticPin,
        );
        await tap(tester, 'gateSubmit');
        await waitFor(tester, find.byKey(const Key('openParentArea')));
        expect(api.gateSession!.hasParentProof, isFalse);
        await tap(tester, 'openParentArea');
        await nativePin(tester);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gated-child-child-A');
        await waitFor(tester, find.byKey(const Key('protectedChildDob')));
        expect(
          await GateScreenSecurity.channel.invokeMethod<bool>(
            'screenProtected',
          ),
          isTrue,
        );
        await tap(tester, 'gatedParentHome');
        await tap(tester, 'parent-child-child-A');
        await tap(tester, 'parentEnterLearning');
        await nativePin(tester);
        await waitFor(tester, find.text('Hi, SYN-child-A!'));
        expect(find.byKey(const Key('protectedChildDob')), findsNothing);
        final childToken = api.gateSession!.current!.token;
        await expectLater(
          api.getChild('child-A'),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.code,
              'code',
              'CHILD_CONTEXT_FORBIDDEN',
            ),
          ),
        );
        await tap(tester, 'openCurriculum');
        await waitFor(tester, find.byKey(const Key('domain-MATH')));
        await tap(tester, 'domain-MATH');
        await tap(tester, 'topic-SYN-TOPIC');
        await tap(tester, 'explorer-lesson-${lesson.lessonId}');
        await waitFor(tester, find.byKey(const Key('startLearning')));
        await tap(tester, 'startLearning');
        await waitFor(
          tester,
          find.byKey(const Key('option-${lesson.optionId}')),
        );
        await tap(tester, 'option-${lesson.optionId}');
        await tap(tester, 'submit-${lesson.cueId}');
        await waitFor(
          tester,
          find.byKey(const Key('feedback-${lesson.cueId}')),
        );
        await tap(tester, 'completeLearning');
        await waitFor(tester, find.byKey(const Key('completionConfirmed')));
        final completed = backend.sessions.values.single;
        final ended = completed['endedAt'];
        expect(ended, isNotNull);
        await tap(tester, 'replayLearning');
        await waitFor(tester, find.text('Session: IN_PROGRESS'));
        expect(backend.sessions, hasLength(2));
        expect(completed['endedAt'], ended);
        for (final request in backend.requests.where(
          (r) => r.uri.path.contains('/children/child-A/'),
        )) {
          expect(request.headers.value('authorization'), 'Bearer $childToken');
          expect(request.headers.value('mimigo-parent-proof'), isNull);
        }
        await tap(tester, 'lessonHome');
        await tap(tester, 'childSwitchGate');
        await nativePin(tester);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gatedParentHome');
        await tap(tester, 'parent-child-child-B');
        await tap(tester, 'parentEnterLearning');
        await nativePin(tester);
        await waitFor(tester, find.text('Hi, SYN-child-B!'));
        expect(api.gateSession!.current!.childId, 'child-B');
        expect(find.text('SYN-child-A'), findsNothing);
        await tap(tester, 'childParentGate');
        await nativePin(tester);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gated-child-child-B');
        await waitFor(tester, find.byKey(const Key('protectedChildDob')));
        backend.revoked = true;
        await tap(tester, 'loadParentActivity');
        await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
        expect(find.byKey(const Key('protectedChildDob')), findsNothing);
        expect(await vault.read(), isNull);
        debugPrint(
          'PARENT GATE ANDROID MOCK PASS: enrollment/Parent Area; real native FLAG_SECURE and encrypted refresh storage; child-token mock lesson complete/replay; PIN switch/exit; revocation hides protected data. HTTP is a test double, NOT live Backend E2E.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        api.gateSession!.dispose();
        await vault.clear();
      }
    },
  );
}
