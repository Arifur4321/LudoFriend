// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'Ludo Friends';

  @override
  String get play => 'খেলুন';

  @override
  String get passAndPlay => 'পাস অ্যান্ড প্লে';

  @override
  String get vsComputer => 'কম্পিউটারের বিরুদ্ধে';

  @override
  String get onlineMatch => 'অনলাইন ম্যাচ';

  @override
  String get privateRoom => 'প্রাইভেট রুম';

  @override
  String get settings => 'সেটিংস';

  @override
  String get leaderboard => 'লিডারবোর্ড';

  @override
  String get profile => 'প্রোফাইল';

  @override
  String get friends => 'বন্ধুরা';

  @override
  String get wallet => 'ওয়ালেট';

  @override
  String get store => 'স্টোর';

  @override
  String get howToPlay => 'কীভাবে খেলবেন';

  @override
  String get continueAsGuest => 'অতিথি হিসেবে চালিয়ে যান';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get home => 'হোম';

  @override
  String get ok => 'ঠিক আছে';

  @override
  String get cancel => 'বাতিল';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get loading => 'লোড হচ্ছে…';

  @override
  String get roll => 'রোল';

  @override
  String get rematch => 'পুনরায় খেলুন';

  @override
  String get yourTurn => 'আপনার পালা';

  @override
  String get yourTurnTapDice => 'আপনার পালা — ছক্কায় ট্যাপ করুন!';

  @override
  String get rollTheDice => 'ছক্কা চালুন';

  @override
  String get selectAToken => 'একটি ঘুঁটি নির্বাচন করুন';

  @override
  String get tapGlowingToken => 'একটি জ্বলজ্বলে ঘুঁটিতে ট্যাপ করুন';

  @override
  String get rolling => 'রোল হচ্ছে…';

  @override
  String get gameOver => 'খেলা শেষ';

  @override
  String get waitingForPlayer => 'খেলোয়াড়ের জন্য অপেক্ষা';

  @override
  String get matchStarted => 'ম্যাচ শুরু হয়েছে';

  @override
  String get matchFinished => 'ম্যাচ শেষ হয়েছে';

  @override
  String get noLegalMove => 'কোনো বৈধ চাল নেই';

  @override
  String get playerDisconnected => 'খেলোয়াড় বিচ্ছিন্ন';

  @override
  String get reconnecting => 'পুনরায় সংযোগ হচ্ছে…';

  @override
  String get connectionRestored => 'সংযোগ পুনরুদ্ধার হয়েছে';

  @override
  String get noConnection => 'কোন সংযোগ নেই';

  @override
  String get messageFailedToSend => 'বার্তা পাঠানো যায়নি';

  @override
  String get inviteSent => 'আমন্ত্রণ পাঠানো হয়েছে';

  @override
  String get playerJoined => 'খেলোয়াড় যোগ দিয়েছে';

  @override
  String get playerLeft => 'খেলোয়াড় চলে গেছে';

  @override
  String get chatHint => 'বার্তা…';

  @override
  String get chatEmpty => 'আপনার টেবিলকে হাই বলুন 👋';

  @override
  String get audioHaptics => 'অডিও ও হ্যাপটিকস';

  @override
  String get soundEffects => 'সাউন্ড এফেক্ট';

  @override
  String get music => 'সঙ্গীত';

  @override
  String get vibration => 'ভাইব্রেশন';

  @override
  String get gameplay => 'গেমপ্লে';

  @override
  String get turnAlerts => 'পালা সতর্কতা';

  @override
  String get turnAlertsSubtitle => 'আপনার পালা এলে শব্দ ও কম্পন';

  @override
  String get inGameChat => 'ইন-গেম চ্যাট';

  @override
  String get emojiReactions => 'ইমোজি প্রতিক্রিয়া';

  @override
  String get appSection => 'অ্যাপ';

  @override
  String get language => 'ভাষা';

  @override
  String get about => 'সম্পর্কে';

  @override
  String get legal => 'আইনি';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get termsOfService => 'পরিষেবার শর্তাবলী';

  @override
  String get dataDeletion => 'ডেটা ও অ্যাকাউন্ট মুছে ফেলা';

  @override
  String playerThinking(String name) {
    return '$name ভাবছে…';
  }

  @override
  String playerTurn(String name) {
    return 'পালা: $name';
  }

  @override
  String playerMove(String name) {
    return 'চাল: $name';
  }

  @override
  String tokensHome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count টি ঘুঁটি ঘরে',
      zero: 'কোনো ঘুঁটি ঘরে পৌঁছায়নি',
    );
    return '$_temp0';
  }
}
