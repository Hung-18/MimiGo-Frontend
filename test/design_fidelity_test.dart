import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/mimigo_design.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/parent_gate_screens.dart';

import 'design_test_support.dart';
import 'learning_test_data.dart' as data;
import 'learning_widget_test.dart' show tapVisible;

Future<void> capturePublicWidget(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('MIMIGO_CAPTURE_VISUALS')) return;
  expect(find.byType(GatePinScreen), findsNothing);
  expect(find.byType(GatedParentArea), findsNothing);
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('publicVisualSurface')),
    );
    final rendered = await boundary.toImage();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('reports/evidence/ui_fidelity');
    await directory.create(recursive: true);
    await File('${directory.path}/widget_$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    rendered.dispose();
  });
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);
  test(
    'brand action, link, body and decorative domain labels meet UI-03 contrast',
    () {
      for (final pair in [
        (MimiColors.ink, Colors.white),
        (MimiColors.muted, Colors.white),
        (Colors.white, MimiColors.action),
        (MimiColors.ink, MimiColors.yellow),
        (MimiColors.blueText, Colors.white),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      for (final code in [
        'MATH',
        'LANGUAGE',
        'ENGLISH',
        'LIFE',
        'LOGIC',
        'DISCOVERY',
      ]) {
        final fill = Color.alphaBlend(
          MimiDomainStyle.forCode(code).color.withValues(alpha: .1),
          Colors.white,
        );
        expect(contrast(MimiColors.ink, fill), greaterThanOrEqualTo(4.5));
      }
    },
  );
  for (final size in [
    const Size(320, 740),
    const Size(411, 891),
    const Size(960, 540),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'six live-domain controls and locked Parent navigation at $size / text $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var opened = 0;
          await tester.pumpWidget(
            visualApp(
              ChildHome(
                child: visualChild,
                fixture: false,
                category: (_) => opened++,
                english: () => opened++,
                accountEntry: () {},
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          await capturePublicWidget(
            tester,
            '${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).toInt()}_child',
          );
          for (final code in [
            'math',
            'language',
            'english',
            'lifeSkills',
            'logic',
            'discovery',
          ]) {
            final control = find.byKey(Key('category-$code'));
            expect(tester.getSize(control).width, greaterThanOrEqualTo(64));
            expect(tester.getSize(control).height, greaterThanOrEqualTo(64));
            await tapVisible(tester, 'category-$code');
          }
          expect(opened, 6);
          expect(find.byKey(const Key('category-arts')), findsNothing);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('childParentGate')),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'reference A02 password confirmation validates locally without adding API fields',
    (tester) async {
      final api = FixtureMimiGoApi();
      final reference = await tester.runAsync(api.onboardingReference);
      Registration? request;
      await tester.pumpWidget(
        visualApp(
          Register(
            reference: reference!,
            fixture: true,
            back: () {},
            submitted: (value) async {
              request = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'termsCheckbox');
      await tester.enterText(
        find.byKey(const Key('registerPasswordConfirmation')),
        'different-synthetic-password',
      );
      await tapVisible(tester, 'registerSubmit');
      expect(request, isNull);
      expect(find.text('Ba mẹ nhập lại đúng mật khẩu nhé.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('registerPasswordConfirmation')),
        'synthetic-pass',
      );
      await tapVisible(tester, 'registerSubmit');
      expect(request, isNotNull);
      expect(request!.toJson().keys.toSet(), {
        'email',
        'password',
        'displayName',
        'termsVersionId',
        'termsAccepted',
      });
    },
  );
  testWidgets(
    'Terms remain explicit and Material checkbox ink is unobscured in the new panel',
    (tester) async {
      final api = FixtureMimiGoApi();
      final reference = await tester.runAsync(api.onboardingReference);
      await tester.pumpWidget(
        visualApp(
          Register(
            reference: reference!,
            fixture: true,
            back: () {},
            submitted: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isFalse,
      );
      await tapVisible(tester, 'termsCheckbox');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('termsCheckbox')))
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'landscape choices, acknowledgment-only feedback and completed/replay state retain behavior',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = visualLearningApi();
      final pending = PendingLearningAnswers();
      await tester.pumpWidget(
        visualApp(
          Frame(
            title: 'Learning',
            childMode: true,
            wide: true,
            children: [
              LearningLessonView(
                api: api,
                childId: data.childId,
                lessonId: data.lessonId,
                pending: pending,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'startLearning');
      await tester.ensureVisible(
        find.byKey(const Key('option-${data.optionId}')),
      );
      await tester.pumpAndSettle();
      await capturePublicWidget(tester, '960x540_question');
      expect(
        tester.getSize(find.byKey(const Key('option-${data.optionId}'))).width,
        greaterThan(350),
        reason: 'Two landscape choices share the available width without empty columns.',
      );
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      expect(find.byKey(const Key('feedback-${data.cueId}')), findsNothing);
      await tapVisible(tester, 'option-${data.optionId}');
      expect(find.byKey(const Key('feedback-${data.cueId}')), findsNothing);
      await tapVisible(tester, 'submit-${data.cueId}');
      await tester.ensureVisible(
        find.byKey(const Key('feedback-${data.cueId}')),
      );
      await tester.pumpAndSettle();
      await capturePublicWidget(tester, '960x540_feedback');
      expect(find.byKey(const Key('feedback-${data.cueId}')), findsOneWidget);
      await tapVisible(tester, 'completeLearning');
      await capturePublicWidget(tester, '960x540_completed');
      expect(find.byKey(const Key('completionConfirmed')), findsOneWidget);
      await tapVisible(tester, 'replayLearning');
      expect(find.byKey(const Key('completionConfirmed')), findsNothing);
      expect(find.text('Lượt học: Đang học'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('approved font families render Vietnamese brand text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 891));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      visualApp(
        Frame(
          title: 'Cùng Mimi khám phá',
          children: const [
            Text('Chọn bài học · Khám phá · Phụ huynh'),
            Text('Sẵn sàng học cùng Mimi? Đọc, đếm và khám phá.'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capturePublicWidget(tester, '411x891_font_specimen');
    expect(tester.takeException(), isNull);
  });
}
