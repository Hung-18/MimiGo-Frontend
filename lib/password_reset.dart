import 'dart:async';

import 'package:flutter/material.dart';

import 'api_failure.dart';
import 'user_messages.dart';
import 'po/po_design.dart';
import 'po/code_input.dart';

abstract interface class PasswordResetApi {
  Future<int> requestPasswordReset(String email);
  Future<void> confirmPasswordReset(String email, String otp, String password);
}

/// Public recovery flow. ACCEPTED deliberately does not assert email delivery.
/// Passwords/codes are held only by this route and never logged or persisted.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    required this.api,
    this.email = '',
    this.now = DateTime.now,
  });
  final PasswordResetApi api;
  final String email;
  final DateTime Function() now;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.email);
  final otp = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool accepted = false, busy = false;
  ApiFailure? error;
  DateTime? retryAt;
  Timer? timer;
  String? notice;
  int get seconds => retryAt == null
      ? 0
      : (retryAt!.difference(widget.now()).inMilliseconds / 1000).ceil().clamp(
          0,
          86400,
        );
  void cooldown(int value) {
    retryAt = widget.now().add(Duration(seconds: value));
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {});
      if (seconds == 0) t.cancel();
    });
  }

  Future<void> run(bool confirm) async {
    if (busy ||
        (!confirm && seconds > 0) ||
        (error?.status == 429 && seconds > 0))
      return;
    if (!confirm &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      form.currentState!.validate();
      return;
    }
    if (confirm && !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (confirm) {
        await widget.api.confirmPasswordReset(
          email.text.trim(),
          otp.text,
          password.text,
        );
        if (!mounted) return;
        password.clear();
        confirmation.clear();
        otp.clear();
        Navigator.pop(context, true);
      } else {
        final wait = await widget.api.requestPasswordReset(email.text.trim());
        if (!mounted) return;
        setState(() {
          accepted = true;
          otp.clear();
          notice = 'Yêu cầu đã được tiếp nhận. Nếu tài khoản đủ điều kiện, mã xác nhận sẽ được gửi đến email. Ba mẹ kiểm tra cả thư rác nhé.';
          cooldown(wait);
        });
      }
    } on ApiFailure catch (e) {
      if (mounted)
        setState(() {
          error = e;
          if ((e.retryAfterSeconds ?? 0) > 0) cooldown(e.retryAfterSeconds!);
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    otp.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      body: SafeArea(
        child: StorybookForm(
          title: 'Đặt lại mật khẩu',
          back: busy ? null : () => Navigator.pop(context),
          mood: busy
              ? MimiMood.thinking
              : accepted
              ? MimiMood.guide
              : MimiMood.greeting,
          children: [
            const Text('Ba mẹ dùng email đã đăng ký để khôi phục mật khẩu.'),
            const SizedBox(height: 16),
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('resetEmail'),
                    controller: email,
                    enabled: !busy && !accepted,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email phụ huynh',
                    ),
                    validator: (v) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Vui lòng nhập email hợp lệ.',
                  ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(notice!, key: const Key('resetAccepted')),
                    ),
                  if (accepted) ...[
                    const SizedBox(height: 16),
                    SixDigitCodeField(
                      fieldKey: const Key('resetCode'),
                      controller: otp,
                      enabled: !busy,
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                          ? null
                          : 'Vui lòng nhập đủ 6 chữ số.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('resetPassword'),
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới (10–128 ký tự)',
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) >= 10 && (v?.length ?? 0) <= 128
                          ? null
                          : 'Mật khẩu cần từ 10 đến 128 ký tự.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('resetConfirm'),
                      controller: confirmation,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu mới',
                      ),
                      validator: (v) =>
                          v == password.text && (v?.isNotEmpty ?? false)
                          ? null
                          : 'Hai mật khẩu chưa khớp.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Đổi mật khẩu thành công sẽ đăng xuất tài khoản trên mọi thiết bị. Mã PIN được giữ nguyên.',
                    ),
                  ],
                  UserError(error),
                  if (seconds > 0)
                    Text(
                      'Có thể yêu cầu mã mới sau $seconds giây.',
                      key: const Key('resetCooldown'),
                    ),
                  if (busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang chờ xác nhận',
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 64,
                    child: FilledButton(
                      key: const Key('resetSubmit'),
                      onPressed:
                          busy ||
                              (!accepted && seconds > 0) ||
                              (error?.status == 429 && seconds > 0)
                          ? null
                          : () => run(accepted),
                      child: Text(
                        busy
                            ? 'Đang chờ xác nhận…'
                            : accepted
                            ? 'Xác nhận mật khẩu mới'
                            : 'Yêu cầu mã xác nhận',
                      ),
                    ),
                  ),
                  if (accepted) ...[
                    TextButton(
                      key: const Key('resetResend'),
                      onPressed: busy || seconds > 0 ? null : () => run(false),
                      child: const Text('Yêu cầu mã mới'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              accepted = false;
                              otp.clear();
                              password.clear();
                              confirmation.clear();
                              notice = null;
                              error = null;
                            }),
                      child: const Text('Dùng email khác'),
                    ),
                  ],
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Về đăng nhập'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
