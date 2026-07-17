// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => '플레이';

  @override
  String get passAndPlay => '패스 앤 플레이';

  @override
  String get vsComputer => '컴퓨터 대전';

  @override
  String get onlineMatch => '온라인 대전';

  @override
  String get privateRoom => '비공개 방';

  @override
  String get settings => '설정';

  @override
  String get leaderboard => '순위표';

  @override
  String get profile => '프로필';

  @override
  String get friends => '친구';

  @override
  String get wallet => '지갑';

  @override
  String get store => '상점';

  @override
  String get howToPlay => '게임 방법';

  @override
  String get continueAsGuest => '게스트로 계속하기';

  @override
  String get signIn => '로그인';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get home => '홈';

  @override
  String get ok => '확인';

  @override
  String get cancel => '취소';

  @override
  String get retry => '다시 시도';

  @override
  String get close => '닫기';

  @override
  String get loading => '불러오는 중…';

  @override
  String get roll => '굴리기';

  @override
  String get rematch => '재대결';

  @override
  String get yourTurn => '당신 차례';

  @override
  String get yourTurnTapDice => '당신 차례 — 주사위를 탭하세요!';

  @override
  String get rollTheDice => '주사위를 굴리세요';

  @override
  String get selectAToken => '말을 선택하세요';

  @override
  String get tapGlowingToken => '빛나는 말을 탭하세요';

  @override
  String get rolling => '굴리는 중…';

  @override
  String get gameOver => '게임 종료';

  @override
  String get waitingForPlayer => '플레이어 대기 중';

  @override
  String get matchStarted => '대전 시작';

  @override
  String get matchFinished => '대전 종료';

  @override
  String get noLegalMove => '가능한 이동 없음';

  @override
  String get playerDisconnected => '플레이어 연결 끊김';

  @override
  String get reconnecting => '재연결 중…';

  @override
  String get connectionRestored => '연결 복구됨';

  @override
  String get noConnection => '연결 없음';

  @override
  String get messageFailedToSend => '메시지 전송 실패';

  @override
  String get inviteSent => '초대 전송됨';

  @override
  String get playerJoined => '플레이어 입장';

  @override
  String get playerLeft => '플레이어 퇴장';

  @override
  String get chatHint => '메시지…';

  @override
  String get chatEmpty => '테이블에 인사해 보세요 👋';

  @override
  String get audioHaptics => '오디오 및 햅틱';

  @override
  String get soundEffects => '음향 효과';

  @override
  String get music => '음악';

  @override
  String get vibration => '진동';

  @override
  String get gameplay => '게임플레이';

  @override
  String get turnAlerts => '차례 알림';

  @override
  String get turnAlertsSubtitle => '당신 차례일 때 소리+진동';

  @override
  String get inGameChat => '게임 내 채팅';

  @override
  String get emojiReactions => '이모지 반응';

  @override
  String get appSection => '앱';

  @override
  String get language => '언어';

  @override
  String get about => '정보';

  @override
  String get legal => '법적 고지';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfService => '서비스 약관';

  @override
  String get dataDeletion => '데이터 및 계정 삭제';

  @override
  String playerThinking(String name) {
    return '$name 님이 고민 중…';
  }

  @override
  String playerTurn(String name) {
    return '차례: $name';
  }

  @override
  String playerMove(String name) {
    return '이동: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '집에 들어온 말 $count개',
      zero: '집에 들어온 말 없음',
    );
    return '$_temp0';
  }
}
