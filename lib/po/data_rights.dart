import 'package:flutter/material.dart';

import '../api_failure.dart';
import '../user_messages.dart' show viDate;
import 'mobile_services.dart';
import 'po_design.dart';

/// Parent privacy-rights requests: POST/GET/DELETE /parents/me/privacy-requests.
/// The server only records a request; the MimiGo team erases data by hand.
class RightsRequest {
  const RightsRequest({
    required this.id,
    required this.kind,
    required this.state,
    required this.dueAt,
    this.childId,
  });
  factory RightsRequest.fromJson(Map<String, dynamic> j) {
    final id = j['requestId'], state = j['state'], due = j['dueAt'];
    if (id is! String || id.isEmpty || state is! String || due is! String) {
      throw const ApiInvalidResponse('Invalid privacy request.');
    }
    final dueAt = DateTime.tryParse(due);
    if (dueAt == null)
      throw const ApiInvalidResponse('Invalid privacy request.');
    return RightsRequest(
      id: id,
      kind: j['kind'] is String ? j['kind'] as String : '',
      state: state,
      dueAt: dueAt,
      childId: j['childId'] is String ? j['childId'] as String : null,
    );
  }
  final String id, kind, state;
  final String? childId;
  final DateTime dueAt;
  bool get cancellable => state == 'RECEIVED';
}

class DataRightsService {
  DataRightsService(this.request);
  final MobileRequest request;

  Future<List<RightsRequest>> list() async {
    final x = await request(
      'GET',
      'parents/me/privacy-requests',
      protected: true,
    );
    final items = x['items'];
    if (items is! List) throw const ApiInvalidResponse('Invalid privacy list.');
    return [
      for (final i in items)
        if (i is Map<String, dynamic>)
          RightsRequest.fromJson(i)
        else
          throw const ApiInvalidResponse('Invalid privacy list.'),
    ];
  }

  /// Returns the recorded request. Reuse [key] when retrying the same attempt.
  Future<RightsRequest> open(String kind, String? childId, String key) async =>
      RightsRequest.fromJson(
        await request(
          'POST',
          'parents/me/privacy-requests',
          body: {'kind': kind, 'childId': ?childId},
          headers: {'Idempotency-Key': key},
          protected: true,
        ),
      );

  Future<void> cancel(String requestId) async {
    await request(
      'DELETE',
      'parents/me/privacy-requests/$requestId',
      protected: true,
    );
  }
}

String rightsErrorText(ApiFailure e) {
  switch (e.code) {
    case 'RIGHTS_REQUEST_ALREADY_OPEN':
      return 'Ba mẹ đã có một yêu cầu cùng loại đang chờ xử lý.';
    case 'RIGHTS_REQUEST_NOT_CANCELLABLE':
      return 'Yêu cầu này đã được xử lý nên không hủy được nữa.';
    case 'RIGHTS_REQUEST_NOT_FOUND':
      return 'Không tìm thấy yêu cầu này. Ba mẹ tải lại danh sách nhé.';
    case 'PARENT_GATE_REQUIRED':
      return 'Ba mẹ vui lòng nhập lại mã PIN để tiếp tục.';
  }
  if (e.status == 403) return 'Ba mẹ vui lòng nhập lại mã PIN để tiếp tục.';
  if (e.status == 409)
    return 'Ba mẹ đã có một yêu cầu cùng loại đang chờ xử lý.';
  return 'Chưa gửi được. Vui lòng thử lại hoặc viết email tới contact@mimigo.id.vn.';
}

String rightsStateLabel(String s) => switch (s) {
  'RECEIVED' => 'Đã nhận',
  'IN_REVIEW' => 'Đang xem xét',
  'FULFILLED' => 'Đã hoàn tất',
  'REJECTED' => 'Bị từ chối',
  'CANCELLED' || 'CANCELED' => 'Đã hủy',
  _ => 'Đang xử lý',
};

class DataRightsPanel extends StatefulWidget {
  const DataRightsPanel({
    super.key,
    required this.service,
    required this.children,
  });
  final DataRightsService service;

  /// (childId, alias) pairs the parent may pick from.
  final List<({String id, String alias})> children;
  @override
  State<DataRightsPanel> createState() => _DataRightsPanelState();
}

class _DataRightsPanelState extends State<DataRightsPanel> {
  List<RightsRequest>? requests;
  ApiFailure? error;
  String? notice;
  bool busy = false;
  // One idempotency key per attempt; kept after a failure so a retry cannot duplicate.
  String? attemptKey, attemptKind, attemptChild;

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
      notice = null;
    });
    try {
      await work();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = const ApiInvalidResponse('Invalid privacy response.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final v = await widget.service.list();
    if (mounted) setState(() => requests = v);
  });

  Future<void> submit(String kind, String? childId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gửi yêu cầu xóa dữ liệu?'),
        content: const Text(
          'Hành động này không thể hoàn tác sau khi chúng tôi đã xóa. '
          'Ba mẹ vẫn có thể hủy yêu cầu trước khi chúng tôi bắt đầu xử lý.',
        ),
        actions: [
          TextButton(
            key: const Key('rightsConfirmCancel'),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            key: const Key('rightsConfirmSend'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (attemptKey == null || attemptKind != kind || attemptChild != childId) {
      attemptKey = mobileRequestKey();
      attemptKind = kind;
      attemptChild = childId;
    }
    await run(() async {
      final r = await widget.service.open(kind, childId, attemptKey!);
      attemptKey = attemptKind = attemptChild = null;
      final all = await widget.service.list();
      if (mounted) {
        setState(() {
          requests = all;
          notice =
              'Đã ghi nhận yêu cầu. Chúng tôi sẽ xử lý trước ngày ${viDate(r.dueAt)} và báo kết quả qua email đã đăng ký.';
        });
      }
    });
  }

  Future<void> cancel(RightsRequest r) => run(() async {
    await widget.service.cancel(r.id);
    final all = await widget.service.list();
    if (mounted) setState(() => requests = all);
  });

  String _childName(String? id) {
    for (final c in widget.children) {
      if (c.id == id) return c.alias;
    }
    return 'bé';
  }

  String _kindLabel(RightsRequest r) => r.kind == 'ACCOUNT_CLOSURE'
      ? 'Đóng tài khoản ba mẹ'
      : 'Xóa dữ liệu của ${_childName(r.childId)}';

  @override
  Widget build(BuildContext context) => PoCard(
    color: PoPalette.lavender,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PoHeading('Xóa dữ liệu và đóng tài khoản'),
        const Text(
          'Khi yêu cầu được xác minh, chúng tôi sẽ xóa hồ sơ, tiến trình học và dữ liệu xem video của bé trong vòng 30 ngày. Việc xóa do đội MimiGo thực hiện thủ công.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Một số bản ghi sẽ được giữ lại để chứng minh việc đồng ý và xử lý yêu cầu: lịch sử đồng ý, khai báo giám hộ, yêu cầu quyền dữ liệu và nhật ký bảo mật.',
        ),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(semanticsLabel: 'Đang xử lý'),
        for (final c in widget.children)
          OutlinedButton(
            key: Key('rightsDeleteChild-${c.id}'),
            onPressed: busy ? null : () => submit('DELETION', c.id),
            child: Text('Xóa dữ liệu của ${c.alias}'),
          ),
        OutlinedButton(
          key: const Key('rightsCloseAccount'),
          onPressed: busy ? null : () => submit('ACCOUNT_CLOSURE', null),
          child: const Text(
            'Đóng tài khoản ba mẹ (xóa dữ liệu của tất cả các bé)',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(rightsErrorText(error!), key: const Key('rightsError')),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(notice!, key: const Key('rightsNotice')),
          ),
        if (requests != null && requests!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Yêu cầu của ba mẹ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final r in requests!)
            ListTile(
              key: Key('rightsItem-${r.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(_kindLabel(r)),
              subtitle: Text(
                '${rightsStateLabel(r.state)} · xử lý trước ${viDate(r.dueAt)}',
              ),
              trailing: r.cancellable
                  ? TextButton(
                      key: Key('rightsCancel-${r.id}'),
                      onPressed: busy ? null : () => cancel(r),
                      child: const Text('Hủy yêu cầu'),
                    )
                  : null,
            ),
        ],
        TextButton(
          key: const Key('rightsReload'),
          onPressed: busy ? null : load,
          child: const Text('Tải lại danh sách'),
        ),
        const Text('Cần hỗ trợ? contact@mimigo.id.vn'),
      ],
    ),
  );
}
