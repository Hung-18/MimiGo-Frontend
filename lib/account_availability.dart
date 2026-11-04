/// Presentation seam for a future verified legal-content adapter. These are
/// not invented Backend JSON fields and are never parsed from current metadata.
class ApprovedLegalDocument {
  const ApprovedLegalDocument({
    required this.versionId,
    required this.contentHash,
    required this.title,
    required this.body,
    required this.approved,
  });
  final String versionId, contentHash, title, body;
  final bool approved;
  bool matches(String id, String? hash) =>
      approved &&
      versionId == id &&
      hash != null &&
      contentHash == hash &&
      title.trim().isNotEmpty &&
      body.trim().isNotEmpty;
}

/// No password-reset route has been approved for this client. A forthcoming
/// implementation must provide the verified contract before this can change.
abstract final class AccountAvailability {
  static const passwordRecoveryAvailable = false;
  static const passwordRecoveryMessage =
      'Khôi phục mật khẩu hiện chưa khả dụng. Ba mẹ vui lòng liên hệ hỗ trợ để được hướng dẫn.';
  static const termsUnavailable =
      'Điều khoản đã được phê duyệt hiện chưa có. Ba mẹ chưa thể đăng ký hoặc đồng ý điều khoản lúc này. Vui lòng thử lại sau.';
  static bool isPlaceholder(String code) => RegExp(
    r'(^|[_-])(MOCK|SYNTHETIC|SYN|DEMO|TEST)([_-]|$)',
    caseSensitive: false,
  ).hasMatch(code);
}
