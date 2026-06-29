/// Low-level exceptions thrown by data sources, mapped to `Failure`s upstream.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.errors = const {}]);
  final int statusCode;
  final String message;
  final Map<String, List<String>> errors;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class CacheException implements Exception {
  CacheException(this.message);
  final String message;
}
