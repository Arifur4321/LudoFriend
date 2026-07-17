// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => '开始';

  @override
  String get passAndPlay => '传递游戏';

  @override
  String get vsComputer => '对战电脑';

  @override
  String get onlineMatch => '在线对战';

  @override
  String get privateRoom => '私人房间';

  @override
  String get settings => '设置';

  @override
  String get leaderboard => '排行榜';

  @override
  String get profile => '个人资料';

  @override
  String get friends => '好友';

  @override
  String get wallet => '钱包';

  @override
  String get store => '商店';

  @override
  String get howToPlay => '玩法说明';

  @override
  String get continueAsGuest => '以访客身份继续';

  @override
  String get signIn => '登录';

  @override
  String get createAccount => '创建账户';

  @override
  String get home => '主页';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get close => '关闭';

  @override
  String get loading => '加载中…';

  @override
  String get roll => '掷骰';

  @override
  String get rematch => '再来一局';

  @override
  String get yourTurn => '轮到你了';

  @override
  String get yourTurnTapDice => '轮到你了 — 点击骰子！';

  @override
  String get rollTheDice => '掷骰子';

  @override
  String get selectAToken => '选择一个棋子';

  @override
  String get tapGlowingToken => '点击发光的棋子';

  @override
  String get rolling => '掷骰中…';

  @override
  String get gameOver => '游戏结束';

  @override
  String get waitingForPlayer => '等待玩家';

  @override
  String get matchStarted => '对局开始';

  @override
  String get matchFinished => '对局结束';

  @override
  String get noLegalMove => '无合法走法';

  @override
  String get playerDisconnected => '玩家已断线';

  @override
  String get reconnecting => '重新连接中…';

  @override
  String get connectionRestored => '连接已恢复';

  @override
  String get noConnection => '无连接';

  @override
  String get messageFailedToSend => '消息发送失败';

  @override
  String get inviteSent => '邀请已发送';

  @override
  String get playerJoined => '玩家已加入';

  @override
  String get playerLeft => '玩家已离开';

  @override
  String get chatHint => '消息…';

  @override
  String get chatEmpty => '和你的牌桌打个招呼吧 👋';

  @override
  String get audioHaptics => '音频与振动';

  @override
  String get soundEffects => '音效';

  @override
  String get music => '音乐';

  @override
  String get vibration => '振动';

  @override
  String get gameplay => '游戏玩法';

  @override
  String get turnAlerts => '回合提醒';

  @override
  String get turnAlertsSubtitle => '轮到你时声音+振动';

  @override
  String get inGameChat => '游戏内聊天';

  @override
  String get emojiReactions => '表情反应';

  @override
  String get appSection => '应用';

  @override
  String get language => '语言';

  @override
  String get about => '关于';

  @override
  String get legal => '法律';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get dataDeletion => '数据与账户删除';

  @override
  String playerThinking(String name) {
    return '$name 正在思考…';
  }

  @override
  String playerTurn(String name) {
    return '回合：$name';
  }

  @override
  String playerMove(String name) {
    return '走子：$name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个棋子到家',
      zero: '没有棋子到家',
    );
    return '$_temp0';
  }
}
