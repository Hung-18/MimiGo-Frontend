import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/po/po_design.dart';
import 'package:mimigo_frontend/po/preview_app.dart';
import 'package:mimigo_frontend/po/preview_learning.dart';
import 'package:mimigo_frontend/po/preview_state.dart';

import 'design_test_support.dart';

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  expect(find.byType(PreviewGate), findsNothing);
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('poCapture')),
    );
    final im = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final file = File('reports/evidence/po_mobile/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

Widget shell(Widget page, {double scale = 1}) => MaterialApp(
  theme: poTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(key: const Key('poCapture'), child: child!),
  ),
  home: page,
);
void main() {
  setUpAll(loadDesignFonts);
  for (final domain in previewDomains) {
    testWidgets(
      '${domain.name}: wrong answer, complete and replay are interactive',
      (t) async {
        final model = PreviewState();
        addTearDown(model.dispose);
        await t.pumpWidget(shell(PreviewGame(domain: domain, model: model)));
        await t.pumpAndSettle();
        await tap(t, find.byKey(const Key('gameChoice-1')));
        expect(find.text('Mình thử một lựa chọn khác nhé!'), findsOneWidget);
        final rounds = [0, 3, 4].contains(domain.kind) ? 3 : 1;
        for (var i = 0; i < rounds; i++) {
          final index = domain.kind == 0 || domain.kind == 3
              ? i
              : domain.kind == 4
              ? i % 2
              : 0;
          await tap(t, find.byKey(Key('gameChoice-$index')));
          if (domain.kind == 0 && i == 0) await capture(t, 'counting_feedback');
          await tap(t, find.byKey(const Key('gameNext')));
        }
        expect(model.completed, [domain.activity]);
        expect(find.text('Bé đã chơi xong!'), findsOneWidget);
        await tap(t, find.text('Chơi lại'));
        expect(find.byKey(const Key('gameChoice-0')), findsOneWidget);
        expect(model.completed, hasLength(1));
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'preview family selects child and PIN gates both mode transitions',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: poTheme(),
          home: Builder(
            builder: (c) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute<void>(builder: (_) => const PoPreview()),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tap(t, find.text('Open'));
      await tap(t, find.text('Vào thế giới của bé'));
      await t.enterText(find.byKey(const Key('previewPin')), '583927');
      await t.enterText(find.byKey(const Key('previewPinConfirm')), '583927');
      await tap(t, find.text('Tiếp tục preview'));
      expect(find.textContaining('Thế giới của'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('previewPin')), findsOneWidget);
      await t.enterText(find.byKey(const Key('previewPin')), '583928');
      await tap(t, find.text('Tiếp tục preview'));
      expect(find.textContaining('PIN mẫu chưa đúng'), findsOneWidget);
      await t.enterText(find.byKey(const Key('previewPin')), '583927');
      await tap(t, find.text('Tiếp tục preview'));
      expect(find.text('Góc phụ huynh'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('public parent preview render at phone size', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(shell(const PoPreview()));
    await t.pumpAndSettle();
    await capture(t, 'parent_home');
    expect(t.takeException(), isNull);
  });
  testWidgets('narrow phone and large type have no overflow', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(shell(const PoPreview(), scale: 2));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await tap(t, find.text('Cài đặt'));
    expect(t.takeException(), isNull);
    await tap(t, find.text('Gia đình'));
    await tap(t, find.text('Vào thế giới của bé'));
    await t.enterText(find.byKey(const Key('previewPin')), '583927');
    await t.enterText(find.byKey(const Key('previewPinConfirm')), '583927');
    await tap(t, find.text('Tiếp tục preview'));
    expect(t.takeException(), isNull);
  });
  testWidgets('public child and settings screens render and navigate', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(shell(const PoPreview()));
    await t.pumpAndSettle();
    await tap(t, find.text('Vào thế giới của bé'));
    await t.enterText(find.byKey(const Key('previewPin')), '583927');
    await t.enterText(find.byKey(const Key('previewPinConfirm')), '583927');
    await tap(t, find.text('Tiếp tục preview'));
    await capture(t, 'child_home');
    await tap(t, find.text('Toán học'));
    await capture(t, 'subject_math');
    await tap(t, find.text('Giỏ táo của Mimi'));
    await capture(t, 'lesson_detail');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('previewPin')), '583927');
    await tap(t, find.text('Tiếp tục preview'));
    await tap(t, find.text('Cài đặt'));
    await capture(t, 'parent_settings');
    await tap(t, find.text('Gói học & phạm vi'));
    await capture(t, 'premium_preview');
    await tap(t, find.text('Xem tóm tắt'));
    expect(find.textContaining('Chưa mua'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
