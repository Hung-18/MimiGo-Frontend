import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/learning_models.dart';

import '../test/parent_gate_session_test.dart' show MemoryVault;
import 'live_auth_test.dart' show tap, waitFor;

class GateLearningLive extends LiveMimiGoApi {
  GateLearningLive(super.baseUri) : super(parentGateEnabled: true);
  LessonDetail? detail;
  SessionDetail? readback;
  LearningSession? completed;
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async =>
      detail = await super.lesson(childId, lessonId);
  @override
  Future<SessionDetail> learningSession(
    String childId,
    String sessionId,
  ) async => readback = await super.learningSession(childId, sessionId);
  @override
  Future<LearningSession> completeLearning(
    String childId,
    String sessionId,
  ) async => completed = await super.completeLearning(childId, sessionId);
}

Future<void> livePin(WidgetTester tester, String pin) async {
  await waitFor(tester, find.byKey(const Key('gatePin')));
  expect(
    await GateScreenSecurity.channel.invokeMethod<bool>('screenProtected'),
    isTrue,
  );
  await tester.enterText(find.byKey(const Key('gatePin')), pin);
  await tap(tester, 'gateSubmit');
}

Future<void> expectRawDenial(
  Uri base,
  String path,
  String token,
  int status,
  String code,
) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      base.replace(path: '${base.path}/$path'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    expect(response.statusCode, status);
    final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    expect(json['code'], code);
    expect(json.containsKey('dateOfBirth'), isFalse);
  } finally {
    client.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Parent Gate LIVE disposable R0 end-to-end with real authorization only',
    (tester) async {
      // Explicit operator attestations: this test never activates schemas, starts
      // an API or assumes the ordinary Dev API at 5187 is authorized for Gate.
      const authorized = bool.fromEnvironment(
        'MIMIGO_PARENT_GATE_E2E_AUTHORIZED',
      );
      const database = String.fromEnvironment(
        'MIMIGO_PARENT_GATE_E2E_DATABASE',
      );
      const address = String.fromEnvironment('MIMIGO_API_BASE_URL');
      expect(
        authorized,
        isTrue,
        reason: 'Requires explicit authorization of an already-running disposable R0 API.',
      );
      expect(
        RegExp(r'^mimigo_conc_[a-z0-9_]+$').hasMatch(database),
        isTrue,
        reason: 'Never run candidate activation on mimigo_dev, mimigo_test or production.',
      );
      expect(
        address,
        isNotEmpty,
        reason:
            'Provide the exact emulator URL of the approved disposable API.',
      );
      final config = ApiConfiguration.fromEnvironment();
      expect(config.mode, ApiMode.live);
      expect(config.parentGateEnabled, isTrue);
      const vault = PlatformCredentialVault();
      expect(
        await vault.read(),
        isNull,
        reason: 'Use a disposable emulator app profile without pre-existing credentials.',
      );
      final uri = Uri.parse(address);
      final setup = LiveMimiGoApi(
        uri,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final random = Random.secure();
      final email = 'pg-$suffix@example.test';
      final password = 'SYN-${random.nextInt(1 << 30)}-$suffix';
      final reference = await setup.onboardingReference();
      final registration = await setup.register(
        Registration(
          email,
          password,
          'SYN Gate Parent',
          reference.terms!.id,
          true,
        ),
      );
      expect(registration.mockOtp, isNotNull);
      await setup.verifyMockEmail(email: email, otp: registration.mockOtp!);
      await setup.login(email: email, password: password);
      final children = <ChildSummary>[];
      for (final name in ['A', 'B']) {
        final attempt = await setup.beginOnboardingAttempt();
        children.add(
          await setup.createChild(
            CreateChildRequest(
              attemptId: attempt.id,
              idempotencyKey: 'pg-$name-$suffix',
              childAlias: 'SYN-Gate-$name-$suffix',
              dateOfBirth: DateTime(2023, 1, 1),
              stockAvatarKey: 'bear-blue',
              guardianAffirmed: true,
              purposeChoices: attempt.notices
                  .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
                  .toList(),
            ),
          ),
        );
      }
      await setup.gateSession!.logout();
      setup.gateSession!.dispose();
      final api = GateLearningLive(uri);
      final other = LiveMimiGoApi(
        uri,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      try {
        await tester.pumpWidget(MimiGoApp(api: api, configuration: config));
        await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
        await tap(tester, 'welcomeSignIn');
        await tester.enterText(find.byKey(const Key('signInEmail')), email);
        await tester.enterText(
          find.byKey(const Key('signInPassword')),
          password,
        );
        await tap(tester, 'signInSubmit');
        await waitFor(tester, find.byKey(const Key('manageParentPin')));
        expect(find.textContaining('Date of birth'), findsNothing);
        expect(api.gateSession!.hasParentProof, isFalse);
        await tap(tester, 'manageParentPin');
        await waitFor(tester, find.byKey(const Key('gatePin')));
        String? acceptedPin;
        for (var attempt = 0; attempt < 3; attempt++) {
          final candidate = random.nextInt(1000000).toString().padLeft(6, '0');
          await tester.enterText(
            find.byKey(const Key('gatePassword')),
            password,
          );
          await tester.enterText(find.byKey(const Key('gatePin')), candidate);
          await tester.enterText(
            find.byKey(const Key('gatePinConfirmation')),
            candidate,
          );
          await tap(tester, 'gateSubmit');
          await tester.pumpAndSettle();
          if (find.byKey(const Key('openParentArea')).evaluate().isNotEmpty) {
            acceptedPin = candidate;
            break;
          }
          expect(find.textContaining('PIN_TOO_WEAK'), findsOneWidget);
        }
        expect(acceptedPin, isNotNull);
        final pin = acceptedPin!;
        await tap(tester, 'openParentArea');
        await livePin(tester, pin);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gated-child-${children.first.id}');
        await waitFor(tester, find.byKey(const Key('protectedChildDob')));
        await tap(tester, 'gatedParentHome');
        await tap(tester, 'parent-child-${children.first.id}');
        await tap(tester, 'parentEnterLearning');
        await livePin(tester, pin);
        await waitFor(tester, find.byType(ChildHome));
        final oldChildToken = api.gateSession!.current!.token;
        await expectRawDenial(
          uri,
          'children/${children.first.id}',
          oldChildToken,
          403,
          'CHILD_CONTEXT_FORBIDDEN',
        );
        expect(find.byKey(const Key('protectedChildDob')), findsNothing);
        expect(find.byKey(const Key('manageParentPin')), findsNothing);
        final catalog = await api.curriculum(children.first.id);
        final lesson = catalog.domains
            .expand((d) => d.topics)
            .expand((t) => t.lessons)
            .singleWhere((l) => l.lessonCode == 'SYN-MATH-001');
        await tap(tester, 'openCurriculum');
        await waitFor(tester, find.byKey(const Key('domain-MATH')));
        await tap(tester, 'domain-MATH');
        await tap(tester, 'topic-${lesson.topicCode}');
        await tap(tester, 'explorer-lesson-${lesson.lessonId}');
        await waitFor(tester, find.byKey(const Key('startLearning')));
        await tap(tester, 'startLearning');
        final cues = api.detail!.cues.toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
        for (final cue in cues) {
          await waitFor(
            tester,
            find.byKey(Key('option-${cue.options.first.optionId}')),
          );
          await tap(tester, 'option-${cue.options.first.optionId}');
          await tap(tester, 'submit-${cue.cueId}');
          await waitFor(tester, find.byKey(Key('feedback-${cue.cueId}')));
        }
        await tap(tester, 'completeLearning');
        await waitFor(tester, find.byKey(const Key('completionConfirmed')));
        final completed = api.completed!;
        expect(completed.endedAt, isNotNull);
        await tap(tester, 'replayLearning');
        await waitFor(tester, find.text('Session: IN_PROGRESS'));
        expect(api.readback!.sessionId, isNot(completed.sessionId));
        expect(
          (await api.learningSession(
            children.first.id,
            completed.sessionId,
          )).endedAt,
          completed.endedAt,
        );
        await tap(tester, 'lessonHome');
        await tap(tester, 'childSwitchGate');
        await livePin(tester, pin);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gatedParentHome');
        await tap(tester, 'parent-child-${children.last.id}');
        await tap(tester, 'parentEnterLearning');
        await livePin(tester, pin);
        await waitFor(tester, find.byType(ChildHome));
        expect(api.gateSession!.current!.childId, children.last.id);
        await expectRawDenial(
          uri,
          'children/${children.first.id}/curriculum',
          oldChildToken,
          401,
          'SESSION_REVOKED',
        );
        await tap(tester, 'childParentGate');
        await livePin(tester, pin);
        await waitFor(tester, find.byType(GatedParentArea));
        await tap(tester, 'gated-child-${children.first.id}');
        await waitFor(tester, find.byKey(const Key('protectedChildDob')));
        await api.gateSession!.refresh();
        expect(api.gateSession!.current!.mode, SessionMode.parent);
        await other.login(email: email, password: password);
        expect(
          other.gateSession!.current!.sessionId,
          isNot(api.gateSession!.current!.sessionId),
        );
        await other.revokeOtherDevices();
        await tap(tester, 'loadParentActivity');
        await waitFor(tester, find.byKey(const Key('welcomeSignIn')));
        expect(find.byKey(const Key('protectedChildDob')), findsNothing);
        expect(await vault.read(), isNull);
        debugPrint(
          'PARENT GATE ANDROID LIVE PASS: real PIN enrollment and Parent Area; child-context learning completion/replay; PIN switch/exit; stale token denial; separate-device revocation; protected data hidden after invalidation. No mocked authorization or schema activation.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        try {
          await api.gateSession!.logout();
        } catch (_) {}
        try {
          await other.gateSession!.logout();
        } catch (_) {}
        api.gateSession!.dispose();
        other.gateSession!.dispose();
        await vault.clear();
      }
    },
  );
}
