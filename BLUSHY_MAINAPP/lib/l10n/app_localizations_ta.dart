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
  String get navSia => 'Docsy';

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
      'இணைப்பு இல்லை. கடைDocsyகச் சேமித்த காட்சி காண்பிக்கப்படுகிறது.';

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
  String get languageSheetTitle => 'Docsy பேசும் மொழி';

  @override
  String get languageSheetExplainer =>
      'இது Docsyவின் பதில் மொழியை மாற்றுகிறது. மற்ற பகுதிகள் தற்போதைக்கு ஆங்கிலத்திலேயே இருக்கும்.';

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
  String get settingsSiaAssistant => 'Docsy ஏஐ உதவியாளர்';

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
  String get siaAsk => 'Docsyவிடம் கேள்';

  @override
  String get siaThinking => 'Typing....';

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
  String get dashSiaInsights => 'Docsyவின் கவனிப்புகள்';

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
      'இதுவரை சிந்திக்க எதுவும் இல்லை. ஏதாவது எழுதுங்கள், Docsy அதைப் படித்துக் காட்டுவாள்.';

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
      'Docsyவின் கவனிப்புகளுக்கு கிளவுட் செயலாக்கத்தை அனுமதி';

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
  String get partnerSiaDecoding => 'Docsy புரிந்துகொள்கிறாள்…';

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
  String get partnerSiaAdviceTitle => 'Docsyவின் உறவு ஆலோசனை';

  @override
  String get partnerSiaAdviceExplainer =>
      'உங்கள் மனதில் உள்ளதைக் கேளுங்கள். உங்கள் துணை பகிரத் தேர்ந்தெடுத்ததை மட்டுமே Docsy பார்க்கிறாள்.';

  @override
  String get partnerTryAgain => 'மீண்டும் முயற்சி';

  @override
  String homeGreetingMorning(String name) {
    return 'காலை வணக்கம், $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'மதிய வணக்கம், $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'மாலை வணக்கம், $name';
  }

  @override
  String get homeGreetingSubtitle =>
      'இன்று எப்படி இருந்தாலும், நீங்கள் தனியாக இருக்க வேண்டாம்.';

  @override
  String get dashLogFirstCheckIn => 'முதல் செக்-இன் பதிவு செய்யுங்கள்';

  @override
  String get dashAddCondition => 'நிலைமையைச் சேர்க்கவும்';

  @override
  String get onbContinue => 'தொடரவும்';

  @override
  String get onbBack => 'பின்';

  @override
  String get onbDontRemember => 'எனக்கு நினைவில்லை';

  @override
  String get onbLetsGetIntroduced => 'அறிமுகம் செய்துக்கோம்';

  @override
  String get onbCreatingSafeSpace => 'உங்கள் பாதுகாப்பான இடத்தை உருவாக்குகிறது';

  @override
  String get onbCuratingContent =>
      'ஆரோக்கிய உள்ளடக்கம் தேர்ந்தெடுக்கப்படுகிறது';

  @override
  String get onbCreatingInsights => 'உங்கள் தைனிக தகவல்கள் உருவாக்கப்படுகிறது';

  @override
  String get onbPreparingDocsy => 'Docsy தயாராகிறார்';

  @override
  String get jrnCancel => 'ரத்து';

  @override
  String get jrnShare => 'பகிர்';

  @override
  String get jrnDelete => 'நீக்கு';

  @override
  String get jrnCouldNotTranscribe =>
      'அந்தப் பதிவை எழுத்தாக மாற்ற முடியவில்லை.';

  @override
  String get jrnNothingRecognised =>
      'அந்தப் பதிவில் எதுவும் அடையாளம் காணப்படவில்லை. நீங்கள் தட்டச்சு செய்யலாம்.';

  @override
  String get jrnCouldNotChangeSharing =>
      'அந்த நாளின் பகிர்வை மாற்ற முடியவில்லை.';

  @override
  String get jrnNoLongerShared => 'இனி பகிரப்படவில்லை.';

  @override
  String get jrnTranscribing => 'எழுதப்படுகிறது…';

  @override
  String get jrnRecordingVoiceNote => 'குரல் பதிவாகிறது…';

  @override
  String get csoSignOut => 'வெளியேறு';

  @override
  String get csoCancel => 'ரத்து செய்';

  @override
  String get crRecordedAgainstEverythingYou =>
      'நீங்கள் அனுமதித்த அனைத்துடனும் பதிவு செய்யப்பட்டது.';

  @override
  String get eafWhatSYourEmail => 'உங்கள் மின்னஞ்சல் என்ன?';

  @override
  String get eafCreateYourPassword => 'உங்கள் கடவுச்சொல்லை உருவாக்குங்கள்';

  @override
  String get eafCheckYourEmail => 'உங்கள் மின்னஞ்சலைப் பாருங்கள்';

  @override
  String get eafChangeEmail => 'மின்னஞ்சலை மாற்று';

  @override
  String get eafWelcomeBack => 'மீண்டும் வரவேற்கிறோம்';

  @override
  String get eafForgotPassword => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get eafResetPassword => 'கடவுச்சொல்லை மீட்டமை';

  @override
  String get eafChooseANewPassword => 'புதிய கடவுச்சொல்லைத் தேர்ந்தெடுங்கள்';

  @override
  String get oPrivacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String get oIAgreeToThe => 'நான் ஒப்புக்கொள்கிறேன் ';

  @override
  String get oTermsOfService => 'சேவை விதிமுறைகள்';

  @override
  String get oWhenIsYourBirthday => 'உங்கள் பிறந்தநாள் எப்போது?';

  @override
  String get oWhereAreYouToday => 'இன்று நீங்கள் எங்கே இருக்கிறீர்கள்?';

  @override
  String get oWhenDidYourLast => 'உங்கள் கடைசி மாதவிடாய் எப்போது தொடங்கியது?';

  @override
  String get oWhatSYourDue => 'உங்கள் எதிர்பார்க்கப்படும் பிரசவ தேதி என்ன?';

  @override
  String get oWhenWasYourBaby => 'உங்கள் குழந்தை எப்போது பிறந்தது?';

  @override
  String get oYourPreferredName => 'நீங்கள் விரும்பும் பெயர்';

  @override
  String get oWhatWouldYouLike =>
      'முதலில் எதைத் தெரிந்துகொள்ள விரும்புகிறீர்கள்?';

  @override
  String get oWhenDidYourFirst => 'உங்கள் முதல் மாதவிடாய் எப்போது தொடங்கியது?';

  @override
  String get oWhatWouldYouLike2 => 'எதில் உதவி வேண்டும்?';

  @override
  String get oHowWouldYouDescribe => 'உங்கள் சுழற்சியை எப்படி விவரிப்பீர்கள்?';

  @override
  String get oWhatWouldYouLike3 => 'Blushy எதில் உங்களுக்கு உதவ வேண்டும்?';

  @override
  String get oAreYouCurrentlyUsing =>
      'நீங்கள் தற்போது ஹார்மோன் கருத்தடை பயன்படுத்துகிறீர்களா?';

  @override
  String get oWhichConditionBestMatches =>
      'எந்த நிலை உங்கள் சூழலுக்கு மிகவும் பொருந்துகிறது?';

  @override
  String get oWhichSymptomsAffectYou =>
      'எந்த அறிகுறிகள் உங்களை அதிகம் பாதிக்கின்றன?';

  @override
  String get oAreYouCurrentlyReceiving =>
      'உங்களுக்கு தற்போது சிகிச்சை நடக்கிறதா?';

  @override
  String get oHowLongHaveYou => 'எவ்வளவு காலமாக முயற்சி செய்கிறீர்கள்?';

  @override
  String get oHowAreYouTracking => 'கருவுறுதலை எப்படிக் கண்காணிக்கிறீர்கள்?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'உங்களுக்கு தற்போது கருவுறுதல் சிகிச்சை நடக்கிறதா?';

  @override
  String get oIsThisYourFirst => 'இது உங்கள் முதல் கர்ப்பமா?';

  @override
  String get oWhatSupportWouldYou => 'எந்த வகையான ஆதரவை விரும்புகிறீர்கள்?';

  @override
  String get oHowAreYouFeeding => 'உங்கள் குழந்தைக்கு எப்படி உணவளிக்கிறீர்கள்?';

  @override
  String get oHowHaveYourPeriods =>
      'உங்கள் மாதவிடாயில் என்ன மாற்றம் ஏற்பட்டுள்ளது?';

  @override
  String get oWhatWouldYouMost => 'எதில் அதிகம் முன்னேற்றம் விரும்புகிறீர்கள்?';

  @override
  String get oHowLongHasIt => 'உங்கள் கடைசி மாதவிடாய் ஆகி எவ்வளவு காலம்?';

  @override
  String get oWhichSymptomsAffectYour =>
      'எந்த அறிகுறிகள் உங்கள் அன்றாட வாழ்வைப் பாதிக்கின்றன?';

  @override
  String get oWhatWouldYouLike4 => 'Blushy எதில் கவனம் செலுத்த வேண்டும்?';

  @override
  String get poYourPreferredName => 'நீங்கள் விரும்பும் பெயர்';

  @override
  String get sGoToSignIn => 'உள்நுழைவுக்குச் செல்';

  @override
  String get sVerifyCode => 'குறியீட்டைச் சரிபார்';

  @override
  String get sForgotPassword => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get sIAgreeToThe => 'நான் ஒப்புக்கொள்கிறேன் ';

  @override
  String get sTermsConditions => 'விதிமுறைகள் & நிபந்தனைகள்';

  @override
  String get sTerms => 'விதிமுறைகள்';

  @override
  String get sPrivacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String get cPeople => 'நபர்கள்';

  @override
  String get cSearchTitleTextTags =>
      'தலைப்பு, உரை, குறிச்சொல் அல்லது பயனர்பெயர்/மின்னஞ்சலைத் தேடுங்கள்...';

  @override
  String get cpPublish => 'வெளியிடு';

  @override
  String get cpAnInterestingTitle => 'ஒரு சுவாரஸ்யமான தலைப்பு...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'உங்கள் எண்ணங்கள், அனுபவங்கள் அல்லது கேள்விகளைப் பகிருங்கள்...';

  @override
  String get cpEGLutealMoodswings =>
      'எ.கா., லூட்டியல், மூட்ஸ்விங்ஸ், ஸ்லீப்டிப்ஸ்';

  @override
  String get pdDeleteComment => 'கருத்தை நீக்கு';

  @override
  String get pdAreYouSureYou => 'இந்தக் கருத்தை நீக்க வேண்டும் என்பது உறுதியா?';

  @override
  String get pdCancel => 'ரத்து செய்';

  @override
  String get pdDelete => 'நீக்கு';

  @override
  String get pdDeletePost => 'இடுகையை நீக்கு';

  @override
  String get pdAreYouSureYou2 => 'இந்த இடுகையை நீக்க வேண்டும் என்பது உறுதியா?';

  @override
  String get pdComments => 'கருத்துகள்';

  @override
  String get upFailedToLoadProfile => 'சுயவிவரத் தகவல்களை ஏற்ற முடியவில்லை.';

  @override
  String get upCancel => 'ரத்து செய்';

  @override
  String get upSave => 'சேமி';

  @override
  String get hDrDocsy => 'Docsy';

  @override
  String get hClose => 'மூடு';

  @override
  String get dsQuestionsToAsk => 'கேட்கக்கூடிய கேள்விகள்';

  @override
  String get umsdDailyUnifiedCheckIn => 'தினசரி ஒருங்கிணைந்த செக்-இன்';

  @override
  String get umsdCheckInSavedAnd =>
      'செக்-இன் சேமிக்கப்பட்டு உங்கள் சுயவிவரத்துடன் ஒத்திசைக்கப்பட்டது! ✨';

  @override
  String get cYourCycleLengthIs =>
      'உங்கள் சுழற்சியின் நீளம் மாறுகிறது. தினமும் அறிகுறிகளைப் பதிவு செய்யுங்கள், Docsy கணிப்புகளைச் சரிசெய்யும்.';

  @override
  String get cTrackingIsDisabledFocus =>
      'கண்காணிப்பு நிறுத்தப்பட்டுள்ளது. உங்கள் அன்றாட ஆற்றல், மனநிலை மற்றும் தூக்கத்தில் கவனம் செலுத்துங்கள்.';

  @override
  String get cYourRecommendationsAreAdapted =>
      'உங்கள் பரிந்துரைகள் உங்கள் தற்போதைய வாழ்க்கை நிலைக்கு ஏற்ப அமைக்கப்பட்டுள்ளன.';

  @override
  String get paTodaySNextStep => 'இன்றைய அடுத்த படி';

  @override
  String get smClearDrDocsyMemory => 'Docsy நினைவகத்தை அழி';

  @override
  String get scClinicalAlignment => 'மருத்துவ ஒத்திசைவு';

  @override
  String get scCurrentTrack => 'தற்போதைய பாதை';

  @override
  String get scNewTrack => 'புதிய பாதை';

  @override
  String get scKeepCurrentTrack => 'தற்போதைய பாதையை வைத்திரு';

  @override
  String get scSwitchTrack => 'பாதையை மாற்று';

  @override
  String get sqWhatWouldYouLike =>
      'முதலில் எதைத் தெரிந்துகொள்ள விரும்புகிறீர்கள்?';

  @override
  String get sqWhenDidYourFirst => 'உங்கள் முதல் மாதவிடாய் எப்போது தொடங்கியது?';

  @override
  String get sqWhatWouldYouLike2 => 'எதில் ஆதரவு வேண்டும்?';

  @override
  String get sqHowWouldYouDescribe => 'உங்கள் சுழற்சியை எப்படி விவரிப்பீர்கள்?';

  @override
  String get sqWhenDidYourLast => 'உங்கள் கடைசி மாதவிடாய் எப்போது தொடங்கியது?';

  @override
  String get sqWhatAreYourPrimary => 'உங்கள் முக்கிய நல்வாழ்வு இலக்குகள் என்ன?';

  @override
  String get sqAreYouUsingHormonal =>
      'நீங்கள் ஹார்மோன் கருத்தடை பயன்படுத்துகிறீர்களா?';

  @override
  String get sqWhichHormonalConditionS =>
      'எந்த ஹார்மோன் நிலை உங்களுக்குப் பொருந்தும்?';

  @override
  String get sqWhichSymptomsAffectYou =>
      'எந்த அறிகுறிகள் உங்களை அதிகம் பாதிக்கின்றன?';

  @override
  String get sqAreYouCurrentlyReceiving =>
      'உங்களுக்கு தற்போது சிகிச்சை நடக்கிறதா?';

  @override
  String get sqHowLongHaveYou =>
      'எவ்வளவு காலமாக கருத்தரிக்க முயற்சி செய்கிறீர்கள்?';

  @override
  String get sqHowAreYouTracking => 'கருவுறுதலை எப்படிக் கண்காணிக்கிறீர்கள்?';

  @override
  String get sqAreYouUndergoingFertility =>
      'நீங்கள் கருவுறுதல் உதவி பெறுகிறீர்களா?';

  @override
  String get sqWhatIsYourEstimated =>
      'உங்கள் எதிர்பார்க்கப்படும் பிரசவ தேதி என்ன?';

  @override
  String get sqIsThisYourFirst => 'இது உங்கள் முதல் கர்ப்பமா?';

  @override
  String get sqWhatSupportWouldYou =>
      'கர்ப்ப காலத்தில் எந்த ஆதரவை விரும்புகிறீர்கள்?';

  @override
  String get sqWhenWasYourBaby => 'உங்கள் குழந்தை எப்போது பிறந்தது?';

  @override
  String get sqHowAreYouFeeding =>
      'உங்கள் குழந்தைக்கு எப்படி உணவளிக்கிறீர்கள்?';

  @override
  String get sqWhatAreasWouldYou => 'எந்தப் பகுதிகளில் உதவி வேண்டும்?';

  @override
  String get sqHowHaveYourPeriods =>
      'உங்கள் மாதவிடாயில் என்ன மாற்றம் ஏற்பட்டுள்ளது?';

  @override
  String get sqWhatWouldYouMost =>
      'எதில் அதிகம் கவனம் செலுத்த விரும்புகிறீர்கள்?';

  @override
  String get sqHowLongHasIt => 'உங்கள் கடைசி மாதவிடாய் ஆகி எவ்வளவு காலம்?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'எந்த அறிகுறிகள் உங்கள் அன்றாட வாழ்வைப் பாதிக்கின்றன?';

  @override
  String get sqWhatAreYourTop => 'உங்கள் முக்கிய உடல்நல இலக்குகள் என்ன?';

  @override
  String get sjaRegenerate => 'மீண்டும் உருவாக்கு';

  @override
  String get jcQuickPreviewQuietMorning =>
      'முன்னோட்டம்: \"அமைதியான காலை நடை மற்றும் நண்பர்களுடன் சூடான தேநீர்.\"';

  @override
  String get stUndo => 'செயல்தவிர்';

  @override
  String get stRedo => 'மீண்டும் செய்';

  @override
  String get stBack => 'பின்';

  @override
  String get stCopy => 'நகலெடு';

  @override
  String get stDelete => 'நீக்கு';

  @override
  String get ldPrivacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String get ldTermsConditions => 'விதிமுறைகள் & நிபந்தனைகள்';

  @override
  String get ldPrivacyPolicy2 => '📜 தனியுரிமைக் கொள்கை';

  @override
  String get ldRightToErasureDelete => 'அழிக்கும் உரிமை (கணக்கை நீக்கு)';

  @override
  String get ldEmail => 'மின்னஞ்சல்';

  @override
  String get ldWebsite => 'இணையதளம்';

  @override
  String get ldTermsAndConditionsTerms =>
      '⚖️ விதிமுறைகள் மற்றும் நிபந்தனைகள் (சேவை விதிமுறைகள்)';

  @override
  String get ldUnauthorizedUse => 'அனுமதியற்ற பயன்பாடு';

  @override
  String get msNewTimeCapsule => 'புதிய டைம் கேப்சூல்';

  @override
  String get msAmIst => 'காலை 8:00 IST';

  @override
  String get msSave => 'சேமி';

  @override
  String get rspThatIsTheWhole =>
      'இதுவே முழு அமர்வு. எழுவதற்கு முன் ஒரு கணம் இருங்கள்.';

  @override
  String get pPreparingHerEmergencySchool =>
      'அவளுடைய பள்ளி அவசரக் கிட் தயாரித்தல்';

  @override
  String get pConversationStarters => ' உரையாடலைத் தொடங்கும் வழிகள்';

  @override
  String get pParentFrequentQuestions =>
      'பெற்றோரின் அடிக்கடி கேட்கும் கேள்விகள்';

  @override
  String get gBouquet => 'பூங்கொத்து';

  @override
  String get gCommunity => '🌸 யோசனைகள்';

  @override
  String get hBuildABouquet => 'பூங்கொத்து உருவாக்கு';

  @override
  String get hBuildItInBlack => 'கருப்பு-வெள்ளையில் உருவாக்கு';

  @override
  String get pHereAreGeneralWays =>
      'இன்று உங்கள் துணைக்கு ஆதரவளிக்கும் சில பொதுவான வழிகள்:';

  @override
  String get pGotIt => 'புரிந்தது';

  @override
  String get pTips => 'குறிப்புகள்';

  @override
  String get pSavePermissions => 'அனுமதிகளைச் சேமி';

  @override
  String get pReject => 'நிராகரி';

  @override
  String get pPending => 'நிலுவையில்';

  @override
  String get pShareThisInvitation => 'இந்த அழைப்பைப் பகிரவும்';

  @override
  String get pConnect => 'இணை';

  @override
  String get pLiveSynchronized => 'நேரலையில் ஒத்திசைகிறது';

  @override
  String get pCompleteCheckIn => 'செக்-இன் முடிக்கவும்';

  @override
  String get pDigitalFlowerGift => 'டிஜிட்டல் மலர் பரிசு';

  @override
  String get pAiCommunicationHub => 'AI தொடர்பு மையம்';

  @override
  String get pYourPartnerHasChosen =>
      'உங்கள் துணை தற்போது தனிப்பட்ட தகவல்களைப் பகிர வேண்டாம் என்று தேர்ந்தெடுத்துள்ளார்.';

  @override
  String get pWhatWouldYouLike => 'எதில் உதவி வேண்டும்?';

  @override
  String get phHereAreGeneralWays =>
      'இன்று உங்கள் துணைக்கு ஆதரவளிக்கும் சில பொதுவான வழிகள்:';

  @override
  String get phGotIt => 'புரிந்தது';

  @override
  String get phSeeHowICan => 'நான் எப்படி உதவ முடியும் என்று பாருங்கள்';

  @override
  String get phAllTodaySActions => 'இன்றைய அனைத்து செயல்களும் முடிந்தன! 🌸';

  @override
  String get phDrDocsy => 'Docsy';

  @override
  String get phNotSharedWithYou => 'உங்களுடன் பகிரப்படவில்லை';

  @override
  String get phConnectionEnded => 'இணைப்பு முடிந்தது';

  @override
  String get phNothingSharedRightNow => 'இப்போது எதுவும் பகிரப்படவில்லை';

  @override
  String get plConnectWithPartner => 'துணையுடன் இணை';

  @override
  String get plPairingWithYourPartner =>
      'துணையுடன் இணைந்தால் நேரலை AI தகவல்கள், நிலை கண்காணிப்பு மற்றும் Learn பக்கத்தில் ஆதரவு ஆலோசனைகள் கிடைக்கும்.';

  @override
  String get plSendInvite => 'அழைப்பு அனுப்பு';

  @override
  String get plLearnDiscover => 'கற்றுக்கொள் & அறிந்துகொள்';

  @override
  String get plConnectWithYourPartner =>
      'தனிப்பயன் Docsy AI தகவல்களுக்கு உங்கள் துணையுடன் இணையுங்கள்.';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'ஆற்றல் மற்றும் சோர்வு மாற்றங்களைப் புரிந்துகொள்ளுதல்';

  @override
  String get plMindfulCommunicationPrinciples =>
      'விழிப்புணர்வுள்ள தொடர்பின் கொள்கைகள்';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'தினசரி நீரேற்றம் மற்றும் வளர்சிதை சமநிலை';

  @override
  String get plManagingStressDailyResilience =>
      'மன அழுத்த மேலாண்மை மற்றும் அன்றாட மீள்திறன்';

  @override
  String get plBuildingHealthySleepArchitecture =>
      'ஆரோக்கியமான தூக்க அமைப்பை உருவாக்குதல்';

  @override
  String get psAskAboutHerActive =>
      'அவளுடைய தற்போதைய நிலையைப் பற்றிக் கேளுங்கள்...';

  @override
  String get puHowSharingWorks => 'பகிர்வு எப்படி வேலை செய்கிறது';

  @override
  String get puUnderstand => 'புரிந்தது';

  @override
  String get sSavesDirectlyToYour =>
      'நேரடியாக உங்கள் நாட்குறிப்பில் சேமிக்கப்படுகிறது';

  @override
  String get sLutealRecoveryActionChecklist =>
      'லூட்டியல் மீட்பு செயல் பட்டியல்';

  @override
  String get sMedicalReportPdf => 'மருத்துவ அறிக்கை / PDF';

  @override
  String get sSleep => 'தூக்கம்';

  @override
  String get sEnergy => 'ஆற்றல்';

  @override
  String get sMood => 'மனநிலை';

  @override
  String get sWriteYourThoughtsBody =>
      'உங்கள் எண்ணங்கள், உடல் உணர்வுகள் அல்லது சிந்தனைகளை இங்கே எழுதுங்கள்...';

  @override
  String get vnbVoiceReflection => 'குரல் பிரதிபலிப்பு';

  @override
  String get vnbYourVoiceTranscriptWill =>
      'உங்கள் குரலின் எழுத்து வடிவம் இங்கே தோன்றும்...';

  @override
  String get gIdeasSubtitle => 'தொடங்குவதற்குத் தயாரான பூங்கொத்துகள்.';

  @override
  String get jrnCouldNotAddPhoto =>
      'அந்தப் புகைப்படத்தைச் சேர்க்க முடியவில்லை. வேறொன்றை முயற்சிக்கவும்.';

  @override
  String get tourHomeBody =>
      'உங்கள் நாள் ஒரே பார்வையில்: சுழற்சி, செக்-இன் மற்றும் என்ன எதிர்பார்க்கலாம். நீங்கள் எப்படி உணர்கிறீர்கள் என்பதை இங்கே பதிவு செய்யுங்கள்.';

  @override
  String get tourCommunityBody =>
      'அதே அனுபவத்தைக் கடந்து செல்லும் மற்றவர்களின் கேள்விகளும் பதில்களும்.';

  @override
  String get tourSiaBody =>
      'Docsy-யிடம் எதையும் கேளுங்கள், எழுதியோ பேசியோ. நீங்கள் என்ன பதிவு செய்தீர்கள் என்பது அவளுக்குத் தெரியும்.';

  @override
  String get tourStudioBody =>
      'உங்கள் நாட்குறிப்பு, வழிகாட்டப்பட்ட மீட்பு அமர்வுகள் மற்றும் எதிர்கால உங்களுக்கு எழுதும் டைம் கேப்சூல்கள்.';

  @override
  String get tourPartnerBody =>
      'துணையை அழைத்து, அவர்கள் என்ன பார்க்கலாம் என்பதைத் தேர்ந்தெடுங்கள். நீங்கள் சொல்லும் வரை எதுவும் பகிரப்படாது.';

  @override
  String get tourSkip => 'தவிர்';

  @override
  String get tourNext => 'அடுத்து';

  @override
  String get tourDone => 'புரிந்தது';

  @override
  String get upAnonymousProfile =>
      'இது அநாமதேயமாகப் பதிவிடப்பட்டது, எனவே திறக்க சுயவிவரம் இல்லை. எழுதியவர் பெயர் தெரிவிக்க வேண்டாம் என்று தேர்ந்தெடுத்தார், அது அவர்களின் விருப்பம்.';

  @override
  String get dashFocusTopic => 'FOCUS TOPIC';

  @override
  String get dashScrollDownContinueLearning =>
      'Scroll down to Continue Learning section';

  @override
  String get dashSmallLessonsDesignedStage =>
      'Small lessons designed for your stage.';

  @override
  String get dashDailyDiscovery => 'DAILY DISCOVERY';

  @override
  String get dashSweatGlandsBecomeMore =>
      'Sweat glands become more active during puberty. Drinking plenty of water and washing daily helps keep you fresh, confident, and clean.';

  @override
  String get dashRead => 'Read';

  @override
  String get dashLinkCopiedShareFamily => 'Link copied to share with family!';

  @override
  String get dashQuestionsGirlsOftenAsk => 'Questions Girls Often Ask';

  @override
  String get dashGirls => 'Girls';

  @override
  String get dashGrowingTogether => 'Growing Together';

  @override
  String get dashSupportiveCommunityPreview => 'Supportive Community Preview';

  @override
  String get dashHowDoITrack =>
      'How do I track if I haven\'t got my period yet?';

  @override
  String get dashCanFocusLearningDischarge =>
      'You can focus on learning, discharge changes and kits here! Docsy helps guide you.';

  @override
  String get dashReadWhatOthersAre => 'Read what others are sharing';

  @override
  String get dashRealConversationsFromCommunity =>
      'Real conversations from the community, not examples.';

  @override
  String get dashRedirectingCommunitySpace =>
      'Redirecting to Community Space...';

  @override
  String get dashJoinCommunity => 'Join Community';

  @override
  String get dashSharedReading => 'SHARED READING';

  @override
  String get dashShareArticlesAboutGrowing =>
      'Share articles about growing up with your parent safely.';

  @override
  String get dashArticleSharedParentAccount =>
      'Article shared with Parent account!';

  @override
  String get dashSendParent => 'Send to Parent';

  @override
  String get dashOpeningSharedLibrary => 'Opening Shared Library...';

  @override
  String get dashSharedLibrary => 'Shared Library';

  @override
  String get dashLetSTalkWeekly => 'LET\'S TALK • WEEKLY PROMPT';

  @override
  String get dashFirstPeriodKitChecklist => 'FIRST PERIOD KIT CHECKLIST';

  @override
  String get dashSharedJourney => 'SHARED JOURNEY';

  @override
  String get dashDisplayLearningProgressCompleted =>
      'Display learning progress completed together. The child decides what is visible.';

  @override
  String get dashLearningCycleCompanion => 'Your learning cycle companion.';

  @override
  String get dashPastDays => 'PAST 30 DAYS';

  @override
  String get dashSCompletelyNormalFirst =>
      'It\'s completely normal for your first few cycles to be irregular. Your body is gently finding its own natural rhythm.';

  @override
  String get dashVoiceNote => 'Voice Note';

  @override
  String get dashMStudio => 'M Studio';

  @override
  String get dashCommunityDiscussionsStories =>
      'Community Discussions & Stories';

  @override
  String get dashQuestionsPeopleAreAsking => 'Questions people are asking';

  @override
  String get dashOpenCommunityReadReply =>
      'Open the community to read and reply.';

  @override
  String get dashTipsPeopleAreSharing => 'Tips people are sharing';

  @override
  String get dashOpenDiscussions => 'Open Discussions';

  @override
  String get dashSharedReadingParentResources =>
      'SHARED READING & PARENT RESOURCES';

  @override
  String get dashSendCycleArticlesParent =>
      'Send cycle articles to parent or consult conversation guides.';

  @override
  String get dashArticleSharedParent => 'Article shared with Parent!';

  @override
  String get dashShare => 'Share';

  @override
  String get dashOpeningParentResourceLibrary =>
      'Opening Parent Resource library...';

  @override
  String get dashGuides => 'Guides';

  @override
  String get dashConversationPrompt => 'CONVERSATION PROMPT';

  @override
  String get dashFirstPeriodKitStatus => 'FIRST PERIOD KIT STATUS';

  @override
  String get dashDocsySafetyParentNever =>
      ' Docsy Safety: Your parent never has access to your private chat logs, notes, or moods.';

  @override
  String get dashTodaySLoggedSignals => 'TODAY\'S LOGGED SIGNALS';

  @override
  String get dashLogEditPeriod => 'Log / Edit Period';

  @override
  String get dashConfirmCorrectPeriodStart =>
      'Confirm or correct your period start and end dates below.';

  @override
  String get dashPeriodStartDate => 'PERIOD START DATE';

  @override
  String get dashPeriodEndDateOptional => 'PERIOD END DATE (OPTIONAL)';

  @override
  String get dashCancel => 'Cancel';

  @override
  String get dashSave => 'Save';

  @override
  String get dashExplainInsight => 'Explain Insight';

  @override
  String get dashDocsySReflection => 'DOCSY\'S REFLECTION';

  @override
  String get dashHormonalRhythmTracker => 'Hormonal Rhythm Tracker';

  @override
  String get dashRecentCycleHistory => 'RECENT CYCLE HISTORY';

  @override
  String get dashNextPeriodMayArrive =>
      'Your next period may arrive within the next few weeks. Because your cycles vary, this is only an estimate.';

  @override
  String get dashWeightOptional => 'WEIGHT (OPTIONAL)';

  @override
  String get dashFromLogs => 'FROM YOUR LOGS';

  @override
  String get dashBlushyCanPullTogether =>
      'Blushy can pull together what you have logged over a date range you choose. You decide what stays in before you share it.';

  @override
  String get dashRecordWhatReportedWhat =>
      'A record of what you reported and what the app noticed. Not a diagnosis.';

  @override
  String get dashAiGeneratedTrendsAcross =>
      'AI-generated trends across multiple cycle logs';

  @override
  String get dashAskDocsy => 'Ask Docsy';

  @override
  String get dashWhyMatters => 'Why This Matters';

  @override
  String get dashPriority => 'Priority';

  @override
  String get dashReviewedGuidance => 'Reviewed guidance';

  @override
  String get dashDerived => 'Derived';

  @override
  String get dashFertilityJourney => 'Your Fertility Journey';

  @override
  String get dashOvulationLoggedSuccessfully =>
      'Ovulation logged successfully!';

  @override
  String get dashLogOvulation => 'Log Ovulation';

  @override
  String get dashBasalBodyTemperatureBbt => 'BASAL BODY TEMPERATURE (BBT)';

  @override
  String get dashNotesMStudio => 'NOTES & M STUDIO';

  @override
  String get dashTtcMStudioEntry => 'TTC M Studio Entry';

  @override
  String get dashSharedTimelineReminders => 'Shared Timeline & Reminders';

  @override
  String get dashEncouragingMessage => 'Encouraging Message:';

  @override
  String get dashPartnerTasksConversationStarters =>
      'PARTNER TASKS & CONVERSATION STARTERS';

  @override
  String get dashLearnMore => 'Learn More';

  @override
  String get dashKickCountDaily => 'KICK COUNT (DAILY)';

  @override
  String get dashOptionalHealthData => 'OPTIONAL HEALTH DATA';

  @override
  String get dashLogBloodPressure => 'Log Blood Pressure';

  @override
  String get dashBloodPressure => 'Blood Pressure';

  @override
  String get dashLogBloodSugar => 'Log Blood Sugar';

  @override
  String get dashBloodSugar => 'Blood Sugar';

  @override
  String get dashPregnancyMStudioEntry => 'Pregnancy M Studio Entry';

  @override
  String get dashPregnancyPrepLists => 'Pregnancy Prep & Lists';

  @override
  String get dashSharedPregnancyTimeline => 'Shared Pregnancy Timeline';

  @override
  String get dashCoordinatedChecklistsTasks =>
      'Coordinated Checklists & Tasks:';

  @override
  String get dashPostpartumMStudioEntry => 'Postpartum M Studio Entry';

  @override
  String get dashMotherBabyCoordinatedTasks => 'Mother-Baby Coordinated Tasks';

  @override
  String get dashTransitionTrackingHistory => 'Transition Tracking & History';

  @override
  String get dashViewFullHistory => 'View Full History';

  @override
  String get dashMStudioReflection => 'M Studio Reflection';

  @override
  String get dashLongTermWellnessOverview => 'Long-Term Wellness Overview';

  @override
  String get dashTodaySCheck => 'Today\'s Check-In';

  @override
  String get dashViewHealthHistory => 'View Health History';

  @override
  String get dashBloodPressureOptional => 'BLOOD PRESSURE (OPTIONAL)';

  @override
  String get dashEmpoweredPostMenopauseWellness =>
      'EMPOWERED POST-MENOPAUSE WELLNESS CARDS';

  @override
  String get dashWhyMattersEncouragesSustainable =>
      'Why This Matters: Encourages sustainable heart, joint and bone vitalities.';

  @override
  String get dashDailyLifestyleOverview => 'Daily Lifestyle Overview';

  @override
  String get dashCycleOverview => 'CYCLE OVERVIEW';

  @override
  String get dashViewWellnessHistory => 'View Wellness History';

  @override
  String get dashRecordCurrentWeightKg =>
      'Record your current weight in kg to track trends over time.';

  @override
  String get dashAiGeneratedHabitInsights => 'AI-Generated Habit Insights';

  @override
  String get dashWhyMattersSupportsOverall =>
      'Why This Matters: Supports overall physical health and emotional vitality.';

  @override
  String get languageChoiceTitle => 'உங்கள் மொழியைத் தேர்ந்தெடுங்கள்';

  @override
  String get languageChoiceSubtitle =>
      'Blushy மற்றும் Docsy இந்த மொழியில் பேசும். அமைப்புகளில் எப்போது வேண்டுமானாலும் மாற்றலாம்.';

  @override
  String get languageChoiceContinue => 'தொடரவும்';

  @override
  String get dashLogTodayCheckIn => 'இன்றைய செக்-இன் பதிவு செய்யுங்கள்';
}
