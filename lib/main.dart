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

export 'api_failure.dart';

void main() => runApp(const MimiGoApp());

/// Accepted auth/ChildProfile boundary plus the exact S2 Learning operations.
/// Fixture remains the default; live mode is opt-in.
abstract class MimiGoApi implements LearningApi {
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

class TermsReference {
  const TermsReference(this.id, this.code);
  final String id, code;
}

class Purpose {
  const Purpose(this.code, this.isCoreForChild);
  final String code;
  final bool isCoreForChild;
}

class Notice {
  const Notice(this.purposeCode, this.versionId, this.label);
  final String purposeCode, versionId, label;
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
  int _next = 1;
  final _children = <ChildSummary>[];
  @override
  void clearSession() => _token = null;
  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 60));
  @override
  Future<OnboardingReference> onboardingReference() async {
    await _wait();
    return const OnboardingReference(
      TermsReference(termsId, 'R0_MOCK_TERMS_V1'),
      [Purpose('CHILD_PROFILE_AGE', true), Purpose('LEARNING_PROGRESS', true)],
      [
        Notice('CHILD_PROFILE_AGE', ageNoticeId, 'test-v1'),
        Notice('LEARNING_PROGRESS', learningNoticeId, 'test-v1'),
      ],
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
    return OnboardingAttempt(
      'fixture-attempt-${_next++}',
      DateTime.now().add(const Duration(minutes: 30)),
      const [
        Notice('CHILD_PROFILE_AGE', ageNoticeId, 'test-v1'),
        Notice('LEARNING_PROGRESS', learningNoticeId, 'test-v1'),
      ],
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
    if (!value.guardianAffirmed || value.purposeChoices.any((x) => !x.affirmed))
      throw const ApiFailure(
        'Every required purpose must be affirmed.',
        code: 'CORE_PERMISSION_REQUIRED',
        status: 422,
      );
    final child = ChildSummary(
      id: 'fixture-child-${_next++}',
      alias: value.childAlias,
      dateOfBirth: value.dateOfBirth,
      ageYears: productAge(value.dateOfBirth, DateTime.now()),
      withinProgramAgeRange: true,
      state: 'ACTIVE',
      createdAt: DateTime.now(),
      stockAvatarKey: value.stockAvatarKey,
    );
    _children.add(child);
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
    return RegistrationResult(
      _string(x, 'parentId'),
      _date(x, 'otpExpiresAt'),
      _string(x, 'notice'),
      x['mockOtp'] as String?,
    );
  }

  @override
  Future<void> verifyMockEmail({required String email, required String otp}) =>
      _request(
        'POST',
        'auth/mock-email/verify',
        body: {'email': email, 'otp': otp},
      );
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
  return x
      .map((v) {
        final n = _map(v);
        return Notice(
          _string(n, 'purposeCode'),
          _string(n, 'noticeVersionId'),
          _string(n, 'versionLabel'),
        );
      })
      .toList(growable: false);
}

OnboardingReference _reference(Map<String, dynamic> x) {
  final termsJson = x['terms'];
  final terms = termsJson == null
      ? null
      : TermsReference(
          _string(_map(termsJson), 'termsVersionId'),
          _string(_map(termsJson), 'code'),
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
  demo,
  parent,
  parentOnly,
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
  String? email, password, mockOtp;
  ChildDraft? draft;
  ChildSummary? active;
  ParentSummary? authenticatedParent;
  List<ChildSummary> children = [];
  LearningCategory? selectedCategory;
  String? selectedLessonId;
  final pendingLearningAnswers = PendingLearningAnswers();
  late final learningSessions = LearningSessionMemory(api);
  int sessionGeneration = 0;
  bool accountEntryPending = false;

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
      active = null;
      children = [];
      reference = null;
      attempt = null;
      draft = null;
      selectedCategory = null;
      selectedLessonId = null;
      pendingLearningAnswers.clear();
      learningSessions.clear();
      page = Page.welcome;
    });
  }

  void childBack() {
    if (page == Page.learningLesson) {
      setState(() => page = Page.category);
    } else if (page == Page.demo) {
      setState(() => page = Page.category);
    } else if (page == Page.category) {
      setState(() => page = Page.child);
    } else if (page == Page.child) {
      returnToAccountEntry();
    }
  }

  @override
  void dispose() {
    learningSessions.dispose();
    super.dispose();
  }

  Future<void> start() async {
    try {
      final value = await api.onboardingReference();
      if (mounted)
        setState(() {
          reference = value;
          page = Page.register;
        });
    } on ApiFailure catch (e) {
      if (mounted) error(e);
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
    required bool returningParent,
  }) async {
    await api.login(email: email, password: password);
    final parent = await api.parentMe();
    final profiles = returningParent
        ? await api.listChildren()
        : <ChildSummary>[];
    if (!mounted) return;
    setState(() {
      authenticatedParent = parent;
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

  Future<void> signedIn() =>
      authenticate(email: email!, password: password!, returningParent: false);

  Future<void> attemptStart() async {
    try {
      final value = await api.beginOnboardingAttempt();
      if (mounted) setState(() => attempt = value);
    } on ApiFailure catch (e) {
      if (mounted) error(e);
    }
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
          page != Page.learningLesson,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) childBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (page) {
            Page.welcome => Welcome(
              live: config.mode == ApiMode.live,
              start: start,
              signIn: () => setState(() => page = Page.signIn),
            ),
            Page.signIn => SignIn(
              back: () => setState(() => page = Page.welcome),
              submitted: (email, password) => authenticate(
                email: email,
                password: password,
                returningParent: true,
              ),
            ),
            Page.register => Register(
              reference: reference!,
              back: () => setState(() => page = Page.welcome),
              submitted: (v) async {
                try {
                  final result = await api.register(v);
                  if (mounted)
                    setState(() {
                      email = v.email;
                      password = v.password;
                      mockOtp = result.mockOtp;
                      page = Page.otp;
                    });
                } on ApiFailure catch (e) {
                  if (mounted) error(e);
                }
              },
            ),
            Page.otp => Otp(
              api: api,
              email: email!,
              mockOtp: mockOtp,
              back: () => setState(() => page = Page.register),
              done: signedIn,
            ),
            Page.privacy => Privacy(
              attempt: attempt,
              begin: attemptStart,
              declined: () => setState(() => page = Page.parentOnly),
              next: () => setState(() => page = Page.input),
            ),
            Page.input => ChildInput(
              back: () => setState(() => page = Page.privacy),
              next: (v) => setState(() {
                draft = v;
                page = Page.review;
              }),
            ),
            Page.review => Review(
              api: api,
              attempt: attempt!,
              draft: draft!,
              back: () => setState(() => page = Page.input),
              created: (v) async {
                setState(() {
                  active = v;
                  page = Page.child;
                });
                await refresh();
              },
            ),
            Page.child => ChildHome(
              child: active!,
              fixture: config.mode == ApiMode.fixture,
              category: (value) => setState(() {
                selectedCategory = value;
                page = Page.category;
              }),
              accountEntry: returnToAccountEntry,
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
            Page.learningLesson => Frame(
              title: 'Math learning · development/demo',
              children: [
                LearningLessonView(
                  key: ValueKey((active!.id, selectedLessonId)),
                  api: api,
                  childId: active!.id,
                  lessonId: selectedLessonId!,
                  pending: pendingLearningAnswers,
                  sessions: learningSessions,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: OutlinedButton(
                    key: const Key('lessonBack'),
                    onPressed: () => setState(() => page = Page.category),
                    child: const Text('Back to Math'),
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
            Page.parent => ParentArea(
              home: ParentHome(
                api: api,
                parent: authenticatedParent!,
                children: children,
                fixture: config.mode == ApiMode.fixture,
                accountEntry: returnToAccountEntry,
                add: () => setState(() {
                  attempt = null;
                  draft = null;
                  page = Page.privacy;
                }),
                enterChild: (child) => setState(() {
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
              back: () => setState(() => page = Page.privacy),
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
  });
  final bool live;
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
          onPressed: start,
          child: const Text('Create a parent account'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        key: const Key('welcomeSignIn'),
        onPressed: signIn,
        child: const Text('Already have an account? Sign in'),
      ),
    ],
  );
}

class SignIn extends StatefulWidget {
  const SignIn({super.key, required this.back, required this.submitted});
  final VoidCallback back;
  final Future<void> Function(String email, String password) submitted;

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
  });
  final OnboardingReference reference;
  final VoidCallback back;
  final Future<void> Function(Registration) submitted;
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final email = TextEditingController(text: 'parent@example.test'),
      password = TextEditingController(text: 'synthetic-pass'),
      displayName = TextEditingController(text: 'SYN Parent');
  bool terms = false, busy = false;
  ApiFailure? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final id = widget.reference.terms?.id;
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
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Create parent account',
    back: widget.back,
    children: [
      Text(
        'Terms: ${widget.reference.terms?.code ?? 'unavailable'}. Terms are separate from child consent.',
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('registerEmail'),
        controller: email,
        decoration: const InputDecoration(
          labelText: 'Parent email (@example.test in R0)',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: displayName,
        decoration: const InputDecoration(labelText: 'Parent display name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password (10–128 characters)',
        ),
      ),
      CheckboxListTile(
        key: const Key('termsCheckbox'),
        contentPadding: EdgeInsets.zero,
        value: terms,
        onChanged: (v) => setState(() => terms = v ?? false),
        title: const Text('I accept the current R0 Terms'),
      ),
      ErrorText(error),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('registerSubmit'),
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Creating…' : 'Continue to email verification'),
        ),
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
  });
  final MimiGoApi api;
  final String email;
  final String? mockOtp;
  final VoidCallback back;
  final Future<void> Function() done;
  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  final code = TextEditingController();
  bool busy = false;
  bool verified = false;
  ApiFailure? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!verified) {
        await widget.api.verifyMockEmail(email: widget.email, otp: code.text);
        verified = true;
      }
      await widget.done();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Check your email',
    back: widget.back,
    children: [
      Text(
        widget.mockOtp == null
            ? 'No mock code was returned. Enter the development mock code from the Backend operator.'
            : 'Development mock OTP returned by Backend: ${widget.mockOtp}. No email was sent.',
      ),
      TextField(
        key: const Key('otpCode'),
        controller: code,
        maxLength: 6,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Six-digit mock code'),
      ),
      ErrorText(error),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('otpVerify'),
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Checking…' : 'Verify and sign in'),
        ),
      ),
    ],
  );
}

class Privacy extends StatefulWidget {
  const Privacy({
    super.key,
    required this.attempt,
    required this.begin,
    required this.declined,
    required this.next,
  });
  final OnboardingAttempt? attempt;
  final Future<void> Function() begin;
  final VoidCallback declined, next;
  @override
  State<Privacy> createState() => _PrivacyState();
}

class _PrivacyState extends State<Privacy> {
  bool guardian = false, busy = false;
  final choices = <String, bool>{};
  ApiFailure? error;
  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
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
        notices.every((n) => choices[n.purposeCode] == true);
    return Frame(
      title: 'Protect your child’s information',
      children: [
        const Text(
          'No child alias or date of birth is sent before an authenticated Parent starts a PII-free attempt and actively affirms each displayed core purpose.',
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
            onChanged: (v) => setState(() => guardian = v ?? false),
            title: const Text(
              'I state I am a parent or authorised representative.',
            ),
          ),
          ...notices.map(
            (n) => CheckboxListTile(
              key: Key('consent-${n.purposeCode}'),
              contentPadding: EdgeInsets.zero,
              value: choices[n.purposeCode] ?? false,
              onChanged: (v) =>
                  setState(() => choices[n.purposeCode] = v ?? false),
              title: Text('I affirm ${n.purposeCode} (${n.label}).'),
            ),
          ),
          const Text(
            'Choices are unchecked by default and apply only to this new child.',
          ),
          SizedBox(
            height: 64,
            child: FilledButton(
              key: const Key('privacyContinue'),
              onPressed: allowed ? widget.next : null,
              child: const Text('Continue to child profile'),
            ),
          ),
        ],
        ErrorText(error),
        TextButton(
          key: const Key('privacyDecline'),
          onPressed: widget.declined,
          child: const Text('I do not agree'),
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
  const ChildInput({super.key, required this.back, required this.next});
  final VoidCallback back;
  final void Function(ChildDraft) next;
  @override
  State<ChildInput> createState() => _ChildInputState();
}

class _ChildInputState extends State<ChildInput> {
  final alias = TextEditingController(text: 'SYN-Bee'),
      dob = TextEditingController();
  String avatar = 'bear-blue';
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
        date == null ||
        date.isAfter(DateTime.now()) ||
        date.year < 1900) {
      setState(
        () => error = const ApiFailure(
          'Enter a SYN- alias and a valid required past date (YYYY-MM-DD).',
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
        decoration: const InputDecoration(
          labelText: 'Date of birth * (YYYY-MM-DD)',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: avatar,
        decoration: const InputDecoration(labelText: 'Stock avatar'),
        items: const [
          DropdownMenuItem(value: 'bear-blue', child: Text('Blue bear')),
          DropdownMenuItem(value: 'bee-yellow', child: Text('Sunny bee')),
        ],
        onChanged: (v) => setState(() => avatar = v!),
      ),
      ErrorText(error),
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
  });
  final MimiGoApi api;
  final OnboardingAttempt attempt;
  final ChildDraft draft;
  final VoidCallback back;
  final Future<void> Function(ChildSummary) created;
  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  late final request = CreateChildRequest(
    attemptId: widget.attempt.id,
    idempotencyKey: 'r0-${DateTime.now().microsecondsSinceEpoch}',
    childAlias: widget.draft.alias,
    dateOfBirth: widget.draft.dob,
    guardianAffirmed: true,
    stockAvatarKey: widget.draft.avatar,
    purposeChoices: widget.attempt.notices
        .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
        .toList(),
  );
  bool busy = false;
  ApiFailure? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.api.createChild(request);
      await widget.created(value);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Review profile',
    back: widget.back,
    children: [
      ListTile(
        title: const Text('Synthetic alias'),
        subtitle: Text(widget.draft.alias),
      ),
      ListTile(
        title: const Text('Date of birth'),
        subtitle: Text(
          '${dateText(widget.draft.dob)} · ${productAge(widget.draft.dob, DateTime.now())} years old today',
        ),
      ),
      const Text(
        'The same idempotency key and exact payload are retained for a safe retry after a connectivity failure.',
      ),
      ErrorText(error),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('createChild'),
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Creating…'
                : error?.retryable == true
                ? 'Retry identical request'
                : 'Create synthetic profile',
          ),
        ),
      ),
    ],
  );
}

class ChildHome extends StatelessWidget {
  const ChildHome({
    super.key,
    required this.child,
    required this.fixture,
    required this.category,
    required this.accountEntry,
  });
  final ChildSummary child;
  final bool fixture;
  final ValueChanged<LearningCategory> category;
  final VoidCallback accountEntry;
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
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: LearningCategory.values
            .map(
              (value) => SizedBox(
                height: 64,
                child: OutlinedButton(
                  key: Key('category-${value.name}'),
                  onPressed: () => category(value),
                  child: Text(value.label),
                ),
              ),
            )
            .toList(),
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
              'Access relies on the in-memory authenticated bearer session. Backend does not implement Parent PIN, refresh/logout, consent withdrawal or terms re-acceptance.',
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
                'Current Terms acceptance is required to add a child. Terms re-acceptance is not available in this development API.',
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
  const ParentOnly({super.key, required this.back});
  final VoidCallback back;
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
          onPressed: back,
          child: const Text('Review privacy choices'),
        ),
      ),
    ],
  );
}

String errorText(ApiFailure x) =>
    '${x.code ?? 'REQUEST_FAILED'}${x.requestId == null ? '' : ' · request ${x.requestId}'}: ${x.message}';
String dateText(DateTime x) =>
    '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
DateTime? parseDate(String x) {
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
