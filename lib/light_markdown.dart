import 'package:flutter/material.dart';

/// Display-only light markdown clean-up. The source text is never modified or
/// hashed here: callers keep the exact document body for hash/consent logic.
String plainFromMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n').map((raw) {
    var l = raw.trimRight();
    l = l.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '');
    l = l.replaceFirstMapped(RegExp(r'^\s*[-*+]\s+'), (_) => '• ');
    l = l.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*|__(.+?)__'),
      (m) => m[1] ?? m[2]!,
    );
    return l;
  });
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Renders headings bold and the rest as plain text, selectable.
class LightMarkdownText extends StatelessWidget {
  const LightMarkdownText(this.source, {super.key, this.style});
  final String source;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    final spans = <InlineSpan>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final isHeading = RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(lines[i]);
      final text = plainFromMarkdown(lines[i]);
      spans.add(
        TextSpan(
          text: i == lines.length - 1 ? text : '$text\n',
          style: isHeading
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null,
        ),
      );
    }
    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}
