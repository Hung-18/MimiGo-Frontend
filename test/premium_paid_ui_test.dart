import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/api_failure.dart';
import 'package:mimigo_frontend/po/mobile_services.dart';
import 'package:mimigo_frontend/po/po_design.dart';
import 'package:mimigo_frontend/po/premium_panel.dart';

const plan = {
  'planId': 'plan-a',
  'termMonths': 3,
  'price': {'amountMinor': 199000, 'currency': 'VND', 'priceVersionNo': 1},
  'scopeVersionNo': 1,
};

Map<String, dynamic> plansJson({
  bool synthetic = false,
  bool checkout = true,
}) => {
  'plans': [plan],
  'channel': synthetic ? 'SIMULATOR' : 'SEPAY',
  'synthetic': synthetic,
  'checkoutAvailable': checkout,
};

Map<String, dynamic> eligibility() => {
  'childId': 'child-a',
  'synthetic': false,
  'checkoutAvailable': true,
  'terms': [
    {'planId': 'plan-a', 'allowed': true},
  ],
};

Map<String, dynamic> entitlement(String status) => {
  'childId': 'child-a',
  'synthetic': false,
  'status': status,
  'expiresAt': status == 'ACTIVE' ? '2027-02-15T00:00:00Z' : null,
};

Map<String, dynamic> intent() => {
  'intentId': 'intent-a',
  'orderCode': 'MG123',
  'amountMinor': 199000,
  'currency': 'VND',
  'accountNumber': '0123456789',
  'bankCode': 'MBBank',
  'transferContent': 'MG123',
  'qrImageUrl': 'http://not-https.example/qr.png',
  'status': 'AWAITING_TRANSFER',
  'notice': 'n',
};

Map<String, dynamic> payment(String status, {String? quoteEnd}) => {
  'paymentId': 'intent-a',
  'childId': 'child-a',
  'status': status,
  'quoteExpiresAt': ?quoteEnd,
};

PremiumService svc(
  Future<Map<String, dynamic>> Function(String method, String path) answer,
) => PremiumService(
  (
    method,
    path, {
    body,
    bool protected = false,
    Map<String, String>? headers,
  }) => answer(method, path),
);

Future<void> pumpPanel(
  WidgetTester t,
  PremiumService s, {
  bool allowSimulator = false,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: poTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PremiumPanel(
            service: s,
            childId: 'child-a',
            allowSimulator: allowSimulator,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<Map<String, dynamic>> happy(
  String m,
  String p, {
  String pay = 'AWAITING_TRANSFER',
  String? quoteEnd,
}) async {
  if (p == 'billing/premium-plans') return plansJson();
  if (p.endsWith('premium-eligibility')) return eligibility();
  if (p.endsWith('premium-entitlement')) {
    return entitlement(pay == 'SETTLED' ? 'ACTIVE' : 'NONE');
  }
  if (p == 'billing/sepay/payment-intents') return intent();
  if (p.contains('/payments/SEPAY/')) return payment(pay, quoteEnd: quoteEnd);
  throw StateError('unexpected $m $p');
}

void main() {
  group('availability learned from the server only', () {
    test('real offer = real; simulator offer = simulator', () async {
      expect(await svc((m, p) async => plansJson()).mode(), BillingMode.real);
      expect(
        await svc((m, p) async => plansJson(synthetic: true)).mode(),
        BillingMode.simulator,
      );
    });
    test(
      'locked (503 CLOUD_SURFACE_LOCKED), 404, network and bad body = none',
      () async {
        for (final failure in <Object>[
          const ApiFailure('locked', code: 'CLOUD_SURFACE_LOCKED', status: 503),
          const ApiFailure('missing', status: 404),
          StateError('network'),
        ]) {
          expect(
            await svc((m, p) async => throw failure).mode(),
            BillingMode.none,
          );
        }
        expect(await svc((m, p) async => {'x': 1}).mode(), BillingMode.none);
        expect(
          await svc((m, p) async => plansJson(checkout: false)).mode(),
          BillingMode.none,
        );
      },
    );
    test('the availability probe never asks for the Parent proof', () async {
      var protectedSeen = true;
      final s = PremiumService((
        method,
        path, {
        body,
        bool protected = false,
        Map<String, String>? headers,
      }) async {
        protectedSeen = protected;
        return plansJson();
      });
      await s.mode();
      expect(protectedSeen, isFalse);
    });
    test(
      'transfer request carries child and plan only; foreign payment rejected',
      () async {
        Object? sent;
        final s = PremiumService((
          method,
          path, {
          body,
          bool protected = false,
          Map<String, String>? headers,
        }) async {
          expect(protected, isTrue);
          if (method == 'POST') {
            sent = body;
            return intent();
          }
          return {...payment('SETTLED'), 'childId': 'other'};
        });
        await s.createTransfer('child-a', 'plan-a');
        expect(sent, {'childId': 'child-a', 'planId': 'plan-a'});
        await expectLater(
          s.transferStatus('child-a', 'intent-a'),
          throwsA(isA<ApiInvalidResponse>()),
        );
      },
    );
  });

  group('panel', () {
    testWidgets('available: plan, price, instructions, pending then paid', (
      t,
    ) async {
      var pay = 'AWAITING_TRANSFER';
      await pumpPanel(t, svc((m, p) => happy(m, p, pay: pay)));
      expect(find.byKey(const Key('premiumReal')), findsOneWidget);
      expect(find.textContaining('199.000 đ'), findsOneWidget);
      expect(find.textContaining('khu vực của bé'), findsOneWidget);
      await t.tap(find.byType(RadioListTile<String>));
      await t.pump();
      await t.tap(find.text('Tạo hướng dẫn chuyển khoản'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('transferContent')), findsOneWidget);
      expect(find.textContaining('0123456789'), findsOneWidget);
      await t.tap(find.text('Kiểm tra trạng thái thanh toán'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('transferPending')), findsOneWidget);
      expect(find.byKey(const Key('transferPaid')), findsNothing);
      pay = 'SETTLED';
      await t.tap(find.text('Kiểm tra trạng thái thanh toán'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('transferPaid')), findsOneWidget);
    });
    testWidgets('expired and failed states offer a retry', (t) async {
      for (final c in [
        ('AWAITING_TRANSFER', '2020-01-01T00:00:00Z', 'transferExpired'),
        ('REJECTED', null, 'transferFailed'),
      ]) {
        await t.pumpWidget(const SizedBox());
        await pumpPanel(
          t,
          svc((m, p) => happy(m, p, pay: c.$1, quoteEnd: c.$2)),
        );
        await t.tap(find.byType(RadioListTile<String>));
        await t.pump();
        await t.tap(find.text('Tạo hướng dẫn chuyển khoản'));
        await t.pumpAndSettle();
        await t.tap(find.text('Kiểm tra trạng thái thanh toán'));
        await t.pumpAndSettle();
        expect(find.byKey(Key(c.$3)), findsOneWidget);
        expect(find.text('Tạo hướng dẫn chuyển khoản mới'), findsOneWidget);
      }
    });
    testWidgets('simulator offer is never shown outside debug lanes', (
      t,
    ) async {
      Future<Map<String, dynamic>> sim(String m, String p) async {
        if (p == 'billing/premium-plans') return plansJson(synthetic: true);
        if (p.endsWith('premium-eligibility')) {
          return {...eligibility(), 'synthetic': true};
        }
        return {...entitlement('NONE'), 'synthetic': true};
      }

      await pumpPanel(t, svc(sim));
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.textContaining('thử nghiệm'), findsNothing);
      await pumpPanel(t, svc(sim), allowSimulator: true);
      expect(find.textContaining('thử nghiệm'), findsWidgets);
    });
    testWidgets('read error shows a calm message and no payment instructions', (
      t,
    ) async {
      await pumpPanel(
        t,
        svc((m, p) async => throw const ApiFailure('locked', status: 503)),
      );
      expect(find.byKey(const Key('transferContent')), findsNothing);
      expect(find.byKey(const Key('premiumReal')), findsNothing);
    });
  });
}
