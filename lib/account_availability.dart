import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'api_failure.dart';

/// Reviewed content bound to the version/hash of its enclosing server snapshot.
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

  /// Absent/unapproved content cannot grant agreement. A supplied document must
  /// match the enclosing version and the exact UTF-8/CRLF-normalized body hash.
  static ApprovedLegalDocument? fromSnapshot(
    Map<String, dynamic> snapshot, {
    required String versionId,
    required String contentHash,
  }) {
    final approval = snapshot['isApprovedForRealUsers'];
    if (approval != null && approval is! bool) {
      throw const ApiInvalidResponse('Invalid legal approval flag.');
    }
    final raw = snapshot['document'];
    if (raw == null) return null;
    if (approval != true || raw is! Map<String, dynamic>) {
      throw const ApiInvalidResponse('Invalid approved legal document.');
    }
    for (final key in ['title', 'language', 'format', 'body', 'contentHash']) {
      if (raw[key] is! String || (raw[key] as String).trim().isEmpty) {
        throw const ApiInvalidResponse('Incomplete approved legal document.');
      }
    }
    final body = raw['body'] as String;
    if (raw['format'] != 'text/markdown' ||
        !RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$')
            .hasMatch(raw['language'] as String) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash) ||
        raw['contentHash'] != contentHash ||
        sha256.convert(utf8.encode(body.replaceAll('\r\n', '\n'))).toString() !=
            contentHash) {
      throw const ApiInvalidResponse(
        'Legal document does not match its snapshot.',
      );
    }
    return ApprovedLegalDocument(
      versionId: versionId,
      contentHash: contentHash,
      title: raw['title'] as String,
      body: body,
      approved: true,
    );
  }

  bool matches(String id, String? hash) =>
      approved &&
      versionId == id &&
      hash != null &&
      contentHash == hash &&
      title.trim().isNotEmpty &&
      body.trim().isNotEmpty;
}

/// Legal availability and the fallback for clients without a recovery adapter.
/// The normal live client uses PasswordResetApi and server availability.
abstract final class AccountAvailability {
  static const passwordRecoveryMessage =
      'Khôi phục mật khẩu hiện chưa khả dụng. Ba mẹ vui lòng liên hệ hỗ trợ để được hướng dẫn.';
  static const termsUnavailable =
      'Điều khoản đã được phê duyệt hiện chưa có. Ba mẹ chưa thể đăng ký hoặc đồng ý điều khoản lúc này. Vui lòng thử lại sau.';
  static bool isPlaceholder(String code) => RegExp(
    r'(^|[_-])(MOCK|SYNTHETIC|SYN|DEMO|TEST)([_-]|$)',
    caseSensitive: false,
  ).hasMatch(code);
}
