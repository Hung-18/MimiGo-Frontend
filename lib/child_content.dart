import 'package:flutter/material.dart';

enum LearningCategory {
  language('Language'),
  math('Math'),
  logic('Logic'),
  lifeSkills('Life skills'),
  arts('Arts'),
  discovery('Discovery');

  const LearningCategory(this.label);
  final String label;
}

// The sole demo is the original VS-01 fictional shape mini-game. This is not
// a published lesson, curriculum record, media asset or Backend lesson ID.
enum DemoLesson { findTheCircle }

abstract class ChildContentSource {
  Future<List<DemoLesson>> loadCategory(LearningCategory category);
}

class FixtureChildContentSource implements ChildContentSource {
  const FixtureChildContentSource();

  @override
  Future<List<DemoLesson>> loadCategory(LearningCategory category) async =>
      category == LearningCategory.logic ? [DemoLesson.findTheCircle] : [];
}

// Categories outside the current live Math slice remain unavailable. Do not
// send speculative requests or fall back to fixture content in live mode.
class UnavailableLiveContentSource implements ChildContentSource {
  const UnavailableLiveContentSource();

  @override
  Future<List<DemoLesson>> loadCategory(LearningCategory category) async => [];
}

class CategoryContent extends StatefulWidget {
  const CategoryContent({
    super.key,
    required this.category,
    required this.source,
    required this.fixture,
    required this.openDemo,
  });
  final LearningCategory category;
  final ChildContentSource source;
  final bool fixture;
  final VoidCallback openDemo;

  @override
  State<CategoryContent> createState() => _CategoryContentState();
}

class _CategoryContentState extends State<CategoryContent> {
  late Future<List<DemoLesson>> content;

  @override
  void initState() {
    super.initState();
    content = widget.source.loadCategory(widget.category);
  }

  @override
  void didUpdateWidget(covariant CategoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.source != widget.source) {
      content = widget.source.loadCategory(widget.category);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.fixture) const DemoLabel(),
      FutureBuilder<List<DemoLesson>>(
        future: content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading category…'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Could not load content. Please try again.',
                  key: Key('categoryError'),
                ),
                OutlinedButton(
                  key: const Key('categoryRetry'),
                  onPressed: () => setState(() {
                    content = widget.source.loadCategory(widget.category);
                  }),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          // Even a mistakenly supplied fixture source cannot expose demos in
          // live mode. Only the fixture branch can launch the local mini-game.
          if (!widget.fixture ||
              !(snapshot.data?.contains(DemoLesson.findTheCircle) ?? false)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content not available yet',
                    key: Key('categoryEmpty'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.fixture
                        ? 'No fixture lessons are available for ${widget.category.label}.'
                        : 'Learning content for ${widget.category.label} is not available in the current live service.',
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 64,
              child: FilledButton(
                key: const Key('openCircleDemo'),
                onPressed: widget.openDemo,
                child: const Text('Find the circle · DEMO'),
              ),
            ),
          );
        },
      ),
    ],
  );
}

class DemoLabel extends StatelessWidget {
  const DemoLabel({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'DEMO / FIXTURE — local example. No learning progress is saved or sent.',
      key: Key('demoLabel'),
    ),
  );
}

/// Restores the previously implemented VS-01 no-media shape interaction.
/// Feedback is local widget state only, never a result or progress API call.
class CircleDemo extends StatefulWidget {
  const CircleDemo({super.key});
  @override
  State<CircleDemo> createState() => _CircleDemoState();
}

class _CircleDemoState extends State<CircleDemo> {
  String? feedback;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoLabel(),
      const Text('Fictional mini-game: Find the circle'),
      const SizedBox(height: 12),
      const Text('Choose a shape. This fixture has no licensed lesson media.'),
      const SizedBox(height: 16),
      SizedBox(
        height: 64,
        child: OutlinedButton(
          key: const Key('demoTriangle'),
          onPressed: () => setState(
            () => feedback = 'Try again: a triangle has three sides.',
          ),
          child: const Text('△ Triangle'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 64,
        child: FilledButton(
          key: const Key('demoCircle'),
          onPressed: () =>
              setState(() => feedback = 'Nice noticing! A circle is round.'),
          child: const Text('○ Circle'),
        ),
      ),
      if (feedback != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(feedback!, key: const Key('gameFeedback')),
        ),
    ],
  );
}
