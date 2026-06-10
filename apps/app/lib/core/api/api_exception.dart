class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.retryAfterSeconds});

  final int statusCode;
  final String message;
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
