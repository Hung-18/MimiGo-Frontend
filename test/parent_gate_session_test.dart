import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/api_failure.dart';
import 'package:mimigo_frontend/parent_gate_session.dart';
import 'package:mimigo_frontend/parent_gate_api.dart';

class MemoryVault implements CredentialVault {
  String? stored;
  bool failWrite = false;
  final writes = <String>[];
  @override
  Future<String?> read() async => stored;
  @override
  Future<void> clear() async {
    stored = null;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('test storage failure');
    stored = value;
    writes.add(value);
  }
}

Map<String, dynamic> sessionLogin({String sessionId = 'session-A'}) => {
  'accessToken': 'parent-access',
  'tokenType': 'Bearer',
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 5))
      .toUtc()
      .toIso8601String(),
  'parentId': 'synthetic-parent',
  'sessionId': sessionId,
  'sessionMode': 'PARENT',
  'refreshToken': 'rotation-0',
  'refreshExpiresAt': DateTime.now()
      .add(const Duration(hours: 1))
      .toUtc()
      .toIso8601String(),
};
Map<String, dynamic> proofJson(
  String action, {
  String? childId,
  String? mode,
}) => {
  'proof': List.filled(43, action == 'SWITCH_CHILD' ? 'b' : 'a').join(),
  'kind': action.startsWith('PIN_') ? 'STEP_UP' : 'GATE',
  'action': action,
  'method': action.startsWith('PIN_') ? 'PASSWORD' : 'PIN',
  'singleUse': action != 'PARENT_AREA',
  'childId': childId,
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 5))
      .toUtc()
      .toIso8601String(),
  'sessionMode': ?mode,
};

class SessionHarness {
  SessionHarness({this.clock});
  final DateTime Function()? clock;
  final vault = MemoryVault();
  late final manager = GateSessionCoordinator(send, vault, clock: clock);
  late final service = ParentGateService(manager, send);
  final calls = <(String, String, Object?, String?, String?)>[];
  int refreshes = 0;
  String mode = 'PARENT';
  String child = 'child-A';
  String sessionId = 'session-A';
  bool refreshFails = false,
      refreshLost = false,
      wrongChildProof = false,
      loseEnter = false,
      loseLeave = false;
  Completer<void>? refreshGate;
  ApiFailure? pinFailure;
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Object? body,
    String? token,
    String? proof,
    Set<int>? statuses,
  }) async {
    calls.add((method, path, body, token, proof));
    if (path == 'auth/login') return sessionLogin(sessionId: sessionId);
    if (path == 'auth/sessions/refresh') {
      refreshes++;
      if (refreshGate != null) await refreshGate!.future;
      if (refreshFails)
        throw const ApiFailure('Revoked', code: 'SESSION_REVOKED', status: 401);
      if (refreshLost) throw const ApiFailure('Lost', code: 'CONNECTIVITY');
      return {
        'refreshToken': 'rotation-$refreshes',
        'refreshExpiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'sessionMode': mode,
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        if (mode == 'PARENT') 'accessToken': 'parent-rotated-$refreshes',
        if (mode == 'CHILD') 'childContextToken': 'child-rotated-$refreshes',
        if (mode == 'CHILD') 'childId': child,
      };
    }
    if (path == 'auth/step-up')
      return proofJson((body as Map)['action'] as String);
    if (path == 'parents/me/parent-gate' ||
        path == 'parents/me/parent-gate/pin')
      return {};
    if (path == 'parents/me/parent-gate/reset')
      return {'sessionMode': 'PARENT'};
    if (path == 'parent-gate/verifications') {
      if (pinFailure != null) throw pinFailure!;
      final args = body as Map;
      if (args['action'] == 'SWITCH_CHILD')
        return proofJson(
          'SWITCH_CHILD',
          childId: wrongChildProof ? 'foreign' : args['childId'] as String,
          mode: mode,
        );
      final wasChild = mode == 'CHILD';
      mode = 'PARENT';
      if (loseLeave) throw const ApiFailure('Lost', code: 'CONNECTIVITY');
      return {
        ...proofJson('PARENT_AREA', mode: mode),
        if (wasChild) 'accessToken': 'parent-after-leave',
        if (wasChild)
          'accessTokenExpiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
      };
    }
    if (path == 'child-contexts') {
      mode = 'CHILD';
      child = (body as Map)['childId'] as String;
      if (loseEnter) throw const ApiFailure('Lost', code: 'CONNECTIVITY');
      return {
        'childContextToken': 'child-context-$child',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 15))
            .toUtc()
            .toIso8601String(),
        'childId': child,
        'sessionMode': 'CHILD',
      };
    }
    if (path == 'auth/logout') return {};
    if (path == 'auth/sessions/revoke-others') return {'revokedCount': 2};
    return {};
  }

  Future<void> login() =>
      manager.login('synthetic@example.test', 'synthetic-password');
  void dispose() => manager.dispose();
}

void main() {
  test('login persists only refresh metadata, never access tokens, PINs, passwords or proofs', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await h.service.parentArea('284739');
    final json = jsonDecode(h.vault.stored!) as Map;
    expect(json.keys.toSet(), {
      'refreshToken',
      'refreshExpiresAt',
      'sessionId',
      'parentId',
      'apiScope',
    });
    for (final secret in [
      'parent-access',
      '284739',
      'synthetic-password',
      List.filled(43, 'a').join(),
    ]) {
      expect(h.vault.stored, isNot(contains(secret)));
    }
    expect(h.manager.hasParentProof, isTrue);
  });
  test(
    'refresh credentials cannot be restored against a different configured API',
    () async {
      final h = SessionHarness();
      addTearDown(h.dispose);
      await h.login();
      final other = GateSessionCoordinator(
        h.send,
        h.vault,
        credentialScope: 'other-api',
      );
      addTearDown(other.dispose);
      await other.restore();
      expect(other.current, isNull);
      expect(h.refreshes, 0);
      expect(h.vault.stored, isNull);
    },
  );
  test('twenty concurrent refreshes present one credential once and share the rotation', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    h.refreshGate = Completer<void>();
    final pending = List.generate(20, (_) => h.manager.refresh());
    await Future<void>.delayed(Duration.zero);
    expect(h.refreshes, 1);
    expect(
      h.vault.stored,
      isNull,
      reason: 'Old durable refresh is removed before it is presented.',
    );
    h.refreshGate!.complete();
    await Future.wait(pending);
    expect(h.refreshes, 1);
    expect(h.manager.current!.refreshToken, 'rotation-1');
    expect(h.calls.where((c) => c.$2 == 'auth/sessions/refresh').single.$3, {
      'refreshToken': 'rotation-0',
    });
  });
  test('queued authorized requests near expiry do not reuse an old refresh credential', () async {
    var now = DateTime.now();
    final h = SessionHarness(clock: () => now);
    addTearDown(h.dispose);
    await h.login();
    h.manager.adoptAccess(
      'expired',
      now.add(const Duration(minutes: 1)),
      SessionMode.parent,
      null,
    );
    now = now.add(const Duration(seconds: 59));
    final tokens = await Future.wait(
      List.generate(12, (_) => h.manager.authorized((token, _) async => token)),
    );
    expect(h.refreshes, 1);
    expect(tokens.toSet(), {'parent-rotated-1'});
  });
  for (final lost in [false, true]) {
    test(
      '${lost ? 'unknown rotation response' : 'refresh reuse/revocation'} clears credentials and never retries old refresh',
      () async {
        final h = SessionHarness();
        addTearDown(h.dispose);
        await h.login();
        h.refreshFails = !lost;
        h.refreshLost = lost;
        await expectLater(
          h.manager.refresh(),
          throwsA(
            isA<ApiFailure>().having((e) => e.code, 'code', 'SESSION_REVOKED'),
          ),
        );
        expect(h.manager.current, isNull);
        expect(h.vault.stored, isNull);
        await expectLater(h.manager.refresh(), throwsA(isA<ApiFailure>()));
        expect(h.refreshes, 1);
      },
    );
  }
  test('restoring a persisted CHILD session rotates and never invents a Parent token', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    h.mode = 'CHILD';
    h.child = 'child-B';
    h.manager.invalidateMemory();
    await h.manager.restore();
    expect(h.manager.current!.mode, SessionMode.child);
    expect(h.manager.current!.childId, 'child-B');
    await expectLater(
      h.manager.authorized((_, _) async => true),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CHILD_CONTEXT_FORBIDDEN',
        ),
      ),
    );
  });
  test('secure storage write failure fails closed without a session', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    h.vault.failWrite = true;
    await expectLater(h.login(), throwsA(isA<ApiFailure>()));
    expect(h.manager.current, isNull);
    expect(h.vault.stored, isNull);
  });
  test('logout queued behind refresh revokes with the rotated active token then clears storage', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    h.refreshGate = Completer<void>();
    final refreshing = h.manager.refresh();
    final logout = h.manager.logout();
    await Future<void>.delayed(Duration.zero);
    h.refreshGate!.complete();
    await refreshing;
    await logout;
    expect(
      h.calls.where((c) => c.$2 == 'auth/logout').single.$4,
      'parent-rotated-1',
    );
    expect(h.manager.current, isNull);
    expect(h.vault.stored, isNull);
  });
  test('step-up and enroll/change/reset use exact action, header-only single-use proof and bodies', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    for (final action in PinAction.values) {
      await h.service.setPin(action, 'synthetic-password', '284739', '284739');
      final step = h.calls[h.calls.length - 2], command = h.calls.last;
      expect(step.$3, {
        'password': 'synthetic-password',
        'action': switch (action) {
          PinAction.enroll => 'PIN_ENROLL',
          PinAction.change => 'PIN_CHANGE',
          PinAction.reset => 'PIN_RESET',
        },
      });
      expect(step.$5, isNull);
      expect(command.$5, hasLength(43));
      expect(command.$2, isNot(contains(command.$5!)));
      expect(
        command.$3,
        action == PinAction.reset
            ? {'newPin': '284739', 'newPinConfirmation': '284739'}
            : {'pin': '284739', 'pinConfirmation': '284739'},
      );
      expect(command.$1, action == PinAction.change ? 'PUT' : 'POST');
      expect(h.manager.hasParentProof, isFalse);
    }
  });
  for (final pin in [
    '12345',
    '1234567',
    '１２３４５６',
    '١٢٣٤٥٦',
    '12a456',
    ' 12345',
  ]) {
    test(
      'non-ASCII-six PIN format is refused before network: length ${pin.length}',
      () async {
        final h = SessionHarness();
        addTearDown(h.dispose);
        await h.login();
        await expectLater(
          h.service.parentArea(pin),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.code,
              'code',
              'INVALID_PIN_FORMAT',
            ),
          ),
        );
        expect(
          h.calls.where((c) => c.$2 == 'parent-gate/verifications'),
          isEmpty,
        );
      },
    );
  }
  test('Parent proof protects reads, drops on background/expiry and never authorizes learning', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await expectLater(
      h.manager.authorized((_, _) async => true, proofRequired: true),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'PARENT_GATE_REQUIRED'),
      ),
    );
    await h.service.parentArea('284739');
    expect(
      await h.manager.authorized(
        (_, proof) async => proof,
        proofRequired: true,
      ),
      hasLength(43),
    );
    await expectLater(
      h.manager.authorized((_, _) async => true, childId: 'child-A'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CHILD_CONTEXT_REQUIRED',
        ),
      ),
    );
    h.manager.dropProof();
    expect(h.manager.hasParentProof, isFalse);
  });
  test('switch uses one child-bound proof and discards Parent token; old child requests are rejected', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await h.service.parentArea('284739');
    await h.service.enterChild('284739', 'child-A');
    expect(h.manager.current!.mode, SessionMode.child);
    expect(h.manager.hasParentProof, isFalse);
    expect(
      await h.manager.authorized(
        (token, proof) async => [token, proof],
        childId: 'child-A',
      ),
      ['child-context-child-A', null],
    );
    await expectLater(
      h.manager.authorized((_, _) async => true, childId: 'child-B'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 404)),
    );
    await expectLater(
      h.service.setPin(PinAction.reset, 'password', '284739', '284739'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CHILD_CONTEXT_FORBIDDEN',
        ),
      ),
    );
    await h.service.enterChild('284739', 'child-B');
    expect(h.manager.current!.childId, 'child-B');
    await expectLater(
      h.manager.authorized((_, _) async => true, childId: 'child-A'),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('foreign SWITCH proof fails before child-context command', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    h.wrongChildProof = true;
    await expectLater(
      h.service.enterChild('284739', 'child-A'),
      throwsA(isA<ApiInvalidResponse>()),
    );
    expect(h.calls.where((c) => c.$2 == 'child-contexts'), isEmpty);
    expect(h.manager.current!.mode, SessionMode.parent);
  });
  test('unknown enter outcome resolves through one refresh, never reuses the SWITCH proof', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    h.loseEnter = true;
    await h.service.enterChild('284739', 'child-A');
    expect(h.manager.current!.mode, SessionMode.child);
    expect(h.manager.current!.childId, 'child-A');
    expect(h.refreshes, 1);
    expect(h.calls.where((c) => c.$2 == 'child-contexts'), hasLength(1));
  });
  test('leaving Child Mode requires server-issued Parent token and Parent Area proof', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await h.service.enterChild('284739', 'child-A');
    await h.service.parentArea('284739');
    expect(h.manager.current!.token, 'parent-after-leave');
    expect(h.manager.current!.childId, isNull);
    expect(h.manager.hasParentProof, isTrue);
  });
  test('lost leave response refreshes authoritative Parent mode but never invents a proof', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await h.service.enterChild('284739', 'child-A');
    h.loseLeave = true;
    await expectLater(
      h.service.parentArea('284739'),
      throwsA(isA<ApiFailure>()),
    );
    expect(h.manager.current!.mode, SessionMode.parent);
    expect(h.manager.hasParentProof, isFalse);
    expect(h.refreshes, 1);
  });
  test('stale child request after server epoch moved to Parent does not replay in the wrong mode', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    await h.service.enterChild('284739', 'child-A');
    h.mode = 'PARENT';
    var sends = 0;
    await expectLater(
      h.manager.authorized((_, _) async {
        sends++;
        throw const ApiFailure('Stale', code: 'SESSION_REVOKED', status: 401);
      }, childId: 'child-A'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CHILD_CONTEXT_REQUIRED',
        ),
      ),
    );
    expect(sends, 1);
    expect(h.refreshes, 1);
    expect(h.manager.current!.mode, SessionMode.parent);
  });
  test('protected denials remove retained proof while preserving the basic Parent session', () async {
    final h = SessionHarness();
    addTearDown(h.dispose);
    await h.login();
    for (final denial in [
      const ApiFailure('Denied', code: 'PERMISSION_NOT_GRANTED', status: 403),
      const ApiFailure('Unavailable', code: 'CHILD_NOT_FOUND', status: 404),
    ]) {
      await h.service.parentArea('284739');
      await expectLater(
        h.manager.authorized((_, _) async => throw denial, proofRequired: true),
        throwsA(same(denial)),
      );
      expect(h.manager.hasParentProof, isFalse);
      expect(h.manager.current!.mode, SessionMode.parent);
    }
    expect(h.refreshes, 0);
  });
  test(
    'inactive Parent ends the local session and never retries authorization',
    () async {
      final h = SessionHarness();
      addTearDown(h.dispose);
      await h.login();
      await h.service.parentArea('284739');
      await expectLater(
        h.manager.authorized(
          (_, _) async => throw const ApiFailure(
            'Unavailable',
            code: 'PARENT_NOT_ACTIVE',
            status: 403,
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.manager.current, isNull);
      expect(h.vault.stored, isNull);
      expect(h.manager.hasParentProof, isFalse);
      expect(h.refreshes, 0);
    },
  );
  test('independent device coordinators do not overwrite each other’s active child', () async {
    final a = SessionHarness(), b = SessionHarness()..sessionId = 'session-B';
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.login();
    await b.login();
    await a.service.enterChild('284739', 'child-A');
    await b.service.enterChild('284739', 'child-B');
    expect(a.manager.current!.childId, 'child-A');
    expect(b.manager.current!.childId, 'child-B');
    expect(a.manager.current!.sessionId, isNot(b.manager.current!.sessionId));
  });
}
