// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Gioca';

  @override
  String get passAndPlay => 'Passa e gioca';

  @override
  String get vsComputer => 'Contro il computer';

  @override
  String get onlineMatch => 'Partita online';

  @override
  String get privateRoom => 'Stanza privata';

  @override
  String get settings => 'Impostazioni';

  @override
  String get leaderboard => 'Classifica';

  @override
  String get profile => 'Profilo';

  @override
  String get friends => 'Amici';

  @override
  String get wallet => 'Portafoglio';

  @override
  String get store => 'Negozio';

  @override
  String get howToPlay => 'Come si gioca';

  @override
  String get continueAsGuest => 'Continua come ospite';

  @override
  String get signIn => 'Accedi';

  @override
  String get createAccount => 'Crea account';

  @override
  String get home => 'Home';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annulla';

  @override
  String get retry => 'Riprova';

  @override
  String get close => 'Chiudi';

  @override
  String get loading => 'Caricamento…';

  @override
  String get roll => 'Lancia';

  @override
  String get rematch => 'Rivincita';

  @override
  String get yourTurn => 'Il tuo turno';

  @override
  String get yourTurnTapDice => 'È il tuo turno: tocca il dado!';

  @override
  String get rollTheDice => 'Lancia il dado';

  @override
  String get selectAToken => 'Scegli una pedina';

  @override
  String get tapGlowingToken => 'Tocca una pedina illuminata';

  @override
  String get rolling => 'Lancio…';

  @override
  String get gameOver => 'Partita finita';

  @override
  String get waitingForPlayer => 'In attesa di un giocatore';

  @override
  String get matchStarted => 'Partita iniziata';

  @override
  String get matchFinished => 'Partita terminata';

  @override
  String get noLegalMove => 'Nessuna mossa valida';

  @override
  String get playerDisconnected => 'Giocatore disconnesso';

  @override
  String get reconnecting => 'Riconnessione…';

  @override
  String get connectionRestored => 'Connessione ripristinata';

  @override
  String get noConnection => 'Nessuna connessione';

  @override
  String get messageFailedToSend => 'Invio del messaggio non riuscito';

  @override
  String get inviteSent => 'Invito inviato';

  @override
  String get playerJoined => 'Giocatore entrato';

  @override
  String get playerLeft => 'Giocatore uscito';

  @override
  String get chatHint => 'Messaggio…';

  @override
  String get chatEmpty => 'Saluta il tuo tavolo 👋';

  @override
  String get audioHaptics => 'Audio e vibrazione';

  @override
  String get soundEffects => 'Effetti sonori';

  @override
  String get music => 'Musica';

  @override
  String get vibration => 'Vibrazione';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get turnAlerts => 'Avvisi di turno';

  @override
  String get turnAlertsSubtitle => 'Suono + vibrazione quando è il tuo turno';

  @override
  String get inGameChat => 'Chat di gioco';

  @override
  String get emojiReactions => 'Reazioni emoji';

  @override
  String get appSection => 'App';

  @override
  String get language => 'Lingua';

  @override
  String get about => 'Informazioni';

  @override
  String get legal => 'Note legali';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get termsOfService => 'Termini di servizio';

  @override
  String get dataDeletion => 'Dati ed eliminazione account';

  @override
  String playerThinking(String name) {
    return '$name sta pensando…';
  }

  @override
  String playerTurn(String name) {
    return 'Turno: $name';
  }

  @override
  String playerMove(String name) {
    return 'Mossa: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pedine a casa',
      zero: 'Nessuna pedina a casa',
    );
    return '$_temp0';
  }
}
