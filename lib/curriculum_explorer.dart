import 'package:flutter/material.dart';

import 'mimigo_design.dart';

import 'api_failure.dart';
import 'learning_models.dart';
import 'learning_screens.dart' show LearningError, LearningLabel;

// SRS FR-CUR-01 and the canonical R0 domain seed. Availability and topics
// come only from the child's returned Free catalog, not from this framework.
enum CurriculumDomain {
  math('MATH', 'Math', Icons.calculate_outlined),
  language('LANGUAGE', 'Language', Icons.menu_book_outlined),
  english('ENGLISH', 'English', Icons.translate),
  lifeSkills('LIFE_SKILLS', 'Life skills', Icons.self_improvement),
  logic('LOGIC', 'Logic', Icons.extension_outlined),
  discovery('DISCOVERY', 'Discovery', Icons.explore_outlined);

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

  String domainName(CurriculumDomain value) =>
      metadata(value)?.name ?? value.label;
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
            'Learning for ${widget.childAlias}',
            key: const Key('explorerChildContext'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            domain == null
                ? 'Choose a domain'
                : topic == null
                ? '${model.domainName(domain)} / Topics'
                : '${model.domainName(domain)} / ${model.topicName(topic)}',
            key: const Key('explorerBreadcrumb'),
          ),
          const Text(
            'The service checks age and access for this child. Only returned Free lessons are shown; unavailable domains are framework entries, not published content.',
          ),
          if (model.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    semanticsLabel: 'Loading eligible curriculum',
                  ),
                  Text('Loading eligible lessons…'),
                ],
              ),
            )
          else if (model.error != null)
            LearningError(model.error!)
          else ...[
            if (model.disclaimer != null) Text(model.disclaimer!),
            if (domain == null) ...[
              heading(context, 'Curriculum domains'),
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
                          ? 'Content not available yet'
                          : 'Eligible Free lessons available',
                      onPressed: opening
                          ? null
                          : () => model.chooseDomain(value),
                    ),
                ],
              ),
            ] else if (topic == null) ...[
              heading(context, 'Topics in ${model.domainName(domain)}'),
              ...model.topics.map(
                (code) => action(
                  'topic-$code',
                  model.topicName(code),
                  opening ? null : () => model.chooseTopic(code),
                ),
              ),
            ] else ...[
              heading(context, 'Lessons in ${model.topicName(topic)}'),
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
                        Text('${lesson.lessonCode} · Free · development/demo'),
                        Text(lesson.objective),
                        Text('Primary skill: ${lesson.primarySkill}'),
                        Text('Revision: ${lesson.revisionNo}'),
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
              const Text(
                'Content not available yet',
                key: Key('explorerEmpty'),
              ),
              Text(
                model.emptyReason == 'CHILD_OUTSIDE_PROGRAM_AGE'
                    ? 'The service returned no eligible lessons for this child’s age.'
                    : 'No eligible Free lessons were returned for this selection.',
              ),
              if (model.emptyReason != null) Text(model.emptyReason!),
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
