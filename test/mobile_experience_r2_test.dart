import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:mimigo_frontend/password_reset.dart';
import 'package:mimigo_frontend/po/live_child_home.dart';
import 'package:mimigo_frontend/po/po_design.dart';

import 'completion_test_support.dart';
import 'design_test_support.dart';
import 'learning_test_data.dart' as data;
import 'learning_widget_test.dart' show lessonScreen, tapVisible;
import 'password_reset_test.dart' show RecoveryDouble;

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'seven Mimi states use the shared character atlas and distinct poses',
    (t) async {
      for (final mood in MimiMood.values) {
        await t.pumpWidget(
          MaterialApp(
            home: Center(child: MimiBee(size: 160, mood: mood)),
          ),
        );
        await t.pumpAndSettle();
        final art = t.widget<Image>(find.byType(Image));
        expect(
          (art.image as AssetImage).assetName,
          'assets/mascot/mimi_poses.png',
        );
        final transforms = t.widgetList<Transform>(
          find.descendant(
            of: find.byType(OverflowBox),
            matching: find.byType(Transform),
          ),
        );
        expect(
          transforms.single.transform.getTranslation().x,
          -(mood.index % 4) * 160,
        );
        expect(
          transforms.single.transform.getTranslation().y,
          -(mood.index ~/ 4) * 160,
        );
        expect(t.binding.transientCallbackCount, 0);
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets('Parent forms fit 320dp at 200% text without submitting data', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final recovery = RecoveryDouble();
    final api = FixtureMimiGoApi();
    final reference = (await t.runAsync(api.onboardingReference))!;
    final pages = <(Widget, String)>[
      (SignIn(back: () {}, submitted: (_, _) async {}), 'signInSubmit'),
      (
        Register(
          reference: reference,
          fixture: false,
          back: () {},
          submitted: (_) async {},
        ),
        'registerSubmit',
      ),
      (
        Otp(
          api: api,
          email: 'parent@example.test',
          mockOtp: null,
          back: () {},
          done: () async {},
        ),
        'otpCode',
      ),
      (PasswordResetScreen(api: recovery), 'resetSubmit'),
    ];
    for (final page in pages) {
      await t.pumpWidget(visualApp(page.$1, scale: 2));
      await t.pumpAndSettle();
      final target = find.byKey(Key(page.$2));
      if (target.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(target);
      expect(t.takeException(), isNull);
    }
    expect(recovery.requests, 0);
    expect(recovery.confirmations, 0);
  });
  for (final isCorrect in [true, false]) {
    testWidgets('answer reaction follows server correctness $isCorrect', (
      t,
    ) async {
      final api = CompletionApi()..answerGate = Completer<AnswerFeedback>();
      await lessonScreen(t, api);
      await tapVisible(t, 'startLearning');
      await tapVisible(t, 'option-${data.optionId}');
      final submit = find.byKey(Key('submit-${data.cueId}'));
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is MimiBee && w.mood == MimiMood.correct,
        ),
        findsNothing,
      );
      api.answerGate!.complete(
        AnswerFeedback.fromJson({
          ...data.feedbackJson(),
          'isCorrect': isCorrect,
        }),
      );
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MimiBee &&
              w.mood ==
                  (isCorrect == true ? MimiMood.correct : MimiMood.encourage),
        ),
        findsOneWidget,
      );
      expect(find.text('Đã lưu 1 / 1 câu hỏi'), findsOneWidget);
    });
  }
  testWidgets(
    'focused lessons keep one question visible, preserve explanations and replay cleanly',
    (t) async {
      final api = CompletionApi(twoCues: true);
      await t.pumpWidget(
        visualApp(
          SingleChildScrollView(
            child: LearningLessonView(
              api: api,
              childId: data.childId,
              lessonId: data.lessonId,
              pending: PendingLearningAnswers(),
              focused: true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapVisible(t, 'startLearning');
      expect(find.byKey(const Key('option-$secondOptionId')), findsNothing);
      expect(find.byKey(const Key('completeLearning')), findsNothing);
      await tapVisible(t, 'option-${data.optionId}');
      await tapVisible(t, 'submit-${data.cueId}');
      expect(find.byKey(Key('feedback-${data.cueId}')), findsOneWidget);
      expect(find.byKey(const Key('option-$secondOptionId')), findsNothing);
      await tapVisible(t, 'next-cue-${data.cueId}');
      expect(find.byKey(Key('option-${data.optionId}')), findsNothing);
      await tapVisible(t, 'previous-cue-$secondCueId');
      expect(find.byKey(Key('feedback-${data.cueId}')), findsOneWidget);
      await tapVisible(t, 'next-cue-${data.cueId}');
      await tapVisible(t, 'option-$secondOptionId');
      await tapVisible(t, 'submit-$secondCueId');
      await tapVisible(t, 'completeLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      expect(find.byKey(const Key('cue-$secondCueId')), findsNothing);
      await tapVisible(t, 'reviewCompletedAnswers');
      expect(find.byKey(const Key('cue-$secondCueId')), findsOneWidget);
      await tapVisible(t, 'replayLearning');
      expect(find.byKey(Key('option-${data.optionId}')), findsOneWidget);
      expect(find.byKey(const Key('option-$secondOptionId')), findsNothing);
      expect(find.text('Đã lưu 0 / 2 câu hỏi'), findsOneWidget);
    },
  );
  Widget mascot({
    bool reduced = false,
    bool enabled = true,
    MimiMood mood = MimiMood.idle,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: enabled,
        child: Center(child: MimiBee(mood: mood)),
      ),
    ),
  );

  testWidgets(
    'Mimi rests after a bounded burst; background and disposal stop ticking',
    (t) async {
      await t.pumpWidget(mascot());
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(t.binding.transientCallbackCount, 0);
      await t.pumpWidget(mascot(mood: MimiMood.greeting));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpWidget(const SizedBox());
      expect(t.binding.transientCallbackCount, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('reduced motion and offscreen routes do not animate Mimi', (
    t,
  ) async {
    await t.pumpWidget(mascot(reduced: true));
    expect(t.binding.transientCallbackCount, 0);
    await t.pumpWidget(mascot(enabled: false, mood: MimiMood.correct));
    expect(t.binding.transientCallbackCount, 0);
    await t.pumpWidget(mascot(enabled: true, mood: MimiMood.correct));
    await t.pumpAndSettle();
    expect(t.binding.transientCallbackCount, 0);
  });

  for (final size in [const Size(320, 640), const Size(960, 540)]) {
    testWidgets('welcome and live garden fit $size with 200% text', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        visualApp(
          Welcome(live: true, start: () async {}, signIn: () {}),
          scale: 2,
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('welcomeStart')));
      expect(t.takeException(), isNull);
      final api = visualLearningApi();
      await t.pumpWidget(
        visualApp(
          LiveChildHome(
            api: api,
            childId: data.childId,
            openDomain: ([domain]) {},
            parentArea: () {},
          ),
          scale: 2,
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('live-domain-MATH')));
      expect(t.takeException(), isNull);
      final disabled = t.widget<PoCard>(
        find.byKey(const Key('live-domain-ENGLISH')),
      );
      expect(disabled.onTap, isNull);
    });
  }

  testWidgets(
    'illustrated card press responds and opens only the returned domain',
    (t) async {
      final api = visualLearningApi();
      String? opened;
      await t.pumpWidget(
        visualApp(
          LiveChildHome(
            api: api,
            childId: data.childId,
            openDomain: ([domain]) => opened = domain?.code,
            parentArea: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final target = find.byKey(const Key('live-domain-MATH'));
      await t.ensureVisible(target);
      final gesture = await t.startGesture(t.getCenter(target));
      await t.pump(const Duration(milliseconds: 180));
      final scale = t.widget<AnimatedScale>(
        find.descendant(of: target, matching: find.byType(AnimatedScale)),
      );
      expect(scale.scale, lessThan(1));
      await gesture.up();
      await t.pumpAndSettle();
      expect(opened, 'MATH');
    },
  );

  testWidgets(
    'no joyful reaction or saved progress before answer acknowledgement',
    (t) async {
      final api = CompletionApi()..answerGate = Completer<AnswerFeedback>();
      await lessonScreen(t, api);
      await tapVisible(t, 'startLearning');
      await tapVisible(t, 'option-${data.optionId}');
      final submit = find.byKey(Key('submit-${data.cueId}'));
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pump();
      expect(find.text('Đã lưu 0 / 1 câu hỏi'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MimiBee &&
              [MimiMood.correct, MimiMood.completion].contains(w.mood),
        ),
        findsNothing,
      );
      api.answerGate!.complete(AnswerFeedback.fromJson(data.feedbackJson()));
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is MimiBee && w.mood == MimiMood.encourage,
        ),
        findsOneWidget,
      );
      await tapVisible(t, 'next-cue-${data.cueId}');
      expect(
        find.byKey(const Key('completeLearning')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is MimiBee && w.mood == MimiMood.completion,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('completion celebration waits for the server result', (t) async {
    final api = CompletionApi()..completeGate = Completer<LearningSession>();
    api.seedWrongAnswers(data.sessionId);
    await lessonScreen(t, api);
    await tapVisible(t, 'startLearning');
    final complete = find.byKey(const Key('completeLearning'));
    await t.ensureVisible(complete);
    await t.tap(complete);
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is MimiBee && w.mood == MimiMood.completion,
      ),
      findsNothing,
    );
    api.completeGate!.complete(api.completeReply(data.sessionId));
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is MimiBee && w.mood == MimiMood.completion,
      ),
      findsOneWidget,
    );
  });
}
