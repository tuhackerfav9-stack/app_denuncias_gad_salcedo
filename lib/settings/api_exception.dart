enum ApiErrorType { unauthorized, forbidden, server, network, timeout, unknown }

class ApiException implements Exception {
  final ApiErrorType type;
  final int? statusCode;
  final String message;
  final dynamic raw;

  ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.raw,
  });

  @override
  String toString() => "ApiException($type, $statusCode): $message";
}
