import 'package:flutter/material.dart';

import '../mimigo_design.dart';
import 'mimi_world.dart';

/// One brand color per answer option (cycles). UI only.
const _optionColors = [
  MimiColors.blue,
  MimiColors.orange,
  MimiColors.green,
  MimiColors.pink,
  MimiColors.purple,
  MimiColors.yellow,
];

Color answerColor(int index) => _optionColors[index % _optionColors.length];

/// Large answer card style: min 96dp, tinted fill + colored border so ink
/// text stays readable on every brand color. Selected = stronger fill.
ButtonStyle answerCardStyle(int index, {required bool selected}) {
  final color = answerColor(index);
  return OutlinedButton.styleFrom(
    minimumSize: const Size(96, 96),
    padding: const EdgeInsets.all(12),
    foregroundColor: MimiColors.ink,
    backgroundColor: color.withValues(alpha: selected ? .45 : .16),
    side: BorderSide(color: color, width: selected ? 5 : 3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  );
}

/// Speech-bubble question with Mimi beside it and an optional replay button.
class QuestionBubble extends StatelessWidget {
  const QuestionBubble({
    super.key,
    required this.prompt,
    this.replay,
    this.replayKey,
    this.replayEnabled = true,
  });
  final String prompt;
  final VoidCallback? replay;
  final Key? replayKey;
  final bool replayEnabled;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const ExcludeSemantics(child: MimiBee(size: 72, mood: MimiMood.guide)),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: MimiColors.blue, width: 3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    prompt,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              if (replay != null)
                IconButton.filled(
                  key: replayKey,
                  tooltip: 'Nghe lại câu hỏi',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    backgroundColor: MimiColors.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 30),
                  onPressed: replayEnabled ? replay : null,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

enum FeedbackKind { correct, retry, exhausted }

/// Gentle feedback card. No red: CORRECT = green, RETRY = warm yellow
/// ("try again"), EXHAUSTED = soft blue (supportive, shows the answer).
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.kind, required this.children});
  final FeedbackKind kind;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final (color, icon, mood) = switch (kind) {
      FeedbackKind.correct => (
        MimiColors.green,
        Icons.celebration_rounded,
        MimiMood.correct,
      ),
      FeedbackKind.retry => (
        MimiColors.orange,
        Icons.refresh_rounded,
        MimiMood.encourage,
      ),
      FeedbackKind.exhausted => (
        MimiColors.blue,
        Icons.favorite_rounded,
        MimiMood.encourage,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              ExcludeSemantics(child: MimiBee(size: 64, mood: mood)),
              Icon(icon, color: color, size: 28),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Cau 2 / 5" dots + bar. Pure display of counts the caller already has.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.done, required this.total});
  final int done, total;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đã xong $done trên $total câu',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 14,
                color: MimiColors.green,
                backgroundColor: MimiColors.green.withValues(alpha: .2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$done/$total',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: MimiColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
