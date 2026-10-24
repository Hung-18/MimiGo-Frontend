import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';

import 'live_auth_test.dart' show TracedLiveApi, tap, waitFor;

class AdditiveLiveApi extends TracedLiveApi {
  AdditiveLiveApi(super.baseUri);
  OnboardingAttempt? originalAttempt;
  final reads = <OnboardingAttemptStatus>[];
  ParentWorkspace? workspace;
  LearningSession? started;
  int creations = 0;
  bool loseNextCreationAck = true;
  String? curriculumChild;
  @override
  Future<OnboardingAttempt> beginOnboardingAttempt() async =>
      originalAttempt = await super.beginOnboardingAttempt();
  @override
  Future<OnboardingAttemptStatus> getOnboardingAttempt(String id) async {
    final value = await trace(
      'attempt.read',
      () => super.getOnboardingAttempt(id),
    );
    reads.add(value);
    return value;
  }

  @override
  Future<ParentWorkspace> learningWorkspace() async =>
      workspace = await super.learningWorkspace();
  @override
  Future<ChildSummary> createChild(CreateChildRequest request) async {
    creations++;
    final child = await super.createChild(request);
    if (loseNextCreationAck) {
      loseNextCreationAck = false;
      throw const ApiFailure(
        'Controlled test: creation response lost after real acknowledgment.',
        code: 'CONNECTIVITY',
        retryable: true,
      );
    }
    return child;
  }

  @override
  Future<CurriculumCatalog> curriculum(String childId) {
    curriculumChild = childId;
    return super.curriculum(childId);
  }

  @override
  Future<LearningSession> startLearning(
    String childId,
    String lessonId,
  ) async => started = await super.startLearning(childId, lessonId);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android LIVE read-only attempt resume, consumed recovery and READY learning entry',
    (tester) async {
      final config = ApiConfiguration.fromEnvironment();
      expect(config.mode, ApiMode.live);
      final api = AdditiveLiveApi(Uri.parse(config.baseUrl));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'resume-$suffix@example.test';
      final password = 'SYN-${Random.secure().nextInt(1 << 30)}-$suffix';
      final reference = await api.onboardingReference();
      final registration = await api.register(
        Registration(
          email,
          password,
          'SYN Resume Parent',
          reference.terms!.id,
          true,
        ),
      );
      expect(registration.mockOtp, isNotNull);
      await api.verifyMockEmail(email: email, otp: registration.mockOtp!);
      api.clearSession();
      await tester.pumpWidget(MimiGoApp(api: api, configuration: config));
      await tap(tester, 'welcomeSignIn');
      await tester.enterText(find.byKey(const Key('signInEmail')), email);
      await tester.enterText(find.byKey(const Key('signInPassword')), password);
      await tap(tester, 'signInSubmit');
      await waitFor(tester, find.byKey(const Key('addChild')));
      await tap(tester, 'addChild');
      await tap(tester, 'loadAttempt');
      await waitFor(tester, find.byKey(const Key('guardianAssertion')));
      final original = api.originalAttempt!;
      await tap(tester, 'guardianAssertion');
      await tap(tester, 'privacyParentHome');
      await waitFor(tester, find.byKey(const Key('parentResumeOnboarding')));
      await tap(tester, 'parentResumeOnboarding');
      await waitFor(tester, find.byKey(const Key('resumeOpenAttempt')));
      expect(api.reads.single.status, 'OPEN');
      expect(api.reads.single.attempt.id, original.id);
      expect(api.reads.single.attempt.expiresAt, original.expiresAt);
      expect(
        api.reads.single.attempt.notices.map((n) => n.versionId),
        original.notices.map((n) => n.versionId),
      );
      expect(api.creations, 0);
      await tap(tester, 'resumeOpenAttempt');
      await waitFor(tester, find.byKey(const Key('guardianAssertion')));
      expect(find.byKey(const Key('childDob')), findsNothing);
      for (final element in find.byType(CheckboxListTile).evaluate().toList()) {
        final tile = element.widget as CheckboxListTile;
        expect(tile.value, isFalse);
        await tap(tester, (tile.key! as ValueKey<String>).value);
      }
      await tap(tester, 'privacyContinue');
      await waitFor(tester, find.byKey(const Key('childDob')));
      final alias = 'SYN-Resume-$suffix';
      await tester.enterText(find.byKey(const Key('childName')), alias);
      await tester.enterText(find.byKey(const Key('childDob')), '2023-01-01');
      await tap(tester, 'childContinue');
      await tap(tester, 'createChild');
      await waitFor(tester, find.byKey(const Key('onboardingError')));
      expect(find.byKey(const Key('createdChildAlias')), findsNothing);
      expect(api.createdRequest!.attemptId, original.id);
      await tap(tester, 'checkCreationAttempt');
      await waitFor(tester, find.byKey(const Key('resumeConsumedHome')));
      expect(api.reads.last.status, 'ATTEMPT_ALREADY_CONSUMED');
      expect(api.reads.last.childId, api.createdChild!.id);
      expect(api.reads.last.attempt.expiresAt, original.expiresAt);
      expect(api.creations, 1);
      expect(find.byKey(const Key('resumeOpenAttempt')), findsNothing);
      await tap(tester, 'resumeConsumedHome');
      await waitFor(tester, find.text(alias));
      expect(find.byType(ChildHome), findsNothing);
      expect(find.byKey(const Key('parentResumeOnboarding')), findsNothing);
      final child = api.workspace!.children.single;
      expect(child.child.id, api.createdChild!.id);
      expect(child.catalogStatus, 'AVAILABLE');
      expect(child.learningEntryStatus, 'READY');
      await tester.ensureVisible(find.text(alias));
      await tester.tap(find.text(alias));
      await waitFor(tester, find.byKey(const Key('parentLearningEntry')));
      expect(find.textContaining('Learning entry ready'), findsOneWidget);
      await tap(tester, 'parentEnterLearning');
      await waitFor(tester, find.text('Hi, $alias!'));
      for (final key in ['childParentGate', 'childSwitchGate']) {
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
          isNull,
        );
      }
      expect(find.byKey(const Key('parentResumeOnboarding')), findsNothing);
      await tap(tester, 'openCurriculum');
      await waitFor(tester, find.byKey(const Key('domain-MATH')));
      expect(api.curriculumChild, child.child.id);
      final lesson = api.discovered!.domains
          .expand((d) => d.topics)
          .expand((t) => t.lessons)
          .singleWhere((l) => l.lessonCode == 'SYN-MATH-001');
      await tap(tester, 'domain-MATH');
      await tap(tester, 'topic-${lesson.topicCode}');
      await tap(tester, 'explorer-lesson-${lesson.lessonId}');
      await waitFor(tester, find.byKey(const Key('startLearning')));
      await tap(tester, 'startLearning');
    await waitFor(tester, find.byKey(const Key('learningSessionState')));
    expect(find.byKey(const Key('learningError')), findsNothing);
      expect(api.started!.childId, child.child.id);
      expect(api.started!.lessonId, lesson.lessonId);
      expect(api.started!.state, 'IN_PROGRESS');
      expect(api.creations, 1);
      debugPrint(
        'ADDITIVE ANDROID LIVE PASS: OPEN resume kept original expiry/notices, fresh unchecked choices, real creation acknowledgment lost only by test wrapper, consumed read recovered the same child without another POST, server learningEntry READY reached a real session; Parent Gate stays locked. No permission mutation or history endpoint.',
      );
    },
  );
}
