import 'package:flutter/material.dart';

import '../api_failure.dart';
import 'mobile_services.dart';
import 'po_design.dart';
import '../user_messages.dart';

/// Embedded in the existing screen-protected Parent Area. Never a Child route.
class PremiumPanel extends StatefulWidget {
  const PremiumPanel({
    super.key,
    required this.service,
    required this.childId,
    this.allowSimulator = false,
  });
  final PremiumService service;
  final String childId;

  /// Debug/test lanes only: a simulator offer (synthetic money) is never shown to real parents.
  final bool allowSimulator;
  @override
  State<PremiumPanel> createState() => _PremiumPanelState();
}

class _PremiumPanelState extends State<PremiumPanel> {
  List<PremiumPlan> plans = [];
  Set<String> allowed = {};
  PremiumPlan? selected;
  Map<String, dynamic>? entitlement, checkout;
  String? key, outcome;
  ApiFailure? error;
  bool busy = false, loaded = false, available = false;
  bool simulated = false;
  Map<String, dynamic>? transfer, payment;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } catch (_) {
      if (mounted)
        setState(
          () => error = const ApiInvalidResponse('Invalid billing response.'),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    // Clear stale rights before any read; failed reads never retain ACTIVE.
    setState(() {
      entitlement = null;
      plans = [];
      allowed = {};
      loaded = false;
      available = false;
    });
    final p = await widget.service.plans();
    final e = await widget.service.eligibility(widget.childId);
    final rights = await widget.service.entitlement(widget.childId);
    final parsed = (p['plans'] as List)
        .map((v) => PremiumPlan.fromJson(object(v)))
        .toList();
    final eligible = (e['terms'] as List)
        .map(object)
        .where((v) => v['allowed'] == true)
        .map((v) => v['planId'] as String)
        .toSet();
    if (mounted)
      setState(() {
        plans = parsed;
        allowed = eligible;
        entitlement = rights;
        available =
            p['checkoutAvailable'] == true && e['checkoutAvailable'] == true;
        simulated = p['synthetic'] == true;
        loaded = true;
      });
  });
  Future<void> create() => run(() async {
    key ??= mobileRequestKey();
    final j = await widget.service.checkout(widget.childId, selected!.id, key!);
    if (mounted) setState(() => checkout = j);
  });
  Future<void> settle(String choice) => run(() async {
    outcome ??=
        choice; // Unknown outcome retries are locked to the same command.
    final j = await widget.service.settle(
      checkout!['checkoutId'],
      widget.childId,
      selected!.id,
      outcome: outcome!,
    );
    if (mounted)
      setState(() {
        checkout = j;
        entitlement = null;
      });
    final rights = await widget.service.entitlement(widget.childId);
    if (mounted) setState(() => entitlement = rights);
  });
  Future<void> readCheckout() => run(() async {
    final current = await widget.service.checkoutStatus(
      checkout!['checkoutId'],
      widget.childId,
      selected!.id,
    );
    if (mounted)
      setState(() {
        checkout = current;
        entitlement = null;
      });
    final rights = await widget.service.entitlement(widget.childId);
    if (mounted) setState(() => entitlement = rights);
  });
  Future<void> createTransfer() => run(() async {
    final j = await widget.service.createTransfer(widget.childId, selected!.id);
    if (mounted)
      setState(() {
        transfer = j;
        payment = null;
      });
  });
  Future<void> checkTransfer() => run(() async {
    final j = await widget.service.transferStatus(
      widget.childId,
      transfer!['intentId'] as String,
    );
    if (mounted) setState(() => payment = j);
    if (j['status'] == 'SETTLED') {
      final rights = await widget.service.entitlement(widget.childId);
      if (mounted) setState(() => entitlement = rights);
    }
  });
  void newTransfer() {
    setState(() {
      transfer = null;
      payment = null;
      selected = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    // A simulator offer is test money: never show it outside debug/test lanes.
    if (loaded && simulated && !widget.allowSimulator) {
      return const SizedBox.shrink();
    }
    if (loaded && !simulated) return _realBuild();
    return _simulatorBuild();
  }

  String _money(int amount, String currency) {
    final s = amount.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return currency == 'VND' ? '$b đ' : '$b $currency';
  }

  Widget _realBuild() {
    final status = payment?['status'] as String?;
    final paid = status == 'SETTLED';
    final quoteEnd = DateTime.tryParse(
      payment?['quoteExpiresAt']?.toString() ?? '',
    );
    final expired =
        !paid && quoteEnd != null && quoteEnd.isBefore(DateTime.now().toUtc());
    final unknown =
        status != null && !['AWAITING_TRANSFER', 'SETTLED'].contains(status);
    return PoCard(
      color: PoPalette.cream,
      child: Column(
        key: const Key('premiumReal'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PoHeading(
            'Gói học trả phí',
            subtitle: 'Dành cho ba mẹ · trả bằng chuyển khoản',
          ),
          const Text(
            'Gói trả trước, không tự gia hạn, áp dụng riêng cho từng bé. '
            'Thanh toán chỉ thực hiện tại khu vực của ba mẹ, không bao giờ trong khu vực của bé.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) UserError(error),
          if (entitlement != null)
            Text(
              'Gói học: ${viState(entitlement!['status'] as String?)}\nCó hiệu lực đến: ${viInstant(entitlement!['expiresAt'])}',
            ),
          if (transfer == null) ...[
            for (final plan in plans)
              RadioListTile<String>(
                // ignore: deprecated_member_use
                groupValue: selected?.id,
                value: plan.id,
                // ignore: deprecated_member_use
                onChanged: busy || !allowed.contains(plan.id)
                    ? null
                    : (_) => setState(() => selected = plan),
                title: Text(
                  '${plan.months} tháng · ${_money(plan.amount, plan.currency)}',
                ),
                subtitle: const Text(
                  'Mở nội dung học trả phí của bé trong thời hạn gói',
                ),
              ),
            if (loaded && plans.isEmpty) const Text('Chưa có gói khả dụng.'),
            PoAction(
              'Tạo hướng dẫn chuyển khoản',
              onPressed: !busy && available && selected != null
                  ? createTransfer
                  : null,
            ),
          ] else ...[
            Text(
              'Số tiền: ${_money(transfer!['amountMinor'] as int, transfer!['currency'] as String)}',
              key: const Key('transferAmount'),
            ),
            Text('Ngân hàng: ${transfer!['bankCode']}'),
            SelectableText('Số tài khoản: ${transfer!['accountNumber']}'),
            SelectableText(
              'Nội dung chuyển khoản: ${transfer!['transferContent']}',
              key: const Key('transferContent'),
            ),
            if ((transfer!['qrImageUrl'] as String?)?.startsWith('https://') ==
                true)
              Image.network(
                transfer!['qrImageUrl'] as String,
                height: 200,
                errorBuilder: (_, _, _) => const Text(
                  'Không tải được mã QR; hãy chuyển khoản theo thông tin ở trên.',
                ),
              ),
            const Text(
              'Hãy chuyển đúng số tiền và đúng nội dung. Gói chỉ được mở sau khi khoản thanh toán được xác minh; màn hình này không phải biên lai.',
            ),
            PoAction(
              'Kiểm tra trạng thái thanh toán',
              secondary: true,
              icon: Icons.refresh,
              onPressed: busy ? null : checkTransfer,
            ),
            if (status == 'AWAITING_TRANSFER' && !expired)
              const Text(
                'Đang chờ chuyển khoản. Có thể mất vài phút sau khi chuyển; hãy bấm kiểm tra lại.',
                key: Key('transferPending'),
              ),
            if (paid)
              const Text(
                'Đã nhận thanh toán. Gói học đã được xác nhận cho bé.',
                key: Key('transferPaid'),
              ),
            if (expired)
              const Text(
                'Hướng dẫn này đã hết hạn. Nếu bạn chưa chuyển, hãy tạo hướng dẫn mới; nếu đã chuyển, hãy liên hệ contact@mimigo.id.vn.',
                key: Key('transferExpired'),
              ),
            if (unknown)
              const Text(
                'Giao dịch chưa thành công. Bạn có thể tạo hướng dẫn mới hoặc liên hệ contact@mimigo.id.vn.',
                key: Key('transferFailed'),
              ),
            if (paid || expired || unknown)
              TextButton(
                onPressed: busy ? null : newTransfer,
                child: Text(paid ? 'Xong' : 'Tạo hướng dẫn chuyển khoản mới'),
              ),
          ],
          if (transfer == null)
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Tải lại gói và quyền'),
            ),
        ],
      ),
    );
  }

  Widget _simulatorBuild() => PoCard(
    color: PoPalette.cream,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PoHeading(
          'Premium Core',
          subtitle: 'Thanh toán thử nghiệm · không thu tiền',
        ),
        const Text(
          'Giá hiển thị chỉ dành cho thử nghiệm. Gói trả trước, không tự gia hạn, áp dụng riêng cho từng bé và không tự bao gồm chương trình đặc biệt.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) UserError(error),
        if (entitlement != null)
          Text(
            'Gói học: ${viState(entitlement!['status'] as String?)}\nCó hiệu lực đến: ${viInstant(entitlement!['expiresAt'])}',
          ),
        if (checkout == null) ...[
          for (final plan in plans)
            RadioListTile<String>(
              // ignore: deprecated_member_use
              groupValue: selected?.id,
              value: plan.id,
              // ignore: deprecated_member_use
              onChanged: busy || key != null || !allowed.contains(plan.id)
                  ? null
                  : (_) => setState(() => selected = plan),
              title: Text(
                '${plan.months} tháng · ${plan.amount} ${plan.currency}',
              ),
              subtitle: const Text('Giá thử nghiệm, chưa áp dụng thương mại'),
            ),
          if (loaded && plans.isEmpty) const Text('Chưa có gói khả dụng.'),
          PoAction(
            key == null
                ? 'Xem báo giá thử nghiệm'
                : 'Thử lại báo giá giữ nguyên',
            onPressed: !busy && available && selected != null ? create : null,
          ),
        ] else ...[
          Text(
            'Báo giá: ${checkout!['totalMinor']} ${checkout!['currency']}\nTình trạng: ${viState(checkout!['status'] as String?)}\nCó hiệu lực đến: ${viInstant(checkout!['expiresAt'])}',
          ),
          PoAction(
            'Kiểm tra trạng thái giao dịch',
            secondary: true,
            icon: Icons.refresh,
            onPressed: busy ? null : readCheckout,
          ),
          if (checkout!['status'] == 'PENDING_SETTLEMENT') ...[
            PoAction(
              outcome == null
                  ? 'Thử xác nhận thanh toán'
                  : 'Thử lại: ${viState(outcome)}',
              onPressed: busy ? null : () => settle(outcome ?? 'SETTLED'),
            ),
            if (outcome == null)
              PoAction(
                'Thử tình huống không thành công',
                secondary: true,
                onPressed: busy ? null : () => settle('FAILED'),
              ),
          ],
          if (checkout!['status'] == 'SETTLED')
            const Text(
              'Đã xác nhận kết quả thử nghiệm. Đây không phải biên lai thanh toán thật. Bài học được mở theo quyền do dịch vụ xác nhận.',
            ),
          if (checkout!['status'] != 'PENDING_SETTLEMENT')
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        checkout = null;
                        selected = null;
                        key = null;
                        outcome = null;
                      });
                      load();
                    },
              child: const Text('Chọn gói và tạo báo giá mới'),
            ),
        ],
        if (key == null ||
            checkout != null && checkout!['status'] != 'PENDING_SETTLEMENT')
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Tải lại gói và quyền'),
          ),
      ],
    ),
  );
}
