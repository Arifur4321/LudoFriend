// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'खेलें';

  @override
  String get passAndPlay => 'पास एंड प्ले';

  @override
  String get vsComputer => 'कंप्यूटर के विरुद्ध';

  @override
  String get onlineMatch => 'ऑनलाइन मैच';

  @override
  String get privateRoom => 'निजी कमरा';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get leaderboard => 'लीडरबोर्ड';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get friends => 'मित्र';

  @override
  String get wallet => 'वॉलेट';

  @override
  String get store => 'स्टोर';

  @override
  String get howToPlay => 'कैसे खेलें';

  @override
  String get continueAsGuest => 'अतिथि के रूप में जारी रखें';

  @override
  String get signIn => 'साइन इन';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get home => 'होम';

  @override
  String get ok => 'ठीक है';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get close => 'बंद करें';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get roll => 'रोल';

  @override
  String get rematch => 'पुनः मैच';

  @override
  String get yourTurn => 'आपकी बारी';

  @override
  String get yourTurnTapDice => 'आपकी बारी — पासे पर टैप करें!';

  @override
  String get rollTheDice => 'पासा फेंकें';

  @override
  String get selectAToken => 'एक गोटी चुनें';

  @override
  String get tapGlowingToken => 'चमकती गोटी पर टैप करें';

  @override
  String get rolling => 'रोल हो रहा है…';

  @override
  String get gameOver => 'खेल समाप्त';

  @override
  String get waitingForPlayer => 'खिलाड़ी की प्रतीक्षा';

  @override
  String get matchStarted => 'मैच शुरू हुआ';

  @override
  String get matchFinished => 'मैच समाप्त हुआ';

  @override
  String get noLegalMove => 'कोई वैध चाल नहीं';

  @override
  String get playerDisconnected => 'खिलाड़ी डिस्कनेक्ट';

  @override
  String get reconnecting => 'पुनः कनेक्ट हो रहा है…';

  @override
  String get connectionRestored => 'कनेक्शन बहाल';

  @override
  String get noConnection => 'कोई कनेक्शन नहीं';

  @override
  String get messageFailedToSend => 'संदेश भेजने में विफल';

  @override
  String get inviteSent => 'निमंत्रण भेजा गया';

  @override
  String get playerJoined => 'खिलाड़ी शामिल हुआ';

  @override
  String get playerLeft => 'खिलाड़ी चला गया';

  @override
  String get chatHint => 'संदेश…';

  @override
  String get chatEmpty => 'अपनी टेबल को नमस्ते कहें 👋';

  @override
  String get audioHaptics => 'ऑडियो और हैप्टिक्स';

  @override
  String get soundEffects => 'ध्वनि प्रभाव';

  @override
  String get music => 'संगीत';

  @override
  String get vibration => 'कंपन';

  @override
  String get gameplay => 'गेमप्ले';

  @override
  String get turnAlerts => 'बारी अलर्ट';

  @override
  String get turnAlertsSubtitle => 'आपकी बारी आने पर ध्वनि और कंपन';

  @override
  String get inGameChat => 'इन-गेम चैट';

  @override
  String get emojiReactions => 'इमोजी प्रतिक्रियाएं';

  @override
  String get appSection => 'ऐप';

  @override
  String get language => 'भाषा';

  @override
  String get about => 'परिचय';

  @override
  String get legal => 'कानूनी';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsOfService => 'सेवा की शर्तें';

  @override
  String get dataDeletion => 'डेटा और खाता हटाना';

  @override
  String playerThinking(String name) {
    return '$name सोच रहा है…';
  }

  @override
  String playerTurn(String name) {
    return 'बारी: $name';
  }

  @override
  String playerMove(String name) {
    return 'चाल: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count गोटियां घर में',
      zero: 'कोई गोटी घर नहीं पहुंची',
    );
    return '$_temp0';
  }
}
