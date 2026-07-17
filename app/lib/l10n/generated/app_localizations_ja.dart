// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'プレイ';

  @override
  String get passAndPlay => '交代プレイ';

  @override
  String get vsComputer => 'コンピュータ対戦';

  @override
  String get onlineMatch => 'オンライン対戦';

  @override
  String get privateRoom => 'プライベートルーム';

  @override
  String get settings => '設定';

  @override
  String get leaderboard => 'ランキング';

  @override
  String get profile => 'プロフィール';

  @override
  String get friends => 'フレンド';

  @override
  String get wallet => 'ウォレット';

  @override
  String get store => 'ストア';

  @override
  String get howToPlay => '遊び方';

  @override
  String get continueAsGuest => 'ゲストとして続ける';

  @override
  String get signIn => 'サインイン';

  @override
  String get createAccount => 'アカウント作成';

  @override
  String get home => 'ホーム';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get retry => '再試行';

  @override
  String get close => '閉じる';

  @override
  String get loading => '読み込み中…';

  @override
  String get roll => '振る';

  @override
  String get rematch => '再戦';

  @override
  String get yourTurn => 'あなたの番';

  @override
  String get yourTurnTapDice => 'あなたの番 — サイコロをタップ！';

  @override
  String get rollTheDice => 'サイコロを振る';

  @override
  String get selectAToken => 'コマを選択';

  @override
  String get tapGlowingToken => '光っているコマをタップ';

  @override
  String get rolling => '振っています…';

  @override
  String get gameOver => 'ゲーム終了';

  @override
  String get waitingForPlayer => 'プレイヤーを待っています';

  @override
  String get matchStarted => '対戦開始';

  @override
  String get matchFinished => '対戦終了';

  @override
  String get noLegalMove => '有効な手がありません';

  @override
  String get playerDisconnected => 'プレイヤーが切断';

  @override
  String get reconnecting => '再接続中…';

  @override
  String get connectionRestored => '接続が回復しました';

  @override
  String get noConnection => '接続なし';

  @override
  String get messageFailedToSend => 'メッセージを送信できません';

  @override
  String get inviteSent => '招待を送信しました';

  @override
  String get playerJoined => 'プレイヤーが参加';

  @override
  String get playerLeft => 'プレイヤーが退出';

  @override
  String get chatHint => 'メッセージ…';

  @override
  String get chatEmpty => 'テーブルに挨拶しよう 👋';

  @override
  String get audioHaptics => '音とハプティクス';

  @override
  String get soundEffects => '効果音';

  @override
  String get music => '音楽';

  @override
  String get vibration => 'バイブレーション';

  @override
  String get gameplay => 'ゲームプレイ';

  @override
  String get turnAlerts => 'ターン通知';

  @override
  String get turnAlertsSubtitle => 'あなたの番になったら音とバイブ';

  @override
  String get inGameChat => 'ゲーム内チャット';

  @override
  String get emojiReactions => '絵文字リアクション';

  @override
  String get appSection => 'アプリ';

  @override
  String get language => '言語';

  @override
  String get about => 'このアプリについて';

  @override
  String get legal => '法的情報';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get dataDeletion => 'データとアカウントの削除';

  @override
  String playerThinking(String name) {
    return '$name が考えています…';
  }

  @override
  String playerTurn(String name) {
    return '手番: $name';
  }

  @override
  String playerMove(String name) {
    return '手: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ゴールしたコマ $count個',
      zero: 'ゴールしたコマなし',
    );
    return '$_temp0';
  }
}
