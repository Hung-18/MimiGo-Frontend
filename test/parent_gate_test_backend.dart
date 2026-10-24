// Explicit test-only HTTP double. Never imported by lib/ or used as live fallback.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'learning_api_test.dart' show Headers, Reply;
import 'learning_test_data.dart' as lesson;
import 'parent_gate_session_test.dart' show proofJson, sessionLogin;

const syntheticPin = '284739';
const syntheticPassword = 'synthetic-password';

class GateRequest extends Fake implements HttpClientRequest {
  GateRequest(this.method, this.uri, this.backend);
  @override
  final String method;
  @override
  final Uri uri;
  final GateTestBackend backend;
  String body = '';
  @override
  final headers = Headers();
  @override
  void write(Object? value) {
    body += value.toString();
  }

  @override
  Future<HttpClientResponse> close() async => backend.respond(this);
}

class GateTestBackend extends Fake implements HttpClient {
  final requests = <GateRequest>[];
  bool enrolled = false,
      revoked = false,
      expiredProof = false,
      weakNext = false;
  String pin = syntheticPin, mode = 'PARENT', token = 'parent-access';
  String? activeChild;
  int rotations = 0, contexts = 0;
  String? switchTarget;
  Map<String, dynamic>? forcedPinError;
  Map<String, dynamic>? forcedLoginError;
  Map<String, dynamic>? forcedActivityError;
  int? forcedLoginRetry;
  int? forcedPinRetry;
  final sessions = <String, Map<String, dynamic>>{};
  final activeSessions = <String, String>{};
  int nextSession = 1;
  String get parentProof => List.filled(43, 'a').join();
  String get switchProof => List.filled(43, 'b').join();
  String get stepProof => List.filled(43, 'a').join();
  List<Map<String, dynamic>> roster() => [
    for (final id in ['child-A', 'child-B'])
      {
        'childId': id,
        'childAlias': 'SYN-$id',
        'stockAvatarKey': 'bear-blue',
        'withinProgramAgeRange': true,
        'state': 'ACTIVE',
      },
  ];
  Map<String, dynamic> protectedChild(String id) => {
    ...roster().firstWhere((c) => c['childId'] == id),
    'dateOfBirth': '2023-01-01',
    'ageYears': 3,
    'createdAt': '2026-10-24T00:00:00Z',
    'recordedDecisions': [
      {
        'purposeCode': 'CHILD_PROFILE_AGE',
        'recordedState': 'GRANTED',
        'noticeVersionId': 'notice-A',
      },
      {
        'purposeCode': 'LEARNING_PROGRESS',
        'recordedState': 'GRANTED',
        'noticeVersionId': 'notice-B',
      },
    ],
    'disclaimer': 'Synthetic protected detail',
  };
  Reply failure(String code, int status, {int? retry}) {
    final reply = Reply({
      'code': code,
      'message': 'PRIVATE_SERVER_DETAIL_NOT_FOR_UI',
      'requestId': 'synthetic-request',
      'retryAfterSeconds': ?retry,
    }, statusCode: status);
    if (retry != null) reply.headers.set('retry-after', retry.toString());
    return reply;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = GateRequest(method, url, this);
    requests.add(request);
    return request;
  }

  Reply respond(GateRequest request) {
    final path = request.uri.path.replaceFirst('/api/v1/', '');
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (path == 'auth/login') {
      if (forcedLoginError != null)
        return failure(
          forcedLoginError!['code'] as String,
          forcedLoginError!['status'] as int,
          retry: forcedLoginRetry,
        );
      if (body['password'] != syntheticPassword)
        return failure('INVALID_CREDENTIALS', 401);
      revoked = false;
      mode = 'PARENT';
      token = 'parent-access';
      activeChild = null;
      rotations = 0;
      return Reply(sessionLogin());
    }
    if (path == 'auth/sessions/refresh') {
      if (revoked || body['refreshToken'] != 'rotation-$rotations') {
        revoked = true;
        return failure('SESSION_REVOKED', 401);
      }
      rotations++;
      token = '${mode == 'PARENT' ? 'parent' : 'child'}-refresh-$rotations';
      return Reply({
        'refreshToken': 'rotation-$rotations',
        'refreshExpiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'sessionMode': mode,
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 15))
            .toUtc()
            .toIso8601String(),
        if (mode == 'PARENT') 'accessToken': token,
        if (mode == 'CHILD') 'childContextToken': token,
        if (mode == 'CHILD') 'childId': activeChild,
      });
    }
    if (path == 'privacy/onboarding-reference')
      return Reply({
        'terms': null,
        'purposes': [],
        'currentNotices': [],
        'disclaimer': 'Synthetic reference',
      });
    if (request.headers.value('authorization') != 'Bearer $token' || revoked)
      return failure('SESSION_REVOKED', 401);
    if (path == 'auth/logout') {
      revoked = true;
      return Reply('', statusCode: 204, raw: true);
    }
    if (path == 'parent-gate/verifications') {
      if (forcedPinError != null)
        return failure(
          forcedPinError!['code'] as String,
          forcedPinError!['status'] as int,
          retry: forcedPinRetry,
        );
      if (!enrolled) return failure('PARENT_GATE_NOT_ENROLLED', 409);
      if (body['pin'] != pin) return failure('PARENT_GATE_FAILED', 403);
      if (body['action'] == 'SWITCH_CHILD') {
        switchTarget = body['childId'] as String?;
        if (!roster().any((c) => c['childId'] == switchTarget))
          return failure('CHILD_NOT_FOUND', 404);
        return Reply(
          proofJson('SWITCH_CHILD', childId: switchTarget, mode: mode),
        );
      }
      final child = mode == 'CHILD';
      mode = 'PARENT';
      activeChild = null;
      expiredProof = false;
      if (child) token = 'parent-after-leave-${++contexts}';
      return Reply({
        ...proofJson('PARENT_AREA', mode: mode),
        if (child) 'accessToken': token,
        if (child)
          'accessTokenExpiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
      });
    }
    if (path == 'child-contexts') {
      if (request.headers.value('mimigo-parent-proof') != switchProof ||
          body['childId'] != switchTarget)
        return failure('PARENT_GATE_REQUIRED', 403);
      mode = 'CHILD';
      activeChild = switchTarget;
      switchTarget = null;
      token = 'child-context-${++contexts}';
      expiredProof = true;
      return Reply({
        'childContextToken': token,
        'childId': activeChild,
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 15))
            .toUtc()
            .toIso8601String(),
        'sessionMode': 'CHILD',
      }, statusCode: 201);
    }
    final parts = path.split('/');
    final learning =
        parts.length >= 3 &&
        parts[0] == 'children' &&
        {'lessons', 'curriculum', 'learning-sessions'}.contains(parts[2]) &&
        !(parts.length == 3 &&
            parts[2] == 'learning-sessions' &&
            request.method == 'GET');
    if (learning) {
      if (mode != 'CHILD') return failure('CHILD_CONTEXT_REQUIRED', 403);
      if (parts[1] != activeChild) return failure('CHILD_NOT_FOUND', 404);
      if (parts[2] == 'curriculum')
        return Reply(lesson.curriculumJson([lesson.summaryJson()]));
      if (parts[2] == 'lessons')
        return Reply(
          parts.length == 3
              ? {
                  'items': [lesson.summaryJson()],
                  'emptyReason': null,
                  'disclaimer': 'Mock synthetic lesson',
                }
              : lesson.detailJson(),
        );
      if (parts.length == 3 && request.method == 'POST') {
        final existing = activeSessions[activeChild!];
        if (existing != null) return Reply(sessions[existing]!);
        final id = 'mock-session-${nextSession++}';
        final session = {
          ...lesson.sessionJson(),
          'sessionId': id,
          'childId': activeChild,
          'answers': <Map<String, dynamic>>[],
        };
        sessions[id] = session;
        activeSessions[activeChild!] = id;
        return Reply(session, statusCode: 201);
      }
      final id = parts[3];
      final session = sessions[id];
      if (session == null || session['childId'] != activeChild)
        return failure('SESSION_NOT_FOUND', 404);
      if (parts.length == 4) return Reply(session);
      if (parts[4] == 'answers') {
        final answers = session['answers'] as List;
        final answer = {
          'cueId': body['cueId'],
          'optionId': body['optionId'],
          'attemptNo': answers.length + 1,
          'usedHint': false,
          'isCorrect': false,
        };
        answers.add(answer);
        return Reply({...lesson.feedbackJson(), ...answer, 'sessionId': id});
      }
      if (parts[4] == 'complete') {
        if ((session['answers'] as List).isEmpty)
          return failure('SESSION_INCOMPLETE', 409);
        session['state'] = 'COMPLETED';
        session['endedAt'] ??= DateTime.now().toUtc().toIso8601String();
        activeSessions.remove(activeChild);
        return Reply(session);
      }
    }
    if (mode == 'CHILD') return failure('CHILD_CONTEXT_FORBIDDEN', 403);
    if (path == 'parents/me')
      return Reply({
        'parentId': 'synthetic-parent',
        'email': 'synthetic@example.test',
        'displayName': 'SYN Gate Parent',
        'currentTermsAccepted': true,
        'parentGate': {'status': enrolled ? 'ENROLLED' : 'NOT_ENROLLED'},
        'session': {'sessionId': 'session-A', 'sessionMode': 'PARENT'},
      });
    if (path == 'children') return Reply({'items': roster()});
    if (path == 'parents/me/learning-workspace')
      return Reply({
        'children': [
          for (final child in roster())
            {
              'child': child,
              'catalog': {'status': 'AVAILABLE', 'eligibleLessonCount': 1},
              'learningEntry': {'status': 'READY'},
              'openSessions': {'status': 'PARENT_GATE_REQUIRED', 'items': []},
            },
        ],
        'disclaimer': 'Synthetic basic roster',
      });
    if (path == 'auth/step-up') {
      if (body['password'] != syntheticPassword)
        return failure('STEP_UP_FAILED', 403);
      return Reply(proofJson(body['action'] as String));
    }
    if (path == 'parents/me/parent-gate' ||
        path == 'parents/me/parent-gate/pin' ||
        path == 'parents/me/parent-gate/reset') {
      if (request.headers.value('mimigo-parent-proof') != stepProof)
        return failure('STEP_UP_REQUIRED', 403);
      final value = (body['pin'] ?? body['newPin']) as String;
      if (weakNext || {'123456', '000000'}.contains(value)) {
        weakNext = false;
        return failure('PIN_TOO_WEAK', 400);
      }
      if (path == 'parents/me/parent-gate' && enrolled)
        return failure('PARENT_GATE_ALREADY_ENROLLED', 409);
      pin = value;
      enrolled = true;
      expiredProof = true;
      return path.endsWith('/reset')
          ? Reply({'sessionMode': 'PARENT'})
          : Reply('', statusCode: 204, raw: true);
    }
    if (path == 'auth/sessions/revoke-others')
      return Reply({'revokedCount': 1});
    if (parts.length >= 2 && parts[0] == 'children') {
      if (request.headers.value('mimigo-parent-proof') != parentProof ||
          expiredProof)
        return failure('PARENT_GATE_REQUIRED', 403);
      if (parts.length == 2) return Reply(protectedChild(parts[1]));
      if (parts.length == 3 &&
          parts[2] == 'learning-sessions' &&
          forcedActivityError != null)
        return failure(
          forcedActivityError!['code'] as String,
          forcedActivityError!['status'] as int,
        );
      if (parts.length == 3 && parts[2] == 'learning-sessions')
        return Reply({
          'items': [
            for (final value in sessions.values.where(
              (s) => s['childId'] == parts[1],
            ))
              {
                ...value,
                'lessonCode': 'SYN-MATH-001',
                'lessonTitle': 'Synthetic Math',
              },
          ],
        });
    }
    return failure('ROUTE_NOT_FOUND', 404);
  }
}
