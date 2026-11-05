import 'package:flutter/material.dart';

import '../mimigo_design.dart';
import 'mimi_world.dart';

/// A text-rendered brand mark, not a crop of the supplied logo artwork.
class MimiWordmark extends StatelessWidget {
  const MimiWordmark({super.key, this.size = 54});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MimiGo',
    image: true,
    child: ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          children: [
            Text(
              'MimiGo',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontWeight: FontWeight.w900,
                fontSize: size,
                height: 1.15,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5
                  ..color = MimiColors.ink,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Mimi',
                    style: TextStyle(color: MimiColors.yellow),
                  ),
                  const TextSpan(
                    text: 'Go',
                    style: TextStyle(color: MimiColors.blue),
                  ),
                ],
              ),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontWeight: FontWeight.w900,
                fontSize: size,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Scenery owns the header; opaque forms and lists own the reading surface.
/// A single existing asset is decoded/shared, with no decorative ticker.
class StorybookCanvas extends StatelessWidget {
  const StorybookCanvas({super.key, required this.child, this.height = 340});
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) => Material(
    color: MimiColors.canvas,
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: const StorybookBackdrop(alignment: Alignment.topCenter),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height + 1,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFCF6),
                    Color(0x00FFFCF6),
                    MimiColors.canvas,
                  ],
                  stops: [0, .65, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class StorybookForm extends StatelessWidget {
  const StorybookForm({
    super.key,
    required this.title,
    required this.children,
    this.back,
    this.mood = MimiMood.greeting,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? back;
  final MimiMood mood;
  @override
  Widget build(BuildContext context) => StorybookCanvas(
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (back != null)
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: BackButton(onPressed: back),
                    ),
                  const Spacer(),
                ],
              ),
              Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: MimiWordmark(size: 48),
                    ),
                  ),
                  MimiBee(size: 142, mood: mood),
                ],
              ),
              MimiPanel(
                padding: EdgeInsets.all(
                  MediaQuery.textScalerOf(context).scale(16) > 24 ? 14 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final child in children)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: child is SizedBox ? 0 : 12,
                        ),
                        child: child,
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

/// A short scenic banner leaves the available curriculum in the first view.
class StorybookBanner extends StatelessWidget {
  const StorybookBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.mood,
    this.compact = false,
  });
  final String title, subtitle;
  final MimiMood mood;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      image: const DecorationImage(
        image: AssetImage('assets/scenery/garden.png'),
        fit: BoxFit.cover,
      ),
      border: Border.all(color: Colors.white, width: 3),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x15102665),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final large = MediaQuery.textScalerOf(context).scale(16) > 24;
        final copy = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xF5FFFFFF),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 22, color: MimiColors.blueText),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(14),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: MimiBee(size: 112, mood: mood)),
                    copy,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 4),
                    MimiBee(size: compact ? 108 : 132, mood: mood),
                  ],
                ),
        );
      },
    ),
  );
}
