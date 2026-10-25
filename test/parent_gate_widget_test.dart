import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_gate_api.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';

import 'learning_widget_test.dart' show tapVisible;
import 'parent_gate_test_backend.dart';
import 'parent_gate_repository_test.dart' show gateClient;
import 'parent_gate_session_test.dart' show MemoryVault, proofJson;

final trackedGateApis = <LiveMimiGoApi>[];
void gateWidgets(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        for (final api in trackedGateApis) {
          api.gateSession!.dispose();
        }
        trackedGateApis.clear();
      }
    });

class TestScreenSecurity extends GateScreenSecurity {
  bool fail = false;
  Completer<void>? wait;
  @override
  Future<void> protect() async {
    if (fail) throw PlatformException(code: 'unavailable');
    await wait?.future;
  }

  @override
  Future<void> release() async {}
}

class GateWidgetApp {
  GateWidgetApp(this.backend, this.api, this.vault);
  final GateTestBackend backend;
  final LiveMimiGoApi api;
  final MemoryVault vault;
}

Future<GateWidgetApp> openGateApp(
  WidgetTester tester, {
  bool enrolled = false,
  GateTestBackend? backendOverride,
}) async {
  final backend = backendOverride ?? (GateTestBackend()..enrolled = enrolled);
  final vault = MemoryVault();
  final api = LiveMimiGoApi(
    Uri.parse('http://unit.invalid/api/v1'),
    client: backend,
    parentGateEnabled: true,
    vault: vault,
  );
  trackedGateApis.add(api);
  await tester.pumpWidget(
    MimiGoApp(
      api: api,
      configuration: const ApiConfiguration(
        ApiMode.live,
        'unused',
        parentGateEnabled: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tapVisible(tester, 'welcomeSignIn');
  await tester.enterText(
    find.byKey(const Key('signInEmail')),
    'synthetic@example.test',
  );
  await tester.enterText(
    find.byKey(const Key('signInPassword')),
    syntheticPassword,
  );
  await tapVisible(tester, 'signInSubmit');
  return GateWidgetApp(backend, api, vault);
}

Future<void> fillGatePin(
  WidgetTester tester, {
  String pin = syntheticPin,
}) async {
  await tester.enterText(find.byKey(const Key('gatePin')), pin);
  await tapVisible(tester, 'gateSubmit');
}

void main() {
  gateWidgets(
    'failed history reload removes the previous result and permits retry',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      await tapVisible(tester, 'openParentArea');
      await fillGatePin(tester);
      await tapVisible(tester, 'gated-child-child-A');
      await tapVisible(tester, 'loadParentActivity');
      expect(find.text('No sessions returned.'), findsOneWidget);
      app.backend.forcedActivityError = {
        'code': 'SERVICE_UNAVAILABLE',
        'status': 503,
      };
      await tapVisible(tester, 'loadParentActivity');
      expect(find.text('No sessions returned.'), findsNothing);
      expect(find.textContaining('SERVICE_UNAVAILABLE'), findsOneWidget);
      app.backend.forcedActivityError = null;
      await tapVisible(tester, 'loadParentActivity');
      expect(find.text('No sessions returned.'), findsOneWidget);
      expect(app.api.gateSession!.hasParentProof, isTrue);
    },
  );

  gateWidgets(
    'protected roster failure retries without an empty-account claim or PIN bypass',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      app.backend.forcedRosterError = {
        'code': 'SERVICE_UNAVAILABLE',
        'status': 503,
      };
      await tapVisible(tester, 'openParentArea');
      await fillGatePin(tester);
      expect(find.byType(GatedParentArea), findsOneWidget);
      expect(find.text('No child profiles returned.'), findsNothing);
      expect(find.byKey(const Key('gated-child-child-A')), findsNothing);
      expect(find.textContaining('PRIVATE_SERVER_DETAIL'), findsNothing);
      expect(app.api.gateSession!.hasParentProof, isTrue);
      app.backend.forcedRosterError = null;
      await tapVisible(tester, 'gatedRefresh');
      expect(find.byKey(const Key('gated-child-child-A')), findsOneWidget);
      await tapVisible(tester, 'gated-child-child-A');
      expect(find.byKey(const Key('protectedChildDob')), findsOneWidget);
      await tapVisible(tester, 'gatedRefresh');
      expect(find.byKey(const Key('protectedChildDob')), findsNothing);
    },
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('mimigo/security'),
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('mimigo/security'), null);
  });

  gateWidgets(
    'account login lock uses Retry-After without private messages or another attempt',
    (tester) async {
      final app = await openGateApp(
        tester,
        backendOverride: GateTestBackend()
          ..forcedLoginError = {'code': 'ACCOUNT_LOGIN_LOCKED', 'status': 423}
          ..forcedLoginRetry = 8,
      );
      expect(find.textContaining('ACCOUNT_LOGIN_LOCKED'), findsOneWidget);
      expect(find.byKey(const Key('loginRetryAfter')), findsOneWidget);
      expect(find.textContaining('PRIVATE_SERVER_DETAIL'), findsNothing);
      expect(find.textContaining('remaining'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('signInSubmit')))
            .onPressed,
        isNull,
      );
      expect(
        app.backend.requests.where((r) => r.uri.path.endsWith('/login')),
        hasLength(1),
      );
      expect(app.api.gateSession!.hasSession, isFalse);
    },
  );
  gateWidgets(
    'rapid verification taps cannot submit twice or expose the PIN in feedback',
    (tester) async {
      final backend = GateTestBackend()..enrolled = true;
      final api = await gateClient(backend);
      trackedGateApis.add(api);
      final done = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePinScreen(
              api: api,
              security: TestScreenSecurity(),
              done: () => done.future,
              back: () {},
              accountEntry: () {},
              recover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
      await tester.ensureVisible(find.byKey(const Key('gateSubmit')));
      await tester.tap(find.byKey(const Key('gateSubmit')));
      await tester.tap(find.byKey(const Key('gateSubmit')));
      await tester.pump();
      expect(
        backend.requests.where((r) => r.uri.path.endsWith('/verifications')),
        hasLength(1),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('gatePin')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text(syntheticPin), findsNothing);
      done.complete();
      await tester.pumpAndSettle();
    },
  );

  gateWidgets(
    'PIN proof expiry hides protected data without requiring another API call',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      await tapVisible(tester, 'openParentArea');
      await fillGatePin(tester);
      await tapVisible(tester, 'gated-child-child-A');
      expect(find.byKey(const Key('protectedChildDob')), findsOneWidget);
      final json = {
        ...proofJson('PARENT_AREA'),
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 2))
            .toIso8601String(),
      };
      app.api.gateSession!.retainParentProof(
        GateProof.fromJson(json, action: 'PARENT_AREA', kind: 'GATE'),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(app.api.gateSession!.hasParentProof, isFalse);
      expect(find.byKey(const Key('protectedChildDob')), findsNothing);
    },
  );

  gateWidgets('six-digit form remains usable on a narrow large-text screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = GateTestBackend()..enrolled = true;
    final api = await gateClient(backend);
    trackedGateApis.add(api);
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: GatePinScreen(
            api: api,
            security: TestScreenSecurity(),
            done: () async {
              done++;
            },
            back: () {},
            accountEntry: () {},
            recover: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillGatePin(tester);
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  gateWidgets(
    'PIN inputs wait for native protection and stay unavailable if it fails',
    (tester) async {
      final api = await gateClient(GateTestBackend()..enrolled = true);
      trackedGateApis.add(api);
      final shield = TestScreenSecurity()..wait = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePinScreen(
              api: api,
              security: shield,
              done: () async {},
              back: () {},
              accountEntry: () {},
              recover: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('gatePin')), findsNothing);
      shield.wait!.completeError(PlatformException(code: 'blocked'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gatePin')), findsNothing);
      expect(
        find.textContaining('SCREEN_PROTECTION_UNAVAILABLE'),
        findsOneWidget,
      );
    },
  );

  gateWidgets(
    'enrollment requires password and matching six digits, clears fields and does not issue Parent proof',
    (tester) async {
      final backend = GateTestBackend();
      final api = await gateClient(backend);
      trackedGateApis.add(api);
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePinScreen(
              api: api,
              security: TestScreenSecurity(),
              pinAction: PinAction.enroll,
              done: () async {
                done++;
              },
              back: () {},
              accountEntry: () {},
              recover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('gatePassword')),
        syntheticPassword,
      );
      await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
      await tester.enterText(
        find.byKey(const Key('gatePinConfirmation')),
        '395184',
      );
      await tapVisible(tester, 'gateSubmit');
      expect(find.textContaining('PIN_CONFIRMATION_MISMATCH'), findsOneWidget);
      expect(
        backend.requests.where((r) => r.uri.path.endsWith('/step-up')),
        isEmpty,
      );
      await tester.enterText(find.byKey(const Key('gatePin')), '123456');
      await tester.enterText(
        find.byKey(const Key('gatePinConfirmation')),
        '123456',
      );
      await tapVisible(tester, 'gateSubmit');
      expect(find.textContaining('PIN_TOO_WEAK'), findsOneWidget);
      expect(find.textContaining('PRIVATE_SERVER_DETAIL'), findsNothing);
      expect(done, 0);
      for (final key in ['gatePassword', 'gatePin', 'gatePinConfirmation']) {
        expect(
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text,
          isEmpty,
        );
      }
      await tester.enterText(
        find.byKey(const Key('gatePassword')),
        syntheticPassword,
      );
      await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
      await tester.enterText(
        find.byKey(const Key('gatePinConfirmation')),
        syntheticPin,
      );
      await tapVisible(tester, 'gateSubmit');
      expect(done, 1);
      expect(backend.enrolled, isTrue);
      expect(api.gateSession!.hasParentProof, isFalse);
    },
  );

  gateWidgets(
    'temporary lock honors Retry-After, has no remaining-attempt count and never auto-submits',
    (tester) async {
      final backend = GateTestBackend()
        ..enrolled = true
        ..forcedPinError = {'code': 'PARENT_GATE_LOCKED', 'status': 423}
        ..forcedPinRetry = 3;
      final api = await gateClient(backend);
      trackedGateApis.add(api);
      var now = DateTime.now();
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePinScreen(
              api: api,
              security: TestScreenSecurity(),
              clock: () => now,
              done: () async {
                done++;
              },
              back: () {},
              accountEntry: () {},
              recover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillGatePin(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('gateSubmit')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('remaining'), findsNothing);
      expect(find.textContaining('Try again in 3 seconds'), findsOneWidget);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(done, 0);
      expect(
        backend.requests.where((r) => r.uri.path.endsWith('/verifications')),
        hasLength(1),
      );
      backend.forcedPinError = null;
      await fillGatePin(tester);
      expect(done, 1);
    },
  );

  gateWidgets(
    'recovery-required in Child Mode offers logout, never password step-up or PIN reset',
    (tester) async {
      final backend = GateTestBackend()..enrolled = true;
      final api = await gateClient(backend);
      trackedGateApis.add(api);
      await api.switchChildContext(syntheticPin, 'child-A');
      backend.forcedPinError = {
        'code': 'PARENT_GATE_RECOVERY_REQUIRED',
        'status': 423,
      };
      var recovery = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePinScreen(
              api: api,
              security: TestScreenSecurity(),
              done: () async {},
              back: () {},
              accountEntry: () {},
              recover: () {
                recovery++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillGatePin(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('gateSubmit')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('gatePassword')), findsNothing);
      expect(
        find.textContaining('Forgot PIN? Sign out and sign in'),
        findsOneWidget,
      );
      await tapVisible(tester, 'gateRecover');
      expect(recovery, 1);
      expect(
        backend.requests.where((r) => r.uri.path.endsWith('/step-up')),
        isEmpty,
      );
    },
  );

  gateWidgets(
    'Parent Home uses public roster without protected requests, DOB, age or null placeholders',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      expect(find.text('Parent Home'), findsOneWidget);
      expect(find.textContaining('Age returned'), findsNothing);
      expect(find.textContaining('Date of birth'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      await tapVisible(tester, 'parent-child-child-A');
      expect(
        app.backend.requests.where(
          (r) => r.uri.path == '/api/v1/children/child-A',
        ),
        isEmpty,
      );
      await tapVisible(tester, 'parentEnterLearning');
      expect(find.byType(GatePinScreen), findsOneWidget);
      expect(find.byType(ChildHome), findsNothing);
    },
  );

  gateWidgets(
    'complete PIN enrollment and Parent Area access reveal detail only after proof; background hides it',
    (tester) async {
      final app = await openGateApp(tester);
      await tapVisible(tester, 'manageParentPin');
      await tester.enterText(
        find.byKey(const Key('gatePassword')),
        syntheticPassword,
      );
      await tester.enterText(find.byKey(const Key('gatePin')), syntheticPin);
      await tester.enterText(
        find.byKey(const Key('gatePinConfirmation')),
        syntheticPin,
      );
      await tapVisible(tester, 'gateSubmit');
      expect(find.text('Parent Home'), findsOneWidget);
      expect(app.api.gateSession!.hasParentProof, isFalse);
      await tapVisible(tester, 'openParentArea');
      await fillGatePin(tester);
      expect(find.byType(GatedParentArea), findsOneWidget);
      await tapVisible(tester, 'gated-child-child-A');
      expect(find.byKey(const Key('protectedChildDob')), findsOneWidget);
      await tapVisible(tester, 'loadParentActivity');
      expect(find.text('No sessions returned.'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(app.api.gateSession!.hasParentProof, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('protectedChildDob')), findsNothing);
      expect(find.byType(GatedParentArea), findsNothing);
    },
  );

  gateWidgets(
    'permission denial removes previously visible protected details',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      await tapVisible(tester, 'openParentArea');
      await fillGatePin(tester);
      await tapVisible(tester, 'gated-child-child-A');
      expect(find.byKey(const Key('protectedChildDob')), findsOneWidget);
      app.backend.forcedActivityError = {
        'code': 'PERMISSION_NOT_GRANTED',
        'status': 403,
      };
      await tapVisible(tester, 'loadParentActivity');
      expect(app.api.gateSession!.hasParentProof, isFalse);
      expect(app.api.gateSession!.current!.mode, SessionMode.parent);
      expect(find.byType(GatedParentArea), findsNothing);
      expect(find.byKey(const Key('protectedChildDob')), findsNothing);
      expect(find.byKey(const Key('openParentArea')), findsOneWidget);
    },
  );
  gateWidgets(
    'Child Mode, switch and exit require actual token transitions; no Parent data appears before PIN',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      await tapVisible(tester, 'parent-child-child-A');
      await tapVisible(tester, 'parentEnterLearning');
      await fillGatePin(tester);
      expect(find.text('Hi, SYN-child-A!'), findsOneWidget);
      expect(app.api.gateSession!.current!.mode, SessionMode.child);
      expect(find.byKey(const Key('protectedChildDob')), findsNothing);
      expect(find.text('SYN-child-B'), findsNothing);
      await tapVisible(tester, 'childSwitchGate');
      expect(find.byType(GatePinScreen), findsOneWidget);
      expect(find.text('SYN-child-B'), findsNothing);
      await fillGatePin(tester);
      expect(app.api.gateSession!.current!.mode, SessionMode.parent);
      expect(find.byType(GatedParentArea), findsOneWidget);
      await tapVisible(tester, 'gatedParentHome');
      await tapVisible(tester, 'parent-child-child-B');
      await tapVisible(tester, 'parentEnterLearning');
      await fillGatePin(tester);
      expect(find.text('Hi, SYN-child-B!'), findsOneWidget);
      expect(app.api.gateSession!.current!.childId, 'child-B');
      await tapVisible(tester, 'childParentGate');
      await fillGatePin(tester);
      expect(find.byType(GatedParentArea), findsOneWidget);
      expect(app.api.gateSession!.current!.childId, isNull);
    },
  );

  gateWidgets(
    'revoked Child session refresh failure removes all protected app state and returns to login',
    (tester) async {
      final app = await openGateApp(tester, enrolled: true);
      await tapVisible(tester, 'parent-child-child-A');
      await tapVisible(tester, 'parentEnterLearning');
      await fillGatePin(tester);
      app.backend.revoked = true;
      await tapVisible(tester, 'openCurriculum');
      expect(find.byKey(const Key('welcomeSignIn')), findsOneWidget);
      expect(find.byType(ParentArea), findsNothing);
      expect(find.byType(ChildHome), findsNothing);
      expect(app.vault.stored, isNull);
    },
  );

  gateWidgets(
    'restored Child session uses only child token and a generic label without persisted profile data',
    (tester) async {
      final backend = GateTestBackend()..enrolled = true;
      final vault = MemoryVault();
      final original = await gateClient(backend, vault: vault);
      await original.switchChildContext(syntheticPin, 'child-B');
      original.gateSession!.dispose();
      final api = LiveMimiGoApi(
        Uri.parse('http://unit.invalid/api/v1'),
        client: backend,
        parentGateEnabled: true,
        vault: vault,
      );
      trackedGateApis.add(api);
      final before = backend.requests.length;
      await tester.pumpWidget(MimiGoApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back to Child Mode!'), findsOneWidget);
      expect(find.text('SYN-child-B'), findsNothing);
      expect(backend.requests.skip(before).map((r) => r.uri.path), [
        '/api/v1/auth/sessions/refresh',
      ]);
      await tapVisible(tester, 'openCurriculum');
      expect(
        backend.requests.last.uri.path,
        '/api/v1/children/child-B/curriculum',
      );
      expect(
        backend.requests.last.headers.value('authorization'),
        'Bearer ${api.gateSession!.current!.token}',
      );
    },
  );
}
