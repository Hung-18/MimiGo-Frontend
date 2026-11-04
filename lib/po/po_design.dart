import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mimigo_design.dart';

/// PO mobile presentation. Original vector artwork, no reference-board crops.
abstract final class PoPalette {
  static const pink = Color(0xFFE92F85);
  static const plum = Color(0xFF49335E);
  static const cream = Color(0xFFFFFAED);
  static const mint = Color(0xFFDDF2E5);
  static const lavender = Color(0xFFEDE5FA);
  static const peach = Color(0xFFFFE6CF);
  static const sky = Color(0xFFDDF2FC);
  static const radius = 28.0;
}

ThemeData poTheme() => mimiTheme().copyWith(
  scaffoldBackgroundColor: PoPalette.cream,
  colorScheme: mimiTheme().colorScheme.copyWith(primary: PoPalette.pink),
  appBarTheme: const AppBarTheme(
    backgroundColor: PoPalette.cream,
    foregroundColor: PoPalette.plum,
    centerTitle: false,
    elevation: 0,
  ),
);

class PoCard extends StatelessWidget {
  const PoCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(PoPalette.radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PoPalette.radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: PoPalette.plum.withValues(alpha: .07)),
          borderRadius: BorderRadius.circular(PoPalette.radius),
        ),
        child: child,
      ),
    ),
  );
}

class PoPill extends StatelessWidget {
  const PoPill(this.text, {super.key, this.color = PoPalette.mint});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        color: PoPalette.plum,
      ),
    ),
  );
}

class PoHeading extends StatelessWidget {
  const PoHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class PoDomainMark extends StatelessWidget {
  const PoDomainMark(this.kind, {super.key});
  final int kind;
  @override
  Widget build(BuildContext context) => kind < 3
      ? Text(
          ['123', 'Aa', 'Hi!'][kind],
          style: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 34,
            color: PoPalette.pink,
            fontWeight: FontWeight.w800,
          ),
        )
      : Icon(
          [
            Icons.favorite_rounded,
            Icons.extension_rounded,
            Icons.eco_rounded,
          ][kind - 3],
          size: 40,
          color: PoPalette.pink,
        );
}

class MimiBee extends StatelessWidget {
  const MimiBee({super.key, this.size = 140});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Mimi, bạn ong nhỏ đang vẫy chào',
    child: CustomPaint(size: Size.square(size), painter: const _BeePainter()),
  );
}

/// Portable vector pictures: no emoji fonts or remote image dependency.
class PoPicture extends StatelessWidget {
  const PoPicture(this.kind, {super.key, this.size = 64});
  final String kind;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: kind,
    child: CustomPaint(size: Size.square(size), painter: _PicturePainter(kind)),
  );
}

class _PicturePainter extends CustomPainter {
  const _PicturePainter(this.kind);
  final String kind;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 100);
    final p = Paint();
    void oval(double x, double y, double w, double h, Color color) {
      p.color = color;
      c.drawOval(Rect.fromLTWH(x, y, w, h), p);
    }

    void line(Offset a, Offset b, Color color, double width) {
      p
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      c.drawLine(a, b, p);
    }

    void triangle(List<Offset> points, Color color) {
      p.color = color;
      c.drawPath(Path()..addPolygon(points, true), p);
    }

    if (kind == 'apple') {
      oval(17, 30, 46, 57, const Color(0xFFED5367));
      oval(41, 30, 44, 57, const Color(0xFFED5367));
      line(const Offset(50, 35), const Offset(54, 17), PoPalette.plum, 6);
      oval(55, 14, 24, 13, const Color(0xFF70AC76));
      oval(28, 39, 9, 21, const Color(0xFFFFA6A4));
    } else if (kind == 'fish') {
      triangle([
        const Offset(68, 50),
        const Offset(94, 25),
        const Offset(94, 77),
      ], const Color(0xFF4389CD));
      oval(9, 25, 70, 51, const Color(0xFF65BEE6));
      oval(27, 39, 8, 8, PoPalette.plum);
      oval(2, 14, 10, 10, PoPalette.sky);
      oval(13, 2, 6, 6, PoPalette.sky);
    } else if (kind == 'butterfly') {
      oval(9, 15, 41, 43, const Color(0xFFF292BA));
      oval(9, 50, 41, 34, const Color(0xFFC1A1ED));
      oval(50, 15, 41, 43, const Color(0xFFF292BA));
      oval(50, 50, 41, 34, const Color(0xFFC1A1ED));
      line(const Offset(50, 29), const Offset(50, 78), PoPalette.plum, 9);
    } else if (kind == 'flower' || kind == 'sun') {
      line(
        const Offset(50, 54),
        const Offset(50, 94),
        const Color(0xFF5EA778),
        6,
      );
      oval(23, 67, 25, 12, const Color(0xFF7DBD7D));
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        oval(
          37 + 23 * math.cos(angle),
          27 + 23 * math.sin(angle),
          25,
          25,
          kind == 'sun' ? const Color(0xFFFFCE46) : const Color(0xFFF292BA),
        );
      }
      oval(37, 27, 25, 25, const Color(0xFFFFCE46));
    } else {
      final color = kind == 'dog'
          ? const Color(0xFFD9AA83)
          : kind == 'rabbit'
          ? const Color(0xFFC8B1EB)
          : kind == 'panda'
          ? Colors.white
          : const Color(0xFFF7BF69);
      if (kind == 'rabbit') {
        oval(24, 1, 19, 49, color);
        oval(57, 1, 19, 49, color);
      } else if (kind == 'dog') {
        oval(11, 28, 26, 58, const Color(0xFF996C51));
        oval(65, 28, 26, 58, const Color(0xFF996C51));
      } else {
        triangle([
          const Offset(15, 48),
          const Offset(19, 11),
          const Offset(46, 34),
        ], color);
        triangle([
          const Offset(54, 34),
          const Offset(81, 11),
          const Offset(85, 48),
        ], color);
      }
      oval(14, 28, 72, 61, color);
      if (kind == 'panda') {
        oval(25, 44, 19, 22, PoPalette.plum);
        oval(57, 44, 19, 22, PoPalette.plum);
      }
      oval(31, 49, 6, 8, kind == 'panda' ? Colors.white : PoPalette.plum);
      oval(63, 49, 6, 8, kind == 'panda' ? Colors.white : PoPalette.plum);
      oval(44, 63, 12, 8, PoPalette.plum);
      line(const Offset(50, 69), const Offset(50, 77), PoPalette.plum, 2);
      line(const Offset(50, 77), const Offset(42, 80), PoPalette.plum, 2);
      line(const Offset(50, 77), const Offset(58, 80), PoPalette.plum, 2);
      if (kind == 'cat') {
        line(const Offset(9, 63), const Offset(29, 68), PoPalette.plum, 2);
        line(const Offset(71, 68), const Offset(91, 63), PoPalette.plum, 2);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) => oldDelegate.kind != kind;
}

class _BeePainter extends CustomPainter {
  const _BeePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    final p = Paint();
    void oval(Rect r, Color c) {
      p.color = c;
      canvas.drawOval(r, p);
    }

    oval(const Rect.fromLTWH(28, 132, 108, 12), const Color(0x200C5E4C));
    oval(const Rect.fromLTWH(12, 37, 66, 43), Colors.white);
    oval(const Rect.fromLTWH(85, 32, 65, 46), Colors.white);
    oval(const Rect.fromLTWH(31, 48, 102, 89), const Color(0xFFFFCE46));
    canvas.save();
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(31, 48, 102, 89)));
    p.color = PoPalette.plum;
    canvas.drawRect(const Rect.fromLTWH(32, 103, 100, 12), p);
    canvas.drawRect(const Rect.fromLTWH(32, 124, 100, 9), p);
    canvas.restore();
    p
      ..color = PoPalette.plum
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(60, 53), const Offset(48, 30), p);
    canvas.drawLine(const Offset(102, 52), const Offset(114, 29), p);
    p.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(47, 27), 6, p);
    canvas.drawCircle(const Offset(116, 26), 6, p);
    canvas.drawCircle(const Offset(63, 77), 5, p);
    canvas.drawCircle(const Offset(102, 77), 5, p);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(const Rect.fromLTWH(73, 78, 20, 14), 0, math.pi, false, p);
    p.style = PaintingStyle.fill;
    oval(const Rect.fromLTWH(44, 83, 17, 10), const Color(0xFFFF8AA3));
    oval(const Rect.fromLTWH(106, 83, 17, 10), const Color(0xFFFF8AA3));
    p
      ..color = PoPalette.plum
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawLine(const Offset(127, 100), const Offset(143, 86), p);
    canvas.drawLine(const Offset(34, 102), const Offset(21, 93), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeePainter oldDelegate) => false;
}

class PoGarden extends StatelessWidget {
  const PoGarden({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });
  final String title, subtitle;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [PoPalette.sky, PoPalette.mint],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -24,
          bottom: -48,
          child: _Hill(color: Color(0xFFAED8B1), size: 210),
        ),
        const Positioned(
          left: -40,
          bottom: -85,
          child: _Hill(color: Color(0xFFC3E2A2), size: 230),
        ),
        Positioned(
          right: 18,
          top: 14,
          child: Icon(
            Icons.wb_sunny_rounded,
            color: Colors.amber.shade400,
            size: 34,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PoPill('MỖI NGÀY MỘT KHÁM PHÁ', color: Colors.white),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: PoPalette.plum),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              MimiBee(size: compact ? 82 : 114),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hill extends StatelessWidget {
  const _Hill({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class PoScaffold extends StatelessWidget {
  const PoScaffold({
    super.key,
    required this.title,
    required this.children,
    this.back,
    this.bottom,
    this.actions,
    this.preview = true,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? back;
  final Widget? bottom;
  final List<Widget>? actions;
  final bool preview;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: back == null
          ? null
          : IconButton(
              onPressed: back,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Quay lại',
            ),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: actions,
    ),
    bottomNavigationBar: bottom,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            key: PageStorageKey((title, key)),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (preview)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PoPill(
                        'UI PREVIEW · DỮ LIỆU TỔNG HỢP',
                        color: PoPalette.peach,
                      ),
                    ),
                  ),
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PoAction extends StatelessWidget {
  const PoAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool secondary;
  @override
  Widget build(BuildContext context) => secondary
      ? OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        )
      : FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: PoPalette.pink),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
}
