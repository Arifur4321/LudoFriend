/// REST endpoint paths (relative to `AppConfig.apiBaseUrl`).
///
/// Mirrors `backend/routes/api.php`. Never embed a full URL here — the base
/// comes from configuration.
abstract class ApiEndpoints {
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String guest = '/auth/guest';
  static const String facebook = '/auth/facebook';
  static const String google = '/auth/google';

  // Profile
  static const String profile = '/profile';
  static const String stats = '/profile/stats';
  static const String matchHistory = '/profile/matches';

  // Friends / presence
  static const String friends = '/friends';
  static const String friendsFacebook = '/friends/facebook';
  static const String invite = '/friends/invite';
  static const String friendsAccept = '/friends/accept';
  static const String inviteToRoom = '/friends/invite-to-room';
  static const String presencePing = '/presence/ping';
  static String acceptInvite(String code) => '/friends/accept/$code';

  // Rooms
  static const String rooms = '/rooms';
  static String room(String code) => '/rooms/$code';
  static String joinRoom(String code) => '/rooms/$code/join';
  static String leaveRoom(String code) => '/rooms/$code/leave';
  static String readyRoom(String code) => '/rooms/$code/ready';
  static String startRoom(String code) => '/rooms/$code/start';

  // Matchmaking
  static const String matchmakingEnqueue = '/matchmaking/enqueue';
  static const String matchmakingCancel = '/matchmaking/cancel';
  static const String matchmakingStatus = '/matchmaking/status';

  // Game
  static String gameState(String matchId) => '/matches/$matchId/state';
  static String rollDice(String matchId) => '/matches/$matchId/roll';
  static String moveToken(String matchId) => '/matches/$matchId/move';
  static String reconnect(String matchId) => '/matches/$matchId/reconnect';
  static String chatMessage(String matchId) => '/matches/$matchId/chat';
  static String chatEmoji(String matchId) => '/matches/$matchId/emoji';

  // Leaderboard
  static const String leaderboard = '/leaderboard';

  // Economy — wallet, staked boards, hourly free spin, coin store.
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String boards = '/boards';
  static const String spinStatus = '/spin/status';
  static const String spin = '/spin';
  static const String storePacks = '/store/packs';
  static const String storePurchase = '/store/purchase';
}
