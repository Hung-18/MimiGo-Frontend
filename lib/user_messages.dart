import 'package:flutter/material.dart';

import 'api_failure.dart';

String friendlyError(ApiFailure e) => switch (e.code) {
  'INVALID_RESET_CODE' => 'Mã chưa đúng, đã hết hạn hoặc đã được sử dụng. Ba mẹ kiểm tra mã mới nhất hoặc yêu cầu mã mới nhé.',
  'PASSWORD_RESET_UNAVAILABLE' =>
    'Khôi phục mật khẩu hiện chưa khả dụng. Ba mẹ vui lòng thử lại sau.',
  'TERMS_DOCUMENT_UNAVAILABLE' || 'NOTICE_DOCUMENT_UNAVAILABLE' => 'Nội dung pháp lý đã được phê duyệt hiện chưa có. Ba mẹ chưa thể đồng ý hoặc tiếp tục bước này. Vui lòng thử lại sau.',
  'TERMS_VERSION_NOT_CURRENT' =>
    'Điều khoản đã thay đổi. Vui lòng tải lại và đọc trước khi lựa chọn.',
  'TERMS_ACCEPTANCE_REQUIRED' =>
    'Ba mẹ cần đọc và đồng ý với điều khoản hiện hành để tiếp tục.',
  'REGISTRATION_RESTRICTED' => 'Đăng ký hiện chỉ mở cho tài khoản được mời. Ba mẹ có thể đăng nhập nếu đã có tài khoản.',
  'EMAIL_ALREADY_REGISTERED' => 'Email này đã được đăng ký. Ba mẹ hãy đăng nhập hoặc xác minh email nếu được yêu cầu.',
  'EMAIL_NOT_VERIFIED' => 'Ba mẹ cần xác minh email trước khi đăng nhập.',
  'EMAIL_DELIVERY_UNAVAILABLE' => 'Chưa gửi được email xác nhận. Vui lòng thử gửi lại sau, không cần tạo thêm tài khoản.',
  'INVALID_EMAIL' => 'Ba mẹ kiểm tra lại địa chỉ email nhé.',
  'INVALID_PASSWORD' =>
    'Mật khẩu chưa đáp ứng yêu cầu. Ba mẹ kiểm tra lại nhé.',
  'INVALID_CREDENTIALS' ||
  'STEP_UP_FAILED' => 'Email hoặc mật khẩu chưa đúng. Ba mẹ kiểm tra lại nhé.',
  'INVALID_OTP' => 'Mã xác nhận chưa đúng hoặc đã hết hạn. Vui lòng dùng mã mới nhất trong email.',
  'INVALID_OTP_FORMAT' => 'Vui lòng nhập đủ 6 chữ số của mã xác nhận.',
  'PARENT_GATE_FAILED' => 'Mã PIN chưa đúng. Ba mẹ thử lại nhé.',
  'INVALID_PIN_FORMAT' => 'Mã PIN cần gồm đúng 6 chữ số.',
  'PIN_CONFIRMATION_MISMATCH' =>
    'Hai mã PIN chưa khớp. Ba mẹ kiểm tra lại nhé.',
  'PIN_TOO_WEAK' => 'Mã PIN này quá dễ đoán. Ba mẹ chọn mã khác nhé.',
  'PARENT_GATE_LOCKED' || 'ACCOUNT_LOGIN_LOCKED' =>
    'Đã thử quá nhiều lần. Ba mẹ vui lòng chờ rồi thử lại.',
  'PARENT_GATE_REQUIRED' => 'Ba mẹ vui lòng xác minh PIN để xem thông tin này.',
  'PARENT_GATE_NOT_ENROLLED' =>
    'Ba mẹ cần thiết lập mã PIN trước khi tiếp tục.',
  'PARENT_GATE_ALREADY_ENROLLED' =>
    'Ba mẹ đã có mã PIN. Có thể đổi hoặc đặt lại bằng mật khẩu.',
  'PARENT_GATE_RECOVERY_REQUIRED' =>
    'Ba mẹ cần đăng nhập lại và dùng mật khẩu để đặt lại PIN.',
  'STEP_UP_REQUIRED' => 'Ba mẹ nhập lại mật khẩu để xác nhận thao tác này nhé.',
  'SCREEN_PROTECTION_UNAVAILABLE' => 'Chưa thể bảo vệ màn hình thông tin riêng tư. Tính năng này tạm thời chưa dùng được.',
  'SECURE_STORAGE_UNAVAILABLE' =>
    'Chưa thể lưu phiên đăng nhập an toàn trên thiết bị. Vui lòng thử lại sau.',
  'LOGOUT_UNCONFIRMED' => 'Đã xóa phiên trên thiết bị, nhưng chưa xác nhận được đăng xuất từ dịch vụ.',
  'SESSION_REVOKED' || 'UNAUTHENTICATED' =>
    'Phiên đăng nhập đã hết hạn. Ba mẹ vui lòng đăng nhập lại.',
  'CHILD_CONTEXT_REQUIRED' || 'CHILD_CONTEXT_FORBIDDEN' => 'Tính năng này chưa dùng được ở chế độ hiện tại. Ba mẹ vui lòng quay lại màn hình phù hợp.',
  'CHILD_NOT_FOUND' || 'CHILD_NOT_ACTIVE' =>
    'Hồ sơ bé hiện chưa dùng được. Ba mẹ hãy kiểm tra lại danh sách hồ sơ.',
  'PARENT_NOT_ACTIVE' =>
    'Tài khoản hiện chưa dùng được. Ba mẹ vui lòng liên hệ hỗ trợ.',
  'ATTEMPT_EXPIRED' ||
  'ATTEMPT_NOT_FOUND' ||
  'NOTICE_CHANGED_REDISPLAY_REQUIRED' => 'Lượt xem xét đã hết hạn hoặc nội dung đã thay đổi. Ba mẹ cần tải lại và lựa chọn từ đầu.',
  'ATTEMPT_ALREADY_CONSUMED' || 'IDEMPOTENCY_CONFLICT' => 'Không thể gửi lại dưới dạng yêu cầu mới. Ba mẹ hãy kiểm tra hồ sơ trước khi tiếp tục.',
  'CORE_PERMISSION_REQUIRED' =>
    'Ba mẹ cần xem xét riêng từng mục đích bắt buộc trước khi tiếp tục.',
  'INVALID_CHILD_PROFILE' ||
  'INVALID_CHILD_ALIAS' ||
  'SYNTHETIC_ALIAS_REQUIRED' ||
  'INVALID_DATE_OF_BIRTH' ||
  'DATE_OF_BIRTH_REQUIRED' ||
  'INVALID_AVATAR' => 'Thông tin hồ sơ chưa hợp lệ. Ba mẹ kiểm tra tên gọi, ngày sinh và ảnh đại diện nhé.',
  'CHILD_PROFILE_VERSION_CONFLICT' =>
    'Hồ sơ đã thay đổi. Ba mẹ tải lại và xem xét trước khi lưu.',
  'SESSION_INCOMPLETE' =>
    'Bé cần có câu trả lời được lưu cho mỗi câu hỏi trước khi hoàn thành.',
  'SESSION_NOT_ACTIVE' =>
    'Lượt học này đã kết thúc. Hãy tải lại để xem kết quả đã lưu.',
  'PREMIUM_ENTITLEMENT_REQUIRED' => 'Bài học này hiện chưa nằm trong quyền học của bé. Ba mẹ kiểm tra gói học nhé.',
  'LESSON_NO_LONGER_AVAILABLE' ||
  'LESSON_NOT_AVAILABLE' ||
  'SESSION_NOT_FOUND' =>
    'Bài học hoặc lượt học hiện chưa dùng được. Bé chọn bài khác nhé.',
  'CHECKOUT_QUOTE_EXPIRED' =>
    'Báo giá đã hết hạn. Ba mẹ kiểm tra trạng thái và chọn lại gói nhé.',
  'CHECKOUT_ALREADY_FINALIZED' =>
    'Giao dịch này đã có kết quả. Ba mẹ kiểm tra lại trạng thái nhé.',
  'PREMIUM_AGE_NOT_ELIGIBLE' || 'PREMIUM_HORIZON_EXCEEDED' =>
    'Hiện chưa thể mua thời hạn này cho bé. Ba mẹ xem các lựa chọn khác nhé.',
  'CONNECTIVITY' || 'TIMEOUT' || 'REQUEST_CANCELLED' =>
    'Chưa kết nối được với MimiGo. Vui lòng kiểm tra mạng và thử lại.',
  'CLOUD_SURFACE_LOCKED' ||
  'ROUTE_NOT_FOUND' ||
  'MEDIA_DISABLED' ||
  'CHILD_PROFILE_WRITE_CONTRACT_UNAVAILABLE' =>
    'Tính năng này hiện chưa khả dụng. Vui lòng thử lại sau.',
  _ when e.status == 401 =>
    'Phiên đăng nhập đã hết hạn. Ba mẹ vui lòng đăng nhập lại.',
  _ when e.status == 403 => 'Hiện chưa được phép thực hiện thao tác này. Ba mẹ vui lòng kiểm tra lại quyền truy cập.',
  _ when e.status == 404 =>
    'Nội dung này hiện chưa khả dụng. Vui lòng quay lại và tải lại.',
  _ when e.status == 429 =>
    'Đã thử quá nhiều lần. Vui lòng chờ một chút rồi thử lại.',
  _ when (e.status ?? 0) >= 500 =>
    'MimiGo đang tạm gián đoạn. Vui lòng thử lại sau.',
  _ => 'Chưa xác nhận được thao tác. Vui lòng kiểm tra thông tin và thử lại.',
};

class UserError extends StatelessWidget {
  const UserError(this.failure, {super.key, this.messageKey, this.message});
  final ApiFailure? failure;
  final Key? messageKey;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final e = failure;
    if (e == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              message ?? friendlyError(e),
              key: messageKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        TechnicalDetails(
          key: ValueKey((e.code, e.status, e.requestId)),
          children: [
            SelectableText('Mã hỗ trợ: ${e.code ?? 'REQUEST_FAILED'}'),
            if (e.status != null) Text('Trạng thái: ${e.status}'),
            if (e.requestId != null)
              SelectableText('Mã yêu cầu: ${e.requestId}'),
          ],
        ),
      ],
    );
  }
}

class TechnicalDetails extends StatefulWidget {
  const TechnicalDetails({super.key, required this.children});
  final List<Widget> children;
  @override
  State<TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<TechnicalDetails> {
  // Isolate expansion state from the surrounding scroll view's offset bucket.
  final storageKey = PageStorageKey<Object>(Object());
  final detailBucket = PageStorageBucket();
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: storageKey,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: const Text('Chi tiết kỹ thuật', style: TextStyle(fontSize: 13)),
    children: [
      PageStorage(
        bucket: detailBucket,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children,
        ),
      ),
    ],
  );
}

String viState(String? value) => switch (value) {
  'ACTIVE' => 'Đang hoạt động',
  'INACTIVE' => 'Tạm ngừng',
  'IN_PROGRESS' => 'Đang học',
  'COMPLETED' => 'Đã hoàn thành',
  'ABANDONED' => 'Đã kết thúc',
  'NONE' => 'Chưa có gói học',
  'EXPIRED' => 'Đã hết hạn',
  'CURRENT' => 'Đang áp dụng',
  'FUTURE' => 'Chưa bắt đầu',
  'PAST' => 'Đã kết thúc',
  'PENDING_SETTLEMENT' => 'Đang chờ kết quả',
  'SETTLED' => 'Đã xác nhận',
  'FAILED' => 'Không thành công',
  'READY' => 'Có thể bắt đầu',
  'GRANTED' => 'Đã đồng ý',
  'WITHDRAWN' => 'Đã thu hồi',
  'DENIED' => 'Không được phép',
  'OPEN' => 'Đang xem xét',
  'ATTEMPT_ALREADY_CONSUMED' => 'Đã tạo hồ sơ',
  'TERMS_ACCEPTANCE_REQUIRED' => 'Cần xem điều khoản',
  'ATTEMPT_EXPIRED' => 'Đã hết hạn',
  'NOT_ENROLLED' => 'Chưa thiết lập',
  'ENROLLED' => 'Đã thiết lập',
  'LOCKED' => 'Tạm khóa',
  'RECOVERY_REQUIRED' => 'Cần đặt lại',
  'FREE' => 'Miễn phí',
  'CORE' => 'Premium Core',
  _ => 'Chưa có thông tin',
};
String viPurpose(String code) => switch (code) {
  'CHILD_PROFILE_AGE' => 'Hồ sơ và độ tuổi của bé',
  'LEARNING_PROGRESS' => 'Ghi nhận hoạt động học của bé',
  _ => 'Mục đích sử dụng thông tin',
};
String viDate(DateTime? date) {
  if (date == null) return 'Chưa có thông tin';
  final d = date.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)}/${d.year}';
}

String viTime(DateTime? date) {
  if (date == null) return 'Chưa có thông tin';
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} · ${viDate(d)}';
}

String viInstant(Object? value) =>
    value is String ? viTime(DateTime.tryParse(value)) : 'Chưa có thông tin';
