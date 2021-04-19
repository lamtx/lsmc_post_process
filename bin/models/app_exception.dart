class AppException implements Exception {
  const AppException(this.httpStatusCode, this.message);

  final int httpStatusCode;
  final String message;

  @override
  String toString() => message;
}
