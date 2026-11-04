import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/po/code_input.dart';
import 'package:mimigo_frontend/mimigo_design.dart';

void main() {
  testWidgets(
    'single six-digit input filters paste, supports deletion, autofill and disabled state',
    (t) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      Widget app(bool enabled) => MaterialApp(
        theme: mimiTheme(),
        home: Scaffold(
          body: SixDigitCodeField(
            controller: code,
            fieldKey: const Key('code'),
            enabled: enabled,
          ),
        ),
      );
      await t.pumpWidget(app(true));
      await t.enterText(find.byKey(const Key('code')), 'a12 345678');
      expect(code.text, '123456');
      await t.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await t.enterText(find.byKey(const Key('code')), '12345');
      expect(code.text, '12345');
      final field = t.widget<TextFormField>(find.byKey(const Key('code')));
      expect(field.controller, same(code));
      expect(find.byType(EditableText), findsOneWidget);
      await t.pumpWidget(app(false));
      expect(
        t.widget<TextFormField>(find.byKey(const Key('code'))).enabled,
        isFalse,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('OTP remains usable at 320dp with 200 percent text', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final code = TextEditingController(text: '123456');
    await t.pumpWidget(
      MaterialApp(
        theme: mimiTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SixDigitCodeField(
                controller: code,
                fieldKey: const Key('code'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    code.dispose();
  });
  testWidgets(
    'expiry uses absolute server deadline and catches up after backgrounding',
    (t) async {
      var now = DateTime.utc(2030);
      final expires = now.add(const Duration(seconds: 62));
      await t.pumpWidget(
        MaterialApp(
          home: CodeExpiry(expiresAt: expires, now: () => now),
        ),
      );
      expect(find.textContaining('1:02'), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 70));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(find.textContaining('đã hết hạn'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
}
