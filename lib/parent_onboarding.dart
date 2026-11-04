import 'user_messages.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi;
import 'api_failure.dart';

/// Keeps verified-email success separate from a later login/network failure.
/// Resend/countdown has its own view; verification never persists credentials.
class EmailVerificationState extends ChangeNotifier {
  EmailVerificationState(this.api, this.email);
  final MimiGoApi api;
  final String email;
  bool busy = false, verified = false;
  ApiFailure? error;
  DateTime? retryAt;
  Timer? _retryTimer;
  int get retrySeconds => retryAt == null
      ? 0
      : (retryAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 86400);
  int _generation = 0;

  Future<bool> submit(String code, Future<void> Function() authenticate) async {
    if (busy || retrySeconds > 0) return false;
    if (!verified && !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      error = const ApiFailure(
        'Enter exactly six digits.',
        code: 'INVALID_OTP_FORMAT',
      );
      notifyListeners();
      return false;
    }
    final generation = _generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!verified) {
        await api.verifyMockEmail(email: email, otp: code);
        if (generation != _generation) return false;
        verified = true;
      }
      await authenticate();
      return generation == _generation;
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        error = failure;
        final retry = failure.retryAfterSeconds;
        if (retry != null && retry > 0) {
          retryAt = DateTime.now().add(Duration(seconds: retry));
          _retryTimer?.cancel();
          _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (generation != _generation) {
              timer.cancel();
              return;
            }
            notifyListeners();
            if (retrySeconds == 0) timer.cancel();
          });
        }
      }
      return false;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _generation++;
    super.dispose();
  }
}

/// Safe Parent-facing guidance. Server details/PII are never displayed.
class OnboardingError extends StatelessWidget {
  const OnboardingError(this.failure, {super.key});
  final ApiFailure? failure;
  static String message(ApiFailure error) => friendlyError(error);

  @override
  Widget build(BuildContext context) =>
      UserError(failure, messageKey: const Key('onboardingError'));
}
