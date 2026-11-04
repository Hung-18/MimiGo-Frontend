// Public synthetic presentation/interaction evidence. No live account or API.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:mimigo_frontend/parent_home.dart';
import 'package:mimigo_frontend/po/live_child_home.dart';
import 'package:mimigo_frontend/po/mimi_world.dart';

import '../test/design_test_support.dart';
import '../test/learning_test_data.dart' as data;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'R2 Android public welcome, server-shaped garden, saved answer and completion',
    (t) async {
      final api = visualLearningApi();
      Future<void> show(Widget child) async {
        await t.pumpWidget(visualApp(child));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      Future<void> capture(String name) async {
        expect(
          await GateScreenSecurity.channel.invokeMethod<bool>(
            'screenProtected',
          ),
          isFalse,
        );
        await binding.takeScreenshot('r2_$name');
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
      await capture('garden');
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
