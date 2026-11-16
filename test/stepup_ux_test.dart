import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/gate_screen_security.dart';
import 'package:mimigo_frontend/parent_gate_api.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';

import 'learning_widget_test.dart' show tapVisible;
import 'parent_gate_repository_test.dart' show gateClient;
import 'parent_gate_test_backend.dart';
import 'parent_gate_widget_test.dart'
    show TestScreenSecurity, gateWidgets, trackedGateApis;

Future<void> pumpChange(WidgetTester tester) async {
  final api = await gateClient(GateTestBackend());
  trackedGateApis.add(api);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GatePinScreen(
          api: api,
          security: TestScreenSecurity() as GateScreenSecurity,
          pinAction: PinAction.change,
          done: () async {},
          back: () {},
          accountEntry: () {},
          recover: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool obscured(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).obscureText;

void main() {
  gateWidgets('PIN step-up password has an eye toggle; PIN fields do not', (
    tester,
  ) async {
    await pumpChange(tester);
    expect(obscured(tester, 'gatePassword'), isTrue);
    await tapVisible(tester, 'gatePasswordToggle');
    expect(obscured(tester, 'gatePassword'), isFalse);
    expect(obscured(tester, 'gatePin'), isTrue);
    expect(find.byKey(const Key('gatePasswordToggle')), findsOneWidget);
    await tapVisible(tester, 'gatePasswordToggle');
    expect(obscured(tester, 'gatePassword'), isTrue);
  });

  gateWidgets(
    'STEP_UP_FAILED shows a password-only message, details collapsed',
    (tester) async {
      await pumpChange(tester);
      await tester.enterText(
        find.byKey(const Key('gatePassword')),
        'wrong-one',
      );
      await tester.enterText(find.byKey(const Key('gatePin')), '395184');
      await tester.enterText(
        find.byKey(const Key('gatePinConfirmation')),
        '395184',
      );
      await tapVisible(tester, 'gateSubmit');
      await tester.pumpAndSettle();
      expect(
        find.text('Mật khẩu chưa đúng. Ba mẹ kiểm tra lại nhé.'),
        findsOneWidget,
      );
      expect(find.textContaining('Email'), findsNothing);
      expect(find.textContaining('STEP_UP_FAILED'), findsNothing);
    },
  );
}
