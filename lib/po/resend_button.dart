import 'dart:async';

import 'package:flutter/material.dart';

import '../api_failure.dart';
import 'mobile_services.dart';
import '../user_messages.dart';

class ResendButton extends StatefulWidget {
  const ResendButton({super.key, required this.api, required this.email});
  final MobileCapabilities api;
  final String email;
  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  DateTime? next;
  Timer? timer;
  bool busy = false;
  String? notice;
  ApiFailure? failure;
  int get seconds => next == null
      ? 0
      : (next!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
          0,
          86400,
        );
  void wait(int count) {
    next = DateTime.now().add(Duration(seconds: count));
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

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> resend() async {
    if (busy || seconds > 0) return;
    setState(() {
      busy = true;
      notice = null;
      failure = null;
    });
    try {
      final result = await widget.api.resendVerification(widget.email);
      if (mounted)
        setState(() {
          wait(result.cooldown);
          notice = 'Nếu email đủ điều kiện, mã mới sẽ được gửi. Ba mẹ kiểm tra cả thư rác nhé.';
        });
    } on ApiFailure catch (e) {
      if (mounted)
        setState(() {
          failure = e;
          if (e.retryAfterSeconds != null) wait(e.retryAfterSeconds!);
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton(
        onPressed: busy || seconds > 0 ? null : resend,
        child: Text(
          busy
              ? 'Đang yêu cầu…'
              : seconds > 0
              ? 'Gửi lại sau ${seconds}s'
              : 'Gửi lại mã xác nhận',
        ),
      ),
      if (notice != null)
        Text(notice!, style: Theme.of(context).textTheme.bodySmall),
      if (failure != null) UserError(failure),
    ],
  );
}
