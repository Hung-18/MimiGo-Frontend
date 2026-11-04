import 'dart:math';

import '../api_failure.dart';

typedef MobileRequest = Future<Map<String, dynamic>> Function(
  String method,
  String path, {
  Object? body,
  bool protected,
  Map<String, String>? headers,
});

String mobileRequestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ResendResult {
  const ResendResult(this.cooldown, this.notice);
  factory ResendResult.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ACCEPTED' ||
        json['resendCooldownSeconds'] is! int ||
        json['notice'] is! String ||
        (json['resendCooldownSeconds'] as int) < 0) {
      throw const ApiInvalidResponse('Invalid resend acknowledgment.');
    }
    return ResendResult(
      json['resendCooldownSeconds'] as int,
      json['notice'] as String,
    );
  }
  final int cooldown;
  final String notice;
}

abstract interface class MobileCapabilities {
  Future<ResendResult> resendVerification(String email);
  PremiumService get premium;
  ProfileService get profiles;
}

class ProfileService {
  ProfileService(this.request);
  final MobileRequest request;
  Future<Map<String, dynamic>> read(String childId) async => _validate(
    await request('GET', 'children/$childId', protected: true),
    childId,
  );
  Future<Map<String, dynamic>> update(
    String childId,
    int version,
    String alias,
    String avatar,
    String key,
  ) async => _validate(
    await request(
      'PATCH',
      'children/$childId',
      body: {'childAlias': alias, 'stockAvatarKey': avatar},
      headers: {'If-Match': '"$version"', 'Idempotency-Key': key},
      protected: true,
    ),
    childId,
  );
  Map<String, dynamic> _validate(Map<String, dynamic> value, String childId) {
    if (value['childId'] != childId ||
        value['childAlias'] is! String ||
        (value['stockAvatarKey'] != null &&
            value['stockAvatarKey'] is! String) ||
        value['profileVersion'] is! int ||
        value['profileVersion'] < 1)
      throw const ApiInvalidResponse('Invalid protected profile version.');
    return value;
  }
}

class PremiumPlan {
  const PremiumPlan(
    this.id,
    this.months,
    this.amount,
    this.currency,
    this.priceVersion,
    this.scopeVersion,
  );
  final String id, currency;
  final int months, amount, priceVersion, scopeVersion;
  factory PremiumPlan.fromJson(Map<String, dynamic> j) {
    final p = object(j['price']);
    if (j['planId'] is! String ||
        ![1, 3, 6, 12].contains(j['termMonths']) ||
        p['amountMinor'] is! int ||
        p['amountMinor'] < 0 ||
        p['currency'] is! String ||
        p['priceVersionNo'] is! int ||
        j['scopeVersionNo'] is! int)
      throw const ApiInvalidResponse('Invalid simulator plan.');
    return PremiumPlan(
      j['planId'],
      j['termMonths'],
      p['amountMinor'],
      p['currency'],
      p['priceVersionNo'],
      j['scopeVersionNo'],
    );
  }
}

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>)
    throw const ApiInvalidResponse('Invalid mobile response.');
  return value;
}

class PremiumService {
  PremiumService(this.request);
  final MobileRequest request;
  Future<Map<String, dynamic>> plans() async {
    final j = await request('GET', 'billing/premium-plans', protected: true);
    if (j['synthetic'] != true ||
        j['channel'] != 'SIMULATOR' ||
        j['plans'] is! List ||
        j['checkoutAvailable'] is! bool)
      throw const ApiInvalidResponse('Expected simulator plans.');
    return j;
  }

  Future<Map<String, dynamic>> eligibility(String childId) async {
    final j = await request(
      'GET',
      'children/$childId/premium-eligibility',
      protected: true,
    );
    if (j['childId'] != childId ||
        j['synthetic'] != true ||
        j['terms'] is! List ||
        j['checkoutAvailable'] is! bool)
      throw const ApiInvalidResponse('Invalid child eligibility.');
    return j;
  }

  Future<Map<String, dynamic>> entitlement(String childId) async {
    final j = await request(
      'GET',
      'children/$childId/premium-entitlement',
      protected: true,
    );
    if (j['childId'] != childId ||
        j['synthetic'] != true ||
        !['NONE', 'ACTIVE', 'EXPIRED'].contains(j['status']))
      throw const ApiInvalidResponse('Invalid child entitlement.');
    return j;
  }

  Future<Map<String, dynamic>> checkout(
    String childId,
    String planId,
    String key,
  ) async => _checkout(
    await request(
      'POST',
      'billing/premium-checkouts',
      body: {
        'idempotencyKey': key,
        'items': [
          {'childId': childId, 'planId': planId},
        ],
      },
      protected: true,
    ),
    childId,
    planId,
  );
  Future<Map<String, dynamic>> checkoutStatus(
    String checkoutId,
    String childId,
    String planId,
  ) async {
    final value = _checkout(
      await request(
        'GET',
        'billing/premium-checkouts/$checkoutId',
        protected: true,
      ),
      childId,
      planId,
    );
    if (value['checkoutId'] != checkoutId)
      throw const ApiInvalidResponse('Checkout identity changed.');
    return value;
  }

  Future<Map<String, dynamic>> settle(
    String checkoutId,
    String childId,
    String planId, {
    required String outcome,
  }) async {
    if (!['SETTLED', 'FAILED'].contains(outcome))
      throw ArgumentError.value(outcome);
    final j = _checkout(
      await request(
        'POST',
        'billing/premium-checkouts/$checkoutId/synthetic-settlement',
        body: {'outcome': outcome},
        protected: true,
      ),
      childId,
      planId,
    );
    if (j['checkoutId'] != checkoutId)
      throw const ApiInvalidResponse('Checkout identity changed.');
    if (j['status'] == 'SETTLED' &&
        object(j['settlement'])['result'] != 'SETTLED')
      throw const ApiInvalidResponse('Settlement is unconfirmed.');
    return j;
  }

  Map<String, dynamic> _checkout(
    Map<String, dynamic> j,
    String childId,
    String planId,
  ) {
    if (j['synthetic'] != true ||
        j['checkoutId'] is! String ||
        ![
          'PENDING_SETTLEMENT',
          'EXPIRED',
          'SETTLED',
          'FAILED',
        ].contains(j['status']) ||
        j['totalMinor'] is! int ||
        j['currency'] is! String ||
        DateTime.tryParse(j['expiresAt']?.toString() ?? '') == null)
      throw const ApiInvalidResponse('Invalid checkout acknowledgment.');
    final lines = j['lines'];
    if (lines is! List ||
        lines.length != 1 ||
        object(lines.single)['childId'] != childId ||
        object(lines.single)['planId'] != planId)
      throw const ApiInvalidResponse('Checkout ownership mismatch.');
    return j;
  }
}
