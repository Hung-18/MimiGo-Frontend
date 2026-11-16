import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mimigo_design.dart';
import 'mimi_world.dart';

/// Screen transition: short fade plus a small upward slide. Instant when the
/// system asks for reduced motion.
class MimiPageTransitionsBuilder extends PageTransitionsBuilder {
  const MimiPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MimiMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

const mimiPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: MimiPageTransitionsBuilder(),
    TargetPlatform.iOS: MimiPageTransitionsBuilder(),
  },
);

/// Press feedback that does not take part in hit testing: the child keeps its
/// own tap handling. Scales to .96 while a pointer is down (no motion if reduced).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});
  final Widget child;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool down = false;
  void set(bool v) {
    if (down != v && mounted) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MimiMotion.reduced(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => set(true),
      onPointerUp: (_) => set(false),
      onPointerCancel: (_) => set(false),
      child: AnimatedScale(
        scale: down && !reduced ? .96 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// One-shot confetti drawn in code (stars and dots, about 1.3 s). It only moves
/// along smooth curves and fades out: nothing blinks. Skipped for reduced motion.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({super.key, required this.child});
  final Widget child;
  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && !MimiMotion.reduced(context)) {
      started = true;
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, _) => controller.isCompleted || !started
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _BurstPainter(controller.value)),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t);
  final double t;
  static const colors = [
    MimiColors.yellow,
    MimiColors.orange,
    MimiColors.pink,
    MimiColors.purple,
    MimiColors.blue,
    MimiColors.green,
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(t);
    final alpha = t < .6 ? 1.0 : (1 - (t - .6) / .4).clamp(0.0, 1.0);
    final origin = Offset(size.width * .5, size.height * .55);
    for (var i = 0; i < 14; i++) {
      final angle = -math.pi / 2 + (i - 6.5) * .34;
      final reach = (size.shortestSide * .55 + (i % 3) * 18) * eased;
      final pos = origin + Offset(math.cos(angle), math.sin(angle)) * reach;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: alpha);
      final r = 4.0 + (i % 3) * 2;
      if (i.isEven) {
        canvas.drawPath(_star(pos, r * 1.6, t * math.pi), paint);
      } else {
        canvas.drawCircle(pos, r, paint);
      }
    }
  }

  Path _star(Offset c, double r, double rotation) {
    final p = Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * .45;
      final a = rotation + k * math.pi / 5 - math.pi / 2;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
      k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
