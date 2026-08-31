// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get navHome => 'होम';

  @override
  String get navCommunity => 'समुदाय';

  @override
  String get navSia => 'Dr. Docsy';

  @override
  String get navStudio => 'एम स्टूडियो';

  @override
  String get navPartner => 'पार्टनर';

  @override
  String get actionSave => 'सहेजें';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionClose => 'बंद करें';

  @override
  String get actionRetry => 'फिर कोशिश करें';

  @override
  String get actionDelete => 'हटाएं';

  @override
  String get actionShare => 'साझा करें';

  @override
  String get actionShared => 'साझा किया गया';

  @override
  String get actionAsk => 'पूछें';

  @override
  String get actionStart => 'शुरू करें';

  @override
  String get actionPause => 'रोकें';

  @override
  String get actionDone => 'पूरा हुआ';

  @override
  String get actionRefresh => 'रिफ्रेश करें';

  @override
  String get actionSignOut => 'साइन आउट';

  @override
  String get stateLoading => 'लोड हो रहा है…';

  @override
  String get stateOfflineWithCache =>
      'कनेक्ट नहीं है। आपका पिछला सहेजा गया दृश्य दिखाया जा रहा है।';

  @override
  String get stateOfflineNoCache =>
      'अभी सर्वर से संपर्क नहीं हो पा रहा। कनेक्शन वापस आते ही यह लोड हो जाएगा।';

  @override
  String get stateRefreshing => 'रिफ्रेश हो रहा है…';

  @override
  String get stateNothingYet => 'अभी तक कुछ दर्ज नहीं किया गया।';

  @override
  String get stateNotSharedWithYou => 'आपके साथ साझा नहीं किया गया।';

  @override
  String get stateCouldNotSave => 'सहेजा नहीं जा सका। कृपया फिर कोशिश करें।';

  @override
  String get languageSheetTitle => 'Dr. Docsy की भाषा';

  @override
  String get languageSheetExplainer =>
      'इससे Dr. Docsy के जवाब की भाषा बदलती है। बाकी ऐप फिलहाल अंग्रेज़ी में ही रहेगा।';

  @override
  String get privacyTitle => 'निजता और साझाकरण';

  @override
  String get privacyWhatYouReceive => 'आपको क्या मिलता है';

  @override
  String get privacyPartnerDecides =>
      'आपकी पार्टनर तय करती हैं कि इस डिवाइस पर क्या पहुंचे, एक-एक श्रेणी करके। वे इसे कभी भी बदल सकती हैं, और बदलाव आपके अगले अनुरोध पर ही लागू हो जाता है।';

  @override
  String get privacyOn => 'चालू';

  @override
  String get privacyOff => 'बंद';

  @override
  String get privacyAsked => 'पूछा गया';

  @override
  String get connectFirst => 'पहले अपनी पार्टनर से जुड़ें।';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count यादें',
      one: '1 याद',
      zero: 'अभी कोई याद नहीं',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'सेटिंग्स और निजता केंद्र';

  @override
  String get settingsSiaAssistant => 'Dr. Docsy एआई सहायक';

  @override
  String get settingsSiaAssistantSub => 'टाइपिंग सुझाव और चिंतन साथी';

  @override
  String get settingsMemoryBooks => 'स्मृति पुस्तकें';

  @override
  String get settingsMemoryBooksSub => 'साप्ताहिक और मासिक सारांश स्क्रैपबुक';

  @override
  String get settingsContentGarden => 'चिंतन उद्यान';

  @override
  String get settingsContentGardenSub =>
      'आपकी जर्नल विविधता के साथ बढ़ता उद्यान';

  @override
  String get settingsTimeCapsules => 'स्मृति टाइम कैप्सूल';

  @override
  String get settingsTimeCapsulesSub =>
      'सील की गई यादें जो आपके चुने दिन खुलती हैं';

  @override
  String get settingsReducedMotion => 'कम एनिमेशन';

  @override
  String get settingsReducedMotionSub => 'गैर-जरूरी एनिमेशन रोकें';

  @override
  String get settingsHighContrast => 'उच्च कंट्रास्ट थीम';

  @override
  String get settingsHighContrastSub =>
      'टेक्स्ट और किनारों का कंट्रास्ट बढ़ाएं';

  @override
  String get settingsLargeHandles => 'बड़े हैंडल नियंत्रण';

  @override
  String get settingsLargeHandlesSub =>
      'आसान चयन के लिए कोने के हैंडल बड़े करें';

  @override
  String get settingsDiagnostics => 'प्लेटफ़ॉर्म डायग्नोस्टिक्स';

  @override
  String get settingsDiagnosticsSub =>
      'स्टोरेज, कैश, सर्च इंडेक्स और एआई कतार की स्थिति देखें';

  @override
  String get siaAsk => 'Dr. Docsy से पूछें';

  @override
  String get siaThinking => 'Dr. Docsy सोच रही है…';

  @override
  String get siaVoiceTranscribed =>
      'आवाज़ टेक्स्ट में बदल दी गई। जांचें और भेजें।';

  @override
  String get siaNoSpeechRecognised =>
      'कोई आवाज़ पहचानी नहीं जा सकी। कृपया फिर कोशिश करें।';

  @override
  String get siaNoAudioRecorded =>
      'कोई ऑडियो रिकॉर्ड नहीं हुआ। माइक्रोफ़ोन अनुमति जांचें।';

  @override
  String get siaConversationStarters => 'बातचीत शुरू करें';

  @override
  String get siaHowFeelingToday => 'आज आप कैसा महसूस कर रही हैं?';

  @override
  String get siaEnergyLevel => 'आपकी ऊर्जा का स्तर क्या है?';

  @override
  String get siaLogSleep => 'नींद की अवधि दर्ज करें';

  @override
  String get siaLogPeriodStart => 'मासिक धर्म की शुरुआत की तारीख दर्ज करें';

  @override
  String get siaPeriodRecorded => 'मासिक धर्म की शुरुआत दर्ज कर ली गई।';

  @override
  String get siaLoggedSymptoms => 'दर्ज लक्षण और संकेत';

  @override
  String get siaLogCheckIn => 'स्वास्थ्य चेक-इन दर्ज करें';

  @override
  String get siaDailyReflection => 'दैनिक जर्नल चिंतन';

  @override
  String get siaOpenJournal => 'जर्नल खोलें';

  @override
  String get siaWriteBeforeSaving => 'सहेजने से पहले अपना चिंतन लिखें।';

  @override
  String get siaEntrySaved => 'आपकी जर्नल प्रविष्टि सहेज ली गई।';

  @override
  String get siaSaveEntry => 'प्रविष्टि सहेजें';

  @override
  String get dashHowAreYouToday => 'आज आप कैसी हैं?';

  @override
  String get dashMood => 'मनोदशा';

  @override
  String get dashEnergyLevel => 'ऊर्जा स्तर';

  @override
  String get dashFlowLevel => 'रक्तस्राव स्तर';

  @override
  String get dashNotesReflections => 'नोट्स और चिंतन';

  @override
  String get dashCheckIn => 'चेक-इन करें';

  @override
  String get dashSiaInsights => 'Dr. Docsy की टिप्पणियाँ';

  @override
  String get dashHelpful => 'उपयोगी';

  @override
  String get dashNotUseful => 'उपयोगी नहीं';

  @override
  String get dashPatternsTitle => 'चक्र के पैटर्न और टिप्पणियाँ';

  @override
  String get dashPatternNotDiagnosis =>
      'यह आपकी दर्ज की गई बातों में दिखा एक पैटर्न है, कोई निदान या कारण नहीं।';

  @override
  String get dashNothingLoggedYet =>
      'अभी कुछ दर्ज नहीं है। आप जो लिखेंगी वह यहाँ दिखेगा।';

  @override
  String get dashNoCommunityPosts => 'इस विषय पर अभी कोई पोस्ट नहीं है।';

  @override
  String get dashYourConditions => 'आपकी स्थितियाँ';

  @override
  String get dashNoReviewedArticle => 'इसके लिए अभी कोई समीक्षित लेख नहीं है।';

  @override
  String get dashPrepareSummary => 'एक सारांश तैयार करें';

  @override
  String get dashBuildMySummary => 'मेरा सारांश बनाएं';

  @override
  String get dashSummaryNotDiagnosis =>
      'आपने जो बताया और ऐप ने जो देखा, उसका रिकॉर्ड। यह निदान नहीं है।';

  @override
  String get dashLogWeight => 'वज़न दर्ज करें';

  @override
  String get dashLogPeriod => 'मासिक धर्म दर्ज करें';

  @override
  String get dashDismiss => 'हटाएं';

  @override
  String get dashNotNow => 'अभी नहीं';

  @override
  String get journalAutoSaving => 'स्वतः सहेजा जा रहा है…';

  @override
  String get journalNewMemory => 'नई याद';

  @override
  String get journalBackToHome => 'होम पर वापस';

  @override
  String get journalReadingYourEntries => 'आपने जो लिखा है उसे देखा जा रहा है…';

  @override
  String get journalNothingToReflect =>
      'अभी चिंतन के लिए कुछ नहीं है। कुछ लिखें और Dr. Docsy उसे आपको पढ़कर सुनाएगी।';

  @override
  String get journalNoMemoriesFound => 'अभी कोई याद नहीं मिली';

  @override
  String get journalNoSearchMatch => 'उस खोज से कोई प्रविष्टि नहीं मिली।';

  @override
  String get journalRecordVoiceNote => 'वॉइस नोट रिकॉर्ड करें';

  @override
  String get journalDoneRecording => 'रिकॉर्डिंग पूरी';

  @override
  String get journalAddTextBox => 'टेक्स्ट बॉक्स जोड़ें';

  @override
  String get journalPaperTheme => 'कागज़ थीम';

  @override
  String get journalFontStyle => 'फ़ॉन्ट शैली';

  @override
  String get journalApply => 'लागू करें';

  @override
  String get journalAiPrivacyControls => 'एआई और निजता नियंत्रण';

  @override
  String get journalAiPrivacySub =>
      'चुनें कि आपके जर्नल पर कौन सी एआई सुविधाएं चलें';

  @override
  String get journalTitleGeneration => 'शीर्षक सुझाव';

  @override
  String get journalSmartSearch => 'खोज और संग्रह';

  @override
  String get journalSmartSearchSub =>
      'अपनी प्रविष्टियाँ कीवर्ड और मिलते-जुलते शब्दों से खोजें';

  @override
  String get journalCloudAi => 'क्लाउड एआई';

  @override
  String get journalCloudAiSub =>
      'Dr. Docsy की टिप्पणियों के लिए क्लाउड प्रोसेसिंग की अनुमति दें';

  @override
  String get journalCloseMemoryBook => 'स्मृति पुस्तक बंद करें';

  @override
  String get journalSelectTemplate => 'जर्नल टेम्पलेट चुनें';

  @override
  String get journalCreateNew => 'नया जर्नल बनाएं';

  @override
  String get partnerNoConnection => 'कोई सक्रिय पार्टनर कनेक्शन नहीं';

  @override
  String get partnerSendInviteExplainer =>
      'अपडेट और टिप्पणियाँ साझा करना शुरू करने के लिए अपने पार्टनर को उनके ईमेल पते पर निमंत्रण भेजें।';

  @override
  String get partnerInvalidEmail => 'कृपया एक मान्य ईमेल पता दर्ज करें।';

  @override
  String get partnerInviteSent => 'निमंत्रण भेज दिया गया।';

  @override
  String get partnerInviteLinkTitle => 'साझा करने योग्य निमंत्रण लिंक';

  @override
  String get partnerHaveInviteCode => 'मेरे पास एक निमंत्रण कोड है';

  @override
  String get partnerEnterInviteCode => 'निमंत्रण कोड दर्ज करें';

  @override
  String get partnerNoPendingRequests => 'कोई लंबित अनुरोध नहीं';

  @override
  String get partnerAccept => 'स्वीकार करें';

  @override
  String get partnerDecline => 'अस्वीकार करें';

  @override
  String get partnerDisconnect => 'कनेक्शन हटाएं';

  @override
  String get partnerNoMessages => 'अभी कोई संदेश नहीं';

  @override
  String get partnerSayHello => 'बातचीत शुरू करने के लिए नमस्ते कहें।';

  @override
  String get partnerSiaDecoding => 'Dr. Docsy समझ रही है…';

  @override
  String get partnerSuggestedReply => 'सुझाया गया उत्तर';

  @override
  String get partnerUseReply => 'यह उत्तर उपयोग करें';

  @override
  String get partnerDateIdeas => 'डेट के सुझाव';

  @override
  String get partnerSharedActivities => 'साझा गतिविधियाँ';

  @override
  String get partnerLettersTitle => 'पत्र';

  @override
  String get partnerWriteLetter => 'पत्र लिखें';

  @override
  String get partnerNoLetters =>
      'अभी कोई पत्र नहीं। एक लिखें, वह यहाँ आप दोनों के लिए रखा जाएगा।';

  @override
  String get partnerMemoryBook => 'स्मृति पुस्तक';

  @override
  String get partnerNoMemories =>
      'अभी यहाँ कुछ नहीं। साथ में कोई गतिविधि पूरी करें, वह यहाँ रखी जाएगी।';

  @override
  String get partnerSiaAdviceTitle => 'Dr. Docsy की रिश्ते संबंधी सलाह';

  @override
  String get partnerSiaAdviceExplainer =>
      'जो आपके मन में है, वह पूछें। Dr. Docsy केवल वही देखती है जो आपकी पार्टनर ने साझा करना चुना है।';

  @override
  String get partnerTryAgain => 'फिर कोशिश करें';

  @override
  String homeGreetingMorning(String name) {
    return 'सुप्रभात, $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'शुभ संध्या, $name';
  }

  @override
  String get homeGreetingSubtitle => 'आज आप कैसा महसूस कर रही हैं?';

  @override
  String get dashLogFirstCheckIn => 'पहला चेक-इन दर्ज करें';

  @override
  String get dashAddCondition => 'स्थिति जोड़ें';

  @override
  String get onbContinue => 'जारी रखें';

  @override
  String get onbBack => 'वापस';

  @override
  String get onbDontRemember => 'मुझे याद नहीं';

  @override
  String get onbLetsGetIntroduced => 'आइए परिचय करें';

  @override
  String get onbCreatingSafeSpace => 'आपका सुरक्षित स्थान बना रहे हैं';

  @override
  String get onbCuratingContent => 'स्वास्थ्य सामग्री चुन रहे हैं';

  @override
  String get onbCreatingInsights => 'आपकी दैनिक जानकारी बना रहे हैं';

  @override
  String get onbPreparingDocsy => 'Dr. Docsy तैयार हो रही हैं';

  @override
  String get jrnCancel => 'रद्द करें';

  @override
  String get jrnShare => 'साझा करें';

  @override
  String get jrnDelete => 'हटाएं';

  @override
  String get jrnCouldNotTranscribe => 'उस रिकॉर्डिंग को लिखा नहीं जा सका।';

  @override
  String get jrnNothingRecognised =>
      'उस रिकॉर्डिंग में कुछ पहचाना नहीं गया। आप इसे टाइप कर सकती हैं।';

  @override
  String get jrnCouldNotChangeSharing =>
      'उस दिन की साझाकरण सेटिंग बदली नहीं जा सकी।';

  @override
  String get jrnNoLongerShared => 'अब साझा नहीं किया गया।';

  @override
  String get jrnTranscribing => 'लिखा जा रहा है…';

  @override
  String get jrnRecordingVoiceNote => 'आवाज़ रिकॉर्ड हो रही है…';

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
