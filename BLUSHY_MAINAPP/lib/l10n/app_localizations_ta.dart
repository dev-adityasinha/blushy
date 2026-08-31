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
  String get navSia => 'Dr. Docsy';

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
      'இணைப்பு இல்லை. கடைDr. Docsyகச் சேமித்த காட்சி காண்பிக்கப்படுகிறது.';

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
  String get languageSheetTitle => 'Dr. Docsy பேசும் மொழி';

  @override
  String get languageSheetExplainer =>
      'இது Dr. Docsyவின் பதில் மொழியை மாற்றுகிறது. மற்ற பகுதிகள் தற்போதைக்கு ஆங்கிலத்திலேயே இருக்கும்.';

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
  String get settingsSiaAssistant => 'Dr. Docsy ஏஐ உதவியாளர்';

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
  String get siaAsk => 'Dr. Docsyவிடம் கேள்';

  @override
  String get siaThinking => 'Dr. Docsy யோசிக்கிறாள்…';

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
  String get dashSiaInsights => 'Dr. Docsyவின் கவனிப்புகள்';

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
      'இதுவரை சிந்திக்க எதுவும் இல்லை. ஏதாவது எழுதுங்கள், Dr. Docsy அதைப் படித்துக் காட்டுவாள்.';

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
      'Dr. Docsyவின் கவனிப்புகளுக்கு கிளவுட் செயலாக்கத்தை அனுமதி';

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
  String get partnerSiaDecoding => 'Dr. Docsy புரிந்துகொள்கிறாள்…';

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
  String get partnerSiaAdviceTitle => 'Dr. Docsyவின் உறவு ஆலோசனை';

  @override
  String get partnerSiaAdviceExplainer =>
      'உங்கள் மனதில் உள்ளதைக் கேளுங்கள். உங்கள் துணை பகிரத் தேர்ந்தெடுத்ததை மட்டுமே Dr. Docsy பார்க்கிறாள்.';

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
  String get homeGreetingSubtitle => 'இன்று எப்படி உணர்கிறீர்கள்?';

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
  String get onbPreparingDocsy => 'Dr. Docsy தயாராகிறார்';

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
  String get csoSignOut => 'Sign out';

  @override
  String get csoCancel => 'Cancel';

  @override
  String get crRecordedAgainstEverythingYou =>
      'Recorded against everything you approve.';

  @override
  String get eafWhatSYourEmail => 'What\'s your email?';

  @override
  String get eafCreateYourPassword => 'Create your password';

  @override
  String get eafCheckYourEmail => 'Check your email';

  @override
  String get eafChangeEmail => 'Change email';

  @override
  String get eafWelcomeBack => 'Welcome back';

  @override
  String get eafForgotPassword => 'Forgot password?';

  @override
  String get eafResetPassword => 'Reset Password';

  @override
  String get eafChooseANewPassword => 'Choose a New Password';

  @override
  String get oPrivacyPolicy => 'Privacy Policy';

  @override
  String get oIAgreeToThe => 'I agree to the ';

  @override
  String get oTermsOfService => 'Terms of Service';

  @override
  String get oWhenIsYourBirthday => 'When is your birthday?';

  @override
  String get oWhereAreYouToday => 'Where are you today?';

  @override
  String get oWhenDidYourLast => 'When did your last period begin?';

  @override
  String get oWhatSYourDue => 'What\'s your due date?';

  @override
  String get oWhenWasYourBaby => 'When was your baby born?';

  @override
  String get oYourPreferredName => 'Your preferred name';

  @override
  String get oWhatWouldYouLike => 'What would you like to learn first?';

  @override
  String get oWhenDidYourFirst => 'When did your first period start?';

  @override
  String get oWhatWouldYouLike2 => 'What would you like help with?';

  @override
  String get oHowWouldYouDescribe => 'How would you describe your cycle?';

  @override
  String get oWhatWouldYouLike3 => 'What would you like Blushy to help with?';

  @override
  String get oAreYouCurrentlyUsing =>
      'Are you currently using hormonal contraception?';

  @override
  String get oWhichConditionBestMatches =>
      'Which condition best matches your situation?';

  @override
  String get oWhichSymptomsAffectYou => 'Which symptoms affect you most?';

  @override
  String get oAreYouCurrentlyReceiving =>
      'Are you currently receiving treatment?';

  @override
  String get oHowLongHaveYou => 'How long have you been trying?';

  @override
  String get oHowAreYouTracking => 'How are you tracking fertility?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'Are you currently receiving fertility treatment?';

  @override
  String get oIsThisYourFirst => 'Is this your first pregnancy?';

  @override
  String get oWhatSupportWouldYou => 'What support would you like?';

  @override
  String get oHowAreYouFeeding => 'How are you feeding your baby?';

  @override
  String get oHowHaveYourPeriods => 'How have your periods changed?';

  @override
  String get oWhatWouldYouMost => 'What would you most like to improve?';

  @override
  String get oHowLongHasIt => 'How long has it been since your last period?';

  @override
  String get oWhichSymptomsAffectYour =>
      'Which symptoms affect your daily life?';

  @override
  String get oWhatWouldYouLike4 => 'What would you like Blushy to focus on?';

  @override
  String get poYourPreferredName => 'Your preferred name';

  @override
  String get sGoToSignIn => 'Go to sign in';

  @override
  String get sVerifyCode => 'Verify Code';

  @override
  String get sForgotPassword => 'Forgot password?';

  @override
  String get sIAgreeToThe => 'I agree to the ';

  @override
  String get sTermsConditions => 'Terms & Conditions';

  @override
  String get sTerms => 'Terms';

  @override
  String get sPrivacyPolicy => 'Privacy Policy';

  @override
  String get cPeople => 'People';

  @override
  String get cSearchTitleTextTags =>
      'Search title, text, tags, or username/email...';

  @override
  String get cpPublish => 'Publish';

  @override
  String get cpAnInterestingTitle => 'An interesting title...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'Share your thoughts, experiences, or questions...';

  @override
  String get cpEGLutealMoodswings => 'e.g., Luteal, MoodSwings, SleepTips';

  @override
  String get pdDeleteComment => 'Delete Comment';

  @override
  String get pdAreYouSureYou => 'Are you sure you want to delete this comment?';

  @override
  String get pdCancel => 'Cancel';

  @override
  String get pdDelete => 'Delete';

  @override
  String get pdDeletePost => 'Delete Post';

  @override
  String get pdAreYouSureYou2 => 'Are you sure you want to delete this post?';

  @override
  String get pdComments => 'Comments';

  @override
  String get upFailedToLoadProfile => 'Failed to load profile details.';

  @override
  String get upCancel => 'Cancel';

  @override
  String get upSave => 'Save';

  @override
  String get hDrDocsy => 'Dr. Docsy';

  @override
  String get hClose => 'Close';

  @override
  String get dsQuestionsToAsk => 'Questions to ask';

  @override
  String get umsdDailyUnifiedCheckIn => 'Daily Unified Check-in';

  @override
  String get umsdCheckInSavedAnd =>
      'Check-in saved and synced to your live MongoDB profile! ✨';

  @override
  String get cYourCycleLengthIs =>
      'Your cycle length is varying. Log your symptoms daily so Dr. Docsy can adjust predictions.';

  @override
  String get cTrackingIsDisabledFocus =>
      'Tracking is disabled. Focus on your daily energy, mood, and sleep.';

  @override
  String get cYourRecommendationsAreAdapted =>
      'Your recommendations are adapted to your current life stage.';

  @override
  String get paTodaySNextStep => 'TODAY\\\'S NEXT STEP';

  @override
  String get smClearDrDocsyMemory => 'Clear Dr. Docsy Memory';

  @override
  String get scClinicalAlignment => 'Clinical Alignment';

  @override
  String get scCurrentTrack => 'CURRENT TRACK';

  @override
  String get scNewTrack => 'NEW TRACK';

  @override
  String get scKeepCurrentTrack => 'Keep Current Track';

  @override
  String get scSwitchTrack => 'Switch Track';

  @override
  String get sqWhatWouldYouLike => 'What would you like to learn first?';

  @override
  String get sqWhenDidYourFirst => 'When did your first period start?';

  @override
  String get sqWhatWouldYouLike2 => 'What would you like support with?';

  @override
  String get sqHowWouldYouDescribe => 'How would you describe your cycle?';

  @override
  String get sqWhenDidYourLast => 'When did your last period start?';

  @override
  String get sqWhatAreYourPrimary => 'What are your primary wellness goals?';

  @override
  String get sqAreYouUsingHormonal => 'Are you using hormonal contraception?';

  @override
  String get sqWhichHormonalConditionS =>
      'Which hormonal condition(s) apply to you?';

  @override
  String get sqWhichSymptomsAffectYou => 'Which symptoms affect you most?';

  @override
  String get sqAreYouCurrentlyReceiving =>
      'Are you currently receiving treatment?';

  @override
  String get sqHowLongHaveYou => 'How long have you been trying to conceive?';

  @override
  String get sqHowAreYouTracking => 'How are you tracking fertility?';

  @override
  String get sqAreYouUndergoingFertility =>
      'Are you undergoing fertility assistance?';

  @override
  String get sqWhatIsYourEstimated => 'What is your estimated due date?';

  @override
  String get sqIsThisYourFirst => 'Is this your first pregnancy?';

  @override
  String get sqWhatSupportWouldYou =>
      'What support would you like during pregnancy?';

  @override
  String get sqWhenWasYourBaby => 'When was your baby born?';

  @override
  String get sqHowAreYouFeeding => 'How are you feeding your baby?';

  @override
  String get sqWhatAreasWouldYou => 'What areas would you like help with?';

  @override
  String get sqHowHaveYourPeriods => 'How have your periods changed?';

  @override
  String get sqWhatWouldYouMost => 'What would you most like to focus on?';

  @override
  String get sqHowLongHasIt => 'How long has it been since your last period?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'Which symptoms affect your daily life?';

  @override
  String get sqWhatAreYourTop => 'What are your top health goals?';

  @override
  String get sjaRegenerate => 'Regenerate';

  @override
  String get jcQuickPreviewQuietMorning =>
      'Quick Preview: \"Quiet morning walks and warm tea with friends.\"';

  @override
  String get stUndo => 'Undo';

  @override
  String get stRedo => 'Redo';

  @override
  String get stBack => 'Back';

  @override
  String get stCopy => 'Copy';

  @override
  String get stDelete => 'Delete';

  @override
  String get ldPrivacyPolicy => 'Privacy Policy';

  @override
  String get ldTermsConditions => 'Terms & Conditions';

  @override
  String get ldPrivacyPolicy2 => '📜 Privacy Policy';

  @override
  String get ldRightToErasureDelete => 'Right to Erasure (Delete Account)';

  @override
  String get ldEmail => 'Email';

  @override
  String get ldWebsite => 'Website';

  @override
  String get ldTermsAndConditionsTerms =>
      '⚖️ Terms and Conditions (Terms of Service)';

  @override
  String get ldUnauthorizedUse => 'Unauthorized Use';

  @override
  String get msNewTimeCapsule => 'New Time Capsule';

  @override
  String get msAmIst => '8:00 AM IST';

  @override
  String get msSave => 'Save';

  @override
  String get rspThatIsTheWhole =>
      'That is the whole session. Take a moment before you get up.';

  @override
  String get pPreparingHerEmergencySchool =>
      'PREPARING HER EMERGENCY SCHOOL KIT';

  @override
  String get pConversationStarters => ' CONVERSATION STARTERS';

  @override
  String get pParentFrequentQuestions => 'PARENT FREQUENT QUESTIONS';

  @override
  String get gBouquet => 'Bouquet';

  @override
  String get gCommunity => '🌸 Ideas';

  @override
  String get hBuildABouquet => 'Build a Bouquet';

  @override
  String get hBuildItInBlack => 'Build it in Black & White';

  @override
  String get pHereAreGeneralWays =>
      'Here are general ways to support your partner today:';

  @override
  String get pGotIt => 'Got it';

  @override
  String get pTips => 'Tips';

  @override
  String get pSavePermissions => 'Save Permissions';

  @override
  String get pReject => 'Reject';

  @override
  String get pPending => 'Pending';

  @override
  String get pShareThisInvitation => 'Share this invitation';

  @override
  String get pConnect => 'Connect';

  @override
  String get pLiveSynchronized => 'Live synchronized';

  @override
  String get pCompleteCheckIn => 'Complete Check-in';

  @override
  String get pDigitalFlowerGift => 'Digital Flower Gift';

  @override
  String get pAiCommunicationHub => 'AI Communication Hub';

  @override
  String get pYourPartnerHasChosen =>
      'Your partner has chosen not to share personal insights right now.';

  @override
  String get pWhatWouldYouLike => 'What would you like help with?';

  @override
  String get phHereAreGeneralWays =>
      'Here are general ways to support your partner today:';

  @override
  String get phGotIt => 'Got it';

  @override
  String get phSeeHowICan => 'See how I can help';

  @override
  String get phAllTodaySActions => 'All Today\'s Actions Completed! 🌸';

  @override
  String get phDrDocsy => 'Dr. Docsy';

  @override
  String get phNotSharedWithYou => 'Not shared with you';

  @override
  String get phConnectionEnded => 'Connection ended';

  @override
  String get phNothingSharedRightNow => 'Nothing shared right now';

  @override
  String get plConnectWithPartner => 'Connect with Partner';

  @override
  String get plPairingWithYourPartner =>
      'Pairing with your partner enables live AI insights, phase tracking, and support advice on the Learn page.';

  @override
  String get plSendInvite => 'Send Invite';

  @override
  String get plLearnDiscover => 'Learn & Discover';

  @override
  String get plConnectWithYourPartner =>
      'Connect with your partner to unlock personalized Dr. Docsy AI insights.';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'Understanding Energy & Fatigue Shifts';

  @override
  String get plMindfulCommunicationPrinciples =>
      'Mindful Communication Principles';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'Daily Hydration & Metabolic Balance';

  @override
  String get plManagingStressDailyResilience =>
      'Managing Stress & Daily Resilience';

  @override
  String get plBuildingHealthySleepArchitecture =>
      'Building Healthy Sleep Architecture';

  @override
  String get psAskAboutHerActive => 'Ask about her active stage...';

  @override
  String get puHowSharingWorks => 'How Sharing Works';

  @override
  String get puUnderstand => 'Understand';

  @override
  String get sSavesDirectlyToYour =>
      'Saves directly to your journal and MongoDB';

  @override
  String get sLutealRecoveryActionChecklist =>
      'Luteal Recovery Action Checklist';

  @override
  String get sMedicalReportPdf => 'Medical Report / PDF';

  @override
  String get sSleep => 'Sleep';

  @override
  String get sEnergy => 'Energy';

  @override
  String get sMood => 'Mood';

  @override
  String get sWriteYourThoughtsBody =>
      'Write your thoughts, body sensations, or reflections here...';

  @override
  String get vnbVoiceReflection => 'Voice Reflection';

  @override
  String get vnbYourVoiceTranscriptWill =>
      'Your voice transcript will appear here...';

  @override
  String get gIdeasSubtitle => 'Ready-made bouquets to start from.';

  @override
  String get jrnCouldNotAddPhoto =>
      'That photo could not be added. Try another one.';
}
