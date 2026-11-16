import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/api_failure.dart';
import 'package:mimigo_frontend/po/data_rights.dart';

// Fake transport only: no real API is ever called.
class Fake {
  final calls =
      <
        ({
          String method,
          String path,
          Object? body,
          Map<String, String>? headers,
        })
      >[];
  List<Map<String, dynamic>> items = [];
  ApiFailure? failOpen, failCancel, failList;
  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Object? body,
    bool protected = false,
    Map<String, String>? headers,
  }) async {
    expect(protected, isTrue);
    calls.add((method: method, path: path, body: body, headers: headers));
    if (method == 'GET') {
      if (failList != null) throw failList!;
      return {'items': items};
    }
    if (method == 'POST') {
      if (failOpen != null) throw failOpen!;
      final r = {
        'requestId': 'req-1',
        'state': 'RECEIVED',
        'dueAt': '2026-12-16T00:00:00Z',
        'note': 'n',
      };
      items = [
        {...r, 'kind': (body as Map)['kind'], 'childId': body['childId']},
      ];
      return r;
    }
    if (failCancel != null) throw failCancel!;
    items = [];
    return {};
  }
}

Widget host(Fake f) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: DataRightsPanel(
        service: DataRightsService(f.call),
        children: const [(id: 'c1', alias: 'Bi')],
      ),
    ),
  ),
);

Future<void> openAndConfirm(WidgetTester t, Key entry) async {
  await t.ensureVisible(find.byKey(entry));
  await t.tap(find.byKey(entry));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('rightsConfirmSend')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows copy, lists existing requests, sends nothing on load besides GET',
    (t) async {
      final f = Fake()
        ..items = [
          {
            'requestId': 'r0',
            'kind': 'DELETION',
            'childId': 'c1',
            'state': 'RECEIVED',
            'dueAt': '2026-12-01T00:00:00Z',
          },
        ];
      await t.pumpWidget(host(f));
      await t.pumpAndSettle();
      expect(find.textContaining('trong vòng 30 ngày'), findsOneWidget);
      expect(find.textContaining('không chứa tên'), findsNothing);
      expect(find.text('Xóa dữ liệu của Bi'), findsWidgets);
      expect(find.text('Đã nhận · xử lý trước 01/12/2026'), findsOneWidget);
      expect(f.calls.map((c) => c.method), ['GET']);
    },
  );

  testWidgets('declining the confirmation sends no request', (t) async {
    final f = Fake();
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('rightsCloseAccount')));
    await t.tap(find.byKey(const Key('rightsCloseAccount')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('rightsConfirmCancel')));
    await t.pumpAndSettle();
    expect(f.calls.where((c) => c.method == 'POST'), isEmpty);
  });

  testWidgets('child deletion posts kind, childId and an Idempotency-Key', (
    t,
  ) async {
    final f = Fake();
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    await openAndConfirm(t, const Key('rightsDeleteChild-c1'));
    final post = f.calls.singleWhere((c) => c.method == 'POST');
    expect(post.path, 'parents/me/privacy-requests');
    expect(post.body, {'kind': 'DELETION', 'childId': 'c1'});
    expect(post.headers!['Idempotency-Key']!.length, inInclusiveRange(8, 128));
    expect(find.textContaining('trước ngày 16/12/2026'), findsOneWidget);
  });

  testWidgets('account closure sends no childId', (t) async {
    final f = Fake();
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    await openAndConfirm(t, const Key('rightsCloseAccount'));
    expect(f.calls.singleWhere((c) => c.method == 'POST').body, {
      'kind': 'ACCOUNT_CLOSURE',
    });
  });

  testWidgets('409 shows the duplicate message; retry reuses the same key', (
    t,
  ) async {
    final f = Fake()
      ..failOpen = const ApiFailure(
        'x',
        code: 'RIGHTS_REQUEST_ALREADY_OPEN',
        status: 409,
      );
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    await openAndConfirm(t, const Key('rightsCloseAccount'));
    expect(
      find.text('Ba mẹ đã có một yêu cầu cùng loại đang chờ xử lý.'),
      findsOneWidget,
    );
    await openAndConfirm(t, const Key('rightsCloseAccount'));
    final keys = f.calls
        .where((c) => c.method == 'POST')
        .map((c) => c.headers!['Idempotency-Key'])
        .toSet();
    expect(keys.length, 1);
  });

  testWidgets(
    '403 asks for the PIN again; 503 shows a friendly fallback with the email',
    (t) async {
      final f = Fake()..failOpen = const ApiFailure('x', status: 403);
      await t.pumpWidget(host(f));
      await t.pumpAndSettle();
      await openAndConfirm(t, const Key('rightsCloseAccount'));
      expect(
        find.text('Ba mẹ vui lòng nhập lại mã PIN để tiếp tục.'),
        findsOneWidget,
      );
      f.failOpen = const ApiFailure('x', status: 503, retryable: true);
      await openAndConfirm(t, const Key('rightsCloseAccount'));
      expect(find.textContaining('contact@mimigo.id.vn'), findsWidgets);
      expect(find.textContaining('Exception'), findsNothing);
    },
  );

  testWidgets('a locked or failing list does not crash the panel', (t) async {
    final f = Fake()
      ..failList = const ApiFailure(
        'x',
        code: 'CLOUD_SURFACE_LOCKED',
        status: 403,
      );
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    expect(tester(t), isNull);
    expect(find.byKey(const Key('rightsCloseAccount')), findsOneWidget);
  });

  testWidgets('cancel only for RECEIVED and DELETE hits the request id', (
    t,
  ) async {
    final f = Fake()
      ..items = [
        {
          'requestId': 'r1',
          'kind': 'ACCOUNT_CLOSURE',
          'state': 'RECEIVED',
          'dueAt': '2026-12-01T00:00:00Z',
        },
        {
          'requestId': 'r2',
          'kind': 'DELETION',
          'childId': 'c1',
          'state': 'IN_REVIEW',
          'dueAt': '2026-12-01T00:00:00Z',
        },
      ];
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rightsCancel-r1')), findsOneWidget);
    expect(find.byKey(const Key('rightsCancel-r2')), findsNothing);
    await t.ensureVisible(find.byKey(const Key('rightsCancel-r1')));
    await t.tap(find.byKey(const Key('rightsCancel-r1')));
    await t.pumpAndSettle();
    final del = f.calls.singleWhere((c) => c.method == 'DELETE');
    expect(del.path, 'parents/me/privacy-requests/r1');
  });

  test('malformed list item is rejected, not guessed', () async {
    final s = DataRightsService(
      (m, p, {body, protected = false, headers}) async => {
        'items': [
          {'requestId': 'r', 'state': 'RECEIVED'},
        ],
      },
    );
    await expectLater(s.list(), throwsA(isA<ApiInvalidResponse>()));
  });
}

Object? tester(WidgetTester t) => t.takeException();
