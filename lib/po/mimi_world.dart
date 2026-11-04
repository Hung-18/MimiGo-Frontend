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
/// Entry gives the selected illustrated pose a gentle hover, then Mimi rests.
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
        child: _MimiSprite(size: widget.size, mood: widget.mood),
        builder: (context, child) {
          final t = allowed ? controller.value : 1.0;
          final pulse = math.sin(t * math.pi * 4) * (1 - t);
          final joyful =
              widget.mood == MimiMood.correct ||
              widget.mood == MimiMood.completion;
          return Transform.translate(
            offset: Offset(0, -pulse * (joyful ? 5 : 2)),
            child: Transform.rotate(
              angle:
                  pulse *
                  switch (widget.mood) {
                    MimiMood.greeting => .035,
                    MimiMood.guide => .015,
                    MimiMood.thinking => -.018,
                    MimiMood.correct => .025,
                    MimiMood.encourage => -.012,
                    MimiMood.completion => .04,
                    MimiMood.idle => .01,
                  },
              child: child,
            ),
          );
        },
      ),
    ),
  );
}

/// Seven art-directed poses share one decoded atlas. Rigid transforms preserve
/// the character's face, costume and silhouette throughout each bounded burst.
class _MimiSprite extends StatelessWidget {
  const _MimiSprite({required this.size, required this.mood});
  static const asset = 'assets/mascot/mimi_poses.png';
  final double size;
  final MimiMood mood;
  @override
  Widget build(BuildContext context) {
    final column = mood.index % 4;
    final row = mood.index ~/ 4;
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size * 4,
          maxWidth: size * 4,
          minHeight: size * 2,
          maxHeight: size * 2,
          child: Transform.translate(
            offset: Offset(-column * size, -row * size),
            child: Image.asset(
              asset,
              width: size * 4,
              height: size * 2,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

const _leaf = Color(0xFF61A780);

/// Bundled original storybook scenery; no remote images or offscreen ticker.
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
        const Positioned.fill(child: StorybookBackdrop()),
        if (child != null) Center(child: child),
      ],
    ),
  );
}

/// Decorative only. Forms always own an opaque surface above this artwork.
class StorybookBackdrop extends StatelessWidget {
  const StorybookBackdrop({super.key, this.alignment = Alignment.center});
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: Image.asset(
        'assets/scenery/garden.png',
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    ),
  );
}

/// Six decorative destinations in canonical domain order, sharing one atlas.
class DomainIllustration extends StatelessWidget {
  const DomainIllustration(this.kind, {super.key});
  final int kind;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 132,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 396,
          maxWidth: 396,
          minHeight: 264,
          maxHeight: 264,
          child: Transform.translate(
            offset: Offset(-(kind % 3) * 132, -(kind ~/ 3) * 132),
            child: Image.asset(
              'assets/scenery/domains.png',
              width: 396,
              height: 264,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
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
