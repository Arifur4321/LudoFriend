/// User-facing, typed failures. Repositories convert exceptions into these so
/// the UI can render friendly messages and decide on retry/reconnect flows.
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our side.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [this.errors = const {}]);
  final Map<String, List<String>> errors;
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unexpected error.']);
}
