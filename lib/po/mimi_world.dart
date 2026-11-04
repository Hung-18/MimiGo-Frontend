import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presentation states only. Callers supply confirmed Learning outcomes.
enum MimiMood {
  idle,
  greeting,
  guide,
  thinking,
  correct,
  encourage,
  completion,
}

abstract final class MimiMotion {
  static const entrance = Duration(milliseconds: 420);
  static const reaction = Duration(milliseconds: 1400);
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
}

/// A bounded animation burst: no timers, perpetual tickers or offscreen work.
/// Entry gives a little hover, wing flutter and blink, then Mimi rests.
class MimiBee extends StatefulWidget {
  const MimiBee({super.key, this.size = 140, this.mood = MimiMood.idle});
  final double size;
  final MimiMood mood;
  @override
  State<MimiBee> createState() => _MimiBeeState();
}

class _MimiBeeState extends State<MimiBee>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(
    vsync: this,
    duration: MimiMotion.reaction,
  );
  bool foreground = true;
  bool get allowed =>
      foreground &&
      TickerMode.valuesOf(context).enabled &&
      !MimiMotion.reduced(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void play() {
    if (allowed) controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (allowed) {
      if (!controller.isCompleted) controller.forward();
    } else {
      controller.stop();
    }
  }

  @override
  void didUpdateWidget(MimiBee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      controller.stop();
    } else if (allowed && !controller.isCompleted) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: switch (widget.mood) {
      MimiMood.greeting => 'Mimi vẫy chào bé',
      MimiMood.guide => 'Mimi cùng bé khám phá',
      MimiMood.thinking => 'Mimi đang chờ cùng bé',
      MimiMood.correct => 'Mimi vui cùng bé',
      MimiMood.encourage => 'Mimi động viên bé',
      MimiMood.completion => 'Mimi chúc mừng bé hoàn thành',
      MimiMood.idle => 'Mimi, bạn ong nhỏ',
    },
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _MimiPainter(widget.mood, allowed ? controller.value : 1),
        ),
      ),
    ),
  );
}

const _ink = Color(0xFF49335E);
const _leaf = Color(0xFF61A780);

class _MimiPainter extends CustomPainter {
  const _MimiPainter(this.mood, this.t);
  final MimiMood mood;
  final double t;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 180, s.height / 180);
    final p = Paint()..strokeCap = StrokeCap.round;
    void oval(double x, double y, double w, double h, Color color) {
      p
        ..color = color
        ..style = PaintingStyle.fill;
      c.drawOval(Rect.fromLTWH(x, y, w, h), p);
    }

    void line(Offset a, Offset b, double width) {
      p
        ..color = _ink
        ..strokeWidth = width
        ..style = PaintingStyle.stroke;
      c.drawLine(a, b, p);
    }

    final wave = math.sin(t * math.pi * 4) * (1 - t);
    final joyful = mood == MimiMood.correct || mood == MimiMood.completion;
    oval(42, 158, 100, 10, const Color(0x1F32644F));
    c.translate(0, -wave * (joyful ? 7 : 3));
    oval(15, 44 - wave * 5, 70, 43 + wave * 8, const Color(0xFFF4FCFF));
    oval(99, 39 + wave * 5, 66, 48 - wave * 8, const Color(0xFFF4FCFF));
    oval(32, 53, 116, 102, const Color(0xFFFFD14F));
    c.save();
    c.clipPath(Path()..addOval(const Rect.fromLTWH(32, 53, 116, 102)));
    oval(18, 116, 143, 15, _ink);
    oval(18, 143, 143, 12, _ink);
    c.restore();
    line(const Offset(67, 57), const Offset(53, 31), 4);
    line(const Offset(112, 57), const Offset(127, 30), 4);
    oval(46, 22, 12, 12, _ink);
    oval(122, 21, 12, 12, _ink);
    final blink = t > .44 && t < .50;
    if (blink || joyful) {
      for (final x in [66.0, 107.0]) {
        p
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        c.drawArc(Rect.fromLTWH(x - 6, 79, 13, 12), math.pi, math.pi, false, p);
      }
    } else {
      oval(62, 79, 9, mood == MimiMood.thinking ? 9 : 13, _ink);
      oval(104, 79, 9, 13, _ink);
      oval(64, 80, 3, 4, Colors.white);
      oval(106, 80, 3, 4, Colors.white);
    }
    oval(45, 96, 20, 11, const Color(0xFFF69BA4));
    oval(114, 96, 20, 11, const Color(0xFFF69BA4));
    p
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawArc(
      Rect.fromLTWH(78, 94, 24, joyful ? 21 : 12),
      0,
      math.pi,
      false,
      p,
    );
    final handY = switch (mood) {
      MimiMood.greeting => 75.0 + wave * 12,
      MimiMood.guide => 106.0,
      MimiMood.thinking => 95.0,
      _ => joyful ? 72.0 + wave * 6 : 115.0,
    };
    line(const Offset(142, 112), Offset(164, handY), 6);
    oval(158, handY - 5, 12, 12, const Color(0xFFFFD14F));
    line(const Offset(36, 114), Offset(18, joyful ? 84 : 123), 6);
    if (joyful) {
      // Decorative sparkles, never a score, currency or earned badge.
      for (var i = 0; i < 5; i++) {
        final x = 14.0 + i * 37;
        final y = 17.0 + (i.isEven ? 0 : 14);
        p
          ..color = i.isEven ? const Color(0xFFEDA149) : const Color(0xFFDD73A7)
          ..style = PaintingStyle.fill;
        c.drawCircle(Offset(x, y), 2 + 2 * math.sin(t * math.pi), p);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_MimiPainter old) => old.mood != mood || old.t != t;
}

/// Original scenery shared by welcome, discovery and supportive states.
class GardenScene extends StatelessWidget {
  const GardenScene({super.key, this.child, this.height = 210});
  final Widget? child;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ExcludeSemantics(child: CustomPaint(painter: _GardenPainter())),
        if (child != null) Center(child: child),
      ],
    ),
  );
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    c.save();
    c.scale(s.width / 360, s.height / 230);
    void oval(double x, double y, double w, double h, Color color) {
      p.color = color;
      c.drawOval(Rect.fromLTWH(x, y, w, h), p);
    }

    oval(278, 10, 43, 43, const Color(0xFFFFD568));
    for (final x in [20.0, 222.0]) {
      oval(x, 34, 64, 16, Colors.white);
      oval(x + 14, 22, 28, 28, Colors.white);
    }
    oval(-110, 155, 440, 180, const Color(0xFFB6DDB1));
    oval(160, 152, 350, 190, const Color(0xFF9ECDAD));
    p.color = const Color(0xFFFFE8BA);
    c.drawPath(
      Path()
        ..moveTo(166, 230)
        ..quadraticBezierTo(280, 185, 188, 171)
        ..quadraticBezierTo(326, 192, 240, 230)
        ..close(),
      p,
    );
    for (final x in [28.0, 323.0]) {
      p
        ..color = const Color(0xFF99775C)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(x, 170), Offset(x, 100), p);
      oval(x - 25, 74, 50, 64, _leaf);
      oval(x - 19, 63, 40, 49, const Color(0xFF83BF85));
    }
    for (var i = 0; i < 9; i++) {
      final x = 10.0 + i * 43;
      final y = 202.0 + (i.isEven ? 7 : -8);
      p
        ..color = _leaf
        ..strokeWidth = 3;
      c.drawLine(Offset(x, y), Offset(x, y + 17), p);
      for (var j = 0; j < 5; j++) {
        final a = j * math.pi * 2 / 5;
        oval(
          x - 4 + math.cos(a) * 6,
          y - 4 + math.sin(a) * 6,
          8,
          8,
          i.isEven ? const Color(0xFFF7A7C6) : const Color(0xFFFFF8E9),
        );
      }
      oval(x - 3, y - 3, 6, 6, const Color(0xFFFFCE46));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) => false;
}

/// Native illustrated destinations for the six canonical curriculum codes.
class DomainIllustration extends StatelessWidget {
  const DomainIllustration(this.kind, {super.key});
  final int kind;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 86,
      width: 132,
      child: CustomPaint(painter: _DomainPainter(kind)),
    ),
  );
}

class _DomainPainter extends CustomPainter {
  const _DomainPainter(this.kind);
  final int kind;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 132, s.height / 86);
    final p = Paint();
    void shape(Rect rect, Color color, [double radius = 12]) {
      p.color = color;
      c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), p);
    }

    shape(const Rect.fromLTWH(7, 69, 118, 10), const Color(0xFFD0DFC5), 5);
    if (kind == 0) {
      for (var i = 0; i < 3; i++) {
        shape(
          Rect.fromLTWH(14 + i * 35, 39 - i * 12, 30, 30 + i * 12),
          [
            const Color(0xFFF393A9),
            const Color(0xFFFAC95B),
            const Color(0xFF83BDD8),
          ][i],
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(22 + i * 35, 38 - i * 12));
      }
    } else if (kind == 1 || kind == 2) {
      shape(const Rect.fromLTWH(18, 19, 47, 49), const Color(0xFFF7ACB8), 6);
      shape(const Rect.fromLTWH(67, 19, 47, 49), const Color(0xFFFFE7AC), 6);
      for (var i = 0; i < 3; i++) {
        shape(Rect.fromLTWH(29, 33 + i * 10, 23, 3), Colors.white, 1);
        shape(
          Rect.fromLTWH(79, 33 + i * 10, 23, 3),
          const Color(0xFFB4A681),
          1,
        );
      }
      if (kind == 2) {
        shape(const Rect.fromLTWH(74, 2, 47, 25), const Color(0xFF9DCFD4));
        final tp = TextPainter(
          text: const TextSpan(
            text: 'Hi!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, const Offset(84, 1));
      }
    } else if (kind == 3) {
      shape(const Rect.fromLTWH(39, 33, 54, 38), const Color(0xFF85BCAF));
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = _leaf;
      c.drawArc(
        const Rect.fromLTWH(48, 18, 36, 36),
        math.pi,
        math.pi,
        false,
        p,
      );
      p.style = PaintingStyle.fill;
      shape(const Rect.fromLTWH(48, 41, 36, 19), const Color(0xFFE6F4D1), 6);
    } else if (kind == 4) {
      shape(const Rect.fromLTWH(18, 31, 40, 40), const Color(0xFFB69BDF), 4);
      p.color = const Color(0xFFEFAD83);
      c.drawCircle(const Offset(91, 51), 21, p);
      p.color = const Color(0xFF91BFBA);
      c.drawPath(
        Path()..addPolygon(const [
          Offset(45, 26),
          Offset(67, 0),
          Offset(89, 26),
        ], true),
        p,
      );
    } else {
      shape(const Rect.fromLTWH(60, 43, 7, 29), _leaf, 3);
      p.color = const Color(0xFF98CBB1);
      c.drawOval(const Rect.fromLTWH(30, 30, 34, 17), p);
      c.drawOval(const Rect.fromLTWH(65, 20, 35, 20), p);
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _ink;
      c.drawCircle(const Offset(48, 35), 22, p);
      c.drawLine(const Offset(31, 52), const Offset(15, 69), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_DomainPainter old) => kind != old.kind;
}

/// Count reflects acknowledged cues in this session, independent of correctness.
class SessionTrail extends StatelessWidget {
  const SessionTrail({super.key, required this.recorded, required this.total});
  final int recorded, total;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đã lưu $recorded trên $total câu hỏi',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Đã lưu $recorded / $total câu hỏi',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: total == 0 ? 0 : (recorded / total).clamp(0, 1)),
          duration: MimiMotion.reduced(context)
              ? Duration.zero
              : MimiMotion.entrance,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 10,
              child: ColoredBox(
                color: const Color(0xFFE4EFE5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: const ColoredBox(
                      color: _leaf,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

/// Use only the exact option label. Numeric dot groups are a rendering of that
/// number, not an inferred object, solution or new activity contract.
class ActivityChoice extends StatelessWidget {
  const ActivityChoice({
    super.key,
    required this.label,
    required this.selected,
  });
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final number = int.tryParse(label);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (number != null && number > 0 && number <= 10)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(
                  number,
                  (_) => Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF619F91),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Text(
          '${selected ? 'Đã chọn: ' : ''}$label',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (selected)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.check_circle_outline_rounded, size: 22),
          ),
      ],
    );
  }
}
