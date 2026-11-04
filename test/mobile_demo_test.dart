import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mobile_demo.dart';

import 'child_onboarding_test.dart' show noticeSnapshot;
import 'design_test_support.dart';
import 'design_fidelity_test.dart' show capturePublicWidget;

Future<void> demoTap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    MimiGoApp(configuration: const ApiConfiguration(ApiMode.fixture, 'unused')),
  );
  await tester.pumpAndSettle();
  await demoTap(tester, 'welcomeMobileDemo');
}

void main() {
  setUpAll(loadDesignFonts);

  testWidgets(
    'direct local journey: profiles, wrong/right feedback, continuation, completion, replay and exit',
    (tester) async {
      await enterDemo(tester);
      await demoTap(tester, 'demoProfile-Bé Nắng');
      expect(find.text('Không gian của Bé Nắng'), findsOneWidget);
      await demoTap(tester, 'demoEnterChild');
      expect(find.text('Chào Bé Nắng!'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('demoParentLocked')))
            .onPressed,
        isNull,
      );
      await demoTap(tester, 'demoDomain-MATH');
      expect(
        find.text('Lĩnh vực này chưa có bài trong bản demo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Về trang khám phá'));
      await tester.pumpAndSettle();
      await demoTap(tester, 'demoFruitLesson');
      expect(find.textContaining('không phải video'), findsOneWidget);
      await demoTap(tester, 'demoStartStory');
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(const Key('demoAnswer-0')), findsNothing);
        await demoTap(tester, 'demoPauseCue');
        expect(find.byKey(const Key('demoContinueStory')), findsNothing);
        // Chưa đúng answers are valid demo evidence and do not block completion.
        await demoTap(tester, 'demoAnswer-${i == 0 ? 1 : i}');
        expect(
          find.textContaining(i == 0 ? 'Cùng nhìn lại nhé' : 'Đúng rồi!'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('demoAnswer-0')))
              .onPressed,
          isNull,
        );
        await demoTap(tester, 'demoContinueStory');
      }
      expect(find.byKey(const Key('demoCompleted')), findsOneWidget);
      expect(find.textContaining('Không gửi hay lưu tiến độ'), findsOneWidget);
      await demoTap(tester, 'demoReplay');
      await demoTap(tester, 'demoPauseCue');
      expect(find.byKey(const Key('demoFeedback')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('demoAnswer-0')))
            .onPressed,
        isNotNull,
      );
      // Android Back goes to child discovery, never to Parent profile selection.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Chào Bé Nắng!'), findsOneWidget);
      expect(find.byKey(const Key('demoProfile-Bé Mây')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileDemo), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await demoTap(tester, 'demoConfirmExit');
      expect(find.byType(MobileDemo), findsNothing);
      await demoTap(tester, 'welcomeMobileDemo');
      expect(find.text('Không gian của Bé Mây'), findsOneWidget);
      expect(find.byKey(const Key('demoCompleted')), findsNothing);
    },
  );

  testWidgets('live welcome cannot enter local demo', (tester) async {
    await tester.pumpWidget(
      MimiGoApp(
        configuration: const ApiConfiguration(
          ApiMode.live,
          'http://unused/api/v1',
        ),
        api: FixtureMimiGoApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcomeMobileDemo')), findsNothing);
  });

  testWidgets(
    'privacy metadata remains accessible and purposes stay unchecked',
    (tester) async {
      await tester.pumpWidget(
        visualApp(
          Privacy(
            attempt: OnboardingAttempt(
              'demo-notice',
              DateTime(2099),
              noticeSnapshot(),
            ),
            begin: () async => throw StateError('not used'),
            next: () {},
            declined: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ và độ tuổi của bé'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('consent-CHILD_PROFILE_AGE')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('privacyContinue')))
            .onPressed,
        isNull,
      );
      final expansion = find.byType(ExpansionTile).first;
      await tester.ensureVisible(expansion);
      await tester.tap(expansion);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Mã mục đích: CHILD_PROFILE_AGE'),
        findsOneWidget,
      );
      expect(find.textContaining('Mã kiểm tra nội dung:'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(411, 891),
    const Size(960, 540),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('story and choices fit $size at $scale text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          visualApp(const MobileDemo(startInChildMode: true), scale: scale),
        );
        await tester.pumpAndSettle();
        await capturePublicWidget(
          tester,
          'mobile_demo_home_${size.width.toInt()}_${scale.toInt()}',
        );
        await demoTap(tester, 'demoFruitLesson');
        await demoTap(tester, 'demoStartStory');
        await demoTap(tester, 'demoPauseCue');
        for (var i = 0; i < 3; i++) {
          expect(
            tester.getSize(find.byKey(Key('demoAnswer-$i'))).height,
            greaterThanOrEqualTo(64),
          );
        }
        await demoTap(tester, 'demoAnswer-0');
        await capturePublicWidget(
          tester,
          'mobile_demo_feedback_${size.width.toInt()}_${scale.toInt()}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
