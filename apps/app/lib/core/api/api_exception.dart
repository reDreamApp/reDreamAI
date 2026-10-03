/// Non-2xx response from the backend.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.retryAfterSeconds});

  final int statusCode;
  final String message;
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The request never got a response: no connectivity, DNS failure, timeout.
class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
