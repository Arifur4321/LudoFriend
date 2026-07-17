// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Jugar';

  @override
  String get passAndPlay => 'Pasar y jugar';

  @override
  String get vsComputer => 'Contra la máquina';

  @override
  String get onlineMatch => 'Partida en línea';

  @override
  String get privateRoom => 'Sala privada';

  @override
  String get settings => 'Ajustes';

  @override
  String get leaderboard => 'Clasificación';

  @override
  String get profile => 'Perfil';

  @override
  String get friends => 'Amigos';

  @override
  String get wallet => 'Cartera';

  @override
  String get store => 'Tienda';

  @override
  String get howToPlay => 'Cómo jugar';

  @override
  String get continueAsGuest => 'Continuar como invitado';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get home => 'Inicio';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get close => 'Cerrar';

  @override
  String get loading => 'Cargando…';

  @override
  String get roll => 'Tirar';

  @override
  String get rematch => 'Revancha';

  @override
  String get yourTurn => 'Tu turno';

  @override
  String get yourTurnTapDice => 'Tu turno: ¡toca el dado!';

  @override
  String get rollTheDice => 'Tira el dado';

  @override
  String get selectAToken => 'Elige una ficha';

  @override
  String get tapGlowingToken => 'Toca una ficha iluminada';

  @override
  String get rolling => 'Tirando…';

  @override
  String get gameOver => 'Fin del juego';

  @override
  String get waitingForPlayer => 'Esperando jugador';

  @override
  String get matchStarted => 'Partida iniciada';

  @override
  String get matchFinished => 'Partida finalizada';

  @override
  String get noLegalMove => 'Sin movimiento válido';

  @override
  String get playerDisconnected => 'Jugador desconectado';

  @override
  String get reconnecting => 'Reconectando…';

  @override
  String get connectionRestored => 'Conexión restaurada';

  @override
  String get noConnection => 'Sin conexión';

  @override
  String get messageFailedToSend => 'No se pudo enviar el mensaje';

  @override
  String get inviteSent => 'Invitación enviada';

  @override
  String get playerJoined => 'Jugador se unió';

  @override
  String get playerLeft => 'Jugador salió';

  @override
  String get chatHint => 'Mensaje…';

  @override
  String get chatEmpty => 'Saluda a tu mesa 👋';

  @override
  String get audioHaptics => 'Audio y vibración';

  @override
  String get soundEffects => 'Efectos de sonido';

  @override
  String get music => 'Música';

  @override
  String get vibration => 'Vibración';

  @override
  String get gameplay => 'Juego';

  @override
  String get turnAlerts => 'Avisos de turno';

  @override
  String get turnAlertsSubtitle => 'Sonido + vibración cuando es tu turno';

  @override
  String get inGameChat => 'Chat en el juego';

  @override
  String get emojiReactions => 'Reacciones emoji';

  @override
  String get appSection => 'Aplicación';

  @override
  String get language => 'Idioma';

  @override
  String get about => 'Acerca de';

  @override
  String get legal => 'Legal';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos del servicio';

  @override
  String get dataDeletion => 'Datos y eliminación de cuenta';

  @override
  String playerThinking(String name) {
    return '$name está pensando…';
  }

  @override
  String playerTurn(String name) {
    return 'Turno: $name';
  }

  @override
  String playerMove(String name) {
    return 'Movimiento: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichas en casa',
      zero: 'Sin fichas en casa',
    );
    return '$_temp0';
  }
}
