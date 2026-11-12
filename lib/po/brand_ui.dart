import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mimigo_design.dart';
import 'mimi_world.dart';

/// Sky, clouds and hills drawn in code (no bitmap). Decorative only.
class BrandSky extends StatelessWidget {
  const BrandSky({super.key, this.height = 340});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: const _SkyPainter(),
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FB3FF), Color(0xFF9ED8FF), Color(0xFFDDF2FF)],
        ).createShader(rect),
    );
    void cloud(double cx, double cy, double w) {
      final p = Paint()..color = Colors.white.withValues(alpha: .9);
      final h = w * .34;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
          Radius.circular(h / 2),
        ),
        p,
      );
      canvas.drawCircle(Offset(cx - w * .12, cy - h * .35), h * .6, p);
      canvas.drawCircle(Offset(cx + w * .14, cy - h * .45), h * .75, p);
    }

    cloud(s.width * .18, s.height * .12, 110);
    cloud(s.width * .78, s.height * .08, 140);
    cloud(s.width * .55, s.height * .27, 90);
    Path hill(double y0, double y1, double y2) => Path()
      ..moveTo(0, s.height * y0)
      ..cubicTo(
        s.width * .3,
        s.height * y1,
        s.width * .6,
        s.height * y2,
        s.width,
        s.height * y0,
      )
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(
      hill(.70, .56, .80),
      Paint()..color = const Color(0xFF8FD67F),
    );
    canvas.drawPath(hill(.82, .96, .68), Paint()..color = MimiColors.green);
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

/// Brand color per canonical domain index: Math, Language, English,
/// Life skills, Logic, Discovery.
const brandDomainColors = [
  MimiColors.orange,
  MimiColors.blue,
  MimiColors.pink,
  MimiColors.green,
  MimiColors.purple,
  MimiColors.yellow,
];

/// Material icons for domains whose hand-drawn shape was too crude
/// (English, Life skills); null keeps the custom painter.
const _domainIcons = <IconData?>[
  null,
  null,
  Icons.menu_book_rounded,
  Icons.volunteer_activism_rounded,
  null,
  null,
];

/// Large rounded brand-colored domain card. Label sits on a white pill so
/// text keeps strong contrast on every brand color.
class BrandDomainCard extends StatefulWidget {
  const BrandDomainCard({
    super.key,
    required this.index,
    required this.label,
    required this.caption,
    required this.onTap,
    this.locked = false,
  });
  final int index;
  final String label, caption;
  final VoidCallback? onTap;
  final bool locked;
  @override
  State<BrandDomainCard> createState() => _BrandDomainCardState();
}

class _BrandDomainCardState extends State<BrandDomainCard> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final index = widget.index, label = widget.label;
    final caption = widget.caption, locked = widget.locked;
    final base = brandDomainColors[index % brandDomainColors.length];
    final reduced = MimiMotion.reduced(context);
    return AnimatedScale(
      scale: pressed && !reduced ? .975 : 1,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
      child: Material(
        color: locked ? base.withValues(alpha: .35) : base,
        borderRadius: BorderRadius.circular(32),
        elevation: locked ? 0 : 3,
        shadowColor: base.withValues(alpha: .5),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => pressed = value),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: _domainIcons[index % 6] == null
                      ? CustomPaint(
                          size: const Size.square(84),
                          painter: _DomainShapePainter(index),
                        )
                      : Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .35),
                          ),
                          child: Icon(
                            _domainIcons[index % 6],
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontFamily: 'Baloo2',
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                height: 1.1,
                                color: MimiColors.ink,
                              ),
                            ),
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 12,
                                color: MimiColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        locked
                            ? Icons.lock_outline
                            : Icons.arrow_forward_rounded,
                        size: 22,
                        color: MimiColors.ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DomainShapePainter extends CustomPainter {
  const _DomainShapePainter(this.index);
  final int index;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 100);
    final white = Paint()..color = Colors.white;
    final soft = Paint()..color = Colors.white.withValues(alpha: .35);
    final ink = Paint()
      ..color = MimiColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawCircle(const Offset(50, 50), 46, soft);
    switch (index % 6) {
      case 0: // math: plus sign
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 18, 20, 64),
            const Radius.circular(10),
          ),
          white,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 40, 64, 20),
            const Radius.circular(10),
          ),
          white,
        );
      case 1: // language: speech bubble
        c.drawPath(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(16, 20, 68, 48),
                const Radius.circular(20),
              ),
            )
            ..moveTo(32, 66)
            ..lineTo(28, 84)
            ..lineTo(48, 68)
            ..close(),
          white,
        );
        for (final x in [36.0, 50.0, 64.0]) {
          c.drawCircle(Offset(x, 44), 4.5, Paint()..color = MimiColors.blue);
        }
      case 2: // english: open book
        c.drawPath(
          Path()
            ..moveTo(50, 28)
            ..lineTo(50, 78)
            ..lineTo(14, 70)
            ..lineTo(14, 22)
            ..close()
            ..moveTo(50, 28)
            ..lineTo(86, 22)
            ..lineTo(86, 70)
            ..lineTo(50, 78)
            ..close(),
          white,
        );
        c.drawLine(const Offset(24, 40), const Offset(40, 43), ink);
        c.drawLine(const Offset(60, 43), const Offset(76, 40), ink);
      case 3: // life skills: sprout
        c.drawLine(const Offset(50, 84), const Offset(50, 42), ink);
        c.drawOval(const Rect.fromLTWH(14, 24, 36, 22), white);
        c.drawOval(const Rect.fromLTWH(50, 16, 36, 22), white);
      case 4: // logic: two blocks and a circle
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 18, 34, 34),
            const Radius.circular(8),
          ),
          white,
        );
        c.drawCircle(const Offset(70, 36), 18, white);
        c.drawPath(
          Path()
            ..moveTo(32, 58)
            ..lineTo(52, 86)
            ..lineTo(12, 86)
            ..close(),
          white,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(58, 60, 28, 28),
            const Radius.circular(8),
          ),
          soft,
        );
      default: // discovery: star
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 40.0 : 17.0;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(50 + r * math.cos(a), 54 + r * math.sin(a));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        c.drawPath(path..close(), white);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_DomainShapePainter oldDelegate) =>
      oldDelegate.index != index;
}

/// Tinted rounded chip used on the welcome card.
class BrandChip extends StatelessWidget {
  const BrandChip(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color, width: 2),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: MimiColors.ink,
      ),
    ),
  );
}
