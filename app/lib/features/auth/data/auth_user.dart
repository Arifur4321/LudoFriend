/// The signed-in user (real account or guest).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.isGuest = false,
    this.avatarUrl,
    this.token,
  });

  final String id;
  final String name;
  final String? email;
  final bool isGuest;
  final String? avatarUrl;

  /// Sanctum bearer token (null for purely-offline guests).
  final String? token;

  AuthUser copyWith({String? name, String? avatarUrl, String? token}) =>
      AuthUser(
        id: id,
        name: name ?? this.name,
        email: email,
        isGuest: isGuest,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        token: token ?? this.token,
      );

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: '${j['id']}',
        name: j['name'] as String? ?? 'Player',
        email: j['email'] as String?,
        isGuest: j['is_guest'] as bool? ?? false,
        avatarUrl: j['avatar'] as String?,
        token: j['token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'is_guest': isGuest,
        'avatar': avatarUrl,
      };
}
