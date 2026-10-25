import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/parent_home.dart';

import 'sign_in_test.dart' show AuthApi, openSignIn, fillSignIn, submitSignIn;
import 'learning_widget_test.dart' show tapVisible;
import 'design_test_support.dart' show loadDesignFonts, visualApp;

ChildSummary profile(String id, {String state = 'ACTIVE'}) => ChildSummary(
  id: id,
  alias: 'SYN-$id',
  dateOfBirth: DateTime(2023, 1, 1),
  ageYears: 3,
  withinProgramAgeRange: true,
  state: state,
  createdAt: DateTime(2026),
);

ChildDetail detail(String id, {String state = 'ACTIVE'}) => ChildDetail(
  id: id,
  alias: 'SYN-$id',
  dateOfBirth: DateTime(2023, 1, 1),
  ageYears: 3,
  withinProgramAgeRange: true,
  state: state,
  createdAt: DateTime(2026),
  recordedDecisions: const [],
  disclaimer: 'Synthetic child detail',
);

class ParentApi extends AuthApi {
  Completer<ChildDetail>? gate;
  ApiFailure? detailFailure;
  bool wrongChild = false;
  @override
  Future<ChildDetail> getChild(String id) async {
    calls.add('detail:$id');
    if (detailFailure != null) throw detailFailure!;
    return gate?.future ??
        detail(
          wrongChild ? 'wrong' : id,
          state: profiles.singleWhere((p) => p.id == id).state,
        );
  }
}

Future<void> signInHome(WidgetTester tester, ParentApi api) async {
  await openSignIn(tester, api);
  await fillSignIn(tester);
  await submitSignIn(tester);
}

void main() {
  for (final size in [const Size(320, 740), const Size(960, 540)]) {
    testWidgets('Vietnamese Parent controls fit $size at 2x text', (
      tester,
    ) async {
      await loadDesignFonts();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = ParentApi()..profiles = [profile('A')];
      final workspace = await api.learningWorkspace();
      var entered = 0;
      await tester.pumpWidget(
        visualApp(
          Frame(
            title: 'Phụ huynh',
            children: [
              ParentHome(
                api: api,
                parent: const ParentSummary(
                  'parent',
                  'synthetic@example.test',
                  'SYN',
                  true,
                ),
                children: api.profiles,
                workspace: workspace,
                fixture: true,
                add: () {},
                enterChild: (_) => entered++,
                accountEntry: () {},
              ),
            ],
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không lưu kết quả lên máy chủ'),
        findsOneWidget,
      );
      await tapVisible(tester, 'parent-child-A');
      await tester.ensureVisible(find.byKey(const Key('parentEnterLearning')));
      expect(
        tester.getSize(find.byKey(const Key('parentEnterLearning'))).height,
        greaterThanOrEqualTo(64),
      );
      expect(find.text('Vào không gian của bé'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, 'parentEnterLearning');
      expect(entered, 1);
    });
  }

  testWidgets(
    'failed roster refresh is not an empty account and retries safely',
    (tester) async {
      final api = ParentApi()..profiles = [profile('A')];
      await signInHome(tester, api);
      api.listFailure = const ApiFailure(
        'PRIVATE_SERVER_DETAIL',
        code: 'CONNECTIVITY',
      );
      await tapVisible(tester, 'parentRefresh');
      expect(find.byKey(const Key('parentChildrenEmpty')), findsNothing);
      expect(
        find.textContaining('Add your first synthetic child'),
        findsNothing,
      );
      expect(find.textContaining('PRIVATE_SERVER_DETAIL'), findsNothing);
      expect(find.textContaining('Return to Child Mode'), findsNothing);
      expect(find.byKey(const Key('parent-child-A')), findsNothing);
      api.listFailure = null;
      await tapVisible(tester, 'parentRefresh');
      expect(find.byKey(const Key('parent-child-A')), findsOneWidget);
    },
  );

  test('selection is authenticated, coalesced and never retains the previous child during switching', () async {
    final api = ParentApi()..profiles = [profile('A'), profile('B')];
    final model = ParentHomeState(api)..seed(api.profiles);
    await model.choose('A');
    expect(model.selected!.id, 'A');
    api.gate = Completer<ChildDetail>();
    final first = model.choose('B');
    await model.choose('A');
    expect(model.selected, isNull);
    expect(api.calls, ['detail:A', 'detail:B']);
    api.gate!.complete(detail('B'));
    await first;
    expect(model.selected!.id, 'B');
    model.dispose();
  });

  test('list errors discard stale children and unknown identifiers never call the repository', () async {
    final api = ParentApi()..profiles = [profile('A')];
    final model = ParentHomeState(api)..seed(api.profiles);
    await model.choose('unknown');
    expect(api.calls, isEmpty);
    await model.choose('A');
    api.listFailure = const ApiFailure(
      'Expired',
      code: 'UNAUTHENTICATED',
      status: 401,
    );
    await model.refresh();
    expect(model.selected, isNull);
    expect(model.children, isEmpty);
    expect(model.error!.status, 401);
    model.dispose();
  });

  test('wrong-child response is rejected and late profile responses cannot revive a disposed parent context', () async {
    final api = ParentApi()
      ..profiles = [profile('A')]
      ..wrongChild = true;
    final model = ParentHomeState(api)..seed(api.profiles);
    await model.choose('A');
    expect(model.error, isA<ApiInvalidResponse>());
    expect(model.selected, isNull);
    api.wrongChild = false;
    api.gate = Completer<ChildDetail>();
    final pending = model.choose('A');
    model.dispose();
    api.gate!.complete(detail('A'));
    await pending;
    expect(model.selected, isNull);
  });

  testWidgets(
    'parent selects, reviews, switches and explicitly enters the chosen child only',
    (tester) async {
      final api = ParentApi()..profiles = [profile('A'), profile('B')];
      await signInHome(tester, api);
      expect(find.text('Parent Home'), findsOneWidget);
      await tapVisible(tester, 'parent-child-A');
      expect(find.text('Selected child: SYN-A'), findsOneWidget);
      expect(find.byType(ChildHome), findsNothing);
      await tapVisible(tester, 'parentChooseAnother');
      await tapVisible(tester, 'parent-child-B');
      expect(find.text('Selected child: SYN-B'), findsOneWidget);
      expect(find.text('Selected child: SYN-A'), findsNothing);
      await tapVisible(tester, 'parentEnterLearning');
      expect(find.text('Hi, SYN-B!'), findsOneWidget);
      expect(find.byType(ParentHome), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('childParentGate')))
            .onPressed,
        isNull,
      );
      expect(api.calls.where((c) => c.startsWith('detail:')), [
        'detail:A',
        'detail:B',
      ]);
    },
  );

  for (final status in [401, 403, 404, 503]) {
    testWidgets(
      'child detail HTTP $status shows safe retry guidance without entering Child Mode',
      (tester) async {
        final api = ParentApi()
          ..profiles = [profile('A')]
          ..detailFailure = ApiFailure(
            'Internal detail must be hidden',
            code: 'DENIED_$status',
            status: status,
          );
        await signInHome(tester, api);
        await tapVisible(tester, 'parent-child-A');
        expect(find.textContaining('DENIED_$status'), findsOneWidget);
        expect(find.textContaining('Internal detail'), findsNothing);
        expect(find.byType(ChildHome), findsNothing);
        expect(find.byKey(const Key('parentEnterLearning')), findsNothing);
        api.detailFailure = null;
        await tapVisible(tester, 'parent-child-A');
        expect(find.byKey(const Key('parentSelectedChild')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'pending selection disables duplicate actions and inactive profiles cannot enter learning',
    (tester) async {
      final api = ParentApi()
        ..profiles = [profile('A', state: 'CLOSED')]
        ..gate = Completer<ChildDetail>();
      await signInHome(tester, api);
      await tapVisible(tester, 'parent-child-A', settle: false);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.byKey(const Key('parent-child-A'))).onTap,
        isNull,
      );
      api.gate!.complete(detail('A', state: 'CLOSED'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('parentEnterLearning')))
            .onPressed,
        isNull,
      );
      expect(api.calls.where((c) => c == 'detail:A'), hasLength(1));
    },
  );

  testWidgets(
    'empty home routes through existing consent; account return clears parent access',
    (tester) async {
      final api = ParentApi();
      await signInHome(tester, api);
      expect(find.byKey(const Key('parentChildrenEmpty')), findsOneWidget);
      await tapVisible(tester, 'parentAccountEntry');
      await tapVisible(tester, 'confirmAccountEntry');
      expect(find.byType(ParentArea), findsNothing);
      expect(find.byKey(const Key('welcomeSignIn')), findsOneWidget);
      await fillHomeAgain(tester);
      await tapVisible(tester, 'addChild');
      expect(find.byKey(const Key('loadAttempt')), findsOneWidget);
      expect(find.byKey(const Key('childName')), findsNothing);
    },
  );
}

Future<void> fillHomeAgain(WidgetTester tester) async {
  await tapVisible(tester, 'welcomeSignIn');
  await fillSignIn(tester);
  await submitSignIn(tester);
}
