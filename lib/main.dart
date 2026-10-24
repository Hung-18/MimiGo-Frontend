import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'child_content.dart';
import 'api_failure.dart';
import 'learning_models.dart';
import 'learning_screens.dart';
import 'learning_session_memory.dart';
import 'parent_home.dart';
import 'curriculum_explorer.dart';
import 'terms_reacceptance.dart';
import 'parent_onboarding.dart';
import 'child_onboarding.dart';

export 'api_failure.dart';

void main() => runApp(const MimiGoApp());

/// Accepted auth/ChildProfile boundary plus the exact S2 Learning operations.
/// Fixture remains the default; live mode is opt-in.
abstract class MimiGoApi implements LearningApi {
  Future<TermsAcceptance> acceptCurrentTerms(
    String termsVersionId, {
    required bool termsAccepted,
  });
  Future<ParentWorkspace> learningWorkspace();

  /// Discards the local bearer session only. No server logout/revocation exists.
  void clearSession();
  Future<OnboardingReference> onboardingReference();
  Future<RegistrationResult> register(Registration value);
  Future<void> verifyMockEmail({required String email, required String otp});
  Future<LoginSession> login({required String email, required String password});
  Future<ParentSummary> parentMe();
  Future<OnboardingAttempt> beginOnboardingAttempt();
  Future<ChildSummary> createChild(CreateChildRequest value);
  Future<List<ChildSummary>> listChildren();
  Future<ChildDetail> getChild(String childId);
}

enum ApiMode { fixture, live }

class ApiConfiguration {
  const ApiConfiguration(this.mode, this.baseUrl);
  factory ApiConfiguration.fromEnvironment() => ApiConfiguration(
    const String.fromEnvironment(
              'MIMIGO_API_MODE',
              defaultValue: 'fixture',
            ).toLowerCase() ==
            'live'
        ? ApiMode.live
        : ApiMode.fixture,
    const String.fromEnvironment(
      'MIMIGO_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5187/api/v1',
    ),
  );
  final ApiMode mode;
  final String baseUrl;
  MimiGoApi createClient() => mode == ApiMode.live
      ? LiveMimiGoApi(Uri.parse(baseUrl))
      : FixtureMimiGoApi();
}

class Registration {
  const Registration(
    this.email,
    this.password,
    this.displayName,
    this.termsVersionId,
    this.termsAccepted,
  );
  final String email, password, displayName, termsVersionId;
  final bool termsAccepted;
  Map<String, Object> toJson() => {
    'email': email,
    'password': password,
    'displayName': displayName,
    'termsVersionId': termsVersionId,
    'termsAccepted': termsAccepted,
  };
}

class RegistrationResult {
  const RegistrationResult(
    this.parentId,
    this.otpExpiresAt,
    this.notice, [
    this.mockOtp,
  ]);
  final String parentId, notice;
  final DateTime otpExpiresAt;
  final String? mockOtp;
}

class LoginSession {
  const LoginSession(this.accessToken, this.expiresAt, this.parentId);
  final String accessToken, parentId;
  final DateTime expiresAt;
}

class ParentSummary {
  const ParentSummary(
    this.parentId,
    this.email,
    this.displayName,
    this.currentTermsAccepted,
  );
  final String parentId, email, displayName;
  final bool currentTermsAccepted;
}

/// Safe Parent Home projection. Deliberately does not model, cache or expose
/// openSessions, lesson-history items or progress received in the workspace.
class WorkspaceChildMetadata {
  const WorkspaceChildMetadata(this.child, this.catalogStatus);
  factory WorkspaceChildMetadata.fromJson(Map<String, dynamic> json) {
    final child = _child(_map(json['child']));
    final status = _string(_map(json['catalog']), 'status');
    if (!{
      'AVAILABLE',
      'NO_ELIGIBLE_CONTENT',
      'CHILD_OUTSIDE_PROGRAM_AGE',
      'PERMISSION_NOT_GRANTED',
      'CHILD_NOT_ACTIVE',
    }.contains(status))
      throw const ApiInvalidResponse('Invalid catalog availability.');
    return WorkspaceChildMetadata(child, status);
  }
  final ChildSummary child;
  final String catalogStatus;
}

class ParentWorkspace {
  const ParentWorkspace(this.children, this.disclaimer);
  factory ParentWorkspace.fromJson(Map<String, dynamic> json) {
    final items = json['children'];
    if (items is! List)
      throw const ApiInvalidResponse('Invalid parent workspace children.');
    final children = items
        .map((item) => WorkspaceChildMetadata.fromJson(_map(item)))
        .toList(growable: false);
    if (children.map((item) => item.child.id).toSet().length != children.length)
      throw const ApiInvalidResponse('Duplicate workspace children.');
    return ParentWorkspace(
      List.unmodifiable(children),
      _string(json, 'disclaimer'),
    );
  }
  final List<WorkspaceChildMetadata> children;
  final String disclaimer;
}

class TermsReference {
  const TermsReference(
    this.id,
    this.code, {
    this.contentHash,
    this.effectiveFrom,
  });
  final String id, code;
  final String? contentHash;
  final DateTime? effectiveFrom;
}

class TermsAcceptance {
  const TermsAcceptance(this.id, this.code, this.currentTermsAccepted);
  factory TermsAcceptance.fromJson(Map<String, dynamic> json) =>
      TermsAcceptance(
        _string(json, 'termsVersionId'),
        _string(json, 'code'),
        _bool(json, 'currentTermsAccepted'),
      );
  final String id, code;
  final bool currentTermsAccepted;
}

class Purpose {
  const Purpose(this.code, this.isCoreForChild);
  final String code;
  final bool isCoreForChild;
}

class Notice {
  const Notice(
    this.purposeCode,
    this.versionId,
    this.label, {
    this.contentHash,
    this.effectiveFrom,
    this.isApprovedForRealUsers,
  });
  final String purposeCode, versionId, label;
  final String? contentHash;
  final DateTime? effectiveFrom;
  final bool? isApprovedForRealUsers;
}

class OnboardingReference {
  const OnboardingReference(
    this.terms,
    this.purposes,
    this.notices,
    this.disclaimer,
  );
  final TermsReference? terms;
  final List<Purpose> purposes;
  final List<Notice> notices;
  final String disclaimer;
}

class OnboardingAttempt {
  const OnboardingAttempt(this.id, this.expiresAt, this.notices);
  final String id;
  final DateTime expiresAt;
  final List<Notice> notices;
}

class PurposeChoice {
  const PurposeChoice(this.purposeCode, this.noticeVersionId, this.affirmed);
  final String purposeCode, noticeVersionId;
  final bool affirmed;
  Map<String, Object> toJson() => {
    'purposeCode': purposeCode,
    'noticeVersionId': noticeVersionId,
    'affirmed': affirmed,
  };
}

class CreateChildRequest {
  const CreateChildRequest({
    required this.attemptId,
    required this.idempotencyKey,
    required this.childAlias,
    required this.dateOfBirth,
    required this.guardianAffirmed,
    required this.purposeChoices,
    this.stockAvatarKey,
  });
  final String attemptId, idempotencyKey, childAlias;
  final DateTime dateOfBirth;
  final bool guardianAffirmed;
  final List<PurposeChoice> purposeChoices;
  final String? stockAvatarKey;
  Map<String, Object?> toJson() => {
    'attemptId': attemptId,
    'idempotencyKey': idempotencyKey,
    'childAlias': childAlias,
    'dateOfBirth': dateText(dateOfBirth),
    'stockAvatarKey': stockAvatarKey,
    'guardianAffirmed': guardianAffirmed,
    'purposeChoices': purposeChoices.map((x) => x.toJson()).toList(),
  };
}

class ChildSummary {
  const ChildSummary({
    required this.id,
    required this.alias,
    required this.dateOfBirth,
    required this.ageYears,
    required this.withinProgramAgeRange,
    required this.state,
    required this.createdAt,
    this.stockAvatarKey,
  });
  final String id, alias, state;
  final DateTime dateOfBirth, createdAt;
  final int ageYears;
  final bool withinProgramAgeRange;
  final String? stockAvatarKey;
}

class RecordedDecision {
  const RecordedDecision(
    this.purposeCode,
    this.recordedState,
    this.noticeVersionId,
  );
  final String purposeCode, recordedState, noticeVersionId;
}

class ChildDetail extends ChildSummary {
  const ChildDetail({
    required super.id,
    required super.alias,
    required super.dateOfBirth,
    required super.ageYears,
    required super.withinProgramAgeRange,
    required super.state,
    required super.createdAt,
    super.stockAvatarKey,
    required this.recordedDecisions,
    required this.disclaimer,
  });
  final List<RecordedDecision> recordedDecisions;
  final String disclaimer;
}

class FixtureMimiGoApi implements MimiGoApi {
  @override
  Future<TermsAcceptance> acceptCurrentTerms(
    String termsVersionId, {
    required bool termsAccepted,
  }) async {
    _auth();
    if (!termsAccepted)
      throw const ApiFailure(
        'Explicit Terms acceptance is required.',
        code: 'TERMS_ACCEPTANCE_REQUIRED',
        status: 422,
      );
    if (termsVersionId != termsId)
      throw const ApiFailure(
        'Refresh current Terms.',
        code: 'TERMS_VERSION_NOT_CURRENT',
        status: 422,
      );
    return const TermsAcceptance(termsId, 'R0_MOCK_TERMS_V1', true);
  }

  @override
  Future<CurriculumCatalog> curriculum(String childId) async =>
      const CurriculumCatalog(
        [],
        'NO_ELIGIBLE_CONTENT',
        'DEMO / FIXTURE · no published curriculum catalog.',
      );
  @override
  Future<ParentWorkspace> learningWorkspace() async => ParentWorkspace(
    (await listChildren())
        .map((child) => WorkspaceChildMetadata(child, 'NO_ELIGIBLE_CONTENT'))
        .toList(growable: false),
    'DEMO / FIXTURE · catalog availability only; no protected history.',
  );
  @override
  Future<LearningSession> completeLearning(
    String childId,
    String sessionId,
  ) async => throw const ApiFailure(
    'No fixture learning session.',
    code: 'SESSION_NOT_FOUND',
    status: 404,
  );
  @override
  Future<LessonList> lessons(String childId) async => const LessonList(
    [],
    'NO_ELIGIBLE_CONTENT',
    'Fixture mode has no S2 Math catalog.',
  );
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async =>
      throw const ApiFailure(
        'No S2 fixture lesson is available.',
        code: 'LESSON_NOT_AVAILABLE',
        status: 404,
      );
  @override
  Future<LearningSession> startLearning(
    String childId,
    String lessonId,
  ) async => throw const ApiFailure(
    'S2 sessions require live mode.',
    code: 'LESSON_NOT_AVAILABLE',
    status: 404,
  );
  @override
  Future<SessionDetail> learningSession(
    String childId,
    String sessionId,
  ) async => throw const ApiFailure(
    'No fixture learning session.',
    code: 'SESSION_NOT_FOUND',
    status: 404,
  );
  @override
  Future<AnswerFeedback> submitAnswer(
    String childId,
    String sessionId,
    AnswerRequest request,
  ) async => throw const ApiFailure(
    'No fixture learning session.',
    code: 'SESSION_NOT_FOUND',
    status: 404,
  );
  static const termsId = '11111111-1111-4111-8111-111111111111',
      ageNoticeId = '22222222-2222-4222-8222-222222222222',
      learningNoticeId = '33333333-3333-4333-8333-333333333333';
  String? _email, _password, _token;
  bool _verified = false;
  int _next = 1;
  final _children = <ChildSummary>[];
  final _attempts = <String, OnboardingAttempt>{};
  final _usedAttempts = <String>{};
  final _createdRequests = <String, (String, ChildSummary)>{};
  List<Notice> get _fixtureNotices => [
    for (final item in const [
      ('CHILD_PROFILE_AGE', ageNoticeId),
      ('LEARNING_PROGRESS', learningNoticeId),
    ])
      Notice(
        item.$1,
        item.$2,
        'test-v1',
        contentHash: List.filled(64, '0').join(),
        effectiveFrom: DateTime.utc(2026, 10, 1),
        isApprovedForRealUsers: false,
      ),
  ];
  @override
  void clearSession() => _token = null;
  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 60));
  @override
  Future<OnboardingReference> onboardingReference() async {
    await _wait();
    return OnboardingReference(
      TermsReference(
        termsId,
        'R0_MOCK_TERMS_V1',
        contentHash:
            '0000000000000000000000000000000000000000000000000000000000000000',
        effectiveFrom: DateTime.utc(2026, 10, 1),
      ),
      [Purpose('CHILD_PROFILE_AGE', true), Purpose('LEARNING_PROGRESS', true)],
      _fixtureNotices,
      'Fixture-only reference. No real family data is sent.',
    );
  }

  @override
  Future<RegistrationResult> register(Registration value) async {
    await _wait();
    if (!value.email.endsWith('@example.test'))
      throw const ApiFailure(
        'Fixture emails must end in @example.test.',
        code: 'INVALID_EMAIL',
        status: 400,
      );
    if (value.password.length < 10)
      throw const ApiFailure(
        'Password must contain at least 10 characters.',
        code: 'INVALID_PASSWORD',
        status: 400,
      );
    if (!value.termsAccepted || value.termsVersionId != termsId)
      throw const ApiFailure(
        'Current Terms must be explicitly accepted.',
        code: 'TERMS_ACCEPTANCE_REQUIRED',
        status: 422,
      );
    _email = value.email;
    _password = value.password;
    _verified = false;
    return RegistrationResult(
      'fixture-parent',
      DateTime.now().add(const Duration(minutes: 10)),
      'Fixture OTP only.',
      '123456',
    );
  }

  @override
  Future<void> verifyMockEmail({
    required String email,
    required String otp,
  }) async {
    await _wait();
    if (email != _email || otp != '123456')
      throw const ApiFailure(
        'Mock code is invalid. Use 123456 in fixture mode.',
        code: 'INVALID_OTP',
        status: 400,
      );
    _verified = true;
  }

  @override
  Future<LoginSession> login({
    required String email,
    required String password,
  }) async {
    await _wait();
    if (email != _email || password != _password)
      throw const ApiFailure(
        'Invalid fixture credentials.',
        code: 'INVALID_CREDENTIALS',
        status: 401,
      );
    if (!_verified)
      throw const ApiFailure(
        'Verify synthetic email.',
        code: 'EMAIL_NOT_VERIFIED',
        status: 403,
      );
    _token = 'fixture-token';
    return LoginSession(
      _token!,
      DateTime.now().add(const Duration(minutes: 30)),
      'fixture-parent',
    );
  }

  void _auth() {
    if (_token == null)
      throw const ApiFailure(
        'Parent authentication is required.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
  }

  @override
  Future<ParentSummary> parentMe() async {
    _auth();
    await _wait();
    return ParentSummary('fixture-parent', _email!, 'SYN Parent', true);
  }

  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() async {
    _auth();
    await _wait();
    final attempt = OnboardingAttempt(
      'fixture-attempt-${_next++}',
      DateTime.now().add(const Duration(minutes: 30)),
      _fixtureNotices,
    );
    _attempts[attempt.id] = attempt;
    return attempt;
  }

  @override
  Future<ChildSummary> createChild(CreateChildRequest value) async {
    _auth();
    await _wait();
    if (!value.childAlias.startsWith('SYN-'))
      throw const ApiFailure(
        'Child alias must begin with SYN-.',
        code: 'SYNTHETIC_ALIAS_REQUIRED',
        status: 400,
      );
    final attempt = _attempts[value.attemptId];
    if (attempt == null)
      throw const ApiFailure(
        'Missing fixture attempt.',
        code: 'ATTEMPT_NOT_FOUND',
        status: 404,
      );
    if (!value.guardianAffirmed ||
        value.purposeChoices.length != attempt.notices.length ||
        value.purposeChoices
                .map((choice) => choice.purposeCode)
                .toSet()
                .length !=
            value.purposeChoices.length ||
        attempt.notices.any(
          (notice) => !value.purposeChoices.any(
            (choice) =>
                choice.affirmed &&
                choice.purposeCode == notice.purposeCode &&
                choice.noticeVersionId == notice.versionId,
          ),
        ))
      throw const ApiFailure(
        'Every required purpose must be affirmed.',
        code: 'CORE_PERMISSION_REQUIRED',
        status: 422,
      );
    final fingerprint = jsonEncode(value.toJson());
    final known = _createdRequests[value.idempotencyKey];
    if (known != null) {
      if (known.$1 != fingerprint)
        throw const ApiFailure(
          'Changed fixture request.',
          code: 'IDEMPOTENCY_CONFLICT',
          status: 409,
        );
      return known.$2;
    }
    if (_usedAttempts.contains(value.attemptId))
      throw const ApiFailure(
        'Fixture attempt consumed.',
        code: 'ATTEMPT_ALREADY_CONSUMED',
        status: 409,
      );
    if (!attempt.expiresAt.isAfter(DateTime.now()))
      throw const ApiFailure(
        'Fixture attempt expired.',
        code: 'ATTEMPT_EXPIRED',
        status: 422,
      );
    if (value.childAlias.length > 40 ||
        !acceptableChildDob(value.dateOfBirth, vietnamToday()))
      throw const ApiFailure(
        'Invalid fixture profile.',
        code: 'INVALID_CHILD_PROFILE',
        status: 400,
      );
    final age = productAge(value.dateOfBirth, vietnamToday());
    final child = ChildSummary(
      id: 'fixture-child-${_next++}',
      alias: value.childAlias,
      dateOfBirth: value.dateOfBirth,
      ageYears: age,
      withinProgramAgeRange: age >= 2 && age <= 6,
      state: 'ACTIVE',
      createdAt: DateTime.now(),
      stockAvatarKey: value.stockAvatarKey,
    );
    _children.add(child);
    _usedAttempts.add(value.attemptId);
    _createdRequests[value.idempotencyKey] = (fingerprint, child);
    return child;
  }

  @override
  Future<List<ChildSummary>> listChildren() async {
    _auth();
    await _wait();
    return List.unmodifiable(_children);
  }

  @override
  Future<ChildDetail> getChild(String id) async {
    _auth();
    await _wait();
    final child = _children.where((x) => x.id == id).firstOrNull;
    if (child == null)
      throw const ApiFailure(
        'Child profile was not found.',
        code: 'CHILD_NOT_FOUND',
        status: 404,
      );
    return ChildDetail(
      id: child.id,
      alias: child.alias,
      dateOfBirth: child.dateOfBirth,
      ageYears: child.ageYears,
      withinProgramAgeRange: child.withinProgramAgeRange,
      state: child.state,
      createdAt: child.createdAt,
      stockAvatarKey: child.stockAvatarKey,
      recordedDecisions: const [
        RecordedDecision('CHILD_PROFILE_AGE', 'GRANTED', ageNoticeId),
        RecordedDecision('LEARNING_PROGRESS', 'GRANTED', learningNoticeId),
      ],
      disclaimer: 'Fixture-only recorded decisions.',
    );
  }
}

class LiveMimiGoApi implements MimiGoApi {
  @override
  Future<TermsAcceptance> acceptCurrentTerms(
    String termsVersionId, {
    required bool termsAccepted,
  }) async => TermsAcceptance.fromJson(
    await _request(
      'POST',
      'parents/me/terms-acceptances',
      auth: true,
      body: {'termsVersionId': termsVersionId, 'termsAccepted': termsAccepted},
    ),
  );
  @override
  Future<CurriculumCatalog> curriculum(String childId) async =>
      CurriculumCatalog.fromJson(
        await _request('GET', 'children/$childId/curriculum', auth: true),
      );
  @override
  Future<ParentWorkspace> learningWorkspace() async => ParentWorkspace.fromJson(
    await _request('GET', 'parents/me/learning-workspace', auth: true),
  );
  LiveMimiGoApi(this.baseUri, {HttpClient? client})
    : _client = client ?? HttpClient();
  final Uri baseUri;
  final HttpClient _client;
  String? _token;
  @override
  Future<LearningSession> completeLearning(
    String childId,
    String sessionId,
  ) async => LearningSession.fromJson(
    await _request(
      'POST',
      'children/$childId/learning-sessions/$sessionId/complete',
      auth: true,
    ),
  );
  @override
  Future<LessonList> lessons(String childId) async => LessonList.fromJson(
    await _request('GET', 'children/$childId/lessons', auth: true),
  );
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async =>
      LessonDetail.fromJson(
        await _request(
          'GET',
          'children/$childId/lessons/$lessonId',
          auth: true,
        ),
      );
  @override
  Future<LearningSession> startLearning(
    String childId,
    String lessonId,
  ) async => LearningSession.fromJson(
    await _request(
      'POST',
      'children/$childId/learning-sessions',
      auth: true,
      body: {'lessonId': lessonId},
    ),
  );
  @override
  Future<SessionDetail> learningSession(
    String childId,
    String sessionId,
  ) async => SessionDetail.fromJson(
    await _request(
      'GET',
      'children/$childId/learning-sessions/$sessionId',
      auth: true,
    ),
  );
  @override
  Future<AnswerFeedback> submitAnswer(
    String childId,
    String sessionId,
    AnswerRequest request,
  ) async => AnswerFeedback.fromJson(
    await _request(
      'POST',
      'children/$childId/learning-sessions/$sessionId/answers',
      auth: true,
      body: request.toJson(),
    ),
  );
  @override
  void clearSession() => _token = null;
  @override
  Future<OnboardingReference> onboardingReference() async =>
      _reference(await _request('GET', 'privacy/onboarding-reference'));
  @override
  Future<RegistrationResult> register(Registration value) async {
    final x = await _request('POST', 'auth/register', body: value.toJson());
    if (_string(x, 'status') != 'PENDING_VERIFICATION')
      throw const ApiInvalidResponse(
        'Registration was not confirmed as pending verification.',
      );
    return RegistrationResult(
      _string(x, 'parentId'),
      _date(x, 'otpExpiresAt'),
      _string(x, 'notice'),
      x['mockOtp'] as String?,
    );
  }

  @override
  Future<void> verifyMockEmail({
    required String email,
    required String otp,
  }) async {
    final response = await _request(
      'POST',
      'auth/mock-email/verify',
      body: {'email': email, 'otp': otp},
    );
    if (_string(response, 'status') != 'ACTIVE' ||
        _string(response, 'parentId').isEmpty)
      throw const ApiInvalidResponse('Email verification was not confirmed.');
  }

  @override
  Future<LoginSession> login({
    required String email,
    required String password,
  }) async {
    final x = await _request(
      'POST',
      'auth/login',
      body: {'email': email, 'password': password},
    );
    if (_string(x, 'tokenType') != 'Bearer')
      throw const ApiInvalidResponse(
        'Login response has an unsupported token type.',
      );
    final session = LoginSession(
      _string(x, 'accessToken'),
      _date(x, 'expiresAt'),
      _string(x, 'parentId'),
    );
    _token = session.accessToken;
    return session;
  }

  @override
  Future<ParentSummary> parentMe() async {
    final x = await _request('GET', 'parents/me', auth: true);
    return ParentSummary(
      _string(x, 'parentId'),
      _string(x, 'email'),
      _string(x, 'displayName'),
      _bool(x, 'currentTermsAccepted'),
    );
  }

  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() async {
    final x = await _request(
      'POST',
      'children/onboarding-attempts',
      auth: true,
    );
    return OnboardingAttempt(
      _string(x, 'attemptId'),
      _date(x, 'expiresAt'),
      _notices(x['notices']),
    );
  }

  @override
  Future<ChildSummary> createChild(CreateChildRequest value) async => _child(
    await _request('POST', 'children', auth: true, body: value.toJson()),
  );
  @override
  Future<List<ChildSummary>> listChildren() async {
    final x = await _request('GET', 'children', auth: true);
    final items = x['items'];
    if (items is! List)
      throw const ApiInvalidResponse('Child list response is missing items.');
    return items.map((v) => _child(_map(v))).toList(growable: false);
  }

  @override
  Future<ChildDetail> getChild(String id) async {
    final x = await _request(
      'GET',
      'children/${Uri.encodeComponent(id)}',
      auth: true,
    );
    final child = _child(x);
    final values = x['recordedDecisions'];
    if (values is! List)
      throw const ApiInvalidResponse(
        'Child detail response is missing recorded decisions.',
      );
    return ChildDetail(
      id: child.id,
      alias: child.alias,
      dateOfBirth: child.dateOfBirth,
      ageYears: child.ageYears,
      withinProgramAgeRange: child.withinProgramAgeRange,
      state: child.state,
      createdAt: child.createdAt,
      stockAvatarKey: child.stockAvatarKey,
      recordedDecisions: values
          .map((v) {
            final d = _map(v);
            return RecordedDecision(
              _string(d, 'purposeCode'),
              _string(d, 'recordedState'),
              _string(d, 'noticeVersionId'),
            );
          })
          .toList(growable: false),
      disclaimer: _string(x, 'disclaimer'),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    if (auth && _token == null)
      throw const ApiFailure(
        'A Parent session is required.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/$encoded',
    );
    try {
      final req = await _client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 12));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (auth) {
        if (_token == null)
          throw const ApiFailure(
            'A Parent session is required.',
            code: 'UNAUTHENTICATED',
            status: 401,
          );
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      if (body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 20));
      final id = response.headers.value('x-request-id');
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> json;
      try {
        json = _map(jsonDecode(raw));
      } catch (_) {
        throw ApiInvalidResponse(
          'The server returned malformed JSON.',
          requestId: id,
          status: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw ApiFailure(
          json['message'] is String
              ? json['message'] as String
              : 'The request was rejected.',
          code: json['code'] is String
              ? json['code'] as String
              : 'INVALID_RESPONSE',
          status: response.statusCode,
          requestId: json['requestId'] is String
              ? json['requestId'] as String
              : id,
          retryable: response.statusCode >= 500 || response.statusCode == 429,
        );
      return json;
    } on ApiFailure {
      rethrow;
    } on FormatException {
      throw const ApiInvalidResponse(
        'The service returned invalid response text.',
      );
    } on TimeoutException {
      throw const ApiFailure(
        'The service did not respond in time. Check connectivity and retry.',
        code: 'TIMEOUT',
        retryable: true,
      );
    } on SocketException {
      throw const ApiFailure(
        'Could not reach the service. Check API address and emulator network.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    } on HttpException {
      throw const ApiFailure(
        'Could not complete the network request. Retry when connected.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
  }
}

Map<String, dynamic> _map(Object? x) {
  if (x is! Map)
    throw const ApiInvalidResponse(
      'The server returned an invalid JSON object.',
    );
  return x.map((k, v) => MapEntry(k.toString(), v));
}

String _string(Map<String, dynamic> x, String key) {
  final value = x[key];
  if (value is! String || value.isEmpty)
    throw ApiInvalidResponse('The response is missing $key.');
  return value;
}

bool _bool(Map<String, dynamic> x, String key) {
  if (x[key] is! bool)
    throw ApiInvalidResponse('The response has an invalid $key.');
  return x[key] as bool;
}

DateTime _date(Map<String, dynamic> x, String key) {
  final value = DateTime.tryParse(_string(x, key));
  if (value == null)
    throw ApiInvalidResponse('The response has an invalid $key.');
  return value;
}

List<Notice> _notices(Object? x) {
  if (x is! List)
    throw const ApiInvalidResponse('The response is missing notices.');
  final notices = x
      .map((v) {
        final n = _map(v);
        return Notice(
          _string(n, 'purposeCode'),
          _string(n, 'noticeVersionId'),
          _string(n, 'versionLabel'),
          contentHash: _string(n, 'contentHash'),
          effectiveFrom: _date(n, 'effectiveFrom'),
          isApprovedForRealUsers: _bool(n, 'isApprovedForRealUsers'),
        );
      })
      .toList(growable: false);
  if (notices.any(
        (n) =>
            n.purposeCode.isEmpty ||
            n.versionId.isEmpty ||
            n.isApprovedForRealUsers != false,
      ) ||
      notices.map((n) => n.purposeCode).toSet().length != notices.length)
    throw const ApiInvalidResponse('Invalid R0 purpose notice snapshot.');
  return notices;
}

OnboardingReference _reference(Map<String, dynamic> x) {
  final termsJson = x['terms'];
  final terms = termsJson == null
      ? null
      : TermsReference(
          _string(_map(termsJson), 'termsVersionId'),
          _string(_map(termsJson), 'code'),
          contentHash: _string(_map(termsJson), 'contentHash'),
          effectiveFrom: _date(_map(termsJson), 'effectiveFrom'),
        );
  final raw = x['purposes'];
  if (raw is! List)
    throw const ApiInvalidResponse('Reference response is missing purposes.');
  return OnboardingReference(
    terms,
    raw
        .map((v) {
          final p = _map(v);
          return Purpose(_string(p, 'purposeCode'), _bool(p, 'isCoreForChild'));
        })
        .toList(growable: false),
    _notices(x['currentNotices']),
    _string(x, 'disclaimer'),
  );
}

ChildSummary _child(Map<String, dynamic> x) => ChildSummary(
  id: _string(x, 'childId'),
  alias: _string(x, 'childAlias'),
  dateOfBirth:
      parseDate(_string(x, 'dateOfBirth')) ??
      (throw const ApiInvalidResponse(
        'Child response has an invalid dateOfBirth.',
      )),
  ageYears: x['ageYears'] is int
      ? x['ageYears'] as int
      : throw const ApiInvalidResponse(
          'Child response has an invalid ageYears.',
        ),
  withinProgramAgeRange: _bool(x, 'withinProgramAgeRange'),
  state: _string(x, 'state'),
  createdAt: _date(x, 'createdAt'),
  stockAvatarKey: x['stockAvatarKey'] as String?,
);

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum Page {
  welcome,
  signIn,
  register,
  otp,
  privacy,
  input,
  review,
  child,
  category,
  learningLesson,
  explorer,
  demo,
  parent,
  parentOnly,
  terms,
  childCreated,
}

class MimiGoApp extends StatefulWidget {
  const MimiGoApp({super.key, this.api, this.configuration});
  final MimiGoApi? api;
  final ApiConfiguration? configuration;
  @override
  State<MimiGoApp> createState() => _MimiGoAppState();
}

class _MimiGoAppState extends State<MimiGoApp> {
  late final config =
      widget.configuration ?? ApiConfiguration.fromEnvironment();
  late final MimiGoApi api = widget.api ?? config.createClient();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  Page page = Page.welcome;
  OnboardingReference? reference;
  OnboardingAttempt? attempt;
  RegistrationResult? registration;
  String? email, password, mockOtp;
  ChildDraft? draft;
  ChildCreationState? creation;
  ChildSummary? createdProfile;
  ChildSummary? active;
  ParentSummary? authenticatedParent;
  ParentWorkspace? parentWorkspace;
  List<ChildSummary> children = [];
  LearningCategory? selectedCategory;
  String? selectedLessonId;
  final pendingLearningAnswers = PendingLearningAnswers();
  late final learningSessions = LearningSessionMemory(api);
  CurriculumExplorerState? curriculum;
  bool learningFromExplorer = false;
  String learningDomain = 'MATH';
  int sessionGeneration = 0;
  bool accountEntryPending = false;
  bool startingRegistration = false;
  ApiFailure? registrationEntryError;
  bool verificationReturningParent = false;

  Future<void> returnToAccountEntry() async {
    if (accountEntryPending) return;
    accountEntryPending = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: navigatorKey.currentState!.overlay!.context,
        builder: (context) => AlertDialog(
          title: const Text('Return to account entry?'),
          content: const Text(
            'A parent will need to sign in again to open the Parent Area. Saved profiles will stay available.',
          ),
          actions: [
            TextButton(
              key: const Key('cancelAccountEntry'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                page == Page.parent
                    ? 'Stay in Parent Home'
                    : 'Stay in Child Mode',
              ),
            ),
            FilledButton(
              key: const Key('confirmAccountEntry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Return to account entry'),
            ),
          ],
        ),
      );
    } finally {
      accountEntryPending = false;
    }
    if (!mounted || confirmed != true) return;
    api.clearSession();
    messengerKey.currentState?.clearSnackBars();
    setState(() {
      sessionGeneration++;
      email = password = mockOtp = null;
      authenticatedParent = null;
      parentWorkspace = null;
      active = null;
      children = [];
      reference = null;
      registration = null;
      attempt = null;
      draft = null;
      creation?.dispose();
      creation = null;
      createdProfile = null;
      selectedCategory = null;
      selectedLessonId = null;
      pendingLearningAnswers.clear();
      learningSessions.clear();
      curriculum?.dispose();
      curriculum = null;
      learningFromExplorer = false;
      learningDomain = 'MATH';
      page = Page.welcome;
    });
  }

  void childBack() {
    if (page == Page.childCreated) {
      goParentHome();
    } else if (page == Page.review) {
      if (creation?.canEdit == true) setState(() => page = Page.input);
    } else if (page == Page.input) {
      setState(() => page = Page.privacy);
    } else if (page == Page.privacy || page == Page.parentOnly) {
      goParentHome();
    } else if (page == Page.terms) {
      setState(() => page = Page.parent);
    } else if (page == Page.learningLesson) {
      setState(
        () => page = learningFromExplorer ? Page.explorer : Page.category,
      );
    } else if (page == Page.explorer) {
      if (curriculum?.back() != true) setState(() => page = Page.child);
    } else if (page == Page.demo) {
      setState(() => page = Page.category);
    } else if (page == Page.category) {
      setState(() => page = Page.child);
    } else if (page == Page.child) {
      returnToAccountEntry();
    }
  }

  void openCurriculum([CurriculumDomain? domain]) {
    if (page != Page.child) return;
    curriculum?.dispose();
    setState(() {
      curriculum = CurriculumExplorerState(api, active!.id);
      if (domain != null) curriculum!.chooseDomain(domain);
      page = Page.explorer;
    });
  }

  @override
  void dispose() {
    creation?.dispose();
    learningSessions.dispose();
    curriculum?.dispose();
    super.dispose();
  }

  Future<void> start() async {
    if (startingRegistration) return;
    final generation = sessionGeneration;
    setState(() {
      startingRegistration = true;
      registrationEntryError = null;
    });
    try {
      final value = await api.onboardingReference();
      if (mounted && generation == sessionGeneration && page == Page.welcome)
        setState(() {
          reference = value;
          page = Page.register;
        });
    } on ApiFailure catch (e) {
      if (mounted && generation == sessionGeneration)
        setState(() => registrationEntryError = e);
    } finally {
      if (mounted && generation == sessionGeneration)
        setState(() => startingRegistration = false);
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
    required bool returningParent,
  }) async {
    await api.login(email: email, password: password);
    final parent = await api.parentMe();
    final workspace = returningParent || !parent.currentTermsAccepted
        ? await api.learningWorkspace()
        : null;
    final profiles =
        workspace?.children.map((item) => item.child).toList(growable: false) ??
        <ChildSummary>[];
    if (!mounted) return;
    setState(() {
      authenticatedParent = parent;
      parentWorkspace = workspace;
      children = profiles;
      active = null;
      attempt = null;
      draft = null;
      this.password = null;
      page = returningParent || !parent.currentTermsAccepted
          ? Page.parent
          : Page.privacy;
    });
  }

  Future<void> signedIn() => authenticate(
    email: email!,
    password: password!,
    returningParent: verificationReturningParent,
  );

  Future<void> attemptStart() async {
    final generation = sessionGeneration;
    setState(() {
      attempt = null;
      draft = null;
    });
    try {
      final value = await api.beginOnboardingAttempt();
      if (mounted && generation == sessionGeneration && page == Page.privacy)
        setState(() => attempt = value);
    } on ApiFailure catch (e) {
      if (mounted && generation == sessionGeneration && page == Page.privacy) {
        if (e.code == 'TERMS_ACCEPTANCE_REQUIRED')
          requireCurrentTerms();
        else
          rethrow;
      }
    }
  }

  void requireCurrentTerms() {
    if (authenticatedParent == null ||
        !{Page.parent, Page.privacy, Page.review}.contains(page))
      return;
    setState(() {
      attempt = null;
      draft = null;
      creation?.dispose();
      creation = null;
      parentWorkspace = null;
      children = [];
      page = Page.terms;
    });
  }

  void goParentHome() {
    if (authenticatedParent == null) return;
    setState(() {
      attempt = null;
      draft = null;
      creation?.dispose();
      creation = null;
      parentWorkspace = null;
      active = null;
      page = Page.parent;
    });
  }

  void beginChildOnboarding() {
    if (authenticatedParent == null) return;
    setState(() {
      attempt = null;
      draft = null;
      creation?.dispose();
      creation = null;
      createdProfile = null;
      active = null;
      page = Page.privacy;
    });
  }

  void reviewChild(ChildDraft value) {
    if (attempt == null || creation?.sent == true) return;
    creation?.dispose();
    setState(() {
      draft = value;
      creation = ChildCreationState(
        api,
        CreateChildRequest(
          attemptId: attempt!.id,
          idempotencyKey: 'r0-${DateTime.now().microsecondsSinceEpoch}',
          childAlias: value.alias,
          dateOfBirth: value.dob,
          stockAvatarKey: value.avatar,
          guardianAffirmed: true,
          purposeChoices: attempt!.notices
              .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
              .toList(growable: false),
        ),
      );
      page = Page.review;
    });
  }

  Future<void> refresh() async {
    final generation = sessionGeneration;
    try {
      final value = await api.listChildren();
      if (mounted && generation == sessionGeneration)
        setState(() => children = value);
    } on ApiFailure catch (e) {
      if (mounted && generation == sessionGeneration) error(e);
    }
  }

  void error(ApiFailure e) => messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(errorText(e))),
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: messengerKey,
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6a5acd)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: PopScope(
      canPop:
          page != Page.child &&
          page != Page.category &&
          page != Page.demo &&
          page != Page.learningLesson &&
          page != Page.explorer &&
          page != Page.privacy &&
          page != Page.input &&
          page != Page.review &&
          page != Page.parentOnly &&
          page != Page.childCreated &&
          page != Page.terms,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) childBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (page) {
            Page.welcome => Welcome(
              live: config.mode == ApiMode.live,
              start: start,
              busy: startingRegistration,
              error: registrationEntryError,
              signIn: () => setState(() => page = Page.signIn),
            ),
            Page.signIn => SignIn(
              back: () => setState(() => page = Page.welcome),
              submitted: (email, password) => authenticate(
                email: email,
                password: password,
                returningParent: true,
              ),
              verify: (enteredEmail, enteredPassword) => setState(() {
                email = enteredEmail;
                password = enteredPassword;
                mockOtp = null;
                registration = null;
                verificationReturningParent = true;
                page = Page.otp;
              }),
            ),
            Page.register => Register(
              reference: reference!,
              fixture: config.mode == ApiMode.fixture,
              reloadReference: api.onboardingReference,
              signIn: () => setState(() => page = Page.signIn),
              back: () => setState(() => page = Page.welcome),
              submitted: (v) async {
                final result = await api.register(v);
                if (mounted)
                  setState(() {
                    email = v.email;
                    password = v.password;
                    mockOtp = result.mockOtp;
                    registration = result;
                    verificationReturningParent = false;
                    page = Page.otp;
                  });
              },
            ),
            Page.otp => Otp(
              api: api,
              email: email!,
              mockOtp: mockOtp,
              registration: registration,
              back: () => setState(() {
                password = null;
                page = Page.signIn;
              }),
              done: signedIn,
            ),
            Page.privacy => Privacy(
              attempt: attempt,
              begin: attemptStart,
              parentHome: goParentHome,
              declined: () => setState(() {
                attempt = null;
                draft = null;
                page = Page.parentOnly;
              }),
              next: () => setState(() => page = Page.input),
            ),
            Page.input => ChildInput(
              initialDraft: draft,
              back: () => setState(() => page = Page.privacy),
              next: reviewChild,
            ),
            Page.review => Review(
              api: api,
              attempt: attempt!,
              draft: draft!,
              model: creation!,
              restart: beginChildOnboarding,
              parentHome: goParentHome,
              accountEntry: returnToAccountEntry,
              termsRequired: requireCurrentTerms,
              back: childBack,
              created: (v) async {
                setState(() {
                  createdProfile = v;
                  children = [
                    ...children.where((child) => child.id != v.id),
                    v,
                  ];
                  parentWorkspace = null;
                  page = Page.childCreated;
                });
              },
            ),
            Page.child => ChildHome(
              child: active!,
              fixture: config.mode == ApiMode.fixture,
              category: (value) => setState(() {
                learningFromExplorer = false;
                learningDomain = 'MATH';
                selectedCategory = value;
                page = Page.category;
              }),
              explore: openCurriculum,
              english: () => openCurriculum(CurriculumDomain.english),
              accountEntry: returnToAccountEntry,
            ),
            Page.childCreated => Frame(
              title: 'Synthetic child profile ready',
              children: [
                ChildCreated(
                  child: createdProfile!,
                  parentHome: goParentHome,
                  addAnother: beginChildOnboarding,
                ),
              ],
            ),
            Page.category => Frame(
              title: selectedCategory!.label,
              children: [
                if (config.mode == ApiMode.live &&
                    selectedCategory == LearningCategory.math)
                  MathLessonCatalog(
                    api: api,
                    childId: active!.id,
                    openLesson: (id) {
                      if (page != Page.category) return;
                      setState(() {
                        selectedLessonId = id;
                        page = Page.learningLesson;
                      });
                    },
                  )
                else
                  CategoryContent(
                    key: ValueKey(selectedCategory),
                    category: selectedCategory!,
                    fixture: config.mode == ApiMode.fixture,
                    source: config.mode == ApiMode.fixture
                        ? const FixtureChildContentSource()
                        : const UnavailableLiveContentSource(),
                    openDemo: () {
                      if (config.mode == ApiMode.fixture)
                        setState(() => page = Page.demo);
                    },
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: OutlinedButton(
                    key: const Key('categoryBack'),
                    onPressed: () => setState(() => page = Page.child),
                    child: const Text('Back to Child Mode'),
                  ),
                ),
              ],
            ),
            Page.demo => Frame(
              title: 'Find the circle',
              children: [
                if (config.mode == ApiMode.fixture)
                  const CircleDemo()
                else
                  const Text('Content not available yet'),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('demoBack'),
                  onPressed: () => setState(() => page = Page.category),
                  child: const Text('Back to Logic'),
                ),
                OutlinedButton(
                  key: const Key('demoHome'),
                  onPressed: () => setState(() => page = Page.child),
                  child: const Text('Back to Child Mode'),
                ),
              ],
            ),
            Page.explorer => Frame(
              title: 'Curriculum Explorer',
              children: [
                CurriculumExplorer(
                  model: curriculum!,
                  childAlias: active!.alias,
                  fixture: config.mode == ApiMode.fixture,
                  openLesson: (lesson) {
                    if (page != Page.explorer) return;
                    setState(() {
                      selectedLessonId = lesson.lessonId;
                      learningDomain = lesson.domainCode;
                      learningFromExplorer = true;
                      page = Page.learningLesson;
                    });
                  },
                ),
                AnimatedBuilder(
                  animation: curriculum!,
                  builder: (context, _) => ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: OutlinedButton(
                      key: const Key('explorerBack'),
                      onPressed: childBack,
                      child: Text(
                        curriculum!.topic != null
                            ? 'Back to topics'
                            : curriculum!.domain != null
                            ? 'Back to domains'
                            : 'Back to Child Mode',
                      ),
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('explorerHome'),
                  onPressed: () => setState(() => page = Page.child),
                  child: const Text('Back to Child Mode'),
                ),
              ],
            ),
            Page.learningLesson => Frame(
              title: learningFromExplorer
                  ? 'Learning · development/demo'
                  : 'Math learning · development/demo',
              children: [
                LearningLessonView(
                  key: ValueKey((active!.id, selectedLessonId)),
                  api: api,
                  childId: active!.id,
                  lessonId: selectedLessonId!,
                  pending: pendingLearningAnswers,
                  sessions: learningSessions,
                  domainCode: learningDomain,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: OutlinedButton(
                    key: const Key('lessonBack'),
                    onPressed: childBack,
                    child: Text(
                      learningFromExplorer
                          ? 'Back to curriculum'
                          : 'Back to Math',
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: OutlinedButton(
                    key: const Key('lessonHome'),
                    onPressed: () => setState(() => page = Page.child),
                    child: const Text('Back to Child Mode'),
                  ),
                ),
              ],
            ),
            Page.terms => Frame(
              title: 'Review current account Terms',
              children: [
                TermsReacceptance(
                  api: api,
                  parentId: authenticatedParent!.parentId,
                  accepted: (parent) {
                    if (!mounted ||
                        authenticatedParent?.parentId != parent.parentId)
                      return;
                    setState(() {
                      authenticatedParent = parent;
                      attempt = null;
                      draft = null;
                      page = Page.privacy;
                    });
                  },
                  cancel: childBack,
                  accountEntry: returnToAccountEntry,
                ),
              ],
            ),
            Page.parent => ParentArea(
              home: ParentHome(
                api: api,
                parent: authenticatedParent!,
                children: children,
                fixture: config.mode == ApiMode.fixture,
                workspace: parentWorkspace,
                accountEntry: returnToAccountEntry,
                add: beginChildOnboarding,
                enterChild: (child) => setState(() {
                  curriculum?.dispose();
                  curriculum = null;
                  active = child;
                  selectedCategory = null;
                  selectedLessonId = null;
                  page = Page.child;
                }),
              ),
              children: children,
              active: active,
              currentTermsAccepted: authenticatedParent!.currentTermsAccepted,
              refresh: refresh,
              add: () => setState(() {
                attempt = null;
                draft = null;
                page = Page.privacy;
              }),
              select: (v) async {
                try {
                  final detail = await api.getChild(v.id);
                  if (mounted)
                    setState(() {
                      active = detail;
                      page = Page.child;
                    });
                } on ApiFailure catch (e) {
                  if (mounted) error(e);
                }
              },
            ),
            Page.parentOnly => ParentOnly(
              back: beginChildOnboarding,
              parentHome: goParentHome,
            ),
          },
        ),
      ),
    ),
  );
}

class Frame extends StatelessWidget {
  const Frame({
    super.key,
    required this.title,
    required this.children,
    this.back,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? back;
  @override
  Widget build(BuildContext c) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (back != null)
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: back),
              ),
            Text(
              title,
              style: Theme.of(c).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const InternalBanner(),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class InternalBanner extends StatelessWidget {
  const InternalBanner({super.key});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfffff3cd),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text('R0 SYNTHETIC ONLY — not for real families.'),
  );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.value, {super.key});
  final ApiFailure? value;
  @override
  Widget build(BuildContext c) => value == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            errorText(value!),
            key: const Key('safeError'),
            style: TextStyle(color: Theme.of(c).colorScheme.error),
          ),
        );
}

class Welcome extends StatelessWidget {
  const Welcome({
    super.key,
    required this.live,
    required this.start,
    required this.signIn,
    this.busy = false,
    this.error,
  });
  final bool live;
  final bool busy;
  final ApiFailure? error;
  final Future<void> Function() start;
  final VoidCallback signIn;
  @override
  Widget build(BuildContext c) => Frame(
    title: 'MimiGo',
    children: [
      Text(
        live
            ? 'Development API mode. Use synthetic test accounts only.'
            : 'Fixture mode. No network requests are made.',
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('welcomeStart'),
          onPressed: busy ? null : start,
          child: Text(
            busy ? 'Loading current account Terms…' : 'Create a parent account',
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (busy)
        const LinearProgressIndicator(
          semanticsLabel: 'Loading account reference',
        ),
      OnboardingError(error),
      TextButton(
        key: const Key('welcomeSignIn'),
        onPressed: busy ? null : signIn,
        child: const Text('Already have an account? Sign in'),
      ),
    ],
  );
}

class SignIn extends StatefulWidget {
  const SignIn({
    super.key,
    required this.back,
    required this.submitted,
    this.verify,
  });
  final VoidCallback back;
  final Future<void> Function(String email, String password) submitted;
  final void Function(String email, String password)? verify;

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  ApiFailure? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submitted(email.text.trim(), password.text);
    } on ApiFailure catch (failure) {
      if (mounted)
        setState(
          () => error = failure.code == 'INVALID_CREDENTIALS'
              ? ApiFailure(
                  'Email or password is incorrect.',
                  code: failure.code,
                  status: failure.status,
                  requestId: failure.requestId,
                )
              : failure,
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Frame(
    title: 'Sign in to your parent account',
    back: busy ? null : widget.back,
    children: [
      const Text(
        'Use an existing verified parent account. R0 accounts use @example.test email addresses.',
      ),
      const SizedBox(height: 16),
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('signInEmail'),
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Parent email'),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('signInPassword'),
              controller: password,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
              onFieldSubmitted: (_) => submit(),
            ),
            ErrorText(error),
            if (error?.code == 'EMAIL_NOT_VERIFIED' && widget.verify != null)
              OutlinedButton(
                key: const Key('resumeEmailVerification'),
                onPressed: busy
                    ? null
                    : () => widget.verify!(email.text.trim(), password.text),
                child: const Text('Verify existing synthetic email'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: FilledButton(
                key: const Key('signInSubmit'),
                onPressed: busy ? null : submit,
                child: busy
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Signing in…'),
                        ],
                      )
                    : const Text('Sign in'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class Register extends StatefulWidget {
  const Register({
    super.key,
    required this.reference,
    required this.back,
    required this.submitted,
    this.fixture = false,
    this.reloadReference,
    this.signIn,
  });
  final OnboardingReference reference;
  final VoidCallback back;
  final Future<void> Function(Registration) submitted;
  final bool fixture;
  final Future<OnboardingReference> Function()? reloadReference;
  final VoidCallback? signIn;
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final formKey = GlobalKey<FormState>();
  late final email = TextEditingController(
        text: widget.fixture ? 'parent@example.test' : '',
      ),
      password = TextEditingController(
        text: widget.fixture ? 'synthetic-pass' : '',
      ),
      displayName = TextEditingController(text: 'SYN Parent');
  late OnboardingReference current = widget.reference;
  bool terms = false, busy = false;
  bool versionChanged = false;
  ApiFailure? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate() || versionChanged) return;
    final id = current.terms?.id;
    if (id == null || !terms) {
      setState(
        () => error = const ApiFailure(
          'Current Terms must be explicitly accepted.',
          code: 'TERMS_ACCEPTANCE_REQUIRED',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submitted(
        Registration(
          email.text.trim(),
          password.text,
          displayName.text.trim(),
          id,
          true,
        ),
      );
    } on ApiFailure catch (e) {
      if (mounted)
        setState(() {
          error = e;
          if (e.code == 'TERMS_VERSION_NOT_CURRENT') {
            terms = false;
            versionChanged = true;
          }
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload() async {
    if (busy || widget.reloadReference == null) return;
    setState(() {
      busy = true;
      terms = false;
      error = null;
    });
    try {
      final next = await widget.reloadReference!();
      if (mounted)
        setState(() {
          current = next;
          versionChanged = false;
        });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Create parent account',
    back: busy ? null : widget.back,
    children: [
      Text(
        'Terms: ${current.terms?.code ?? 'unavailable'}. Terms are separate from child consent.',
      ),
      Text(current.disclaimer),
      const Text(
        'R0 synthetic accounts only. The API supplies mock Terms version metadata, not a full legal document. No email is sent and this does not prove guardian authority.',
      ),
      if (current.terms?.effectiveFrom != null)
        Text(
          'Effective: ${current.terms!.effectiveFrom!.toUtc().toIso8601String()}',
        ),
      if (busy)
        const LinearProgressIndicator(
          semanticsLabel: 'Creating parent account',
        ),
      const SizedBox(height: 12),
      Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('registerEmail'),
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (value) =>
                  RegExp(r'^[^\s@]+@example\.test$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Use a synthetic email ending in @example.test.',
              decoration: const InputDecoration(
                labelText: 'Parent email (@example.test in R0)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registerDisplayName'),
              controller: displayName,
              enabled: !busy,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) || value!.trim().length > 80
                  ? 'Enter a display name of 1–80 characters.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Parent display name',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registerPassword'),
              controller: password,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              validator: (value) =>
                  (value?.length ?? 0) < 10 || (value?.length ?? 0) > 128
                  ? 'Use 10–128 characters.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Password (10–128 characters)',
              ),
            ),
          ],
        ),
      ),
      CheckboxListTile(
        key: const Key('termsCheckbox'),
        contentPadding: EdgeInsets.zero,
        value: terms,
        onChanged: busy || versionChanged || current.terms == null
            ? null
            : (v) => setState(() => terms = v ?? false),
        title: const Text('I accept the current R0 Terms'),
      ),
      OnboardingError(error),
      if (widget.reloadReference != null)
        OutlinedButton(
          key: const Key('reloadRegistrationTerms'),
          onPressed: busy ? null : reload,
          child: const Text('Reload current account Terms'),
        ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: FilledButton(
          key: const Key('registerSubmit'),
          onPressed: busy || versionChanged ? null : submit,
          child: Text(busy ? 'Creating…' : 'Continue to email verification'),
        ),
      ),
      if (widget.signIn != null)
        TextButton(
          key: const Key('registrationSignIn'),
          onPressed: busy ? null : widget.signIn,
          child: const Text('Already registered? Return to sign-in'),
        ),
    ],
  );
}

class Otp extends StatefulWidget {
  const Otp({
    super.key,
    required this.api,
    required this.email,
    required this.mockOtp,
    required this.back,
    required this.done,
    this.registration,
  });
  final MimiGoApi api;
  final String email;
  final String? mockOtp;
  final VoidCallback back;
  final Future<void> Function() done;
  final RegistrationResult? registration;
  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  final code = TextEditingController();
  late final model = EmailVerificationState(widget.api, widget.email);
  @override
  void dispose() {
    code.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    await model.submit(code.text, widget.done);
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: model,
    builder: (c, _) => Frame(
      title: model.verified
          ? 'Synthetic email verified'
          : 'Verify synthetic email',
      back: model.busy ? null : widget.back,
      children: [
        Text(
          widget.mockOtp == null
              ? 'No mock code was returned. Enter the development mock code from the Backend operator.'
              : 'Development mock OTP returned by Backend: ${widget.mockOtp}. No email was sent.',
        ),
        Text('Synthetic account: ${widget.email}'),
        if (widget.registration != null) ...[
          Text(widget.registration!.notice),
          Text(
            'Code expiry returned by service: ${widget.registration!.otpExpiresAt.toUtc().toIso8601String()}',
          ),
        ],
        const Text(
          'Wrong, expired and unavailable codes receive the same response. No resend endpoint exists; a development operator must resolve an expired or locked verification. You can return to sign-in without creating another account.',
        ),
        if (model.busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Verifying and signing in',
          ),
        if (model.verified)
          const Text(
            'Email is verified. Retry sign-in without submitting the code again.',
          ),
        TextField(
          key: const Key('otpCode'),
          controller: code,
          enabled: !model.busy && !model.verified,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Six-digit mock code'),
        ),
        OnboardingError(model.error),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: FilledButton(
            key: const Key('otpVerify'),
            onPressed: model.busy ? null : submit,
            child: Text(
              model.busy
                  ? 'Checking…'
                  : model.verified
                  ? 'Retry parent sign-in'
                  : 'Verify and sign in',
            ),
          ),
        ),
      ],
    ),
  );
}

class Privacy extends StatefulWidget {
  const Privacy({
    super.key,
    required this.attempt,
    required this.begin,
    required this.declined,
    required this.next,
    this.parentHome,
  });
  final OnboardingAttempt? attempt;
  final Future<void> Function() begin;
  final VoidCallback declined, next;
  final VoidCallback? parentHome;
  @override
  State<Privacy> createState() => _PrivacyState();
}

class _PrivacyState extends State<Privacy> {
  bool guardian = false, busy = false;
  final choices = <String, bool>{};
  ApiFailure? error;
  @override
  void didUpdateWidget(covariant Privacy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attempt?.id != widget.attempt?.id) {
      guardian = false;
      choices.clear();
    }
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      guardian = false;
      choices.clear();
    });
    try {
      await widget.begin();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final notices = widget.attempt?.notices ?? const <Notice>[];
    final allowed =
        guardian &&
        notices.isNotEmpty &&
        !busy &&
        notices.every((n) => choices[n.purposeCode] == true);
    return Frame(
      title: 'Protect your child’s information',
      children: [
        const Text(
          'No child alias or date of birth is sent before an authenticated Parent starts a PII-free attempt and actively affirms each displayed core purpose.',
        ),
        const Text(
          'R0 SYNTHETIC NOTICE · These are mock purpose/version records, not a production legal consent flow. Self-declaration and email verification do not establish guardian authority. No full legal notice text is supplied by this API.',
        ),
        if (busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading independent privacy notices',
          ),
        if (widget.attempt == null)
          SizedBox(
            height: 64,
            child: FilledButton(
              key: const Key('loadAttempt'),
              onPressed: busy ? null : load,
              child: Text(
                busy
                    ? 'Loading consent notices…'
                    : 'Load current consent notices',
              ),
            ),
          )
        else ...[
          Text('Attempt expires: ${widget.attempt!.expiresAt.toLocal()}'),
          CheckboxListTile(
            key: const Key('guardianAssertion'),
            contentPadding: EdgeInsets.zero,
            value: guardian,
            onChanged: busy
                ? null
                : (v) => setState(() => guardian = v ?? false),
            title: const Text(
              'I state I am a parent or authorised representative.',
            ),
          ),
          ...notices.map(
            (n) => Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Required mock purpose: ${n.purposeCode}',
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        Text('Notice version: ${n.label} · ${n.versionId}'),
                        if (n.effectiveFrom != null)
                          Text(
                            'Effective: ${n.effectiveFrom!.toUtc().toIso8601String()}',
                          ),
                        if (n.contentHash != null)
                          Text('Content hash: ${n.contentHash}'),
                        const Text(
                          'Synthetic development only · not approved for real children.',
                        ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    key: Key('consent-${n.purposeCode}'),
                    contentPadding: EdgeInsets.zero,
                    value: choices[n.purposeCode] ?? false,
                    onChanged: busy
                        ? null
                        : (v) => setState(
                            () => choices[n.purposeCode] = v ?? false,
                          ),
                    title: Text('I affirm ${n.purposeCode} (${n.label}).'),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Choices are unchecked by default and apply only to this new child.',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: FilledButton(
              key: const Key('privacyContinue'),
              onPressed: allowed
                  ? () {
                      if (!widget.attempt!.expiresAt.isAfter(DateTime.now())) {
                        setState(() {
                          guardian = false;
                          choices.clear();
                          error = const ApiFailure(
                            'Expired',
                            code: 'ATTEMPT_EXPIRED',
                            status: 422,
                          );
                        });
                      } else {
                        widget.next();
                      }
                    }
                  : null,
              child: const Text('Continue to child profile'),
            ),
          ),
        ],
        if (widget.attempt != null)
          OutlinedButton(
            key: const Key('reloadPrivacyNotices'),
            onPressed: busy ? null : load,
            child: const Text('Restart with fresh privacy notices'),
          ),
        OnboardingError(error),
        TextButton(
          key: const Key('privacyDecline'),
          onPressed: busy ? null : widget.declined,
          child: const Text('I do not agree'),
        ),
        if (widget.parentHome != null)
          TextButton(
            key: const Key('privacyParentHome'),
            onPressed: busy ? null : widget.parentHome,
            child: const Text('Cancel onboarding and return to Parent Home'),
          ),
      ],
    );
  }
}

class ChildDraft {
  const ChildDraft(this.alias, this.dob, this.avatar);
  final String alias, avatar;
  final DateTime dob;
}

class ChildInput extends StatefulWidget {
  const ChildInput({
    super.key,
    required this.back,
    required this.next,
    this.initialDraft,
  });
  final VoidCallback back;
  final void Function(ChildDraft) next;
  final ChildDraft? initialDraft;
  @override
  State<ChildInput> createState() => _ChildInputState();
}

class _ChildInputState extends State<ChildInput> {
  late final alias = TextEditingController(
        text: widget.initialDraft?.alias ?? 'SYN-Bee',
      ),
      dob = TextEditingController(
        text: widget.initialDraft == null
            ? ''
            : dateText(widget.initialDraft!.dob),
      );
  late String avatar = widget.initialDraft?.avatar ?? 'bear-blue';
  ApiFailure? error;
  @override
  void dispose() {
    alias.dispose();
    dob.dispose();
    super.dispose();
  }

  void submit() {
    final date = parseDate(dob.text);
    if (!alias.text.trim().startsWith('SYN-') ||
        alias.text.trim().length > 40 ||
        date == null ||
        !acceptableChildDob(date, vietnamToday())) {
      setState(
        () => error = const ApiFailure(
          'Use a SYN- alias up to 40 characters and a past date from 1900-01-01 (YYYY-MM-DD).',
          code: 'INVALID_CHILD_PROFILE',
        ),
      );
      return;
    }
    widget.next(ChildDraft(alias.text.trim(), date, avatar));
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Create child profile',
    back: widget.back,
    children: [
      const Text('Available only after per-attempt consent.'),
      const Text(
        'Use synthetic information only. A profile may be outside program age; the service determines eligibility after creation. This does not grant lesson access.',
      ),
      TextField(
        key: const Key('childName'),
        controller: alias,
        decoration: const InputDecoration(
          labelText: 'Synthetic child alias (SYN-…)',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('childDob'),
        controller: dob,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Date of birth * (YYYY-MM-DD)',
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Choose a predefined avatar',
        style: Theme.of(c).textTheme.titleMedium,
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final option in const [
            ('bear-blue', 'Blue bear', Icons.pets_outlined),
            ('bee-yellow', 'Sunny bee', Icons.emoji_nature_outlined),
          ])
            ChoiceChip(
              key: Key('avatar-${option.$1}'),
              selected: avatar == option.$1,
              onSelected: (_) => setState(() => avatar = option.$1),
              avatar: Icon(option.$3),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(option.$2),
              ),
            ),
        ],
      ),
      ErrorText(error),
      const Text(
        'Only the selected predefined avatar key is sent. No photo upload or external media is used.',
      ),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('childContinue'),
          onPressed: submit,
          child: const Text('Review profile'),
        ),
      ),
    ],
  );
}

class Review extends StatefulWidget {
  const Review({
    super.key,
    required this.api,
    required this.attempt,
    required this.draft,
    required this.back,
    required this.created,
    this.termsRequired,
    required this.model,
    required this.restart,
    required this.parentHome,
    required this.accountEntry,
  });
  final MimiGoApi api;
  final OnboardingAttempt attempt;
  final ChildDraft draft;
  final VoidCallback back;
  final VoidCallback? termsRequired;
  final ChildCreationState model;
  final VoidCallback restart, parentHome, accountEntry;
  final Future<void> Function(ChildSummary) created;
  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  bool leaving = false;
  Future<void> submit() async {
    if (leaving) return;
    final value = await widget.model.submit();
    if (!mounted) return;
    if (widget.model.error?.code == 'TERMS_ACCEPTANCE_REQUIRED') {
      widget.termsRequired?.call();
    } else if (value != null && !leaving) {
      setState(() => leaving = true);
      await widget.created(value);
    }
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.model,
    builder: (c, _) => Frame(
      title: 'Review profile',
      back: widget.model.canEdit && !leaving ? widget.back : null,
      children: [
        ListTile(
          title: const Text('Synthetic alias'),
          subtitle: Text(widget.draft.alias),
        ),
        ListTile(
          title: const Text('Date of birth'),
          subtitle: Text(
            '${dateText(widget.draft.dob)} · the service will return age and eligibility',
          ),
        ),
        Text('Predefined avatar: ${widget.draft.avatar}'),
        const Text('Reviewed independently for this new child:'),
        for (final notice in widget.attempt.notices)
          Text('${notice.purposeCode} · ${notice.label} · ${notice.versionId}'),
        if (widget.model.busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Creating synthetic child profile',
          ),
        const Text(
          'The same idempotency key and exact payload are retained for a safe retry after a connectivity failure.',
        ),
        OnboardingError(widget.model.error),
        if (widget.model.sent && widget.model.result == null)
          const Text(
            'The request is locked after submission. Retry the identical request if its outcome is unknown; do not change the profile or create it again. Returning to account entry discards this in-memory request; check Parent Home after signing in before adding another child.',
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: FilledButton(
            key: const Key('createChild'),
            onPressed: widget.model.canSubmit && !leaving ? submit : null,
            child: Text(
              widget.model.busy
                  ? 'Creating…'
                  : widget.model.sent
                  ? 'Retry identical request'
                  : 'Create synthetic profile',
            ),
          ),
        ),
        if (widget.model.needsNotices)
          OutlinedButton(
            key: const Key('restartChildPrivacy'),
            onPressed: widget.model.busy || leaving ? null : widget.restart,
            child: const Text('Restart privacy review'),
          ),
        if (widget.model.conflict)
          OutlinedButton(
            key: const Key('creationParentHome'),
            onPressed: widget.model.busy || leaving ? null : widget.parentHome,
            child: const Text('Check profiles in Parent Home'),
          ),
        TextButton(
          key: const Key('creationAccountEntry'),
          onPressed: leaving ? null : widget.accountEntry,
          child: const Text('Return to account entry'),
        ),
      ],
    ),
  );
}

class ChildHome extends StatelessWidget {
  const ChildHome({
    super.key,
    required this.child,
    required this.fixture,
    required this.category,
    required this.accountEntry,
    this.explore,
    this.english,
  });
  final ChildSummary child;
  final bool fixture;
  final ValueChanged<LearningCategory> category;
  final VoidCallback accountEntry;
  final VoidCallback? explore;
  final VoidCallback? english;
  @override
  Widget build(BuildContext c) => Frame(
    title: 'Hi, ${child.alias}!',
    children: [
      Text(
        fixture
            ? 'Child Mode · fixture demonstrations'
            : 'Child Mode · live account',
      ),
      const SizedBox(height: 16),
      if (explore != null)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: FilledButton.icon(
            key: const Key('openCurriculum'),
            onPressed: explore,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore curriculum'),
          ),
        ),
      Text(
        fixture
            ? 'Development shortcuts · legacy fixture demos'
            : 'Learning shortcuts',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...LearningCategory.values
              .where((value) => fixture || value != LearningCategory.arts)
              .map(
                (value) => SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    key: Key('category-${value.name}'),
                    onPressed: () => category(value),
                    child: Text(value.label),
                  ),
                ),
              ),
          if (!fixture)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: OutlinedButton(
                key: const Key('category-english'),
                onPressed: english,
                child: const Text('English'),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Parent verification is not available inside Child Mode yet. Return to account entry for a parent to sign in again.',
      ),
      SizedBox(
        height: 64,
        child: OutlinedButton(
          key: const Key('childParentGate'),
          onPressed: null,
          child: const Text('Open authenticated Parent Area'),
        ),
      ),
      TextButton(
        key: const Key('returnAccountEntry'),
        onPressed: accountEntry,
        child: const Text('Return to account entry'),
      ),
    ],
  );
}

class ParentArea extends StatefulWidget {
  const ParentArea({
    super.key,
    required this.children,
    required this.active,
    required this.currentTermsAccepted,
    required this.refresh,
    required this.add,
    required this.select,
    this.home,
  });
  final List<ChildSummary> children;
  final ChildSummary? active;
  final bool currentTermsAccepted;
  final Future<void> Function() refresh;
  final VoidCallback add;
  final Future<void> Function(ChildSummary) select;
  final Widget? home;
  @override
  State<ParentArea> createState() => _ParentAreaState();
}

class _ParentAreaState extends State<ParentArea> {
  bool busy = false;
  ApiFailure? error;
  Future<void> reload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.refresh();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: widget.home == null ? 'Authenticated Parent Area' : 'Parent Home',
    children: widget.home != null
        ? [widget.home!]
        : [
            const Text(
              'Access relies on the in-memory authenticated bearer session. Parent PIN, refresh/logout and consent withdrawal remain unavailable.',
            ),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: busy ? null : reload,
                child: Text(
                  busy ? 'Loading profiles…' : 'Refresh child profiles',
                ),
              ),
            ),
            ErrorText(error),
            if (!widget.currentTermsAccepted)
              const Text(
                'Adding a child requires the current account Terms. Parent Home handles any server-required re-acceptance.',
              ),
            if (widget.children.isEmpty)
              const Text('No child profiles returned.')
            else
              ...widget.children.map(
                (x) => ListTile(
                  title: Text(x.alias),
                  subtitle: Text('${dateText(x.dateOfBirth)} · ${x.state}'),
                  trailing: x.id == widget.active?.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => widget.select(x),
                ),
              ),
            SizedBox(
              height: 64,
              child: FilledButton(
                key: const Key('addChild'),
                onPressed: widget.currentTermsAccepted ? widget.add : null,
                child: const Text('Add another child'),
              ),
            ),
          ],
  );
}

class ParentOnly extends StatelessWidget {
  const ParentOnly({super.key, required this.back, this.parentHome});
  final VoidCallback back;
  final VoidCallback? parentHome;
  @override
  Widget build(BuildContext c) => Frame(
    title: 'Parent account ready',
    back: back,
    children: [
      const Text(
        'You did not affirm all required child purposes. No child alias, date of birth or profile was sent or stored.',
      ),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('reviewPrivacyAgain'),
          onPressed: back,
          child: const Text('Review privacy choices'),
        ),
      ),
      if (parentHome != null)
        OutlinedButton(
          key: const Key('refusalParentHome'),
          onPressed: parentHome,
          child: const Text('Continue with Parent Home without adding a child'),
        ),
    ],
  );
}

String errorText(ApiFailure x) =>
    '${x.code ?? 'REQUEST_FAILED'}${x.requestId == null ? '' : ' · request ${x.requestId}'}: ${x.message}';
String dateText(DateTime x) =>
    '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
DateTime? parseDate(String x) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(x)) return null;
  final p = x.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  final value = DateTime(y, m, d);
  return value.year == y && value.month == m && value.day == d ? value : null;
}

int productAge(DateTime dob, DateTime today) {
  var m = dob.month, d = dob.day;
  if (m == 2 && d == 29 && !isLeapYear(today.year)) {
    m = 3;
    d = 1;
  }
  var age = today.year - dob.year;
  if (today.month < m || (today.month == m && today.day < d)) age--;
  return age;
}

bool isLeapYear(int y) => y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
