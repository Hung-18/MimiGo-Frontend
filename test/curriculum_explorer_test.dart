import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/curriculum_explorer.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';

import 'completion_test_support.dart';
import 'learning_test_data.dart';
import 'learning_widget_test.dart' show tapVisible;
import 'sign_in_test.dart' show openSignIn, fillSignIn, submitSignIn;
import 'learning_api_test.dart' show Transport, Reply, authenticated;

class ExplorerApi extends CompletionApi {
  @override
  Future<CurriculumCatalog> curriculum(String child) async {
    final list = await lessons(child);
    return CurriculumCatalog.fromJson(
      curriculumJson(
        catalog.where((item) => item['access'] == 'FREE'),
        emptyReason: list.emptyReason,
      ),
    );
  }

  List<Map<String, dynamic>> catalog = [summaryJson()];
  final catalogChildren = <String>[];
  @override
  Future<LessonList> lessons(String child) async {
    catalogChildren.add(child);
    if (catalogFailure != null) throw catalogFailure!;
    if (catalogGate != null) return catalogGate!.future;
    return LessonList(
      catalog.map(LessonSummary.fromJson).toList(),
      emptyReason,
      'Synthetic API disclaimer',
    );
  }
}

Future<void> explorerRoot(WidgetTester tester, ExplorerApi api) async {
  api.profiles = [
    ChildSummary(
      id: childId,
      alias: 'SYN-Explorer',
      dateOfBirth: DateTime(2023, 1, 1),
      ageYears: 3,
      withinProgramAgeRange: true,
      state: 'ACTIVE',
      createdAt: DateTime(2026),
    ),
  ];
  await openSignIn(tester, api);
  await fillSignIn(tester);
  await submitSignIn(tester);
  await tapVisible(tester, 'parent-child-$childId');
  await tapVisible(tester, 'parentEnterLearning');
  await tapVisible(tester, 'openCurriculum');
}

Future<void> topicScreen(WidgetTester tester, ExplorerApi api) async {
  await explorerRoot(tester, api);
  await tapVisible(tester, 'domain-MATH');
  await tapVisible(tester, 'topic-${summaryJson()['topicCode']}');
}

void main() {
  testWidgets('refresh removes a withdrawn topic and stale lesson navigation', (
    tester,
  ) async {
    final api = ExplorerApi();
    await topicScreen(tester, api);
    api.catalog = [];
    api.emptyReason = 'NO_ELIGIBLE_CONTENT';
    await tapVisible(tester, 'explorerRefresh');
    expect(find.text('Topics in Math'), findsOneWidget);
    expect(find.byKey(const Key('explorerEmpty')), findsOneWidget);
    expect(find.byKey(const Key('explorer-lesson-$lessonId')), findsNothing);
    expect(
      find.byKey(Key('topic-${summaryJson()['topicCode']}')),
      findsNothing,
    );
    expect(api.starts, 0);
    api.catalog = [summaryJson()];
    api.emptyReason = null;
    await tapVisible(tester, 'explorerRefresh');
    expect(
      find.byKey(Key('topic-${summaryJson()['topicCode']}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('explorer-lesson-$lessonId')), findsNothing);
    await tapVisible(tester, 'topic-${summaryJson()['topicCode']}');
    expect(find.byKey(const Key('explorer-lesson-$lessonId')), findsOneWidget);
  });

  testWidgets(
    'Explorer headings and controls remain readable and tappable at narrow width and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final model = CurriculumExplorerState(ExplorerApi(), childId);
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CurriculumExplorer(
                  model: model,
                  childAlias: 'SYN-Explorer',
                  fixture: false,
                  openLesson: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.text('Curriculum domains'))
              .flagsCollection
              .isHeader,
          isTrue,
        );
        await tapVisible(tester, 'domain-MATH');
        await tapVisible(tester, 'topic-${summaryJson()['topicCode']}');
        await tester.ensureVisible(
          find.byKey(const Key('explorer-lesson-$lessonId')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const Key('explorer-lesson-$lessonId')))
              .height,
          greaterThanOrEqualTo(64),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      }
    },
  );

  testWidgets(
    'matching returned Free domain enters the existing player with its authenticated child',
    (tester) async {
      final api = ExplorerApi()
        ..catalog = [
          {...summaryJson(), 'domainCode': 'ENGLISH'},
        ]
        ..lessonOverride = {...detailJson(), 'domainCode': 'ENGLISH'};
      await explorerRoot(tester, api);
      await tapVisible(tester, 'domain-ENGLISH');
      await tapVisible(tester, 'topic-${summaryJson()['topicCode']}');
      await tapVisible(tester, 'explorer-lesson-$lessonId');
      expect(
        tester
            .widget<LearningLessonView>(find.byType(LearningLessonView))
            .domainCode,
        'ENGLISH',
      );
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('option-$optionId')), findsOneWidget);
      expect(api.readIds, [sessionId]);
      expect(api.catalogChildren, [childId]);
    },
  );
  test('canonical six match SRS; group only returned Free metadata by domain and actual topic codes', () async {
    expect(CurriculumDomain.values.map((d) => d.code), [
      'MATH',
      'LANGUAGE',
      'ENGLISH',
      'LIFE_SKILLS',
      'LOGIC',
      'DISCOVERY',
    ]);
    final api = ExplorerApi()
      ..catalog = [
        summaryJson(),
        {
          ...summaryJson(),
          'lessonId': 'english-test',
          'domainCode': 'ENGLISH',
          'topicCode': 'returned-topic',
        },
        {...summaryJson(), 'lessonId': 'unknown-test', 'domainCode': 'ARTS'},
        {...summaryJson(), 'lessonId': 'premium-test', 'access': 'PREMIUM'},
      ];
    final model = CurriculumExplorerState(api, childId);
    await model.load();
    expect(model.lessons, hasLength(2));
    model.chooseDomain(CurriculumDomain.english);
    expect(model.topics, ['returned-topic']);
    model.chooseTopic('invented-topic');
    expect(model.topic, isNull);
    model.chooseTopic('returned-topic');
    expect(model.inTopic.single.lessonId, 'english-test');
    expect(model.back(), isTrue);
    expect(model.topic, isNull);
    expect(model.back(), isTrue);
    expect(model.domain, isNull);
    expect(model.back(), isFalse);
    model.dispose();
  });

  test('refresh coalesces, clears old data and preserves breadcrumbs without a fixture fallback', () async {
    final api = ExplorerApi();
    final model = CurriculumExplorerState(api, childId);
    await model.load();
    model.chooseDomain(CurriculumDomain.math);
    final topic = model.topics.single;
    model.chooseTopic(topic);
    api.catalogGate = Completer<LessonList>();
    final pending = model.load();
    await model.load();
    expect(api.catalogChildren, [childId, childId]);
    expect(model.lessons, isEmpty);
    api.catalogGate!.completeError(
      const ApiFailure('Denied', status: 403, code: 'PERMISSION_NOT_GRANTED'),
    );
    await pending;
    expect(model.error!.status, 403);
    expect(model.inTopic, isEmpty);
    expect(model.topic, topic);
    api.catalogGate = null;
    await model.load();
    expect(model.inTopic.single.lessonId, lessonId);
    model.dispose();
  });

  test(
    'late disposed-child catalog cannot enter another child context',
    () async {
      final api = ExplorerApi()..catalogGate = Completer<LessonList>();
      final old = CurriculumExplorerState(api, childId);
      final pending = old.load();
      old.dispose();
      api.catalogGate!.complete(
        LessonList([LessonSummary.fromJson(summaryJson())], null, 'Old child'),
      );
      await pending;
      expect(old.lessons, isEmpty);
      expect(api.catalogChildren, [childId]);
    },
  );

  test('repository uses only authenticated child lessons GET; topic navigation invents no endpoint', () async {
    final http = Transport()
      ..replies.add(Reply(curriculumJson([summaryJson()])));
    final api = await authenticated(http);
    final model = CurriculumExplorerState(api, childId);
    await model.load();
    model.chooseDomain(CurriculumDomain.math);
    model.chooseTopic(model.topics.single);
    expect(http.requests, hasLength(2));
    expect(http.requests.last.method, 'GET');
    expect(http.requests.last.uri.path, '/api/v1/children/$childId/curriculum');
    expect(
      http.requests.last.headers.value('authorization'),
      'Bearer unit-token',
    );
    expect(http.requests.last.body, isEmpty);
    expect(model.inTopic.single.lessonId, lessonId);
    model.dispose();
  });

  testWidgets(
    'Parent Home to Domain/Topic/Lesson/player; Back preserves child and hierarchy',
    (tester) async {
      final api = ExplorerApi();
      await topicScreen(tester, api);
      expect(find.text('Learning for SYN-Explorer'), findsOneWidget);
      expect(
        find.text('Primary skill: ${summaryJson()['primarySkill']}'),
        findsOneWidget,
      );
      await tapVisible(tester, 'explorer-lesson-$lessonId');
      expect(find.byType(LearningLessonView), findsOneWidget);
      await tapVisible(tester, 'startLearning');
      expect(find.byKey(const Key('option-$optionId')), findsOneWidget);
      await tapVisible(tester, 'lessonBack');
      expect(
        find.byKey(const Key('explorer-lesson-$lessonId')),
        findsOneWidget,
      );
      expect(find.text('Back to topics'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('topic-${summaryJson()['topicCode']}')),
        findsOneWidget,
      );
      expect(find.text('Back to domains'), findsOneWidget);
      await tapVisible(tester, 'explorerBack');
      expect(find.byKey(const Key('domain-ENGLISH')), findsOneWidget);
      await tapVisible(tester, 'explorerHome');
      expect(find.text('Hi, SYN-Explorer!'), findsOneWidget);
      expect(find.byKey(const Key('category-english')), findsOneWidget);
      expect(find.byKey(const Key('category-arts')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('unavailable English has no invented topic or lesson', (
    tester,
  ) async {
    final api = ExplorerApi();
    await explorerRoot(tester, api);
    expect(find.byKey(const Key('domain-ARTS')), findsNothing);
    await tapVisible(tester, 'domain-ENGLISH');
    expect(find.byKey(const Key('explorerEmpty')), findsOneWidget);
    expect(find.text('Topics in English'), findsOneWidget);
    expect(
      find.byKey(Key('topic-${summaryJson()['topicCode']}')),
      findsNothing,
    );
    expect(find.byKey(const Key('explorer-lesson-$lessonId')), findsNothing);
    expect(api.starts, 0);
  });

  for (final reason in ['NO_ELIGIBLE_CONTENT', 'CHILD_OUTSIDE_PROGRAM_AGE']) {
    testWidgets('server $reason remains an honest empty state', (tester) async {
      final api = ExplorerApi()
        ..catalog = []
        ..emptyReason = reason;
      await explorerRoot(tester, api);
      expect(find.text(reason), findsOneWidget);
      expect(find.byKey(const Key('domain-MATH')), findsOneWidget);
      expect(find.byKey(const Key('explorerEmpty')), findsOneWidget);
      expect(api.starts, 0);
    });
  }

  for (final status in [401, 403, 404, 503]) {
    testWidgets(
      'catalog HTTP $status hides stale lessons and permits explicit retry',
      (tester) async {
        final api = ExplorerApi();
        await topicScreen(tester, api);
        api.catalogFailure = ApiFailure(
          'Internal response must stay hidden',
          code: 'CATALOG_$status',
          status: status,
        );
        await tapVisible(tester, 'explorerRefresh');
        expect(find.textContaining('CATALOG_$status'), findsOneWidget);
        expect(find.textContaining('Internal response'), findsNothing);
        expect(
          find.byKey(const Key('explorer-lesson-$lessonId')),
          findsNothing,
        );
        expect(find.byKey(const Key('explorerEmpty')), findsNothing);
        api.catalogFailure = null;
        await tapVisible(tester, 'explorerRefresh');
        expect(
          find.byKey(const Key('explorer-lesson-$lessonId')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'loading guards refresh and lesson selection does not implicitly start a session',
    (tester) async {
      final api = ExplorerApi();
      await topicScreen(tester, api);
      api.catalogGate = Completer<LessonList>();
      final refresh = tester
          .widget<OutlinedButton>(find.byKey(const Key('explorerRefresh')))
          .onPressed!;
      final before = api.catalogChildren.length;
      refresh();
      refresh();
      await tester.pump();
      expect(api.catalogChildren.length, before + 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('explorer-lesson-$lessonId')), findsNothing);
      api.catalogGate!.complete(
        LessonList([LessonSummary.fromJson(summaryJson())], null, 'Synthetic'),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'explorer-lesson-$lessonId');
      expect(find.byType(LearningLessonView), findsOneWidget);
      expect(api.starts, 0);
    },
  );

  testWidgets(
    'player validates selected domain and never substitutes a Math detail for English',
    (tester) async {
      final api = ExplorerApi()
        ..catalog = [
          {...summaryJson(), 'domainCode': 'ENGLISH'},
        ];
      await explorerRoot(tester, api);
      await tapVisible(tester, 'domain-ENGLISH');
      await tapVisible(tester, 'topic-${summaryJson()['topicCode']}');
      await tapVisible(tester, 'explorer-lesson-$lessonId');
      expect(find.textContaining('INVALID_RESPONSE'), findsOneWidget);
      expect(find.byKey(const Key('startLearning')), findsNothing);
      expect(api.starts, 0);
    },
  );
}
