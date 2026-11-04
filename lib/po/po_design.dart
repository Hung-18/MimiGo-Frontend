import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mimigo_design.dart';
import 'mimi_world.dart';
export 'mimi_world.dart';

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
  colorScheme: mimiTheme().colorScheme.copyWith(primary: MimiColors.action),
  appBarTheme: const AppBarTheme(
    backgroundColor: PoPalette.cream,
    foregroundColor: PoPalette.plum,
    centerTitle: false,
    elevation: 0,
  ),
);

class PoCard extends StatefulWidget {
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
  State<PoCard> createState() => _PoCardState();
}

class _PoCardState extends State<PoCard> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed && !MimiMotion.reduced(context) ? .975 : 1,
    duration: MimiMotion.reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    child: Material(
      color: widget.color,
      borderRadius: BorderRadius.circular(PoPalette.radius),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) => setState(() => pressed = value),
        borderRadius: BorderRadius.circular(PoPalette.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: widget.padding,
          decoration: BoxDecoration(
            border: Border.all(color: PoPalette.plum.withValues(alpha: .09)),
            borderRadius: BorderRadius.circular(PoPalette.radius),
          ),
          child: widget.child,
        ),
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
  Widget build(BuildContext context) => DomainIllustration(kind);
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

class PoGarden extends StatelessWidget {
  const PoGarden({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.mood = MimiMood.greeting,
  });
  final String title, subtitle;
  final bool compact;
  final MimiMood mood;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [PoPalette.sky, PoPalette.mint],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(32),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: MimiColors.ink)),
          ],
        );
        if (compact) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MimiBee(size: 96, mood: mood),
                      text,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 12),
                      MimiBee(size: 96, mood: mood),
                    ],
                  ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[
              GardenScene(height: 210, child: MimiBee(size: 200, mood: mood)),
              ColoredBox(
                color: const Color(0xFFFFFBF3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  child: text,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Expanded(child: text),
                    SizedBox(
                      width: compact ? 130 : 190,
                      child: GardenScene(
                        height: compact ? 140 : 200,
                        child: MimiBee(size: compact ? 110 : 160, mood: mood),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
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
          style: FilledButton.styleFrom(backgroundColor: MimiColors.action),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
}
