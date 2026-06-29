class SocialAuthException implements Exception {
  const SocialAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
