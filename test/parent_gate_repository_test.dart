import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/parent_gate_api.dart';

import 'learning_api_test.dart' show Transport, Reply;
import 'learning_test_data.dart' as lesson;
import 'parent_gate_session_test.dart'
    show MemoryVault, sessionLogin, proofJson;
import 'parent_gate_test_backend.dart';

Future<LiveMimiGoApi> gateClient(
  GateTestBackend backend, {
  MemoryVault? vault,
}) async {
  final api = LiveMimiGoApi(
    Uri.parse('http://unit.invalid/api/v1'),
    client: backend,
    parentGateEnabled: true,
    vault: vault ?? MemoryVault(),
  );
  await api.login(email: 'synthetic@example.test', password: syntheticPassword);
  return api;
}

void main() {
  test(
    'mismatched Parent session metadata destroys the unvalidated local session',
    () async {
      final transport = Transport()
        ..replies.addAll([
          Reply(sessionLogin()),
          Reply({
            'parentId': 'other-parent',
            'email': 'synthetic@example.test',
            'displayName': 'SYN Parent',
            'currentTermsAccepted': true,
            'parentGate': {'status': 'ENROLLED'},
            'session': {
              'sessionId': 'foreign-session',
              'sessionMode': 'PARENT',
            },
          }),
        ]);
      final vault = MemoryVault();
      final api = LiveMimiGoApi(
        Uri.parse('http://unit.invalid/api/v1'),
        client: transport,
        parentGateEnabled: true,
        vault: vault,
      );
      addTearDown(() => api.gateSession!.dispose());
      await api.login(
        email: 'synthetic@example.test',
        password: syntheticPassword,
      );
      await expectLater(api.parentMe(), throwsA(isA<ApiInvalidResponse>()));
      expect(api.gateSession!.current, isNull);
      expect(vault.stored, isNull);
    },
  );
  for (final mutation in [
    'two-tokens',
    'missing-child',
    'same-refresh',
    'expired-access',
  ]) {
    test(
      'malformed refresh $mutation never publishes credentials or retries the old family',
      () async {
        final response = <String, dynamic>{
          'refreshToken': 'rotation-1',
          'refreshExpiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'sessionMode': 'PARENT',
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'accessToken': 'parent-new',
        };
        switch (mutation) {
          case 'two-tokens':
            response['childContextToken'] = 'unexpected-child';
          case 'missing-child':
            response['sessionMode'] = 'CHILD';
            response.remove('accessToken');
            response['childContextToken'] = 'child';
          case 'same-refresh':
            response['refreshToken'] = 'rotation-0';
          case 'expired-access':
            response['expiresAt'] = '2000-01-01T00:00:00Z';
        }
        final transport = Transport()
          ..replies.addAll([Reply(sessionLogin()), Reply(response)]);
        final vault = MemoryVault();
        final api = LiveMimiGoApi(
          Uri.parse('http://unit.invalid/api/v1'),
          client: transport,
          parentGateEnabled: true,
          vault: vault,
        );
        addTearDown(() => api.gateSession!.dispose());
        await api.login(
          email: 'synthetic@example.test',
          password: syntheticPassword,
        );
        await expectLater(
          api.gateSession!.refresh(),
          throwsA(isA<ApiFailure>()),
        );
        expect(api.gateSession!.current, isNull);
        expect(vault.stored, isNull);
        expect(transport.requests, hasLength(2));
      },
    );
  }
  test('module-on basic roster/workspace never require DOB age or creation timestamp', () async {
    final backend = GateTestBackend();
    final api = await gateClient(backend);
    addTearDown(() => api.gateSession!.dispose());
    final children = await api.listChildren();
    final workspace = await api.learningWorkspace();
    expect(children, hasLength(2));
    expect(workspace.children, hasLength(2));
    for (final child in children) {
      expect(child.dateOfBirth, isNull);
      expect(child.ageYears, isNull);
      expect(child.createdAt, isNull);
      expect(child.stockAvatarKey, 'bear-blue');
    }
    await expectLater(
      api.getChild('child-A'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'PARENT_GATE_REQUIRED'),
      ),
    );
    expect(
      backend.requests.where((r) => r.uri.path.endsWith('/child-A')),
      isEmpty,
    );
  });
  test('Parent Area detail/history use only header proof; no query or persisted proof', () async {
    final backend = GateTestBackend()..enrolled = true;
    final vault = MemoryVault();
    final api = await gateClient(backend, vault: vault);
    addTearDown(() => api.gateSession!.dispose());
    await api.verifyParentArea(syntheticPin);
    final detail = await api.getChild('child-A');
    expect(detail.dateOfBirth, DateTime(2023, 1, 1));
    expect(await api.parentActivity('child-A'), isEmpty);
    final protected = backend.requests.where(
      (r) =>
          r.uri.path == '/api/v1/children/child-A' ||
          r.uri.path == '/api/v1/children/child-A/learning-sessions',
    );
    expect(protected, hasLength(2));
    for (final request in protected) {
      expect(request.headers.value('mimigo-parent-proof'), backend.parentProof);
      expect(request.uri.query, isEmpty);
      expect(request.body, isEmpty);
    }
    expect(vault.stored, isNot(contains(backend.parentProof)));
    backend.expiredProof = true;
    await expectLater(
      api.getChild('child-A'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'PARENT_GATE_REQUIRED'),
      ),
    );
    expect(api.gateSession!.hasParentProof, isFalse);
  });
  test('204 enroll/change and 200 reset contracts with required password action remain exact', () async {
    final backend = GateTestBackend();
    final api = await gateClient(backend);
    addTearDown(() => api.gateSession!.dispose());
    await api.setParentPin(
      PinAction.enroll,
      syntheticPassword,
      syntheticPin,
      syntheticPin,
    );
    await api.setParentPin(
      PinAction.change,
      syntheticPassword,
      '395184',
      '395184',
    );
    await api.setParentPin(
      PinAction.reset,
      syntheticPassword,
      syntheticPin,
      syntheticPin,
    );
    final actions = backend.requests
        .where((r) => r.uri.path.endsWith('/step-up'))
        .map((r) => (jsonDecode(r.body) as Map)['action'])
        .toList();
    expect(actions, ['PIN_ENROLL', 'PIN_CHANGE', 'PIN_RESET']);
    expect(
      backend.requests
          .singleWhere((r) => r.uri.path.endsWith('/parent-gate/pin'))
          .method,
      'PUT',
    );
    expect(
      jsonDecode(
        backend.requests
            .singleWhere((r) => r.uri.path.endsWith('/parent-gate/reset'))
            .body,
      ),
      {'newPin': syntheticPin, 'newPinConfirmation': syntheticPin},
    );
    expect(api.gateSession!.hasParentProof, isFalse);
  });
  test('all seven learning operations use only the active child token and no Parent Proof', () async {
    final backend = GateTestBackend()..enrolled = true;
    final api = await gateClient(backend);
    addTearDown(() => api.gateSession!.dispose());
    await expectLater(
      api.lessons('child-A'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'CHILD_CONTEXT_REQUIRED',
        ),
      ),
    );
    await api.switchChildContext(syntheticPin, 'child-A');
    final token = api.gateSession!.current!.token;
    await api.curriculum('child-A');
    await api.lessons('child-A');
    await api.lesson('child-A', lesson.lessonId);
    final started = await api.startLearning('child-A', lesson.lessonId);
    await api.learningSession('child-A', started.sessionId);
    await api.submitAnswer(
      'child-A',
      started.sessionId,
      const AnswerRequest(
        clientEventId: lesson.eventId,
        cueId: lesson.cueId,
        optionId: lesson.optionId,
      ),
    );
    final completed = await api.completeLearning('child-A', started.sessionId);
    expect(completed.state, 'COMPLETED');
    expect(completed.endedAt, isNotNull);
    final requests = backend.requests.where(
      (r) => r.uri.path.contains('/children/child-A/'),
    );
    expect(requests, hasLength(7));
    for (final request in requests) {
      expect(request.headers.value('authorization'), 'Bearer $token');
      expect(request.headers.value('mimigo-parent-proof'), isNull);
    }
    final replay = await api.startLearning('child-A', lesson.lessonId);
    expect(replay.sessionId, isNot(completed.sessionId));
    expect(
      (await api.learningSession('child-A', completed.sessionId)).endedAt,
      completed.endedAt,
    );
  });
  test('Child token cannot request Parent data, mutate PIN or learn for another child', () async {
    final backend = GateTestBackend()..enrolled = true;
    final api = await gateClient(backend);
    addTearDown(() => api.gateSession!.dispose());
    await api.switchChildContext(syntheticPin, 'child-A');
    final before = backend.requests.length;
    for (final request in <Future<Object?> Function()>[
      api.parentMe,
      api.listChildren,
      api.learningWorkspace,
      () => api.getChild('child-A'),
      () => api.parentActivity('child-A'),
      () => api.setParentPin(
        PinAction.reset,
        syntheticPassword,
        syntheticPin,
        syntheticPin,
      ),
    ]) {
      await expectLater(
        request(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'CHILD_CONTEXT_FORBIDDEN',
          ),
        ),
      );
    }
    await expectLater(
      api.lessons('child-B'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'CHILD_NOT_FOUND'),
      ),
    );
    expect(
      backend.requests.length,
      before,
      reason: 'Wrong-scope credentials never go on the wire.',
    );
  });
  test(
    'lock Retry-After is propagated without exposing server message/counts',
    () async {
      final backend = GateTestBackend()
        ..enrolled = true
        ..forcedPinError = {'code': 'PARENT_GATE_LOCKED', 'status': 423}
        ..forcedPinRetry = 8;
      final api = await gateClient(backend);
      addTearDown(() => api.gateSession!.dispose());
      await expectLater(
        api.verifyParentArea(syntheticPin),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.retryAfterSeconds,
            'Retry-After',
            8,
          ),
        ),
      );
      expect(api.gateSession!.hasParentProof, isFalse);
    },
  );
  test(
    'revocation on protected route refreshes once then ends local session',
    () async {
      final backend = GateTestBackend()..enrolled = true;
      final api = await gateClient(backend);
      addTearDown(() => api.gateSession!.dispose());
      await api.verifyParentArea(syntheticPin);
      backend.revoked = true;
      await expectLater(api.getChild('child-A'), throwsA(isA<ApiFailure>()));
      expect(api.gateSession!.current, isNull);
      expect(
        backend.requests.where((r) => r.uri.path.endsWith('/sessions/refresh')),
        hasLength(1),
      );
    },
  );
  test('fresh authenticated session receives Parent Gate status but login never grants proof', () async {
    final backend = GateTestBackend();
    final api = await gateClient(backend);
    addTearDown(() => api.gateSession!.dispose());
    final parent = await api.parentMe();
    expect(parent.parentGate!.status, 'NOT_ENROLLED');
    expect(api.gateSession!.hasParentProof, isFalse);
  });
  test(
    'gate opt-in refuses a legacy login response rather than falling back',
    () async {
      final transport = Transport()
        ..replies.add(
          Reply({
            'accessToken': 'legacy',
            'tokenType': 'Bearer',
            'expiresAt': '2030-01-01T00:00:00Z',
            'parentId': 'synthetic-parent',
          }),
        );
      final api = LiveMimiGoApi(
        Uri.parse('http://unit.invalid/api/v1'),
        client: transport,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      addTearDown(() => api.gateSession!.dispose());
      await expectLater(
        api.login(email: 'synthetic@example.test', password: syntheticPassword),
        throwsA(isA<ApiInvalidResponse>()),
      );
      expect(api.gateSession!.current, isNull);
    },
  );
  test(
    'unexpected PIN proof/token mode cannot publish Parent authorization',
    () async {
      final transport = Transport()
        ..replies.addAll([
          Reply(sessionLogin()),
          Reply({...proofJson('PARENT_AREA', mode: 'CHILD')}),
        ]);
      final api = LiveMimiGoApi(
        Uri.parse('http://unit.invalid/api/v1'),
        client: transport,
        parentGateEnabled: true,
        vault: MemoryVault(),
      );
      addTearDown(() => api.gateSession!.dispose());
      await api.login(
        email: 'synthetic@example.test',
        password: syntheticPassword,
      );
      await expectLater(
        api.verifyParentArea(syntheticPin),
        throwsA(isA<ApiInvalidResponse>()),
      );
      expect(api.gateSession!.hasParentProof, isFalse);
    },
  );
}
