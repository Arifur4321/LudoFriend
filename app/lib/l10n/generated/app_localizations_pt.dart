// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'Jogar';

  @override
  String get passAndPlay => 'Passa e joga';

  @override
  String get vsComputer => 'Contra o computador';

  @override
  String get onlineMatch => 'Partida online';

  @override
  String get privateRoom => 'Sala privada';

  @override
  String get settings => 'Configurações';

  @override
  String get leaderboard => 'Classificação';

  @override
  String get profile => 'Perfil';

  @override
  String get friends => 'Amigos';

  @override
  String get wallet => 'Carteira';

  @override
  String get store => 'Loja';

  @override
  String get howToPlay => 'Como jogar';

  @override
  String get continueAsGuest => 'Continuar como convidado';

  @override
  String get signIn => 'Entrar';

  @override
  String get createAccount => 'Criar conta';

  @override
  String get home => 'Início';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get close => 'Fechar';

  @override
  String get loading => 'Carregando…';

  @override
  String get roll => 'Lançar';

  @override
  String get rematch => 'Revanche';

  @override
  String get yourTurn => 'Sua vez';

  @override
  String get yourTurnTapDice => 'Sua vez — toque no dado!';

  @override
  String get rollTheDice => 'Lance o dado';

  @override
  String get selectAToken => 'Escolha um peão';

  @override
  String get tapGlowingToken => 'Toque em um peão brilhante';

  @override
  String get rolling => 'Lançando…';

  @override
  String get gameOver => 'Fim de jogo';

  @override
  String get waitingForPlayer => 'Aguardando jogador';

  @override
  String get matchStarted => 'Partida iniciada';

  @override
  String get matchFinished => 'Partida encerrada';

  @override
  String get noLegalMove => 'Nenhuma jogada válida';

  @override
  String get playerDisconnected => 'Jogador desconectado';

  @override
  String get reconnecting => 'Reconectando…';

  @override
  String get connectionRestored => 'Conexão restaurada';

  @override
  String get noConnection => 'Sem conexão';

  @override
  String get messageFailedToSend => 'Falha ao enviar a mensagem';

  @override
  String get inviteSent => 'Convite enviado';

  @override
  String get playerJoined => 'Jogador entrou';

  @override
  String get playerLeft => 'Jogador saiu';

  @override
  String get chatHint => 'Mensagem…';

  @override
  String get chatEmpty => 'Diga oi para a sua mesa 👋';

  @override
  String get audioHaptics => 'Áudio e vibração';

  @override
  String get soundEffects => 'Efeitos sonoros';

  @override
  String get music => 'Música';

  @override
  String get vibration => 'Vibração';

  @override
  String get gameplay => 'Jogabilidade';

  @override
  String get turnAlerts => 'Alertas de vez';

  @override
  String get turnAlertsSubtitle => 'Som + vibração quando for sua vez';

  @override
  String get inGameChat => 'Chat no jogo';

  @override
  String get emojiReactions => 'Reações emoji';

  @override
  String get appSection => 'Aplicativo';

  @override
  String get language => 'Idioma';

  @override
  String get about => 'Sobre';

  @override
  String get legal => 'Jurídico';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get termsOfService => 'Termos de Serviço';

  @override
  String get dataDeletion => 'Dados e exclusão de conta';

  @override
  String playerThinking(String name) {
    return '$name está pensando…';
  }

  @override
  String playerTurn(String name) {
    return 'Vez: $name';
  }

  @override
  String playerMove(String name) {
    return 'Jogada: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peões em casa',
      zero: 'Nenhum peão em casa',
    );
    return '$_temp0';
  }
}
