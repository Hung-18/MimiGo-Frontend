import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'child_content.dart';
import 'child_media_access.dart';
import 'api_failure.dart';
import 'learning_models.dart';
import 'learning_screens.dart';
import 'learning_session_memory.dart';
import 'parent_home.dart';
import 'curriculum_explorer.dart';
import 'terms_reacceptance.dart';
import 'parent_onboarding.dart';
import 'child_onboarding.dart';
import 'onboarding_resume.dart';
import 'parent_gate_api.dart';
import 'parent_gate_session.dart';
import 'parent_gate_screens.dart';
import 'mimigo_design.dart';
import 'mobile_demo.dart';
import 'po/po_design.dart';
import 'po/preview_app.dart';
import 'po/mobile_services.dart';
import 'po/resend_button.dart';
import 'po/po_boot.dart';

export 'api_failure.dart';

void main() {
  registerMimiFontLicenses();
  runApp(const PoBoot(application: MimiGoApp()));
}

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
  Future<OnboardingAttemptStatus> getOnboardingAttempt(String attemptId);
  Future<ChildSummary> createChild(CreateChildRequest value);
  Future<List<ChildSummary>> listChildren();
  Future<ChildDetail> getChild(String childId);
}

enum ApiMode { fixture, live }

class ApiConfiguration {
  const ApiConfiguration(
    this.mode,
    this.baseUrl, {
    this.parentGateEnabled = false,
    this.childMediaEnabled = false,
    this.childMediaBaseUrl = '',
  });
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
      defaultValue: 'https://mimigo-api-staging.onrender.com/api/v1',
    ),
    parentGateEnabled: const bool.fromEnvironment(
      'MIMIGO_PARENT_GATE_ENABLED',
      defaultValue: false,
    ),
    childMediaEnabled: const bool.fromEnvironment(
      'MIMIGO_CHILD_MEDIA_ENABLED',
      defaultValue: false,
    ),
    childMediaBaseUrl: const String.fromEnvironment(
      'MIMIGO_CHILD_MEDIA_BASE_URL',
      defaultValue: '',
    ),
  );
  final ApiMode mode;
  final String baseUrl;
  final bool parentGateEnabled;
  final bool childMediaEnabled;
  final String childMediaBaseUrl;
  MimiGoApi createClient() => mode == ApiMode.live
      ? LiveMimiGoApi(
          Uri.parse(baseUrl),
          parentGateEnabled: parentGateEnabled,
          childMediaEnabled: childMediaEnabled,
          childMediaBaseUrl: childMediaBaseUrl,
        )
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
    this.currentTermsAccepted, {
    this.parentGate,
  });
  final String parentId, email, displayName;
  final bool currentTermsAccepted;
  final ParentGateStatus? parentGate;
}

/// Safe Parent Home projection. Deliberately does not model, cache or expose
/// openSessions, lesson-history items or progress received in the workspace.
class WorkspaceChildMetadata {
  const WorkspaceChildMetadata(
    this.child,
    this.catalogStatus, [
    this.learningEntryStatus,
  ]);
  factory WorkspaceChildMetadata.fromJson(
    Map<String, dynamic> json, {
    bool rosterOnly = false,
  }) {
    final child = _child(_map(json['child']), rosterOnly: rosterOnly);
    final status = _string(_map(json['catalog']), 'status');
    if (!{
      'AVAILABLE',
      'NO_ELIGIBLE_CONTENT',
      'CHILD_OUTSIDE_PROGRAM_AGE',
      'PERMISSION_NOT_GRANTED',
      'CHILD_NOT_ACTIVE',
    }.contains(status))
      throw const ApiInvalidResponse('Invalid catalog availability.');
    final entry = _string(_map(json['learningEntry']), 'status');
    if (!{
      'READY',
      'CHILD_NOT_ACTIVE',
      'PERMISSION_NOT_GRANTED',
      'CHILD_OUTSIDE_PROGRAM_AGE',
      'NO_ELIGIBLE_CONTENT',
    }.contains(entry))
      throw const ApiInvalidResponse('Invalid learning entry availability.');
    return WorkspaceChildMetadata(child, status, entry);
  }
  final ChildSummary child;
  final String catalogStatus;
  final String? learningEntryStatus;
}

class ParentWorkspace {
  const ParentWorkspace(this.children, this.disclaimer);
  factory ParentWorkspace.fromJson(
    Map<String, dynamic> json, {
    bool rosterOnly = false,
  }) {
    final items = json['children'];
    if (items is! List)
      throw const ApiInvalidResponse('Invalid parent workspace children.');
    final children = items
        .map(
          (item) => WorkspaceChildMetadata.fromJson(
            _map(item),
            rosterOnly: rosterOnly,
          ),
        )
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

class OnboardingAttemptStatus {
  const OnboardingAttemptStatus(this.attempt, this.status, this.childId);
  factory OnboardingAttemptStatus.fromJson(Map<String, dynamic> json) {
    final status = _string(json, 'status');
    if (!{
      'OPEN',
      'ATTEMPT_ALREADY_CONSUMED',
      'PARENT_NOT_ACTIVE',
      'TERMS_ACCEPTANCE_REQUIRED',
      'ATTEMPT_EXPIRED',
      'ATTEMPT_NOTICES_INCOMPLETE',
      'NOTICE_CHANGED_REDISPLAY_REQUIRED',
    }.contains(status))
      throw const ApiInvalidResponse('Invalid onboarding attempt status.');
    if (!json.containsKey('childId') ||
        (json['childId'] != null && json['childId'] is! String))
      throw const ApiInvalidResponse(
        'Invalid onboarding attempt child identity.',
      );
    final child = json['childId'] as String?;
    if ((status == 'ATTEMPT_ALREADY_CONSUMED') !=
            (child != null && child.isNotEmpty) ||
        (status != 'ATTEMPT_ALREADY_CONSUMED' && child != null))
      throw const ApiInvalidResponse(
        'Onboarding status and child identity do not match.',
      );
    return OnboardingAttemptStatus(
      OnboardingAttempt(
        _string(json, 'attemptId'),
        _date(json, 'expiresAt'),
        _notices(json['notices']),
      ),
      status,
      child,
    );
  }
  final OnboardingAttempt attempt;
  final String status;
  final String? childId;
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
    this.dateOfBirth,
    this.ageYears,
    required this.withinProgramAgeRange,
    required this.state,
    this.createdAt,
    this.stockAvatarKey,
  });
  final String id, alias, state;
  final DateTime? dateOfBirth, createdAt;
  final int? ageYears;
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
        .map(
          (child) => WorkspaceChildMetadata(
            child,
            child.withinProgramAgeRange
                ? 'NO_ELIGIBLE_CONTENT'
                : 'CHILD_OUTSIDE_PROGRAM_AGE',
            child.withinProgramAgeRange
                ? 'NO_ELIGIBLE_CONTENT'
                : 'CHILD_OUTSIDE_PROGRAM_AGE',
          ),
        )
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
  final _attemptChildren = <String, String>{};
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
  Future<OnboardingAttemptStatus> getOnboardingAttempt(String attemptId) async {
    _auth();
    await _wait();
    final attempt = _attempts[attemptId];
    if (attempt == null)
      throw const ApiFailure(
        'Unknown fixture attempt.',
        code: 'ATTEMPT_NOT_FOUND',
        status: 404,
      );
    final childId = _attemptChildren[attemptId];
    return OnboardingAttemptStatus(
      attempt,
      childId != null
          ? 'ATTEMPT_ALREADY_CONSUMED'
          : attempt.expiresAt.isAfter(DateTime.now())
          ? 'OPEN'
          : 'ATTEMPT_EXPIRED',
      childId,
    );
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
    _attemptChildren[value.attemptId] = child.id;
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

class LiveMimiGoApi
    implements MimiGoApi, ParentGateApi, ChildMediaAccess, MobileCapabilities {
  @override
  Future<ResendResult> resendVerification(String email) async =>
      ResendResult.fromJson(
        await _request(
          'POST',
          'auth/mock-email/resend',
          body: {'email': email},
        ),
      );
  @override
  late final PremiumService premium = PremiumService((
    method,
    path, {
    body,
    bool protected = false,
    Map<String, String>? headers,
  }) {
    if (!parentGateEnabled)
      throw const ApiFailure(
        'Parent Gate unavailable.',
        code: 'PARENT_GATE_REQUIRED',
        status: 403,
      );
    return _request(
      method,
      path,
      body: body,
      auth: true,
      requireProof: protected,
      headers: headers,
    );
  });
  @override
  late final ProfileService profiles = ProfileService((
    method,
    path, {
    body,
    bool protected = false,
    Map<String, String>? headers,
  }) {
    if (!parentGateEnabled)
      throw const ApiFailure(
        'Parent Gate unavailable.',
        code: 'PARENT_GATE_REQUIRED',
        status: 403,
      );
    return _request(
      method,
      path,
      body: body,
      auth: true,
      requireProof: true,
      headers: headers,
    );
  });
  @override
  final bool parentGateEnabled;
  @override
  bool get childMediaEnabled => _privateMediaOrigin != null;
  final bool _childMediaRequested;
  final String childMediaBaseUrl;
  Uri? get _privateMediaOrigin {
    if (!kDebugMode || !parentGateEnabled || !_childMediaRequested) return null;
    final uri = Uri.tryParse(childMediaBaseUrl);
    if (uri == null ||
        uri.scheme != 'http' ||
        !{'10.0.2.2', '127.0.0.1', 'localhost', '::1'}.contains(uri.host) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/'))
      return null;
    return uri;
  }

  @override
  Listenable get mediaSessionChanges => gateSession!;
  @override
  bool mediaSessionIsCurrent(String childId, String bearer) {
    final current = gateSession?.current;
    return _privateMediaOrigin != null &&
        current?.mode == SessionMode.child &&
        current?.childId == childId &&
        current?.token == bearer &&
        current!.expiresAt.isAfter(DateTime.now());
  }

  @override
  Future<ChildMediaSource> childMediaSource(
    String childId,
    String lessonId,
    String revisionId,
  ) async {
    final origin = _privateMediaOrigin;
    if (origin == null || gateSession == null) {
      throw const ApiFailure(
        'Private media is unavailable.',
        code: 'MEDIA_DISABLED',
        status: 404,
      );
    }
    return gateSession!.authorized(
      (token, _) async => ChildMediaSource(
        origin.replace(
          path:
              '/private/media/children/lessons/'
              '${Uri.encodeComponent(lessonId)}/revisions/'
              '${Uri.encodeComponent(revisionId)}/main-video',
        ),
        token,
      ),
      childId: childId,
    );
  }

  @override
  late final GateSessionCoordinator? gateSession = parentGateEnabled
      ? GateSessionCoordinator(
          _gateWire,
          _vault,
          credentialScope: baseUri.toString(),
        )
      : null;
  late final ParentGateService? _gate = gateSession == null
      ? null
      : ParentGateService(gateSession!, _gateWire);
  final CredentialVault _vault;
  @override
  Future<void> setParentPin(
    PinAction action,
    String password,
    String pin,
    String confirmation,
  ) => _gate!.setPin(action, password, pin, confirmation);
  @override
  Future<void> verifyParentArea(String pin) => _gate!.parentArea(pin);
  @override
  Future<void> switchChildContext(String pin, String childId) =>
      _gate!.enterChild(pin, childId);
  @override
  Future<List<ParentActivityItem>> parentActivity(String childId) =>
      _gate!.activity(childId);
  @override
  Future<int> revokeOtherDevices() => _gate!.revokeOthers();
  Future<Map<String, dynamic>> _gateWire(
    String method,
    String path, {
    Object? body,
    String? token,
    String? proof,
    Set<int>? statuses,
  }) => _rawRequest(
    method,
    path,
    body: body,
    token: token,
    proof: proof,
    statuses: statuses,
  );
  @override
  Future<OnboardingAttemptStatus> getOnboardingAttempt(
    String attemptId,
  ) async => OnboardingAttemptStatus.fromJson(
    await _request(
      'GET',
      'children/onboarding-attempts/${Uri.encodeComponent(attemptId)}',
      auth: true,
    ),
  );
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
        await _request(
          'GET',
          'children/$childId/curriculum',
          auth: true,
          learningChildId: childId,
        ),
      );
  @override
  Future<ParentWorkspace> learningWorkspace() async => ParentWorkspace.fromJson(
    await _request(
      'GET',
      'parents/me/learning-workspace',
      auth: true,
      includeProof: true,
    ),
    rosterOnly: parentGateEnabled,
  );
  LiveMimiGoApi(
    this.baseUri, {
    HttpClient? client,
    this.parentGateEnabled = false,
    bool childMediaEnabled = false,
    this.childMediaBaseUrl = '',
    CredentialVault? vault,
  }) : _childMediaRequested = childMediaEnabled,
       _client = client ?? HttpClient(),
       _vault = vault ?? const PlatformCredentialVault();
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
      learningChildId: childId,
    ),
  );
  @override
  Future<LessonList> lessons(String childId) async => LessonList.fromJson(
    await _request(
      'GET',
      'children/$childId/lessons',
      auth: true,
      learningChildId: childId,
    ),
  );
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async =>
      LessonDetail.fromJson(
        await _request(
          'GET',
          'children/$childId/lessons/$lessonId',
          auth: true,
          learningChildId: childId,
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
      learningChildId: childId,
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
      learningChildId: childId,
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
      learningChildId: childId,
      body: request.toJson(),
    ),
  );
  @override
  void clearSession() {
    _token = null;
    if (gateSession != null) {
      gateSession!.invalidateMemory();
      unawaited(gateSession!.forget().catchError((Object _) {}));
    }
  }

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
    if (gateSession != null) {
      await gateSession!.login(email, password);
      final session = gateSession!.current!;
      return LoginSession(session.token, session.expiresAt, session.parentId);
    }
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
    ParentGateStatus? status;
    if (parentGateEnabled) {
      final session = _map(x['session']);
      if (session['sessionMode'] != 'PARENT' ||
          session['sessionId'] != gateSession!.current?.sessionId ||
          x['parentId'] != gateSession!.current?.parentId) {
        await gateSession!.forget();
        throw const ApiInvalidResponse('Parent session identity mismatch.');
      }
      status = ParentGateStatus.fromJson(_map(x['parentGate']));
    }
    return ParentSummary(
      _string(x, 'parentId'),
      _string(x, 'email'),
      _string(x, 'displayName'),
      _bool(x, 'currentTermsAccepted'),
      parentGate: status,
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
    return items
        .map((v) => _child(_map(v), rosterOnly: parentGateEnabled))
        .toList(growable: false);
  }

  @override
  Future<ChildDetail> getChild(String id) async {
    final x = await _request(
      'GET',
      'children/${Uri.encodeComponent(id)}',
      auth: true,
      requireProof: true,
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
    String? learningChildId,
    bool requireProof = false,
    bool includeProof = false,
    Map<String, String>? headers,
  }) async {
    if (gateSession != null && auth) {
      return gateSession!.authorized(
        (token, proof) => _rawRequest(
          method,
          path,
          body: body,
          token: token,
          proof: requireProof || includeProof ? proof : null,
          headers: headers,
        ),
        childId: learningChildId,
        proofRequired: requireProof,
      );
    }
    if (auth && _token == null)
      throw const ApiFailure(
        'A Parent session is required.',
        code: 'UNAUTHENTICATED',
        status: 401,
      );
    return _rawRequest(
      method,
      path,
      body: body,
      token: auth ? _token : null,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> _rawRequest(
    String method,
    String path, {
    Object? body,
    String? token,
    String? proof,
    Set<int>? statuses,
    Map<String, String>? headers,
  }) async {
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
      if (token != null)
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (proof != null) req.headers.set('MimiGo-Parent-Proof', proof);
      headers?.forEach((name, value) => req.headers.set(name, value));
      if (body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 20));
      final id = response.headers.value('x-request-id');
      if (response.statusCode == 204) {
        await response.drain<void>().timeout(const Duration(seconds: 20));
        if (statuses != null && !statuses.contains(204))
          throw const ApiInvalidResponse('Unexpected response status.');
        return <String, dynamic>{};
      }
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
          retryAfterSeconds:
              int.tryParse(response.headers.value('retry-after') ?? '') ??
              (json['retryAfterSeconds'] is int
                  ? json['retryAfterSeconds'] as int
                  : null),
        );
      if (statuses != null && !statuses.contains(response.statusCode))
        throw const ApiInvalidResponse('Unexpected response status.');
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

ChildSummary _child(Map<String, dynamic> x, {bool rosterOnly = false}) =>
    ChildSummary(
      id: _string(x, 'childId'),
      alias: _string(x, 'childAlias'),
      dateOfBirth: rosterOnly
          ? null
          : parseDate(_string(x, 'dateOfBirth')) ??
                (throw const ApiInvalidResponse(
                  'Child response has an invalid dateOfBirth.',
                )),
      ageYears: rosterOnly
          ? null
          : x['ageYears'] is int
          ? x['ageYears'] as int
          : throw const ApiInvalidResponse(
              'Child response has an invalid ageYears.',
            ),
      withinProgramAgeRange: _bool(x, 'withinProgramAgeRange'),
      state: _string(x, 'state'),
      createdAt: rosterOnly ? null : _date(x, 'createdAt'),
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
  attemptResume,
  gatePin,
  gatedParent,
  restoringSession,
  sessionRecovery,
}

class MimiGoApp extends StatefulWidget {
  const MimiGoApp({super.key, this.api, this.configuration});
  final MimiGoApi? api;
  final ApiConfiguration? configuration;
  @override
  State<MimiGoApp> createState() => _MimiGoAppState();
}

class _MimiGoAppState extends State<MimiGoApp> with WidgetsBindingObserver {
  late final config =
      widget.configuration ?? ApiConfiguration.fromEnvironment();
  late final MimiGoApi api = widget.api ?? config.createClient();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  Page page = Page.welcome;
  OnboardingReference? reference;
  OnboardingAttempt? attempt;
  String? resumableAttemptId;
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
  ParentGateApi? get gate =>
      api is ParentGateApi && (api as ParentGateApi).parentGateEnabled
      ? api as ParentGateApi
      : null;
  GateSessionCoordinator? get gateSession => gate?.gateSession;
  String get currentChildId => gateSession?.current?.mode == SessionMode.child
      ? gateSession!.current!.childId!
      : active!.id;
  PinAction? gatePinAction;
  ChildSummary? gateChildTarget;
  ApiFailure? sessionRecoveryError;
  bool _hadGateSession = false;
  bool _openingGate = false;
  SessionMode? _seenGateMode;
  String? _seenGateChild;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gateSession?.addListener(gateChanged);
    if (gateSession != null) {
      page = Page.restoringSession;
      unawaited(restoreGateSession());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) gateSession?.dropProof();
  }

  void gateChanged() {
    if (!mounted) return;
    final current = gateSession?.current;
    final lost = _hadGateSession && current == null;
    final changed =
        _seenGateMode != current?.mode || _seenGateChild != current?.childId;
    _hadGateSession = current != null;
    _seenGateMode = current?.mode;
    _seenGateChild = current?.childId;
    if (lost) {
      setState(() {
        sessionGeneration++;
        authenticatedParent = null;
        parentWorkspace = null;
        children = [];
        active = null;
        attempt = null;
        draft = null;
        resumableAttemptId = null;
        createdProfile = null;
        creation?.dispose();
        creation = null;
        curriculum?.dispose();
        curriculum = null;
        pendingLearningAnswers.clear();
        learningSessions.clear();
        email = password = mockOtp = null;
        registration = null;
        reference = null;
        gateChildTarget = null;
        gatePinAction = null;
        page = Page.welcome;
        registrationEntryError = const ApiFailure(
          'Sign in again.',
          code: 'SESSION_REVOKED',
          status: 401,
        );
      });
    } else if (page == Page.gatedParent &&
        !(gateSession?.hasParentProof ?? false)) {
      setState(() {
        parentWorkspace = null;
        page = Page.parent;
      });
    } else if (changed &&
        current?.mode == SessionMode.child &&
        !{Page.gatePin, Page.restoringSession}.contains(page)) {
      setState(() {
        active = null;
        curriculum?.dispose();
        curriculum = null;
        selectedLessonId = null;
        selectedCategory = null;
        page = Page.child;
      });
    } else if (changed && current?.mode == SessionMode.parent && inChildMode) {
      setState(() {
        active = null;
        parentWorkspace = null;
        page = Page.restoringSession;
      });
      unawaited(recoverGateParent());
    }
  }

  Future<void> restoreGateSession() async {
    try {
      await gateSession!.restore();
      if (!mounted) return;
      if (gateSession!.current?.mode == SessionMode.child)
        setState(() => page = Page.child);
      else if (gateSession!.hasSession)
        await recoverGateParent();
      else
        setState(() => page = Page.welcome);
    } catch (_) {
      if (mounted)
        setState(() {
          page = Page.welcome;
          registrationEntryError = const ApiFailure(
            'Session unavailable.',
            code: 'SESSION_REVOKED',
            status: 401,
          );
        });
    }
  }

  Future<void> loadGateParent({bool protectedArea = false}) async {
    final parent = await api.parentMe();
    final workspace = await api.learningWorkspace();
    if (!mounted || gateSession?.current?.mode != SessionMode.parent) return;
    setState(() {
      authenticatedParent = parent;
      parentWorkspace = workspace;
      children = workspace.children.map((c) => c.child).toList();
      active = null;
      page = protectedArea && (gateSession?.hasParentProof ?? false)
          ? Page.gatedParent
          : Page.parent;
    });
  }

  Future<void> recoverGateParent() async {
    try {
      await loadGateParent();
    } on ApiFailure catch (failure) {
      if (mounted && gateSession?.hasSession == true)
        setState(() {
          sessionRecoveryError = failure;
          page = Page.sessionRecovery;
        });
    }
  }

  Future<void> openGatePin({ChildSummary? child, PinAction? action}) async {
    if (gate == null || _openingGate) return;
    _openingGate = true;
    if (gateSession?.current?.mode == SessionMode.parent) {
      setState(() => page = Page.restoringSession);
      try {
        final parent = await api.parentMe();
        if (!mounted) return;
        authenticatedParent = parent;
      } on ApiFailure catch (failure) {
        if (mounted && gateSession?.hasSession == true)
          setState(() {
            sessionRecoveryError = failure;
            page = Page.sessionRecovery;
          });
        _openingGate = false;
        return;
      }
    }
    _openingGate = false;
    if (!mounted || gateSession?.hasSession != true) return;
    setState(() {
      gateChildTarget = child;
      gatePinAction = action;
      page = Page.gatePin;
    });
  }

  void openProtectedParent() {
    if (gateSession?.hasParentProof ?? false)
      setState(() => page = Page.gatedParent);
    else
      openGatePin();
  }

  Future<void> gateSucceeded() async {
    if (gateChildTarget != null) {
      if (gateSession?.current?.mode != SessionMode.child ||
          gateSession?.current?.childId != gateChildTarget!.id)
        throw const ApiInvalidResponse('Child transition was not confirmed.');
      setState(() {
        active = gateChildTarget;
        gateChildTarget = null;
        gatePinAction = null;
        resumableAttemptId = null;
        attempt = null;
        draft = null;
        curriculum?.dispose();
        curriculum = null;
        page = Page.child;
      });
    } else {
      final authorized = gatePinAction == null;
      gatePinAction = null;
      await loadGateParent(protectedArea: authorized);
    }
  }

  void gateBack() {
    if (gateSession?.current?.mode == SessionMode.child)
      setState(() => page = Page.child);
    else {
      setState(() => page = Page.restoringSession);
      unawaited(recoverGateParent());
    }
  }

  void gateRecover() {
    if (gateSession?.current?.mode == SessionMode.child) {
      returnToAccountEntry();
      return;
    }
    openGatePin(
      action: authenticatedParent?.parentGate?.status == 'NOT_ENROLLED'
          ? PinAction.enroll
          : PinAction.reset,
    );
  }

  Page get safePage {
    final mode = gateSession?.current?.mode;
    if (gate != null &&
        mode == SessionMode.parent &&
        {
          Page.child,
          Page.category,
          Page.explorer,
          Page.learningLesson,
          Page.demo,
        }.contains(page))
      return authenticatedParent == null ? Page.sessionRecovery : Page.parent;
    if (mode == SessionMode.child &&
        !{
          Page.child,
          Page.category,
          Page.explorer,
          Page.learningLesson,
          Page.demo,
          Page.gatePin,
          Page.restoringSession,
        }.contains(page))
      return Page.child;
    if (gate != null &&
        mode == null &&
        !{
          Page.welcome,
          Page.signIn,
          Page.register,
          Page.otp,
          Page.restoringSession,
        }.contains(page))
      return Page.welcome;
    if (page == Page.gatedParent && !(gateSession?.hasParentProof ?? false))
      return authenticatedParent == null ? Page.sessionRecovery : Page.parent;
    return page;
  }

  bool get inChildMode =>
      gateSession?.current?.mode == SessionMode.child ||
      {
        Page.child,
        Page.category,
        Page.explorer,
        Page.learningLesson,
        Page.demo,
      }.contains(page);

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
    if (gateSession != null) {
      try {
        await gateSession!.logout();
      } on ApiFailure catch (failure) {
        registrationEntryError = failure.code == 'SECURE_STORAGE_UNAVAILABLE'
            ? failure
            : const ApiFailure(
                'Remote logout not confirmed. Local session ended.',
                code: 'LOGOUT_UNCONFIRMED',
              );
      }
    } else
      api.clearSession();
    if (!mounted) return;
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
      resumableAttemptId = null;
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
    if (page == Page.gatePin) {
      gateBack();
    } else if (page == Page.gatedParent) {
      goParentHome();
    } else if (page == Page.attemptResume) {
      if (creation?.sent == true)
        setState(() => page = Page.review);
      else
        goParentHome();
    } else if (page == Page.childCreated) {
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
      curriculum = CurriculumExplorerState(api, currentChildId);
      if (domain != null) curriculum!.chooseDomain(domain);
      page = Page.explorer;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gateSession?.removeListener(gateChanged);
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
        setState(() {
          attempt = value;
          resumableAttemptId = value.id;
        });
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
        !{
          Page.parent,
          Page.privacy,
          Page.review,
          Page.attemptResume,
        }.contains(page))
      return;
    setState(() {
      attempt = null;
      resumableAttemptId = null;
      draft = null;
      creation?.dispose();
      creation = null;
      parentWorkspace = null;
      children = [];
      page = Page.terms;
    });
  }

  void goParentHome() {
    if (authenticatedParent == null || inChildMode) return;
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
    if (authenticatedParent == null || inChildMode) return;
    setState(() {
      attempt = null;
      resumableAttemptId = null;
      draft = null;
      creation?.dispose();
      creation = null;
      createdProfile = null;
      active = null;
      page = Page.privacy;
    });
  }

  void openAttemptResume() {
    if (authenticatedParent == null ||
        inChildMode ||
        resumableAttemptId == null ||
        creation?.busy == true)
      return;
    setState(() => page = Page.attemptResume);
  }

  void reviewChild(ChildDraft value) {
    if (inChildMode || attempt == null || creation?.sent == true) return;
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
    theme: poTheme(),
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
          page != Page.attemptResume &&
          page != Page.gatePin &&
          page != Page.gatedParent &&
          page != Page.restoringSession &&
          page != Page.terms,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) childBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (safePage) {
            Page.sessionRecovery => Frame(
              title: 'Validate Parent session',
              children: [
                GateError(sessionRecoveryError),
                FilledButton(
                  key: const Key('retryParentSession'),
                  onPressed: recoverGateParent,
                  child: const Text('Retry session validation'),
                ),
                TextButton(
                  onPressed: returnToAccountEntry,
                  child: const Text('Sign out and return to account entry'),
                ),
              ],
            ),
            Page.restoringSession => const Frame(
              title: 'Checking device session',
              children: [
                LinearProgressIndicator(semanticsLabel: 'Validating session'),
              ],
            ),
            Page.gatePin => GatePinScreen(
              key: ValueKey((gatePinAction, gateChildTarget?.id)),
              api: gate!,
              childId: gateChildTarget?.id,
              pinAction: gatePinAction,
              status: gateSession?.current?.mode == SessionMode.parent
                  ? authenticatedParent?.parentGate
                  : null,
              done: gateSucceeded,
              back: gateBack,
              accountEntry: returnToAccountEntry,
              recover: gateRecover,
            ),
            Page.gatedParent => GatedParentArea(
              api: api,
              gate: gate!,
              home: goParentHome,
              reverify: openProtectedParent,
              changePin: () => openGatePin(action: PinAction.change),
              resetPin: () => openGatePin(action: PinAction.reset),
            ),
            Page.welcome => Welcome(
              live: config.mode == ApiMode.live,
              start: start,
              busy: startingRegistration,
              error: registrationEntryError,
              signIn: () => setState(() => page = Page.signIn),
            ),
            Page.signIn => SignIn(
              parentGateEnabled: gate != null,
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
              live: config.mode == ApiMode.live,
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
              checkAttempt: openAttemptResume,
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
              checkAttempt: openAttemptResume,
              termsRequired: requireCurrentTerms,
              back: childBack,
              created: (v) async {
                setState(() {
                  createdProfile = v;
                  resumableAttemptId = null;
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
              child: active,
              gateAvailable: gate != null,
              parentArea: openProtectedParent,
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
            Page.attemptResume => Frame(
              title: 'Check pending child onboarding',
              children: [
                OnboardingAttemptResume(
                  api: api,
                  attemptId: resumableAttemptId!,
                  hasPendingCreation: creation?.sent == true,
                  resume: (value) {
                    if (!mounted || inChildMode) return;
                    setState(() {
                      if (creation?.sent == true) {
                        page = Page.review;
                      } else {
                        attempt = value;
                        draft = null;
                        creation?.dispose();
                        creation = null;
                        page = Page.privacy;
                      }
                    });
                  },
                  consumed: () {
                    resumableAttemptId = null;
                    goParentHome();
                  },
                  termsRequired: requireCurrentTerms,
                  restart: beginChildOnboarding,
                  parentHome: childBack,
                  accountEntry: returnToAccountEntry,
                ),
              ],
            ),
            Page.category => Frame(
              childMode: true,
              wide: true,
              title: selectedCategory!.label,
              children: [
                if (config.mode == ApiMode.live &&
                    selectedCategory == LearningCategory.math)
                  MathLessonCatalog(
                    api: api,
                    childId: currentChildId,
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
              childMode: true,
              wide: true,
              title: 'Curriculum Explorer',
              children: [
                CurriculumExplorer(
                  model: curriculum!,
                  childAlias: active?.alias ?? 'Child Mode',
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
              childMode: true,
              wide: true,
              title: learningFromExplorer
                  ? 'Learning · development/demo'
                  : 'Math learning · development/demo',
              children: [
                LearningLessonView(
                  key: ValueKey((currentChildId, selectedLessonId)),
                  api: api,
                  childId: currentChildId,
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
                openParentArea: gate == null ? null : openProtectedParent,
                setupPin: gate == null
                    ? null
                    : () => openGatePin(
                        action:
                            authenticatedParent?.parentGate?.status ==
                                'NOT_ENROLLED'
                            ? PinAction.enroll
                            : PinAction.reset,
                      ),
                resumeOnboarding: resumableAttemptId == null
                    ? null
                    : openAttemptResume,
                enterChild: (child) {
                  if (inChildMode ||
                      child.state != 'ACTIVE' ||
                      !child.withinProgramAgeRange)
                    return;
                  if (gate != null) {
                    openGatePin(child: child);
                    return;
                  }
                  setState(() {
                    curriculum?.dispose();
                    curriculum = null;
                    active = child;
                    selectedCategory = null;
                    selectedLessonId = null;
                    page = Page.child;
                  });
                },
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
    this.childMode = false,
    this.wide = false,
    this.demoPresentation = false,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? back;
  final bool childMode, wide;
  final bool demoPresentation;
  @override
  Widget build(BuildContext c) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MimiColors.sky, MimiColors.canvas, Colors.white],
        stops: [0, .45, 1],
      ),
    ),
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(c).width < 400 ? 16 : 24,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? MimiSpace.learningWidth : MimiSpace.parentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (back != null) ...[
                    Container(
                      width: childMode ? 64 : 48,
                      height: childMode ? 64 : 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: BackButton(onPressed: back),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: title == 'MimiGo'
                            ? Theme.of(c).textTheme.displaySmall
                            : Theme.of(c).textTheme.headlineLarge,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!demoPresentation) const InternalBanner(),
              const SizedBox(height: 20),
              MimiPanel(
                padding: EdgeInsets.all(
                  MediaQuery.textScalerOf(c).scale(16) > 24 ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in children)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: child is SizedBox ? 0 : 12,
                        ),
                        child: child,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class InternalBanner extends StatelessWidget {
  const InternalBanner({super.key});
  @override
  Widget build(BuildContext c) => const MimiNotice(
    icon: Icons.shield_outlined,
    color: Color(0xFFFFF4CD),
    child: Text('R0 SYNTHETIC ONLY — not for real families.'),
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
  Widget build(BuildContext c) => PoScaffold(
    preview: !live,
    title: 'MimiGo',
    children: [
      const PoGarden(
        title: 'Cùng Mimi\nkhám phá thế giới',
        subtitle: 'Học qua những điều bé yêu thích.',
      ),
      if (!live) ...[
        PoAction(
          'Khám phá giao diện mới',
          key: const Key('poPreview'),
          icon: Icons.auto_awesome_rounded,
          onPressed: () => Navigator.of(c)
              .push(MaterialPageRoute<void>(builder: (_) => const PoPreview())),
        ),
        PoAction(
          'Thử luồng đăng ký mẫu',
          secondary: true,
          onPressed: () => Navigator.of(c).push(
            MaterialPageRoute<void>(
              builder: (_) => const PreviewRegistration(),
            ),
          ),
        ),
      ],
      if (live)
        const PoCard(
          color: PoPalette.peach,
          child: Text(
            'LIVE API · Staging tổng hợp. Đăng ký có thể chỉ mở cho email thử nghiệm được cho phép. Không nhập dữ liệu của trẻ thật. Chế độ API không chuyển sang dữ liệu mẫu khi gặp lỗi.',
          ),
        ),
      const Text(
        'Một gia đình, nhiều hành trình riêng. Ba mẹ quản lý, bé tự do khám phá trong không gian học của mình.',
      ),
      TextButton(
        key: const Key('welcomeSignIn'),
        onPressed: busy ? null : signIn,
        child: const Text('Ba mẹ đã có tài khoản? Đăng nhập'),
      ),
      if (!live) ...[
        OutlinedButton.icon(
          key: const Key('welcomeMobileDemo'),
          onPressed: busy
              ? null
              : () => Navigator.of(c).push(
                  MaterialPageRoute<void>(builder: (_) => const MobileDemo()),
                ),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Khám phá bản demo'),
        ),
        const Divider(height: 24),
        const Text('Dành cho phụ huynh · Luồng tài khoản thử nghiệm'),
      ],
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: FilledButton(
          key: const Key('welcomeStart'),
          style: FilledButton.styleFrom(
            backgroundColor: MimiColors.yellow,
            foregroundColor: MimiColors.ink,
          ),
          onPressed: busy ? null : start,
          child: Text(
            busy ? 'Đang tải phiên bản điều khoản…' : 'Tạo tài khoản phụ huynh',
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (busy)
        const LinearProgressIndicator(
          semanticsLabel: 'Loading account reference',
        ),
      OnboardingError(error),
      const Divider(height: 32),
      Text(
        'Thế giới nhỏ, khám phá lớn',
        style: Theme.of(c).textTheme.titleLarge,
      ),
      const Text(
        '6 lĩnh vực trong khung học · nội dung khả dụng do dịch vụ xác nhận.',
      ),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('Toán học')),
          Chip(label: Text('Ngôn ngữ')),
          Chip(label: Text('English Companion')),
          Chip(label: Text('Kỹ năng sống')),
          Chip(label: Text('Logic')),
          Chip(label: Text('Khám phá')),
        ],
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
    this.parentGateEnabled = false,
  });
  final VoidCallback back;
  final Future<void> Function(String email, String password) submitted;
  final void Function(String email, String password)? verify;
  final bool parentGateEnabled;

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  ApiFailure? error;
  DateTime? retryAt;
  Timer? retryTimer;
  int get retrySeconds => retryAt == null
      ? 0
      : (retryAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 86400);

  @override
  void dispose() {
    retryTimer?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || retrySeconds > 0 || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submitted(email.text.trim(), password.text);
    } on ApiFailure catch (failure) {
      final retry = failure.retryAfterSeconds;
      if (mounted && retry != null && retry > 0) {
        retryAt = DateTime.now().add(Duration(seconds: retry));
        retryTimer?.cancel();
        retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {});
          if (retrySeconds == 0) timer.cancel();
        });
      }
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
    title: 'Đăng nhập dành cho ba mẹ',
    back: busy ? null : widget.back,
    children: [
      const Text(
        'Dùng tài khoản đã xác minh. Staging có thể giới hạn email đăng ký; OTP được gửi qua email khi dịch vụ hỗ trợ.',
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
              decoration: const InputDecoration(labelText: 'Email phụ huynh'),
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
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
              onFieldSubmitted: (_) => submit(),
            ),
            if (widget.parentGateEnabled)
              GateError(error)
            else
              ErrorText(error),
            if (retrySeconds > 0)
              Text(
                'Try again in $retrySeconds seconds.',
                key: const Key('loginRetryAfter'),
              ),
            if (error?.code == 'EMAIL_NOT_VERIFIED' && widget.verify != null)
              OutlinedButton(
                key: const Key('resumeEmailVerification'),
                onPressed: busy
                    ? null
                    : () => widget.verify!(email.text.trim(), password.text),
                child: const Text('Verify existing synthetic email'),
              ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: FilledButton(
                key: const Key('signInSubmit'),
                onPressed: busy || retrySeconds > 0 ? null : submit,
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
                    : const Text('Đăng nhập'),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Quên mật khẩu?'),
            content: const Text(
              'Dịch vụ khôi phục mật khẩu chưa được mở trên staging. Không có email khôi phục nào được gửi. Vui lòng liên hệ người vận hành thử nghiệm.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        ),
        child: const Text('Quên mật khẩu?'),
      ),
    ],
  );
}

class Register extends StatefulWidget {
  const Register({
    this.live = false,
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
  final bool live;
}

class _RegisterState extends State<Register> {
  final formKey = GlobalKey<FormState>();
  late final email = TextEditingController(
        text: widget.fixture ? 'parent@example.test' : '',
      ),
      password = TextEditingController(
        text: widget.fixture ? 'synthetic-pass' : '',
      ),
      confirmation = TextEditingController(
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
    confirmation.dispose();
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
    title: 'Tạo tài khoản phụ huynh',
    back: busy ? null : widget.back,
    children: [
      Text(
        'Terms: ${current.terms?.code ?? 'unavailable'}. Terms are separate from child consent.',
      ),
      Text(current.disclaimer),
      Text(
        widget.live
            ? 'Staging thử nghiệm: chỉ email được cho phép có thể đăng ký. Mã xác minh sẽ được gửi qua dịch vụ email khi khả dụng. Thông tin điều khoản chỉ là metadata tổng hợp, không phải văn bản pháp lý đầy đủ hay chứng minh giám hộ.'
            : 'R0 synthetic accounts only. The API supplies mock Terms version metadata, not a full legal document. No email is sent and this does not prove guardian authority.',
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
                  RegExp(
                    widget.live
                        ? r'^[^\s@]+@[^\s@]+\.[^\s@]+$'
                        : r'^[^\s@]+@example\.test$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : widget.live
                  ? 'Kiểm tra định dạng email.'
                  : 'Use a synthetic email ending in @example.test.',
              decoration: InputDecoration(
                labelText: widget.live
                    ? 'Email phụ huynh'
                    : 'Parent email (@example.test in R0)',
                prefixIcon: Icon(Icons.mail_outline),
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
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registerPassword'),
              controller: password,
              enabled: !busy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(c).unfocus(),
              enableSuggestions: false,
              autocorrect: false,
              validator: (value) =>
                  (value?.length ?? 0) < 10 || (value?.length ?? 0) > 128
                  ? 'Use 10–128 characters.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Password (10–128 characters)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registerPasswordConfirmation'),
              controller: confirmation,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              validator: (value) =>
                  value != password.text || (value?.isEmpty ?? true)
                  ? 'Enter the same password again.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
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
      title: model.verified ? 'Email đã được xác minh' : 'Nhập mã xác nhận',
      back: model.busy ? null : widget.back,
      children: [
        Text(
          widget.mockOtp == null
              ? 'Kiểm tra email để lấy mã 6 chữ số. Nếu dịch vụ chưa gửi được, hãy thử gửi lại hoặc liên hệ người vận hành. Không có mã mặc định.'
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
          'Mã sai, hết hạn hoặc không khả dụng đều không thể xác minh. Có thể quay lại đăng nhập mà không tạo thêm tài khoản.',
        ),
        if (widget.api is MobileCapabilities)
          ResendButton(
            api: widget.api as MobileCapabilities,
            email: widget.email,
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
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(labelText: 'Mã xác nhận 6 chữ số'),
        ),
        OnboardingError(model.error),
        if (model.retrySeconds > 0)
          Text('Try again in ${model.retrySeconds} seconds.'),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: FilledButton(
            key: const Key('otpVerify'),
            onPressed: model.busy || model.retrySeconds > 0 ? null : submit,
            child: Text(
              model.busy
                  ? 'Checking…'
                  : model.verified
                  ? 'Retry parent sign-in'
                  : 'Xác nhận và đăng nhập',
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
    this.checkAttempt,
  });
  final OnboardingAttempt? attempt;
  final Future<void> Function() begin;
  final VoidCallback declined, next;
  final VoidCallback? parentHome;
  final VoidCallback? checkAttempt;
  @override
  State<Privacy> createState() => _PrivacyState();
}

String _purposeDescription(String code) => switch (code) {
  'CHILD_PROFILE_AGE' => 'Hồ sơ và độ tuổi của bé',
  'LEARNING_PROGRESS' => 'Ghi nhận hoạt động học của bé',
  _ => code,
};

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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
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
          if (notices.isEmpty)
            const Text(
              'No required mock purpose notices were returned. Child profile input is locked. Reload notices or return to Parent Home.',
              key: Key('privacyNoticesEmpty'),
            ),
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
                          _purposeDescription(n.purposeCode),
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        const Text(
                          'Synthetic development only · not approved for real children.',
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Thông tin phiên bản / Technical details',
                          ),
                          children: [
                            SelectableText(
                              'Purpose: ${n.purposeCode}\nNotice version: ${n.label} · ${n.versionId}',
                            ),
                            if (n.effectiveFrom != null)
                              SelectableText(
                                'Effective: ${n.effectiveFrom!.toUtc().toIso8601String()}',
                              ),
                            if (n.contentHash != null)
                              SelectableText('Content hash: ${n.contentHash}'),
                          ],
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
                    title: Text(
                      'Tôi đồng ý mục đích: ${_purposeDescription(n.purposeCode)}.',
                    ),
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
        if (widget.attempt != null && widget.checkAttempt != null)
          OutlinedButton(
            key: const Key('checkPrivacyAttempt'),
            onPressed: busy ? null : widget.checkAttempt,
            child: const Text('Check or resume this attempt'),
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
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(c).unfocus(),
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
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
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
    this.checkAttempt,
  });
  final MimiGoApi api;
  final OnboardingAttempt attempt;
  final ChildDraft draft;
  final VoidCallback back;
  final VoidCallback? termsRequired;
  final ChildCreationState model;
  final VoidCallback restart, parentHome, accountEntry;
  final VoidCallback? checkAttempt;
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
        if (widget.model.sent && widget.checkAttempt != null)
          OutlinedButton(
            key: const Key('checkCreationAttempt'),
            onPressed: widget.model.busy || leaving
                ? null
                : widget.checkAttempt,
            child: const Text('Check whether this attempt created a profile'),
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
    this.gateAvailable = false,
    this.parentArea,
  });
  final ChildSummary? child;
  final bool fixture;
  final ValueChanged<LearningCategory> category;
  final VoidCallback accountEntry;
  final VoidCallback? explore;
  final VoidCallback? english;
  final bool gateAvailable;
  final VoidCallback? parentArea;
  @override
  Widget build(BuildContext c) => Frame(
    childMode: true,
    title: child == null
        ? 'Welcome back to Child Mode!'
        : 'Hi, ${child!.alias}!',
    children: [
      PoGarden(
        title: child == null ? 'Cùng Mimi khám phá!' : 'Chào ${child!.alias}!',
        subtitle: 'Mỗi ngày một điều mới, bé nhé.',
      ),
      MimiNotice(
        icon: Icons.explore_outlined,
        color: const Color(0xFFFFF4CD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What will you discover today?',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            Text(
              fixture
                  ? 'Child Mode · fixture demonstrations'
                  : 'Child Mode · live account',
            ),
          ],
        ),
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
      if (fixture)
        FilledButton.icon(
          key: const Key('childMobileDemo'),
          onPressed: () => Navigator.of(c).push(
            MaterialPageRoute<void>(
              builder: (_) => const MobileDemo(startInChildMode: true),
            ),
          ),
          icon: const Icon(Icons.shopping_basket_outlined),
          label: const Text('Giỏ trái cây · Demo tương tác'),
        ),
      Text(fixture ? 'Khám phá thêm · Trò chơi mẫu' : 'Learning shortcuts'),
      MimiDomainRail(
        children: [
          for (final value in const [
            LearningCategory.math,
            LearningCategory.language,
          ])
            MimiDomainTile(
              key: Key('category-${value.name}'),
              label: value.label,
              code: value.name,
              onPressed: () => category(value),
            ),
          if (!fixture)
            MimiDomainTile(
              key: const Key('category-english'),
              label: 'English',
              code: 'ENGLISH',
              onPressed: english,
            ),
          for (final value in [
            LearningCategory.lifeSkills,
            LearningCategory.logic,
            if (fixture) LearningCategory.arts,
            LearningCategory.discovery,
          ])
            MimiDomainTile(
              key: Key('category-${value.name}'),
              label: value.label,
              code: value.name,
              onPressed: () => category(value),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        gateAvailable
            ? 'Parent controls require PIN verification. Forgotten PIN: sign out and sign in again for password-authorized reset.'
            : 'Parent verification is not available inside Child Mode yet. Return to account entry for a parent to sign in again.',
      ),
      Semantics(
        header: true,
        child: Text(
          gateAvailable
              ? 'PIN-protected Parent controls'
              : 'Parent controls are locked',
          style: Theme.of(c).textTheme.titleMedium,
        ),
      ),
      Text(
        gateAvailable
            ? 'Verify the Parent Area PIN to leave Child Mode and choose another owned child. Entering the selected child uses a separate child-bound verification.'
            : 'Switching children and opening Parent Area require an approved Parent Gate. Its verification contract is unavailable; no PIN is accepted or simulated.',
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: OutlinedButton.icon(
          key: const Key('childSwitchGate'),
          onPressed: gateAvailable ? parentArea : null,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Switch child · Parent Gate required'),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: OutlinedButton(
          key: const Key('childParentGate'),
          onPressed: gateAvailable ? parentArea : null,
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
                  subtitle: Text(
                    '${x.dateOfBirth == null ? 'Basic roster profile' : dateText(x.dateOfBirth!)} · ${x.state}',
                  ),
                  trailing: x.id == widget.active?.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => widget.select(x),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
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
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
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
