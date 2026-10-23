class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.code,
    this.status,
    this.requestId,
    this.retryable = false,
  });
  final String message;
  final String? code, requestId;
  final int? status;
  final bool retryable;
}

class ApiInvalidResponse extends ApiFailure {
  const ApiInvalidResponse(super.message, {super.requestId, super.status})
    : super(code: 'INVALID_RESPONSE');
}
