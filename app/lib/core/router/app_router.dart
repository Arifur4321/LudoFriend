import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/boards/presentation/board_select_screen.dart';
import '../../features/common/presentation/no_internet_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/game/presentation/game_screen.dart';
import '../../features/help/presentation/help_rules_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/play_options_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/matchmaking/presentation/matchmaking_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/room/presentation/create_room_screen.dart';
import '../../features/room/presentation/join_room_screen.dart';
import '../../features/room/presentation/room_lobby_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/spin/presentation/spin_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/store/presentation/store_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import 'app_routes.dart';

/// Builds a page with a smooth fade transition.
CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  GoRoute route(String path, Widget child) => GoRoute(
        path: path,
        pageBuilder: (context, state) => _fade(child, state),
      );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      route(AppRoutes.splash, const SplashScreen()),
      route(AppRoutes.onboarding, const OnboardingScreen()),
      route(AppRoutes.home, const HomeScreen()),
      route(AppRoutes.login, const LoginScreen()),
      route(AppRoutes.register, const RegisterScreen()),
      route(AppRoutes.play, const PlayOptionsScreen()),
      route(AppRoutes.createRoom, const CreateRoomScreen()),
      route(AppRoutes.joinRoom, const JoinRoomScreen()),
      route(AppRoutes.lobby, const RoomLobbyScreen()),
      route(AppRoutes.matchmaking, const MatchmakingScreen()),
      route(AppRoutes.game, const GameScreen()),
      route(AppRoutes.profile, const ProfileScreen()),
      route(AppRoutes.leaderboard, const LeaderboardScreen()),
      route(AppRoutes.settings, const SettingsScreen()),
      route(AppRoutes.friends, const FriendsScreen()),
      route(AppRoutes.help, const HelpRulesScreen()),
      route(AppRoutes.noInternet, const NoInternetScreen()),
      // Economy
      route(AppRoutes.wallet, const WalletScreen()),
      route(AppRoutes.spin, const SpinScreen()),
      route(AppRoutes.boards, const BoardSelectScreen()),
      route(AppRoutes.store, const StoreScreen()),
    ],
    errorBuilder: (context, state) =>
        ErrorScreen(message: state.error?.toString()),
  );
});
