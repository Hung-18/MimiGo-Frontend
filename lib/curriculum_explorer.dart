import 'user_messages.dart';

import 'package:flutter/material.dart';

import 'mimigo_design.dart';

import 'api_failure.dart';
import 'learning_models.dart';
import 'learning_screens.dart' show LearningError, LearningLabel;

// SRS FR-CUR-01 and the canonical R0 domain seed. Availability and topics
// come only from the child's returned Free catalog, not from this framework.
enum CurriculumDomain {
  math('MATH', 'Toán học', Icons.calculate_outlined),
  language('LANGUAGE', 'Ngôn ngữ', Icons.menu_book_outlined),
  english('ENGLISH', 'Tiếng Anh', Icons.translate),
  lifeSkills('LIFE_SKILLS', 'Kỹ năng sống', Icons.self_improvement),
  logic('LOGIC', 'Tư duy logic', Icons.extension_outlined),
  discovery('DISCOVERY', 'Khám phá', Icons.explore_outlined);

  const CurriculumDomain(this.code, this.label, this.icon);
  final String code, label;
  final IconData icon;
}

class CurriculumExplorerState extends ChangeNotifier {
  CurriculumExplorerState(this.api, this.childId);
  final LearningApi api;
  final String childId;
  List<LessonSummary> lessons = const [];
  List<CurriculumDomainData> domains = const [];
  CurriculumDomain? domain;
  String? topic, emptyReason, disclaimer;
  ApiFailure? error;
  bool loading = false;
  int _generation = 0;

  List<LessonSummary> inDomain(CurriculumDomain value) => List.unmodifiable(
    lessons.where((lesson) => lesson.domainCode == value.code),
  );
  CurriculumDomainData? metadata(CurriculumDomain value) {
    for (final item in domains) {
      if (item.code == value.code) return item;
    }
    return null;
  }

  String domainName(CurriculumDomain value) {
    final name = metadata(value)?.name;
    return name == null ||
            {
              'Math',
              'Language',
              'English',
              'Life skills',
              'Logic',
              'Discovery',
            }.contains(name)
        ? value.label
        : name;
  }

  String topicName(String code) {
    for (final item in metadata(domain!)?.topics ?? <CurriculumTopicData>[]) {
      if (item.code == code) return item.name;
    }
    return code;
  }

  List<CurriculumDomain> get presentation {
    final available = domains
        .map(
          (item) =>
              CurriculumDomain.values.singleWhere((d) => d.code == item.code),
        )
        .toList();
    return [
      ...available,
      ...CurriculumDomain.values.where((d) => !available.contains(d)),
    ];
  }

  List<String> get topics => domain == null
      ? const []
      : ((metadata(domain!)?.topics.toList() ?? <CurriculumTopicData>[])
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((topic) => topic.code)
            .toList();
  List<LessonSummary> get inTopic => domain == null || topic == null
      ? const []
      : List.unmodifiable(
          inDomain(domain!).where((lesson) => lesson.topicCode == topic),
        );

  Future<void> load() async {
    if (loading) return;
    final generation = _generation;
    loading = true;
    error = null;
    lessons = const [];
    domains = const [];
    emptyReason = disclaimer = null;
    notifyListeners();
    try {
      final result = await api.curriculum(childId);
      if (generation != _generation) return;
      // No Premium unlock, local eligibility, production content or fallback.
      domains = List.unmodifiable(
        result.domains
            .where(
              (item) => CurriculumDomain.values.any((d) => d.code == item.code),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
      lessons = List.unmodifiable(
        domains
            .expand((domain) => domain.topics)
            .expand((topic) => topic.lessons),
      );
      emptyReason = result.emptyReason;
      disclaimer = result.disclaimer;
      // Publication/eligibility can remove a topic between visits. Preserve a
      // valid selection, but do not strand the child in a vanished topic.
      if (topic != null && !topics.contains(topic)) topic = null;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void chooseDomain(CurriculumDomain value) {
    if (loading || error != null) return;
    domain = value;
    topic = null;
    notifyListeners();
  }

  void chooseTopic(String code) {
    if (loading || error != null || !topics.contains(code)) return;
    topic = code;
    notifyListeners();
  }

  bool back() {
    if (topic != null) {
      topic = null;
      notifyListeners();
      return true;
    }
    if (domain != null) {
      domain = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class CurriculumExplorer extends StatefulWidget {
  const CurriculumExplorer({
    super.key,
    required this.model,
    required this.childAlias,
    required this.fixture,
    required this.openLesson,
  });
  final CurriculumExplorerState model;
  final String childAlias;
  final bool fixture;
  final ValueChanged<LessonSummary> openLesson;
  @override
  State<CurriculumExplorer> createState() => _CurriculumExplorerState();
}

class _CurriculumExplorerState extends State<CurriculumExplorer> {
  bool opening = false;
  @override
  void initState() {
    super.initState();
    // Revalidate on return from a player. A failed refresh exposes no cached
    // catalog as if it were a fresh authorized response.
    widget.model.load();
  }

  Widget heading(BuildContext context, String value) => Semantics(
    header: true,
    child: Text(value, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget action(
    String key,
    String label,
    VoidCallback? onPressed, {
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: OutlinedButton.icon(
        key: Key(key),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.chevron_right),
        label: Text(label, textAlign: TextAlign.start),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final domain = model.domain;
      final topic = model.topic;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearningLabel(),
          if (widget.fixture)
            const Text(
              'DEMO / FIXTURE · no published fixture curriculum catalog. The local Logic demo remains separate.',
            ),
          Text(
            'Bài học của ${widget.childAlias}',
            key: const Key('explorerChildContext'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            domain == null
                ? 'Chọn lĩnh vực'
                : topic == null
                ? '${model.domainName(domain)} / Chủ đề'
                : '${model.domainName(domain)} / ${model.topicName(topic)}',
            key: const Key('explorerBreadcrumb'),
          ),
          const Text(
            'Chỉ hiển thị bài học được máy chủ cho phép cho bé. Bài Free và Core đều do dịch vụ kiểm tra tuổi, quyền và nội dung đã phát hành.',
          ),
          if (model.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    semanticsLabel: 'Đang tải bài học phù hợp',
                  ),
                  Text('Đang tìm bài học phù hợp…'),
                ],
              ),
            )
          else if (model.error != null)
            LearningError(model.error!)
          else ...[
            if (domain == null) ...[
              heading(context, 'Các lĩnh vực khám phá'),
              const SizedBox(height: 12),
              MimiTileGrid(
                minimumWidth: 180,
                children: [
                  for (final value in model.presentation)
                    MimiDomainTile(
                      key: Key('domain-${value.code}'),
                      label: model.domainName(value),
                      code: value.code,
                      description: model.inDomain(value).isEmpty
                          ? 'Chưa có nội dung phù hợp'
                          : 'Có bài học được dịch vụ cho phép',
                      onPressed: opening
                          ? null
                          : () => model.chooseDomain(value),
                    ),
                ],
              ),
            ] else if (topic == null) ...[
              heading(context, 'Chủ đề: ${model.domainName(domain)}'),
              ...model.topics.map(
                (code) => action(
                  'topic-$code',
                  model.topicName(code),
                  opening ? null : () => model.chooseTopic(code),
                ),
              ),
            ] else ...[
              heading(context, 'Bài học: ${model.topicName(topic)}'),
              ...model.inTopic.map(
                (lesson) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(viState(lesson.access)),
                        Text(lesson.objective),
                        TechnicalDetails(
                          children: [
                            Text('Mã bài: ${lesson.lessonCode}'),
                            Text('Kỹ năng: ${lesson.primarySkill}'),
                            Text('Phiên bản: ${lesson.revisionNo}'),
                          ],
                        ),
                        action(
                          'explorer-lesson-${lesson.lessonId}',
                          'Mở bài học',
                          opening
                              ? null
                              : () {
                                  if (opening) return;
                                  setState(() => opening = true);
                                  widget.openLesson(lesson);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if ((domain == null && model.lessons.isEmpty) ||
                (domain != null && topic == null && model.topics.isEmpty) ||
                (topic != null && model.inTopic.isEmpty)) ...[
              const Text('Chưa có nội dung phù hợp', key: Key('explorerEmpty')),
              Text(
                model.emptyReason == 'CHILD_OUTSIDE_PROGRAM_AGE'
                    ? 'Chưa có bài học phù hợp với độ tuổi của bé.'
                    : 'Chưa có bài học phù hợp được máy chủ trả về cho lựa chọn này.',
              ),
            ],
          ],
          action(
            'explorerRefresh',
            model.error != null
                ? 'Thử tải lại danh mục'
                : 'Tải lại bài học phù hợp',
            model.loading || opening ? null : model.load,
            icon: Icons.refresh,
          ),
        ],
      );
    },
  );
}
