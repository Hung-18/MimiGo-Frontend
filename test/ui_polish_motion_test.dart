import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mimigo_design.dart';
import 'package:mimigo_frontend/po/avatar_choice.dart';
import 'package:mimigo_frontend/po/learning_ui.dart';
import 'package:mimigo_frontend/po/motion.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: mimiTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('avatar choices show a coloured badge with the avatar name', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChildInput(back: () {}, next: (_) {})));
    for (final o in childAvatarOptions) {
      final chip = find.byKey(Key('avatar-${o.key}'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.byType(AvatarBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip, matching: find.text(o.name)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('AvatarBadge draws the stock colour and a fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Row(
          children: [
            AvatarBadge(stockKey: 'bear-blue'),
            AvatarBadge(stockKey: 'unknown-key'),
          ],
        ),
      ),
    );
    final discs = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .toList();
    expect(discs, contains(MimiColors.blue));
    expect(discs, contains(MimiColors.sky));
    expect(avatarOptionFor('bee-yellow')?.name, 'Ong vàng');
    expect(avatarOptionFor('nope'), isNull);
  });

  testWidgets('correct feedback plays a finite celebration and ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const FeedbackPanel(
          kind: FeedbackKind.correct,
          children: [Text('Đúng rồi!')],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byType(CelebrationBurst),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Đúng rồi!'), findsOneWidget);
  });

  testWidgets('retry and exhausted feedback have no celebration', (
    tester,
  ) async {
    for (final k in [FeedbackKind.retry, FeedbackKind.exhausted]) {
      await tester.pumpWidget(
        host(FeedbackPanel(kind: k, children: const [Text('x')])),
      );
      expect(find.byType(CelebrationBurst), findsNothing);
    }
  });

  testWidgets('reduced motion skips the celebration and the press scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            FeedbackPanel(kind: FeedbackKind.correct, children: [Text('ok')]),
            PressScale(child: SizedBox(key: Key('p'), width: 100, height: 100)),
          ],
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('p'))),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });

  testWidgets(
    'press scale shrinks while a pointer is down and keeps taps working',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PressScale(
            child: OutlinedButton(
              key: const Key('b'),
              onPressed: () => taps++,
              child: const Text('Chọn'),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('b'))),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        lessThan(1),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );

  testWidgets(
    'screen transition fades and slides, and is instant when reduced',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mimiTheme(),
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('next')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(FadeTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    },
  );
}
