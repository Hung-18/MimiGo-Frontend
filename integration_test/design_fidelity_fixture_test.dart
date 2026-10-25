// Public synthetic UI capture only. This is not live Backend acceptance.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_home.dart';
import 'package:mimigo_frontend/parent_gate_api.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/child_onboarding.dart';
import 'package:mimigo_frontend/curriculum_explorer.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';

import '../test/design_test_support.dart';
import '../test/learning_test_data.dart' as data;
import 'live_auth_test.dart' show tap, waitFor;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android public synthetic UI design catalog and learning states',
    (tester) async {
      final fixture = FixtureMimiGoApi();
      final reference = await fixture.onboardingReference();
      final attempt = OnboardingAttempt(
        'visual-only',
        DateTime.now().add(const Duration(minutes: 30)),
        reference.notices,
      );
      final api = visualLearningApi();
      final creation = ChildCreationState(
        fixture,
        CreateChildRequest(
          attemptId: attempt.id,
          idempotencyKey: 'visual-only',
          childAlias: visualChild.alias,
          dateOfBirth: DateTime(2023, 1, 1),
          stockAvatarKey: 'bear-blue',
          guardianAffirmed: true,
          purposeChoices: attempt.notices
              .map((n) => PurposeChoice(n.purposeCode, n.versionId, true))
              .toList(),
        ),
      );
      CurriculumExplorerState? explorer;
      Future<void> show(Widget child) async {
        await tester.pumpWidget(visualApp(child));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String name, {String? reveal}) async {
        if (reveal != null) {
          await Scrollable.ensureVisible(
            tester.element(find.byKey(Key(reveal))),
            alignment: .3,
          );
          await tester.pumpAndSettle();
        }
        // Refuse protected surfaces. Never remove FLAG_SECURE or capture PIN,
        // proofs, protected profiles/history or a live account for visual QA.
        expect(find.byType(GatePinScreen), findsNothing);
        expect(find.byType(GatedParentArea), findsNothing);
        expect(
          await GateScreenSecurity.channel.invokeMethod<bool>(
            'screenProtected',
          ),
          isFalse,
        );
        final size = tester.view.physicalSize;
        if (size.width > size.height &&
            !name.startsWith('C0') &&
            name != 'completion' &&
            name != 'replay')
          return;
        await binding.takeScreenshot(
          'public_${size.width.toInt()}x${size.height.toInt()}_$name',
        );
      }

      try {
        await show(Welcome(live: false, start: () async {}, signIn: () {}));
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await capture('A01_welcome');
        await show(
          Register(
            reference: reference,
            fixture: true,
            back: () {},
            submitted: (_) async {},
          ),
        );
        expect(
          tester
              .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
              .value,
          isFalse,
        );
        await capture('A02_registration', reveal: 'registerPassword');
        await show(SignIn(back: () {}, submitted: (_, _) async {}));
        await capture('signin');
        await show(
          Otp(
            api: fixture,
            email: 'synthetic@example.test',
            mockOtp: null,
            back: () {},
            done: () async {},
          ),
        );
        await capture('A04_verification', reveal: 'otpCode');
        await show(
          Privacy(
            attempt: attempt,
            begin: () async {},
            declined: () {},
            next: () {},
          ),
        );
        await capture('privacy_notice');
        await show(ChildInput(back: () {}, next: (_) {}));
        await capture('A06_child_profile', reveal: 'childName');
        await show(
          Review(
            api: fixture,
            attempt: attempt,
            draft: ChildDraft(
              visualChild.alias,
              DateTime(2023, 1, 1),
              'bear-blue',
            ),
            model: creation,
            back: () {},
            created: (_) async {},
            restart: () {},
            parentHome: () {},
            accountEntry: () {},
          ),
        );
        await capture('A07_profile_review');
        await show(
          Frame(
            title: 'Parent Home',
            children: [
              ParentHome(
                api: api,
                parent: const ParentSummary(
                  'test-parent',
                  'parent@example.test',
                  'SYN Parent',
                  true,
                  parentGate: ParentGateStatus('ENROLLED', null),
                ),
                children: const [visualChild],
                workspace: const ParentWorkspace([
                  WorkspaceChildMetadata(visualChild, 'AVAILABLE', 'READY'),
                ], 'Synthetic visual workspace'),
                fixture: true,
                add: () {},
                accountEntry: () {},
                enterChild: (_) {},
                openParentArea: () {},
                setupPin: () {},
              ),
            ],
          ),
        );
        expect(find.textContaining('Date of birth'), findsNothing);
        await capture(
          'B02_parent_child_selection',
          reveal: 'parent-child-${visualChild.id}',
        );
        await show(
          ChildHome(
            child: visualChild,
            fixture: false,
            category: (_) {},
            english: () {},
            explore: () {},
            accountEntry: () {},
          ),
        );
        await capture('B01_child_home', reveal: 'category-math');
        explorer = CurriculumExplorerState(api, visualChild.id);
        await show(
          Frame(
            title: 'Explore curriculum',
            childMode: true,
            wide: true,
            children: [
              CurriculumExplorer(
                model: explorer,
                childAlias: visualChild.alias,
                fixture: true,
                openLesson: (_) {},
              ),
            ],
          ),
        );
        await waitFor(tester, find.byKey(const Key('domain-MATH')));
        await capture('B03_curriculum', reveal: 'domain-MATH');
        await tap(tester, 'domain-MATH');
        await tap(tester, 'topic-SYN-TOPIC');
        await capture(
          'B04_lesson_list',
          reveal: 'explorer-lesson-${data.lessonId}',
        );
        await show(
          Frame(
            title: 'Learning',
            childMode: true,
            wide: true,
            children: [
              LearningLessonView(
                api: api,
                childId: data.childId,
                lessonId: data.lessonId,
                pending: PendingLearningAnswers(),
              ),
            ],
          ),
        );
        await tap(tester, 'startLearning');
        await capture('C01_question', reveal: 'option-${data.optionId}');
        expect(find.byKey(const Key('feedback-${data.cueId}')), findsNothing);
        await tap(tester, 'option-${data.optionId}');
        await tap(tester, 'submit-${data.cueId}');
        await capture('C02_explanation', reveal: 'feedback-${data.cueId}');
        await tap(tester, 'completeLearning');
        await capture('completion', reveal: 'completionConfirmed');
        await tap(tester, 'replayLearning');
        expect(find.text('Session: IN_PROGRESS'), findsOneWidget);
        await capture('replay', reveal: 'option-${data.optionId}');
        await show(
          const Frame(
            title: 'Learning unavailable',
            childMode: true,
            children: [
              LearningError(
                ApiFailure(
                  'not displayed',
                  code: 'CONNECTIVITY',
                  retryable: true,
                ),
              ),
            ],
          ),
        );
        await capture('offline_error');
        await show(
          const Frame(
            title: 'Phụ huynh & bé · MimiGo',
            children: [
              Text('Cùng Mimi học tập và khám phá!'),
              Text('Ngôn ngữ · Kỹ năng sống · Tư duy logic'),
              Text('Ă Â Ê Ô Ơ Ư Đ · ă â ê ô ơ ư đ · ắ ầ ễ ộ ở ự'),
            ],
          ),
        );
        await capture('font_specimen');
        debugPrint(
          'DESIGN ANDROID FIXTURE PASS: public layouts, explicit Terms, canonical domains, feedback/completion/replay; capture refused on protected windows. No Backend requests or visual approval claim.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        explorer?.dispose();
        creation.dispose();
      }
    },
  );
}
