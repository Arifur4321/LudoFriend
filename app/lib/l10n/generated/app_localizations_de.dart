// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Spielen';

  @override
  String get passAndPlay => 'Weitergeben & Spielen';

  @override
  String get vsComputer => 'Gegen Computer';

  @override
  String get onlineMatch => 'Online-Match';

  @override
  String get privateRoom => 'Privater Raum';

  @override
  String get settings => 'Einstellungen';

  @override
  String get leaderboard => 'Bestenliste';

  @override
  String get profile => 'Profil';

  @override
  String get friends => 'Freunde';

  @override
  String get wallet => 'Geldbörse';

  @override
  String get store => 'Shop';

  @override
  String get howToPlay => 'Spielanleitung';

  @override
  String get continueAsGuest => 'Als Gast fortfahren';

  @override
  String get signIn => 'Anmelden';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get home => 'Startseite';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get close => 'Schließen';

  @override
  String get loading => 'Wird geladen…';

  @override
  String get roll => 'Würfeln';

  @override
  String get rematch => 'Revanche';

  @override
  String get yourTurn => 'Du bist dran';

  @override
  String get yourTurnTapDice => 'Du bist dran – tippe auf den Würfel!';

  @override
  String get rollTheDice => 'Würfeln';

  @override
  String get selectAToken => 'Wähle eine Figur';

  @override
  String get tapGlowingToken => 'Tippe auf eine leuchtende Figur';

  @override
  String get rolling => 'Würfelt…';

  @override
  String get gameOver => 'Spiel vorbei';

  @override
  String get waitingForPlayer => 'Warte auf Spieler';

  @override
  String get matchStarted => 'Match gestartet';

  @override
  String get matchFinished => 'Match beendet';

  @override
  String get noLegalMove => 'Kein gültiger Zug';

  @override
  String get playerDisconnected => 'Spieler getrennt';

  @override
  String get reconnecting => 'Neu verbinden…';

  @override
  String get connectionRestored => 'Verbindung wiederhergestellt';

  @override
  String get noConnection => 'Keine Verbindung';

  @override
  String get messageFailedToSend => 'Nachricht konnte nicht gesendet werden';

  @override
  String get inviteSent => 'Einladung gesendet';

  @override
  String get playerJoined => 'Spieler beigetreten';

  @override
  String get playerLeft => 'Spieler hat verlassen';

  @override
  String get chatHint => 'Nachricht…';

  @override
  String get chatEmpty => 'Begrüße deinen Tisch 👋';

  @override
  String get audioHaptics => 'Audio & Haptik';

  @override
  String get soundEffects => 'Soundeffekte';

  @override
  String get music => 'Musik';

  @override
  String get vibration => 'Vibration';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get turnAlerts => 'Zug-Hinweise';

  @override
  String get turnAlertsSubtitle => 'Ton + Vibration, wenn du dran bist';

  @override
  String get inGameChat => 'In-Game-Chat';

  @override
  String get emojiReactions => 'Emoji-Reaktionen';

  @override
  String get appSection => 'App';

  @override
  String get language => 'Sprache';

  @override
  String get about => 'Über';

  @override
  String get legal => 'Rechtliches';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get dataDeletion => 'Daten & Kontolöschung';

  @override
  String playerThinking(String name) {
    return '$name überlegt…';
  }

  @override
  String playerTurn(String name) {
    return 'Am Zug: $name';
  }

  @override
  String playerMove(String name) {
    return 'Zug: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Figuren im Ziel',
      zero: 'Keine Figuren im Ziel',
    );
    return '$_temp0';
  }
}
