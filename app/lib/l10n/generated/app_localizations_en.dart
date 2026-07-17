// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Play';

  @override
  String get passAndPlay => 'Pass & Play';

  @override
  String get vsComputer => 'Vs Computer';

  @override
  String get onlineMatch => 'Online Match';

  @override
  String get privateRoom => 'Private Room';

  @override
  String get settings => 'Settings';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get profile => 'Profile';

  @override
  String get friends => 'Friends';

  @override
  String get wallet => 'Wallet';

  @override
  String get store => 'Store';

  @override
  String get howToPlay => 'How to Play';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get home => 'Home';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading…';

  @override
  String get roll => 'Roll';

  @override
  String get rematch => 'Rematch';

  @override
  String get yourTurn => 'Your turn';

  @override
  String get yourTurnTapDice => 'Your turn — tap the dice!';

  @override
  String get rollTheDice => 'Roll the dice';

  @override
  String get selectAToken => 'Select a token';

  @override
  String get tapGlowingToken => 'Tap a glowing token';

  @override
  String get rolling => 'Rolling…';

  @override
  String get gameOver => 'Game over';

  @override
  String get waitingForPlayer => 'Waiting for player';

  @override
  String get matchStarted => 'Match started';

  @override
  String get matchFinished => 'Match finished';

  @override
  String get noLegalMove => 'No legal move';

  @override
  String get playerDisconnected => 'Player disconnected';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get connectionRestored => 'Connection restored';

  @override
  String get noConnection => 'No connection';

  @override
  String get messageFailedToSend => 'Message failed to send';

  @override
  String get inviteSent => 'Invite sent';

  @override
  String get playerJoined => 'Player joined';

  @override
  String get playerLeft => 'Player left';

  @override
  String get chatHint => 'Message…';

  @override
  String get chatEmpty => 'Say hi to your table 👋';

  @override
  String get audioHaptics => 'Audio & Haptics';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get music => 'Music';

  @override
  String get vibration => 'Vibration';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get turnAlerts => 'Turn alerts';

  @override
  String get turnAlertsSubtitle => 'Sound + buzz when it is your turn';

  @override
  String get inGameChat => 'In-game chat';

  @override
  String get emojiReactions => 'Emoji reactions';

  @override
  String get appSection => 'App';

  @override
  String get language => 'Language';

  @override
  String get about => 'About';

  @override
  String get legal => 'Legal';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get dataDeletion => 'Data & account deletion';

  @override
  String playerThinking(String name) {
    return '$name is thinking…';
  }

  @override
  String playerTurn(String name) {
    return 'Turn: $name';
  }

  @override
  String playerMove(String name) {
    return 'Move: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens home',
      one: '1 token home',
      zero: 'No tokens home',
    );
    return '$_temp0';
  }
}
