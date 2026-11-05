// Public synthetic presentation/interaction evidence. No live account or API.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/child_onboarding.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:mimigo_frontend/parent_home.dart';
import 'package:mimigo_frontend/po/live_child_home.dart';
import 'package:mimigo_frontend/po/mimi_world.dart';

import '../test/design_test_support.dart';
import '../test/learning_test_data.dart' as data;
import '../test/pilot_legal_contract_test.dart'
    show parseReference, legalReference;
import '../test/password_reset_test.dart' show RecoveryDouble;
import '../test/learning_api_test.dart' show Transport, Reply;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P0 Android public welcome, server-shaped garden, saved answer and completion',
    (t) async {
      final api = visualLearningApi();
      Future<void> show(Widget child) async {
        debugPrint('P0 SHOW ${child.runtimeType}');
        await t.pumpWidget(visualApp(child));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      Future<void> capture(String name) async {
        debugPrint('P0 CAPTURE $name');
        expect(
          await GateScreenSecurity.channel.invokeMethod<bool>(
            'screenProtected',
          ),
          isFalse,
        );
        OverlayEntry? marker;
        if (name == 'legal_reader') {
          marker = OverlayEntry(
            builder: (_) => const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Material(
                  color: Color(0xFFFFFCF6),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'VISUAL TEST / FIXTURE · no network',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          Navigator.of(
            t.element(find.byKey(const Key('legalClose'))),
            rootNavigator: true,
          ).overlay!.insert(marker);
          await t.pumpAndSettle();
        }
        await binding.takeScreenshot('pilot_$name');
        marker?.remove();
        await t.pump();
      }

      Future<void> tap(String key) async {
        final target = find.byKey(Key(key));
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      var signInOpened = false;
      await show(
        Welcome(
          live: true,
          start: () async {},
          signIn: () => signInOpened = true,
        ),
      );
      await binding.convertFlutterSurfaceToImage();
      await t.pumpAndSettle();
      await capture('welcome');
      await tap('welcomeSignIn');
      expect(signInOpened, isTrue);
      final reference = await t.runAsync(
        FixtureMimiGoApi().onboardingReference,
      );
      var registered = false;
      await show(
        Register(
          reference: reference!,
          fixture: false,
          live: true,
          back: () {},
          submitted: (_) async => registered = true,
        ),
      );
      expect(
        find.byKey(const Key('registrationTermsUnavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('registerEmail')), findsNothing);
      expect(registered, isFalse);
      await capture('registration');
      final approvedReference = await t.runAsync(
        () => parseReference(legalReference()),
      );
      await show(
        Register(
          reference: approvedReference!,
          fixture: false,
          live: true,
          back: () {},
          submitted: (_) async => registered = true,
        ),
      );
      expect(find.byKey(const Key('registerEmail')), findsOneWidget);
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await capture('register');
      await tap('registrationReadTerms');
      await capture('legal_reader');
      await tap('legalExplicitChoice');
      await tap('legalAgree');
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isTrue,
      );
      await tap('registrationReadTerms');
      await tap('legalDisagree');
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await show(
        SignIn(
          back: () {},
          recovery: RecoveryDouble(),
          submitted: (_, _) async {},
        ),
      );
      await capture('login');
      await t.enterText(
        find.byKey(const Key('signInEmail')),
        'parent@example.test',
      );
      await tap('forgotPassword');
      await capture('recovery');
      await tap('resetSubmit');
      expect(find.byKey(const Key('resetCode')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('resetCode')));
      await t.pumpAndSettle();
      await capture('reset_code');
      await t.enterText(find.byKey(const Key('resetCode')), '123456');
      await t.enterText(
        find.byKey(const Key('resetPassword')),
        'synthetic-new-password',
      );
      await t.enterText(
        find.byKey(const Key('resetConfirm')),
        'synthetic-new-password',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await tap('resetSubmit');
      expect(find.byKey(const Key('passwordResetConfirmed')), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await capture('recovery_success');
      final otpTransport = Transport()
        ..replies.add(
          Reply({
            'status': 'ACCEPTED',
            'resendCooldownSeconds': 60,
            'notice': 'Test-only acknowledgment',
          }, statusCode: 202),
        );
      final otpApi = LiveMimiGoApi(
        Uri.parse('https://unit.invalid/api/v1'),
        client: otpTransport,
      );
      await show(
        Otp(
          api: otpApi,
          email: 'parent@example.test',
          mockOtp: null,
          registration: RegistrationResult(
            'synthetic-parent',
            DateTime.now().add(const Duration(minutes: 5)),
            'Test only',
          ),
          back: () {},
          done: () async {},
        ),
      );
      await t.enterText(find.byKey(const Key('otpCode')), '123');
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('otpCode')))
            .controller!
            .text,
        '123',
      );
      expect(find.text('1'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('otpCode')))
            .controller!
            .text,
        '123',
      );
      await capture('otp');
      final resend = find.text('Gửi lại mã xác nhận');
      await t.ensureVisible(resend);
      await t.pumpAndSettle();
      await t.tap(resend);
      await t.pumpAndSettle();
      expect(
        otpTransport.requests.single.uri.path,
        '/api/v1/auth/mock-email/resend',
      );
      expect(find.textContaining('Gửi lại sau'), findsOneWidget);
      await capture('otp_resend');
      final attempt = OnboardingAttempt(
        'synthetic-attempt',
        DateTime.now().add(const Duration(minutes: 20)),
        approvedReference.notices,
      );
      var noticesReviewed = false;
      await show(
        Privacy(
          attempt: attempt,
          begin: () async {},
          declined: () {},
          next: () => noticesReviewed = true,
        ),
      );
      expect(
        t
            .widget<CheckboxListTile>(
              find.byKey(const Key('guardianAssertion')),
            )
            .value,
        isFalse,
      );
      await capture('privacy');
      await tap('guardianAssertion');
      await tap('consent-CHILD_PROFILE_AGE');
      await tap('privacyContinue');
      expect(noticesReviewed, isTrue);
      ChildDraft? draft;
      await show(ChildInput(back: () {}, next: (value) => draft = value));
      await capture('child_onboarding');
      await t.enterText(find.byKey(const Key('childName')), 'SYN-Mầm');
      await t.enterText(find.byKey(const Key('childDob')), '2022-01-02');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await tap('childContinue');
      expect(draft?.alias, 'SYN-Mầm');
      final creation = ChildCreationState(
        FixtureMimiGoApi(),
        CreateChildRequest(
          attemptId: attempt.id,
          idempotencyKey: 'synthetic-review-only',
          childAlias: draft!.alias,
          dateOfBirth: draft!.dob,
          stockAvatarKey: draft!.avatar,
          guardianAffirmed: true,
          purposeChoices: [
            PurposeChoice(
              attempt.notices.single.purposeCode,
              attempt.notices.single.versionId,
              true,
            ),
          ],
        ),
      );
      await show(
        Review(
          api: FixtureMimiGoApi(),
          attempt: attempt,
          draft: draft!,
          model: creation,
          back: () {},
          created: (_) async {},
          restart: () {},
          parentHome: () {},
          accountEntry: () {},
        ),
      );
      await capture('profile_review');
      expect(creation.sent, isFalse);
      await t.pumpWidget(const SizedBox());
      creation.dispose();
      expect(
        registered,
        isFalse,
        reason: 'No account or child creation is simulated as live success.',
      );
      await show(
        SingleChildScrollView(
          child: Wrap(
            children: [
              for (final mood in MimiMood.values)
                SizedBox(
                  width: 160,
                  child: Column(
                    children: [
                      MimiBee(size: 150, mood: mood),
                      Text(mood.name),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      await capture('mascot_states');
      var enteredChild = false;
      await show(
        Frame(
          title: 'Góc phụ huynh',
          children: [
            ParentHome(
              api: api,
              parent: const ParentSummary(
                'test-parent',
                'parent@example.test',
                'SYN Parent',
                true,
              ),
              children: const [visualChild],
              workspace: const ParentWorkspace([
                WorkspaceChildMetadata(visualChild, 'AVAILABLE', 'READY'),
              ], 'Synthetic workspace'),
              fixture: true,
              add: () {},
              accountEntry: () {},
              enterChild: (_) => enteredChild = true,
            ),
          ],
        ),
      );
      await capture('parent_home');
      await tap('parent-child-${visualChild.id}');
      await tap('parentEnterLearning');
      expect(enteredChild, isTrue);
      String? domain;
      await show(
        LiveChildHome(
          api: api,
          childId: data.childId,
          alias: 'SYN-Mầm',
          openDomain: ([value]) => domain = value?.code,
          parentArea: () {},
        ),
      );
      await capture('child_home');
      await tap('live-domain-MATH');
      expect(domain, 'MATH');
      final pending = PendingLearningAnswers();
      await show(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LearningLessonView(
              api: api,
              childId: data.childId,
              lessonId: data.lessonId,
              pending: pending,
              focused: true,
            ),
          ),
        ),
      );
      await tap('startLearning');
      await capture('lesson');
      await tap('option-${data.optionId}');
      await tap('submit-${data.cueId}');
      await t.ensureVisible(find.byKey(Key('feedback-${data.cueId}')));
      await t.pumpAndSettle();
      await capture('feedback');
      await tap('next-cue-${data.cueId}');
      await tap('completeLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('completionConfirmed')));
      await t.ensureVisible(find.byKey(const Key('replayLearning')));
      await t.pumpAndSettle();
      await capture('completion');
      await tap('replayLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      expect(api.startBodies, hasLength(2));
      await t.pumpWidget(const SizedBox());
    },
  );
}
