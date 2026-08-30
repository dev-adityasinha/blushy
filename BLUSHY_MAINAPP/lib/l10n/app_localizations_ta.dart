// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get navHome => 'முகப்பு';

  @override
  String get navCommunity => 'சமூகம்';

  @override
  String get navSia => 'சியா';

  @override
  String get navStudio => 'எம் ஸ்டுடியோ';

  @override
  String get navPartner => 'துணை';

  @override
  String get actionSave => 'சேமி';

  @override
  String get actionCancel => 'ரத்து செய்';

  @override
  String get actionClose => 'மூடு';

  @override
  String get actionRetry => 'மீண்டும் முயற்சி';

  @override
  String get actionDelete => 'நீக்கு';

  @override
  String get actionShare => 'பகிர்';

  @override
  String get actionShared => 'பகிரப்பட்டது';

  @override
  String get actionAsk => 'கேள்';

  @override
  String get actionStart => 'தொடங்கு';

  @override
  String get actionPause => 'இடைநிறுத்து';

  @override
  String get actionDone => 'முடிந்தது';

  @override
  String get actionRefresh => 'புதுப்பி';

  @override
  String get actionSignOut => 'வெளியேறு';

  @override
  String get stateLoading => 'ஏற்றப்படுகிறது…';

  @override
  String get stateOfflineWithCache =>
      'இணைப்பு இல்லை. கடைசியாகச் சேமித்த காட்சி காண்பிக்கப்படுகிறது.';

  @override
  String get stateOfflineNoCache =>
      'இப்போது சேவையகத்தை அடைய முடியவில்லை. இணைப்பு திரும்பியதும் இது ஏற்றப்படும்.';

  @override
  String get stateRefreshing => 'புதுப்பிக்கப்படுகிறது…';

  @override
  String get stateNothingYet => 'இதுவரை எதுவும் பதிவு செய்யப்படவில்லை.';

  @override
  String get stateNotSharedWithYou => 'உங்களுடன் பகிரப்படவில்லை.';

  @override
  String get stateCouldNotSave =>
      'சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get languageSheetTitle => 'சியா பேசும் மொழி';

  @override
  String get languageSheetExplainer =>
      'இது சியாவின் பதில் மொழியை மாற்றுகிறது. மற்ற பகுதிகள் தற்போதைக்கு ஆங்கிலத்திலேயே இருக்கும்.';

  @override
  String get privacyTitle => 'தனியுரிமை மற்றும் பகிர்வு';

  @override
  String get privacyWhatYouReceive => 'நீங்கள் பெறுவது';

  @override
  String get privacyPartnerDecides =>
      'இந்தச் சாதனத்திற்கு எது வரவேண்டும் என்பதை உங்கள் துணை ஒவ்வொரு பிரிவாகத் தீர்மானிக்கிறார். அவர் எப்போது வேண்டுமானாலும் மாற்றலாம், மாற்றம் உங்கள் அடுத்த கோரிக்கையிலேயே செயல்படும்.';

  @override
  String get privacyOn => 'இயக்கம்';

  @override
  String get privacyOff => 'அணைப்பு';

  @override
  String get privacyAsked => 'கேட்கப்பட்டது';

  @override
  String get connectFirst => 'முதலில் உங்கள் துணையுடன் இணையுங்கள்.';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நினைவுகள்',
      one: '1 நினைவு',
      zero: 'இதுவரை நினைவுகள் இல்லை',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நிமிடங்கள்',
      one: '1 நிமிடம்',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'அமைப்புகள் மற்றும் தனியுரிமை மையம்';

  @override
  String get settingsSiaAssistant => 'சியா ஏஐ உதவியாளர்';

  @override
  String get settingsSiaAssistantSub =>
      'தட்டச்சு பரிந்துரைகள் மற்றும் சிந்தனைத் துணை';

  @override
  String get settingsMemoryBooks => 'நினைவுப் புத்தகங்கள்';

  @override
  String get settingsMemoryBooksSub =>
      'வாராந்திர மற்றும் மாதாந்திர சுருக்கப் புத்தகங்கள்';

  @override
  String get settingsContentGarden => 'சிந்தனைத் தோட்டம்';

  @override
  String get settingsContentGardenSub =>
      'உங்கள் நாட்குறிப்பின் பன்முகத்தன்மையுடன் வளரும் தோட்டம்';

  @override
  String get settingsTimeCapsules => 'நினைவு டைம் கேப்சூல்கள்';

  @override
  String get settingsTimeCapsulesSub =>
      'நீங்கள் தேர்ந்தெடுத்த நாளில் திறக்கும் முத்திரையிட்ட நினைவுகள்';

  @override
  String get settingsReducedMotion => 'குறைந்த அசைவு';

  @override
  String get settingsReducedMotionSub => 'தேவையற்ற அசைவுகளை நிறுத்து';

  @override
  String get settingsHighContrast => 'அதிக மாறுபாட்டு தீம்';

  @override
  String get settingsHighContrastSub =>
      'உரை மற்றும் விளிம்புகளின் மாறுபாட்டை அதிகரி';

  @override
  String get settingsLargeHandles => 'பெரிய கைப்பிடி கட்டுப்பாடுகள்';

  @override
  String get settingsLargeHandlesSub =>
      'எளிதாகத் தேர்ந்தெடுக்க மூலைக் கைப்பிடிகளைப் பெரிதாக்கு';

  @override
  String get settingsDiagnostics => 'தள கண்டறிதல்';

  @override
  String get settingsDiagnosticsSub =>
      'சேமிப்பு, தற்காலிக சேமிப்பு, தேடல் அட்டவணை மற்றும் ஏஐ வரிசையின் நிலையைப் பார்';

  @override
  String get siaAsk => 'சியாவிடம் கேள்';

  @override
  String get siaThinking => 'சியா யோசிக்கிறாள்…';

  @override
  String get siaVoiceTranscribed =>
      'குரல் உரையாக மாற்றப்பட்டது. பார்த்துவிட்டு அனுப்பவும்.';

  @override
  String get siaNoSpeechRecognised =>
      'பேச்சு எதுவும் அடையாளம் காணப்படவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get siaNoAudioRecorded =>
      'ஒலி எதுவும் பதிவாகவில்லை. மைக்ரோஃபோன் அனுமதியைச் சரிபார்க்கவும்.';

  @override
  String get siaConversationStarters => 'உரையாடலைத் தொடங்க';

  @override
  String get siaHowFeelingToday => 'இன்று எப்படி உணர்கிறீர்கள்?';

  @override
  String get siaEnergyLevel => 'உங்கள் ஆற்றல் நிலை என்ன?';

  @override
  String get siaLogSleep => 'தூக்க நேரத்தைப் பதிவு செய்';

  @override
  String get siaLogPeriodStart => 'மாதவிடாய் தொடங்கிய தேதியைப் பதிவு செய்';

  @override
  String get siaPeriodRecorded => 'மாதவிடாய் தொடக்க தேதி பதிவு செய்யப்பட்டது.';

  @override
  String get siaLoggedSymptoms => 'பதிவு செய்யப்பட்ட அறிகுறிகள்';

  @override
  String get siaLogCheckIn => 'உடல்நல பதிவைச் சேர்';

  @override
  String get siaDailyReflection => 'தினசரி நாட்குறிப்பு சிந்தனை';

  @override
  String get siaOpenJournal => 'நாட்குறிப்பைத் திற';

  @override
  String get siaWriteBeforeSaving =>
      'சேமிப்பதற்கு முன் உங்கள் சிந்தனையை எழுதுங்கள்.';

  @override
  String get siaEntrySaved => 'உங்கள் நாட்குறிப்பு சேமிக்கப்பட்டது.';

  @override
  String get siaSaveEntry => 'பதிவைச் சேமி';

  @override
  String get dashHowAreYouToday => 'இன்று நீங்கள் எப்படி இருக்கிறீர்கள்?';

  @override
  String get dashMood => 'மனநிலை';

  @override
  String get dashEnergyLevel => 'ஆற்றல் நிலை';

  @override
  String get dashFlowLevel => 'பாய்வு அளவு';

  @override
  String get dashNotesReflections => 'குறிப்புகள் மற்றும் சிந்தனைகள்';

  @override
  String get dashCheckIn => 'பதிவு செய்';

  @override
  String get dashSiaInsights => 'சியாவின் கவனிப்புகள்';

  @override
  String get dashHelpful => 'பயனுள்ளது';

  @override
  String get dashNotUseful => 'பயனில்லை';

  @override
  String get dashPatternsTitle => 'சுழற்சி முறைகள் மற்றும் கவனிப்புகள்';

  @override
  String get dashPatternNotDiagnosis =>
      'இது நீங்கள் பதிவு செய்ததில் தெரிந்த ஒரு முறை, நோயறிதல் அல்லது காரணம் அல்ல.';

  @override
  String get dashNothingLoggedYet =>
      'இதுவரை எதுவும் பதிவாகவில்லை. நீங்கள் பதிவு செய்வது இங்கே தோன்றும்.';

  @override
  String get dashNoCommunityPosts => 'இந்தத் தலைப்பில் இதுவரை பதிவுகள் இல்லை.';

  @override
  String get dashYourConditions => 'உங்கள் நிலைமைகள்';

  @override
  String get dashNoReviewedArticle =>
      'இதற்கு இதுவரை மதிப்பாய்வு செய்யப்பட்ட கட்டுரை இல்லை.';

  @override
  String get dashPrepareSummary => 'ஒரு சுருக்கத்தைத் தயாரி';

  @override
  String get dashBuildMySummary => 'என் சுருக்கத்தை உருவாக்கு';

  @override
  String get dashSummaryNotDiagnosis =>
      'நீங்கள் தெரிவித்தது மற்றும் செயலி கவனித்ததின் பதிவு. இது நோயறிதல் அல்ல.';

  @override
  String get dashLogWeight => 'எடையைப் பதிவு செய்';

  @override
  String get dashLogPeriod => 'மாதவிடாயைப் பதிவு செய்';

  @override
  String get dashDismiss => 'நிராகரி';

  @override
  String get dashNotNow => 'இப்போது வேண்டாம்';

  @override
  String get journalAutoSaving => 'தானாகச் சேமிக்கப்படுகிறது…';

  @override
  String get journalNewMemory => 'புதிய நினைவு';

  @override
  String get journalBackToHome => 'முகப்புக்குத் திரும்பு';

  @override
  String get journalReadingYourEntries => 'நீங்கள் எழுதியதைப் பார்க்கிறோம்…';

  @override
  String get journalNothingToReflect =>
      'இதுவரை சிந்திக்க எதுவும் இல்லை. ஏதாவது எழுதுங்கள், சியா அதைப் படித்துக் காட்டுவாள்.';

  @override
  String get journalNoMemoriesFound => 'இதுவரை நினைவுகள் எதுவும் இல்லை';

  @override
  String get journalNoSearchMatch =>
      'அந்தத் தேடலுக்கு எந்தப் பதிவும் பொருந்தவில்லை.';

  @override
  String get journalRecordVoiceNote => 'குரல் குறிப்பைப் பதிவு செய்';

  @override
  String get journalDoneRecording => 'பதிவு முடிந்தது';

  @override
  String get journalAddTextBox => 'உரைப் பெட்டியைச் சேர்';

  @override
  String get journalPaperTheme => 'காகித தீம்';

  @override
  String get journalFontStyle => 'எழுத்துரு பாணி';

  @override
  String get journalApply => 'பயன்படுத்து';

  @override
  String get journalAiPrivacyControls =>
      'ஏஐ மற்றும் தனியுரிமைக் கட்டுப்பாடுகள்';

  @override
  String get journalAiPrivacySub =>
      'உங்கள் நாட்குறிப்பில் எந்த ஏஐ வசதிகள் இயங்க வேண்டும் என்பதைத் தேர்ந்தெடு';

  @override
  String get journalTitleGeneration => 'தலைப்பு பரிந்துரைகள்';

  @override
  String get journalSmartSearch => 'தேடல் மற்றும் தொகுப்புகள்';

  @override
  String get journalSmartSearchSub =>
      'முக்கியச் சொல் மற்றும் தொடர்புடைய சொற்களால் உங்கள் பதிவுகளைத் தேடு';

  @override
  String get journalCloudAi => 'கிளவுட் ஏஐ';

  @override
  String get journalCloudAiSub =>
      'சியாவின் கவனிப்புகளுக்கு கிளவுட் செயலாக்கத்தை அனுமதி';

  @override
  String get journalCloseMemoryBook => 'நினைவுப் புத்தகத்தை மூடு';

  @override
  String get journalSelectTemplate => 'நாட்குறிப்பு வார்ப்புருவைத் தேர்ந்தெடு';

  @override
  String get journalCreateNew => 'புதிய நாட்குறிப்பை உருவாக்கு';

  @override
  String get partnerNoConnection => 'செயலில் உள்ள துணை இணைப்பு இல்லை';

  @override
  String get partnerSendInviteExplainer =>
      'புதுப்பிப்புகளையும் கவனிப்புகளையும் பகிரத் தொடங்க உங்கள் துணையின் மின்னஞ்சல் முகவரிக்கு அழைப்பு அனுப்புங்கள்.';

  @override
  String get partnerInvalidEmail => 'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.';

  @override
  String get partnerInviteSent => 'அழைப்பு அனுப்பப்பட்டது.';

  @override
  String get partnerInviteLinkTitle => 'பகிரக்கூடிய அழைப்பு இணைப்பு';

  @override
  String get partnerHaveInviteCode => 'என்னிடம் அழைப்புக் குறியீடு உள்ளது';

  @override
  String get partnerEnterInviteCode => 'அழைப்புக் குறியீட்டை உள்ளிடு';

  @override
  String get partnerNoPendingRequests => 'நிலுவையில் கோரிக்கைகள் இல்லை';

  @override
  String get partnerAccept => 'ஏற்றுக்கொள்';

  @override
  String get partnerDecline => 'நிராகரி';

  @override
  String get partnerDisconnect => 'இணைப்பை நீக்கு';

  @override
  String get partnerNoMessages => 'இதுவரை செய்திகள் இல்லை';

  @override
  String get partnerSayHello => 'உரையாடலைத் தொடங்க வணக்கம் சொல்லுங்கள்.';

  @override
  String get partnerSiaDecoding => 'சியா புரிந்துகொள்கிறாள்…';

  @override
  String get partnerSuggestedReply => 'பரிந்துரைக்கப்பட்ட பதில்';

  @override
  String get partnerUseReply => 'இந்தப் பதிலைப் பயன்படுத்து';

  @override
  String get partnerDateIdeas => 'சந்திப்பு யோசனைகள்';

  @override
  String get partnerSharedActivities => 'பகிர்ந்த செயல்பாடுகள்';

  @override
  String get partnerLettersTitle => 'கடிதங்கள்';

  @override
  String get partnerWriteLetter => 'கடிதம் எழுது';

  @override
  String get partnerNoLetters =>
      'இதுவரை கடிதங்கள் இல்லை. ஒன்று எழுதுங்கள், அது இங்கே உங்கள் இருவருக்கும் வைக்கப்படும்.';

  @override
  String get partnerMemoryBook => 'நினைவுப் புத்தகம்';

  @override
  String get partnerNoMemories =>
      'இங்கே இதுவரை எதுவும் இல்லை. ஒன்றாக ஒரு செயலை முடியுங்கள், அது இங்கே வைக்கப்படும்.';

  @override
  String get partnerSiaAdviceTitle => 'சியாவின் உறவு ஆலோசனை';

  @override
  String get partnerSiaAdviceExplainer =>
      'உங்கள் மனதில் உள்ளதைக் கேளுங்கள். உங்கள் துணை பகிரத் தேர்ந்தெடுத்ததை மட்டுமே சியா பார்க்கிறாள்.';

  @override
  String get partnerTryAgain => 'மீண்டும் முயற்சி';
}
