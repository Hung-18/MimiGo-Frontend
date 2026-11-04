import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/main.dart';
import 'package:mimigo_frontend/learning_models.dart';
import 'package:mimigo_frontend/learning_screens.dart';
import 'package:mimigo_frontend/po/live_child_home.dart';
import 'package:mimigo_frontend/po/po_design.dart';
import 'package:mimigo_frontend/po/preview_app.dart';
import 'package:mimigo_frontend/parent_home.dart';

import 'learning_api_test.dart' show Transport, Reply, Request;
import 'learning_test_data.dart' as data;
import 'parent_gate_repository_test.dart' show gateClient;
import 'parent_gate_test_backend.dart';
import 'parent_gate_session_test.dart' show MemoryVault;

class CurriculumApi extends FixtureMimiGoApi {
  CurriculumApi(this.result);
  Future<CurriculumCatalog> Function() result;
  int reads = 0;
  @override
  Future<CurriculumCatalog> curriculum(String childId) {
    reads++;
    expect(childId, 'child-server-id');
    return result();
  }
}

class DelayedRequest extends Request {
  DelayedRequest(String method, Uri uri, this.response)
    : super(method, uri, Reply({}));
  final Completer<HttpClientResponse> response;
  bool aborted = false;
  @override
  Future<HttpClientResponse> close() => response.future;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }
}

class DelayedTransport extends Transport {
  final response = Completer<HttpClientResponse>();
  late DelayedRequest pending;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      pending = DelayedRequest(method, url, response);
}

class VersionedBackend extends GateTestBackend {
  @override
  Map<String, dynamic> protectedChild(String id) => {
    ...super.protectedChild(id),
    'profileVersion': 7,
  };
}

class CoreLessonApi extends FixtureMimiGoApi {
  @override
  Future<LessonDetail> lesson(String childId, String lessonId) async =>
      LessonDetail.fromJson({...data.detailJson(), 'access': 'CORE'});
}

void main() {
  testWidgets(
    'server-authorized Core lesson detail is accepted without a local Premium unlock',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningLessonView(
                api: CoreLessonApi(),
                childId: data.childId,
                lessonId: data.lessonId,
                pending: PendingLearningAnswers(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('startLearning')), findsOneWidget);
      expect(find.byType(LearningError), findsNothing);
    },
  );
  test(
    'normal configuration always selects real API and secure Gate session',
    () {
      final config = ApiConfiguration.fromEnvironment();
      expect(config.mode, ApiMode.live);
      expect(config.parentGateEnabled, isTrue);
      expect(config.createClient(), isA<LiveMimiGoApi>());
    },
  );
  testWidgets('normal welcome has no preview routes or fixture adapter', (
    t,
  ) async {
    // Explicit no-Gate API double prevents any device-vault request in a widget test.
    await t.pumpWidget(
      MimiGoApp(
        api: FixtureMimiGoApi(),
        configuration: const ApiConfiguration(ApiMode.live, 'unused'),
      ),
    );
    expect(find.byKey(const Key('poPreview')), findsNothing);
    expect(find.byKey(const Key('welcomeMobileDemo')), findsNothing);
    expect(find.byType(PoPreview), findsNothing);
    expect(find.byKey(const Key('welcomeSignIn')), findsOneWidget);
  });
  testWidgets(
    'empty server catalog stays empty, and denied retry never shows local activities',
    (t) async {
      final api = CurriculumApi(
        () async =>
            const CurriculumCatalog([], 'NO_ELIGIBLE_CONTENT', 'server'),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: poTheme(),
          home: LiveChildHome(
            api: api,
            childId: 'child-server-id',
            openDomain: ([d]) {},
            parentArea: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('liveCatalogEmpty')), findsOneWidget);
      expect(find.text('Giỏ táo của Mimi'), findsNothing);
      expect(find.text('Bé Mây'), findsNothing);
      expect(api.reads, 1);
      api.result = () async => throw const ApiFailure(
        'denied',
        code: 'PERMISSION_NOT_GRANTED',
        status: 403,
      );
      await t.ensureVisible(find.byKey(const Key('liveCatalogRefresh')));
      await t.tap(find.byKey(const Key('liveCatalogRefresh')));
      await t.pumpAndSettle();
      expect(find.byType(LearningError), findsOneWidget);
      expect(find.byKey(const Key('liveCatalogEmpty')), findsNothing);
      expect(find.byKey(const Key('live-domain-MATH')), findsNothing);
      expect(api.reads, 2);
    },
  );
  testWidgets(
    'Core catalog uses returned title and server domain selection only',
    (t) async {
      final api = CurriculumApi(
        () async => CurriculumCatalog.fromJson(
          data.curriculumJson([
            {
              ...data.summaryJson(),
              'access': 'CORE',
              'title': 'Server Core Lesson',
            },
          ]),
        ),
      );
      String? chosen;
      await t.pumpWidget(
        MaterialApp(
          theme: poTheme(),
          home: LiveChildHome(
            api: api,
            childId: 'child-server-id',
            openDomain: ([d]) => chosen = d?.code,
            parentArea: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('live-domain-MATH')));
      await t.tap(find.byKey(const Key('live-domain-MATH')));
      await t.pump();
      expect(chosen, 'MATH');
      expect(find.text('UI PREVIEW'), findsNothing);
    },
  );
  test('clearing a session aborts transport and rejects an acknowledgment arriving later', () async {
    final transport = DelayedTransport();
    final api = LiveMimiGoApi(
      Uri.parse('http://unit.invalid/api/v1'),
      client: transport,
    );
    final request = api.onboardingReference();
    await Future<void>.delayed(Duration.zero);
    final rejected = expectLater(
      request,
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'REQUEST_CANCELLED'),
      ),
    );
    api.clearSession();
    expect(transport.pending.aborted, isTrue);
    transport.response.complete(Reply({}));
    await rejected;
  });
  test(
    'protected profile reads use current proof and preserve server version',
    () async {
      final backend = VersionedBackend()..enrolled = true;
      final api = await gateClient(backend, vault: MemoryVault());
      addTearDown(() => api.gateSession!.dispose());
      await api.verifyParentArea(syntheticPin);
      final profile = await api.profiles.read('child-A');
      expect(profile['profileVersion'], 7);
      expect(
        backend.requests.last.headers.value('mimigo-parent-proof'),
        backend.parentProof,
      );
      api.gateSession!.dropProof();
      final before = backend.requests.length;
      await expectLater(
        api.profiles.read('child-A'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'PARENT_GATE_REQUIRED',
          ),
        ),
      );
      expect(backend.requests.length, before);
    },
  );
  test('known age-out workspace can enter a Child context without granting a lesson', () async {
    final backend = VersionedBackend()..enrolled = true;
    final api = await gateClient(backend, vault: MemoryVault());
    addTearDown(() => api.gateSession!.dispose());
    final model = ParentHomeState(api);
    addTearDown(model.dispose);
    const child = ChildSummary(
      id: 'child-A',
      alias: 'server',
      withinProgramAgeRange: false,
      state: 'ACTIVE',
    );
    model.seed([child]);
    model.selected = child;
    model.catalogStatuses = {'child-A': 'CHILD_OUTSIDE_PROGRAM_AGE'};
    model.learningEntryStatuses = {'child-A': 'CHILD_OUTSIDE_PROGRAM_AGE'};
    expect(model.canEnter, isTrue);
    model.learningEntryStatuses = {'child-A': 'PERMISSION_NOT_GRANTED'};
    expect(model.canEnter, isFalse);
  });
}
