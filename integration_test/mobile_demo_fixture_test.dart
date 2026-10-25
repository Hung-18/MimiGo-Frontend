import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mobile_demo.dart';

import 'live_auth_test.dart' show tap, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android no-credentials local storyboard, feedback, complete, replay and clean exit',
    (tester) async {
      final config = ApiConfiguration.fromEnvironment();
      expect(config.mode, ApiMode.fixture);
      await tester.pumpWidget(MimiGoApp(configuration: config));
      await waitFor(tester, find.byKey(const Key('welcomeMobileDemo')));
      await tap(tester, 'welcomeMobileDemo');
      await tap(tester, 'demoProfile-Bé Nắng');
      await tap(tester, 'demoEnterChild');
      await waitFor(tester, find.text('Chào Bé Nắng!'));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('demoParentLocked')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'demoFruitLesson');
      await tap(tester, 'demoStartStory');
      for (var i = 0; i < 3; i++) {
        await tap(tester, 'demoPauseCue');
        await tap(tester, 'demoAnswer-${i == 0 ? 1 : i}');
        await waitFor(tester, find.byKey(const Key('demoFeedback')));
        expect(
          find.textContaining(i == 0 ? 'Cùng nhìn lại nhé' : 'Đúng rồi!'),
          findsOneWidget,
        );
        await tap(tester, 'demoContinueStory');
      }
      await waitFor(tester, find.byKey(const Key('demoCompleted')));
      await tap(tester, 'demoReplay');
      await tap(tester, 'demoPauseCue');
      expect(find.byKey(const Key('demoFeedback')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Chào Bé Nắng!'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(tester, 'demoConfirmExit');
      await waitFor(tester, find.byKey(const Key('welcomeMobileDemo')));
      expect(find.byType(MobileDemo), findsNothing);
    },
  );
}
