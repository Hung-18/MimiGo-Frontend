class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.code,
    this.status,
    this.requestId,
    this.retryable = false,
    this.retryAfterSeconds,
  });
  final String message;
  final String? code, requestId;
  final int? status;
  final bool retryable;
  final int? retryAfterSeconds;
}

class ApiInvalidResponse extends ApiFailure {
  const ApiInvalidResponse(super.message, {super.requestId, super.status})
    : super(code: 'INVALID_RESPONSE');
}
