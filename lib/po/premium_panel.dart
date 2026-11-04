import 'package:flutter/material.dart';

import '../api_failure.dart';
import 'mobile_services.dart';
import 'po_design.dart';
import '../user_messages.dart';

/// Embedded in the existing screen-protected Parent Area. Never a Child route.
class PremiumPanel extends StatefulWidget {
  const PremiumPanel({super.key, required this.service, required this.childId});
  final PremiumService service;
  final String childId;
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
  @override
  Widget build(BuildContext context) => PoCard(
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
