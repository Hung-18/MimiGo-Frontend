import 'package:flutter/material.dart';

import '../curriculum_explorer.dart';
import '../learning_models.dart';
import '../learning_screens.dart' show LearningError;
import 'po_design.dart';

/// Only server-returned content. No fixtures, local completion or entitlement.
class LiveChildHome extends StatefulWidget {
  const LiveChildHome({
    super.key,
    required this.api,
    required this.childId,
    this.alias,
    required this.openDomain,
    required this.parentArea,
  });
  final LearningApi api;
  final String childId;
  final String? alias;
  final void Function([CurriculumDomain? domain]) openDomain;
  final VoidCallback parentArea;
  @override
  State<LiveChildHome> createState() => _LiveChildHomeState();
}

class _LiveChildHomeState extends State<LiveChildHome> {
  late final model = CurriculumExplorerState(widget.api, widget.childId);
  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => PoScaffold(
      title: 'Thế giới của bé',
      preview: false,
      actions: [
        IconButton(
          key: const Key('liveParentGate'),
          constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
          onPressed: widget.parentArea,
          tooltip: 'Cổng phụ huynh',
          icon: const Icon(Icons.lock_outline_rounded),
        ),
      ],
      children: [
        PoGarden(
          title: widget.alias == null
              ? 'Cùng Mimi khám phá!'
              : 'Chào ${widget.alias}!',
          subtitle: 'Mỗi ngày một điều mới, bé nhé.',
          mood: model.loading ? MimiMood.thinking : MimiMood.guide,
        ),
        if (model.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Đang tải bài học của bé',
          ),
        if (model.error != null) LearningError(model.error!),
        if (!model.loading && model.error == null && model.lessons.isEmpty)
          PoCard(
            key: Key('liveCatalogEmpty'),
            color: PoPalette.mint,
            child: Column(
              children: [
                const MimiBee(size: 110, mood: MimiMood.encourage),
                SizedBox(height: 12),
                Text(
                  model.emptyReason == 'CHILD_OUTSIDE_PROGRAM_AGE'
                      ? 'Chưa có bài học phù hợp với độ tuổi của bé'
                      : 'Chưa có bài học phù hợp được phát hành',
                ),
                const Text(
                  'Mimi sẽ hiển thị bài học khi dịch vụ xác nhận nội dung và quyền truy cập cho bé.',
                ),
              ],
            ),
          ),
        if (model.error == null && !model.loading) ...[
          PoHeading(
            'Bé muốn khám phá gì?',
            trailing: IconButton(
              key: const Key('openCurriculum'),
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              tooltip: 'Tất cả bài học',
              onPressed: () => widget.openDomain(),
              icon: const Icon(Icons.auto_stories_outlined),
            ),
          ),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final domain in model.presentation)
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(16) > 24
                        ? c.maxWidth
                        : (c.maxWidth - 12) / 2,
                    child: PoCard(
                      key: Key('live-domain-${domain.code}'),
                      color: model.inDomain(domain).isEmpty
                          ? Colors.white
                          : [
                              PoPalette.peach,
                              PoPalette.lavender,
                              PoPalette.sky,
                              PoPalette.mint,
                              PoPalette.lavender,
                              PoPalette.peach,
                            ][domain.index],
                      onTap: model.inDomain(domain).isEmpty
                          ? null
                          : () => widget.openDomain(domain),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoDomainMark(domain.index),
                          Text(
                            model.domainName(domain),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  model.inDomain(domain).isEmpty
                                      ? 'Chưa có bài học'
                                      : 'Khám phá',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Icon(
                                model.inDomain(domain).isEmpty
                                    ? Icons.lock_outline
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const PoCard(
            color: PoPalette.sky,
            child: Text(
              'Bé làm quen tiếng Anh qua các bài học tiếng Việt phù hợp.',
            ),
          ),
        ],
        PoAction(
          'Tải lại bài học',
          key: const Key('liveCatalogRefresh'),
          secondary: true,
          icon: Icons.refresh,
          onPressed: model.loading ? null : model.load,
        ),
      ],
    ),
  );
}
