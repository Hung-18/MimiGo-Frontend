import 'package:flutter/material.dart';

import 'main.dart' show MimiGoApi;
import 'api_failure.dart';

/// Keeps verified-email success separate from a later login/network failure.
/// No resend, expiry extension, token refresh or local credential persistence.
class EmailVerificationState extends ChangeNotifier {
  EmailVerificationState(this.api, this.email);
  final MimiGoApi api;
  final String email;
  bool busy = false, verified = false;
  ApiFailure? error;
  int _generation = 0;

  Future<bool> submit(String code, Future<void> Function() authenticate) async {
    if (busy) return false;
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
      if (generation == _generation) error = failure;
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
    _generation++;
    super.dispose();
  }
}

/// Safe Parent-facing guidance. Server details/PII are never displayed.
class OnboardingError extends StatelessWidget {
  const OnboardingError(this.failure, {super.key});
  final ApiFailure? failure;
  static String message(ApiFailure error) {
    return switch (error.code) {
      'INVALID_OTP' => 'The code could not be verified. It may be wrong, expired or unavailable. No resend service is available; ask the development operator for help.',
      'INVALID_OTP_FORMAT' =>
        'Enter the six-digit development verification code.',
      'EMAIL_ALREADY_REGISTERED' => 'This synthetic email is already registered. Sign in, or use verification recovery if sign-in reports an unverified account.',
      'TERMS_VERSION_NOT_CURRENT' => 'Account Terms changed. Reload the current version and make a new explicit choice.',
      'TERMS_ACCEPTANCE_REQUIRED' => 'Explicit acceptance of current account Terms is required. This does not grant child consent.',
      'EMAIL_NOT_VERIFIED' => 'Verify this synthetic email before signing in.',
      'INVALID_CREDENTIALS' =>
        'Email or password is incorrect. Return to sign-in to check them.',
      'ATTEMPT_EXPIRED' ||
      'ATTEMPT_NOT_FOUND' ||
      'NOTICE_CHANGED_REDISPLAY_REQUIRED' => 'The child onboarding notices must be loaded again. Restart privacy review and make fresh choices.',
      'ATTEMPT_ALREADY_CONSUMED' || 'IDEMPOTENCY_CONFLICT' => 'This creation request cannot be changed or reused. Check Parent Home for the profile before starting another onboarding.',
      'CORE_PERMISSION_REQUIRED' => 'Every required mock purpose needs its own affirmative choice. No partially authorized child is created.',
      'INVALID_CHILD_ALIAS' ||
      'SYNTHETIC_ALIAS_REQUIRED' ||
      'DATE_OF_BIRTH_REQUIRED' ||
      'INVALID_DATE_OF_BIRTH' ||
      'INVALID_AVATAR' => 'The service rejected the synthetic profile fields. Restart privacy review to enter a corrected profile.',
      'CONNECTIVITY' || 'TIMEOUT' =>
        'We could not reach the service. Check your connection and retry.',
      _ when error.status == 401 => 'Your parent sign-in expired. Return to account entry and sign in again.',
      _ when error.status == 403 =>
        'This parent account cannot continue. Return to account entry.',
      _ when error.status == 429 => 'Too many attempts. Wait before trying again; no new verification code is generated.',
      _ when (error.status ?? 0) >= 500 =>
        'The service is temporarily unavailable. Please try again later.',
      _ when error is ApiInvalidResponse => 'The service returned an invalid response. No success is assumed. Retry or return to account entry.',
      _ => 'The request could not be confirmed. Check the form and try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final error = failure;
    if (error == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '${message(error)}\n${error.code ?? 'REQUEST_FAILED'}'
          '${error.requestId == null ? '' : '\nRequest: ${error.requestId}'}',
          key: const Key('onboardingError'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
