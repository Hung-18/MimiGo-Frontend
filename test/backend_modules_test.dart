import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/curriculum_explorer.dart';

import 'learning_api_test.dart' show Transport, Reply, authenticated;
import 'learning_test_data.dart';
import 'learning_widget_test.dart' show tapVisible;
import 'parent_home_test.dart' show ParentApi, profile, signInHome;

Map<String, dynamic> workspaceJson({String status = 'AVAILABLE'}) => {
  'children': [
    {
      'child': {
        'childId': 'A',
        'childAlias': 'SYN-A',
        'dateOfBirth': '2023-01-01',
        'ageYears': 3,
        'withinProgramAgeRange': true,
        'state': 'ACTIVE',
        'createdAt': '2026-10-24T00:00:00Z',
      },
      'catalog': {'status': status, 'eligibleLessonCount': 1},
      'openSessions': {
        'status': 'AVAILABLE',
        'items': [
          {
            'sessionId': 'PROTECTED-SESSION',
            'state': 'IN_PROGRESS',
            'lessonTitle': 'SECRET HISTORY',
          },
        ],
      },
    },
  ],
  'disclaimer': 'Synthetic safe catalog projection',
};

class WorkspaceApi extends ParentApi {
  String availability = 'AVAILABLE';
  @override
  Future<ParentWorkspace> learningWorkspace() async =>
      ParentWorkspace.fromJson(workspaceJson(status: availability));
}

void main() {
  test(
    'curriculum preserves returned domain/topic names and server display order',
    () async {
      final body = curriculumJson([
        summaryJson(),
        {...summaryJson(), 'lessonId': 'other', 'topicCode': 'AAA'},
      ]);
      final domain = (body['domains'] as List).single as Map;
      domain['name'] = 'Returned Mathematics';
      final topics = domain['topics'] as List;
      topics[0]['name'] = 'Returned Counting';
      topics[0]['sortOrder'] = 1;
      topics[1]['name'] = 'Returned Patterns';
      topics[1]['sortOrder'] = 2;
      final http = Transport()..replies.add(Reply(body));
      final model = CurriculumExplorerState(await authenticated(http), childId);
      await model.load();
      model.chooseDomain(CurriculumDomain.math);
      expect(model.domainName(CurriculumDomain.math), 'Returned Mathematics');
      expect(model.topics, ['SYN-TOPIC', 'AAA']);
      expect(model.topicName('SYN-TOPIC'), 'Returned Counting');
      expect(
        http.requests.last.uri.path,
        '/api/v1/children/$childId/curriculum',
      );
      model.dispose();
    },
  );

  for (final mutation in [
    'empty-topic',
    'wrong-domain',
    'wrong-topic',
    'premium',
    'duplicate-domain',
  ]) {
    test(
      'invalid curriculum $mutation is rejected rather than rendered as eligible',
      () {
        final body = curriculumJson([summaryJson()]);
        final domains = body['domains'] as List;
        final topic = domains.single['topics'][0];
        switch (mutation) {
          case 'empty-topic':
            topic['lessons'] = [];
          case 'wrong-domain':
            topic['lessons'][0]['domainCode'] = 'ENGLISH';
          case 'wrong-topic':
            topic['lessons'][0]['topicCode'] = 'wrong';
          case 'premium':
            topic['lessons'][0]['access'] = 'PREMIUM';
          case 'duplicate-domain':
            domains.add(domains.first);
        }
        expect(
          () => CurriculumCatalog.fromJson(body),
          throwsA(isA<ApiInvalidResponse>()),
        );
      },
    );
  }

  test('workspace client authenticates exact route and discards the protected sessions projection', () async {
    final http = Transport()..replies.add(Reply(workspaceJson()));
    final result = await (await authenticated(http)).learningWorkspace();
    expect(
      http.requests.last.uri.path,
      '/api/v1/parents/me/learning-workspace',
    );
    expect(
      http.requests.last.headers.value('authorization'),
      'Bearer unit-token',
    );
    expect(result.children.single.child.id, 'A');
    expect(result.children.single.catalogStatus, 'AVAILABLE');
    // Even malformed protected data is not parsed, retained as a model or needed
    // for a Parent Home catalog-only view.
    final ignored = workspaceJson();
    ignored['children'] = <Map<String, dynamic>>[
      {
        ...Map<String, dynamic>.from(ignored['children'][0] as Map),
        'openSessions': 'not read',
      },
    ];
    expect(ParentWorkspace.fromJson(ignored).children.single.child.id, 'A');
  });

  for (final status in [
    'AVAILABLE',
    'PERMISSION_NOT_GRANTED',
    'CHILD_NOT_ACTIVE',
  ]) {
    testWidgets(
      'Parent Home uses $status availability without showing protected history',
      (tester) async {
        final api = WorkspaceApi()
          ..profiles = [profile('A')]
          ..availability = status;
        await signInHome(tester, api);
        expect(find.textContaining('SECRET HISTORY'), findsNothing);
        expect(find.textContaining('PROTECTED-SESSION'), findsNothing);
        await tapVisible(tester, 'parent-child-A');
        expect(
          find.byKey(const Key('parentCatalogAvailability')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('parentEnterLearning')),
              )
              .onPressed,
          status == 'AVAILABLE' ? isNotNull : isNull,
        );
        expect(find.textContaining('SECRET HISTORY'), findsNothing);
      },
    );
  }
}
