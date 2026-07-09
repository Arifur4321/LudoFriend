/// Centralised route paths. Screens navigate with `context.go(AppRoutes.x)`.
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String play = '/play';
  static const String createRoom = '/room/create';
  static const String joinRoom = '/room/join';
  static const String lobby = '/room/lobby';
  static const String matchmaking = '/matchmaking';
  static const String game = '/game';
  static const String result = '/result';
  static const String profile = '/profile';
  static const String leaderboard = '/leaderboard';
  static const String settings = '/settings';
  static const String friends = '/friends';
  static const String help = '/help';
  static const String noInternet = '/no-internet';

  // Economy
  static const String wallet = '/wallet';
  static const String spin = '/spin';
  static const String boards = '/boards';
  static const String store = '/store';
}
