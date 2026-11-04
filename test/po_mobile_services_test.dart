import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/api_failure.dart';
import 'package:mimigo_frontend/po/mobile_services.dart';

Map<String, dynamic> quote({
  String child = 'child-a',
  String status = 'PENDING_SETTLEMENT',
}) => {
  'synthetic': true,
  'checkoutId': 'checkout-a',
  'status': status,
  'totalMinor': 123,
  'currency': 'VND',
  'expiresAt': '2026-11-05T12:00:00Z',
  'lines': [
    {'childId': child, 'planId': 'plan-a'},
  ],
  if (status == 'SETTLED') 'settlement': {'result': 'SETTLED'},
};
void main() {
  test('resend accepts only the uniform response and a valid cooldown', () {
    expect(
      ResendResult.fromJson({
        'status': 'ACCEPTED',
        'resendCooldownSeconds': 60,
        'notice': 'uniform',
      }).cooldown,
      60,
    );
    for (final bad in [
      <String, dynamic>{
        'status': 'SENT',
        'resendCooldownSeconds': 60,
        'notice': 'x',
      },
      <String, dynamic>{
        'status': 'ACCEPTED',
        'resendCooldownSeconds': -1,
        'notice': 'x',
      },
    ]) {
      expect(
        () => ResendResult.fromJson(bad),
        throwsA(isA<ApiInvalidResponse>()),
      );
    }
  });
  test(
    'checkout retry sends identical key and lines, and always requires proof',
    () async {
      final bodies = <Object?>[];
      final service = PremiumService((
        method,
        path, {
        body,
        bool protected = false,
        Map<String, String>? headers,
      }) async {
        expect(method, 'POST');
        expect(path, 'billing/premium-checkouts');
        expect(protected, isTrue);
        bodies.add(body);
        return quote();
      });
      await service.checkout('child-a', 'plan-a', 'same-request-key');
      await service.checkout('child-a', 'plan-a', 'same-request-key');
      expect(bodies.first, bodies.last);
      expect(bodies.first, {
        'idempotencyKey': 'same-request-key',
        'items': [
          {'childId': 'child-a', 'planId': 'plan-a'},
        ],
      });
    },
  );
  test(
    'checkout rejects a different child and non-synthetic success',
    () async {
      for (final result in [
        quote(child: 'child-b'),
        {...quote(), 'synthetic': false},
      ]) {
        final service = PremiumService(
          (
            method,
            path, {
            body,
            bool protected = false,
            Map<String, String>? headers,
          }) async => result,
        );
        await expectLater(
          service.checkout('child-a', 'plan-a', 'key'),
          throwsA(isA<ApiInvalidResponse>()),
        );
      }
    },
  );
  test(
    'settlement requires matching checkout and a confirmed result',
    () async {
      final service = PremiumService((
        method,
        path, {
        body,
        bool protected = false,
        Map<String, String>? headers,
      }) async {
        expect(
          path,
          'billing/premium-checkouts/checkout-a/synthetic-settlement',
        );
        expect(body, {'outcome': 'SETTLED'});
        expect(protected, isTrue);
        return quote(status: 'SETTLED');
      });
      expect(
        (await service.settle(
          'checkout-a',
          'child-a',
          'plan-a',
          outcome: 'SETTLED',
        ))['status'],
        'SETTLED',
      );
      final mismatch = PremiumService(
        (
          method,
          path, {
          body,
          bool protected = false,
          Map<String, String>? headers,
        }) async => quote(status: 'SETTLED'),
      );
      await expectLater(
        mismatch.settle(
          'different-checkout',
          'child-a',
          'plan-a',
          outcome: 'SETTLED',
        ),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
  test(
    'profile writes use a pinned version and idempotency header, never DOB',
    () async {
      final service = ProfileService((
        method,
        path, {
        body,
        bool protected = false,
        Map<String, String>? headers,
      }) async {
        expect(method, 'PATCH');
        expect(path, 'children/child-a');
        expect(protected, isTrue);
        expect(headers, {
          'If-Match': '"7"',
          'Idempotency-Key': 'same-profile-key',
        });
        expect(body, {'childAlias': 'SYN-Mây', 'stockAvatarKey': 'bear-blue'});
        return {
          'childId': 'child-a',
          'profileVersion': 8,
          'childAlias': 'SYN-Mây',
          'stockAvatarKey': 'bear-blue',
        };
      });
      expect(
        (await service.update(
          'child-a',
          7,
          'SYN-Mây',
          'bear-blue',
          'same-profile-key',
        ))['profileVersion'],
        8,
      );
    },
  );
  test(
    'protected profile rejects foreign identity or missing version',
    () async {
      final service = ProfileService(
        (
          method,
          path, {
          body,
          bool protected = false,
          Map<String, String>? headers,
        }) async => {
          'childId': 'foreign',
          'profileVersion': 8,
          'childAlias': 'SYN-X',
          'stockAvatarKey': 'bear-blue',
        },
      );
      await expectLater(
        service.read('child-a'),
        throwsA(isA<ApiInvalidResponse>()),
      );
    },
  );
}
