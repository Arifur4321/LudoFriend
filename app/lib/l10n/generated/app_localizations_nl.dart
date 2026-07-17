// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Spelen';

  @override
  String get passAndPlay => 'Doorgeven & Spelen';

  @override
  String get vsComputer => 'Tegen computer';

  @override
  String get onlineMatch => 'Online match';

  @override
  String get privateRoom => 'Privékamer';

  @override
  String get settings => 'Instellingen';

  @override
  String get leaderboard => 'Scorebord';

  @override
  String get profile => 'Profiel';

  @override
  String get friends => 'Vrienden';

  @override
  String get wallet => 'Portemonnee';

  @override
  String get store => 'Winkel';

  @override
  String get howToPlay => 'Hoe te spelen';

  @override
  String get continueAsGuest => 'Doorgaan als gast';

  @override
  String get signIn => 'Inloggen';

  @override
  String get createAccount => 'Account aanmaken';

  @override
  String get home => 'Home';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuleren';

  @override
  String get retry => 'Opnieuw';

  @override
  String get close => 'Sluiten';

  @override
  String get loading => 'Laden…';

  @override
  String get roll => 'Gooien';

  @override
  String get rematch => 'Herkansing';

  @override
  String get yourTurn => 'Jouw beurt';

  @override
  String get yourTurnTapDice => 'Jouw beurt – tik op de dobbelsteen!';

  @override
  String get rollTheDice => 'Gooi de dobbelsteen';

  @override
  String get selectAToken => 'Kies een pion';

  @override
  String get tapGlowingToken => 'Tik op een oplichtende pion';

  @override
  String get rolling => 'Gooien…';

  @override
  String get gameOver => 'Spel voorbij';

  @override
  String get waitingForPlayer => 'Wachten op speler';

  @override
  String get matchStarted => 'Match gestart';

  @override
  String get matchFinished => 'Match afgelopen';

  @override
  String get noLegalMove => 'Geen geldige zet';

  @override
  String get playerDisconnected => 'Speler verbroken';

  @override
  String get reconnecting => 'Opnieuw verbinden…';

  @override
  String get connectionRestored => 'Verbinding hersteld';

  @override
  String get noConnection => 'Geen verbinding';

  @override
  String get messageFailedToSend => 'Bericht niet verzonden';

  @override
  String get inviteSent => 'Uitnodiging verzonden';

  @override
  String get playerJoined => 'Speler toegetreden';

  @override
  String get playerLeft => 'Speler vertrokken';

  @override
  String get chatHint => 'Bericht…';

  @override
  String get chatEmpty => 'Zeg hallo tegen je tafel 👋';

  @override
  String get audioHaptics => 'Audio & haptiek';

  @override
  String get soundEffects => 'Geluidseffecten';

  @override
  String get music => 'Muziek';

  @override
  String get vibration => 'Trillen';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get turnAlerts => 'Beurtmeldingen';

  @override
  String get turnAlertsSubtitle => 'Geluid + tril als je aan de beurt bent';

  @override
  String get inGameChat => 'In-game chat';

  @override
  String get emojiReactions => 'Emoji-reacties';

  @override
  String get appSection => 'App';

  @override
  String get language => 'Taal';

  @override
  String get about => 'Over';

  @override
  String get legal => 'Juridisch';

  @override
  String get privacyPolicy => 'Privacybeleid';

  @override
  String get termsOfService => 'Servicevoorwaarden';

  @override
  String get dataDeletion => 'Gegevens & accountverwijdering';

  @override
  String playerThinking(String name) {
    return '$name denkt na…';
  }

  @override
  String playerTurn(String name) {
    return 'Beurt: $name';
  }

  @override
  String playerMove(String name) {
    return 'Zet: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pionnen thuis',
      zero: 'Geen pionnen thuis',
    );
    return '$_temp0';
  }
}
