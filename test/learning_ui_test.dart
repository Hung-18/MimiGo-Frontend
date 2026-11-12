import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/mimigo_design.dart';
import 'package:mimigo_frontend/po/learning_ui.dart';
import 'package:mimigo_frontend/po/po_design.dart';

import 'design_test_support.dart';

Widget questionScreen(FeedbackKind kind) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgress(done: 1, total: 3),
          const SizedBox(height: 12),
          QuestionBubble(
            prompt: 'Có mấy quả táo?',
            replay: () {},
            replayKey: const Key('replayQuestionAudio'),
          ),
          const SizedBox(height: 8),
          MimiTileGrid(
            minimumWidth: 210,
            children: [
              for (final (i, label) in ['Một quả', 'Hai quả', 'Ba quả'].indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 96),
                    child: OutlinedButton(
                      key: Key('opt-$i'),
                      style: answerCardStyle(i, selected: i == 1),
                      onPressed: () {},
                      child: Text(label, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FeedbackPanel(
            kind: kind,
            children: [
              Text(switch (kind) {
                FeedbackKind.correct => 'Đúng rồi!',
                FeedbackKind.retry => 'Chưa đúng, mình thử lại nhé!',
                FeedbackKind.exhausted => 'Mimi sẽ chỉ đáp án đúng nhé.',
              }),
              const Text('Có hai quả táo trong rổ.'),
            ],
          ),
        ],
      ),
    ),
  ),
);

void main() {
  setUpAll(loadDesignFonts);
  for (final size in const [Size(390, 844), Size(844, 390)]) {
    for (final kind in FeedbackKind.values) {
      final name = '${kind.name}_${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('question screen $name: 96dp answers, no overflow', (
        t,
      ) async {
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('cap'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: poTheme(),
              home: questionScreen(kind),
            ),
          ),
        );
        await t.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/mascot/mimi_poses.png'),
            t.element(find.byType(Scaffold)),
          );
        });
        await t.pump(const Duration(milliseconds: 500));
        for (var i = 0; i < 3; i++) {
          expect(
            t.getSize(find.byKey(Key('opt-$i'))).height,
            greaterThanOrEqualTo(96),
          );
        }
        expect(t.takeException(), isNull);
        if (Platform.environment['T06_SHOTS'] == '1') {
          await t.runAsync(() async {
            final b = t.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('cap')),
            );
            final im = await b.toImage(pixelRatio: 1.5);
            final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
            File('../_ba/screens/T06/$name.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
