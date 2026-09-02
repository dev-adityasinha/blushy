// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get navHome => 'होम';

  @override
  String get navCommunity => 'समुदाय';

  @override
  String get navSia => 'Docsy';

  @override
  String get navStudio => 'एम स्टुडिओ';

  @override
  String get navPartner => 'जोडीदार';

  @override
  String get actionSave => 'जतन करा';

  @override
  String get actionCancel => 'रद्द करा';

  @override
  String get actionClose => 'बंद करा';

  @override
  String get actionRetry => 'पुन्हा प्रयत्न करा';

  @override
  String get actionDelete => 'हटवा';

  @override
  String get actionShare => 'शेअर करा';

  @override
  String get actionShared => 'शेअर केले';

  @override
  String get actionAsk => 'विचारा';

  @override
  String get actionStart => 'सुरू करा';

  @override
  String get actionPause => 'थांबवा';

  @override
  String get actionDone => 'पूर्ण झाले';

  @override
  String get actionRefresh => 'रिफ्रेश करा';

  @override
  String get actionSignOut => 'साइन आउट';

  @override
  String get stateLoading => 'लोड होत आहे…';

  @override
  String get stateOfflineWithCache =>
      'जोडलेले नाही. तुमचे शेवटचे जतन केलेले दृश्य दाखवत आहोत.';

  @override
  String get stateOfflineNoCache =>
      'आत्ता सर्व्हरशी संपर्क होत नाही. जोडणी परत आल्यावर हे लोड होईल.';

  @override
  String get stateRefreshing => 'रिफ्रेश होत आहे…';

  @override
  String get stateNothingYet => 'अजून काहीही नोंदवलेले नाही.';

  @override
  String get stateNotSharedWithYou => 'तुमच्यासोबत शेअर केलेले नाही.';

  @override
  String get stateCouldNotSave => 'जतन करता आले नाही. पुन्हा प्रयत्न करा.';

  @override
  String get languageSheetTitle => 'Docsy बोलते ती भाषा';

  @override
  String get languageSheetExplainer =>
      'यामुळे Docsy उत्तर देते ती भाषा बदलते. उर्वरित अ‍ॅप सध्या इंग्रजीतच राहील.';

  @override
  String get privacyTitle => 'गोपनीयता आणि शेअरिंग';

  @override
  String get privacyWhatYouReceive => 'तुम्हाला काय मिळते';

  @override
  String get privacyPartnerDecides =>
      'या डिव्हाइसवर काय पोहोचावे हे तुमची जोडीदार एकेक श्रेणी ठरवते. त्या कधीही बदलू शकतात, आणि बदल तुमच्या पुढच्या विनंतीलाच लागू होतो.';

  @override
  String get privacyOn => 'चालू';

  @override
  String get privacyOff => 'बंद';

  @override
  String get privacyAsked => 'विचारले';

  @override
  String get connectFirst => 'आधी तुमच्या जोडीदाराशी जोडा.';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आठवणी',
      one: '1 आठवण',
      zero: 'अजून आठवणी नाहीत',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनिटे',
      one: '1 मिनिट',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'सेटिंग्ज आणि गोपनीयता केंद्र';

  @override
  String get settingsSiaAssistant => 'Docsy एआय सहाय्यक';

  @override
  String get settingsSiaAssistantSub => 'टायपिंग सूचना आणि चिंतन सोबती';

  @override
  String get settingsMemoryBooks => 'आठवणींची पुस्तके';

  @override
  String get settingsMemoryBooksSub => 'साप्ताहिक आणि मासिक सारांश स्क्रॅपबुक';

  @override
  String get settingsContentGarden => 'चिंतन बाग';

  @override
  String get settingsContentGardenSub =>
      'तुमच्या जर्नलच्या विविधतेसह वाढणारी बाग';

  @override
  String get settingsTimeCapsules => 'आठवणींचे टाइम कॅप्सूल';

  @override
  String get settingsTimeCapsulesSub =>
      'तुम्ही निवडलेल्या दिवशी उघडणाऱ्या सीलबंद आठवणी';

  @override
  String get settingsReducedMotion => 'कमी अ‍ॅनिमेशन';

  @override
  String get settingsReducedMotionSub => 'अनावश्यक अ‍ॅनिमेशन थांबवा';

  @override
  String get settingsHighContrast => 'उच्च कॉन्ट्रास्ट थीम';

  @override
  String get settingsHighContrastSub => 'मजकूर आणि कडांचा कॉन्ट्रास्ट वाढवा';

  @override
  String get settingsLargeHandles => 'मोठे हँडल नियंत्रण';

  @override
  String get settingsLargeHandlesSub =>
      'सोप्या निवडीसाठी कोपऱ्यातील हँडल मोठे करा';

  @override
  String get settingsDiagnostics => 'प्लॅटफॉर्म डायग्नोस्टिक्स';

  @override
  String get settingsDiagnosticsSub =>
      'स्टोरेज, कॅशे, सर्च इंडेक्स आणि एआय रांगेची स्थिती पहा';

  @override
  String get siaAsk => 'Docsyला विचारा';

  @override
  String get siaThinking => 'Typing....';

  @override
  String get siaVoiceTranscribed => 'आवाज मजकुरात बदलला. तपासा आणि पाठवा.';

  @override
  String get siaNoSpeechRecognised =>
      'बोलणे ओळखता आले नाही. पुन्हा प्रयत्न करा.';

  @override
  String get siaNoAudioRecorded =>
      'ऑडिओ रेकॉर्ड झाला नाही. मायक्रोफोन परवानगी तपासा.';

  @override
  String get siaConversationStarters => 'संवाद सुरू करा';

  @override
  String get siaHowFeelingToday => 'आज तुम्हाला कसे वाटत आहे?';

  @override
  String get siaEnergyLevel => 'तुमची ऊर्जा पातळी काय आहे?';

  @override
  String get siaLogSleep => 'झोपेचा कालावधी नोंदवा';

  @override
  String get siaLogPeriodStart => 'मासिक पाळी सुरू झाल्याची तारीख नोंदवा';

  @override
  String get siaPeriodRecorded => 'मासिक पाळी सुरू झाल्याची तारीख नोंदवली.';

  @override
  String get siaLoggedSymptoms => 'नोंदवलेली लक्षणे आणि संकेत';

  @override
  String get siaLogCheckIn => 'आरोग्य चेक-इन नोंदवा';

  @override
  String get siaDailyReflection => 'दैनंदिन जर्नल चिंतन';

  @override
  String get siaOpenJournal => 'जर्नल उघडा';

  @override
  String get siaWriteBeforeSaving => 'जतन करण्यापूर्वी तुमचे चिंतन लिहा.';

  @override
  String get siaEntrySaved => 'तुमची जर्नल नोंद जतन झाली.';

  @override
  String get siaSaveEntry => 'नोंद जतन करा';

  @override
  String get dashHowAreYouToday => 'आज तुम्ही कशा आहात?';

  @override
  String get dashMood => 'मनःस्थिती';

  @override
  String get dashEnergyLevel => 'ऊर्जा पातळी';

  @override
  String get dashFlowLevel => 'रक्तस्राव पातळी';

  @override
  String get dashNotesReflections => 'टिपा आणि चिंतन';

  @override
  String get dashCheckIn => 'चेक-इन करा';

  @override
  String get dashSiaInsights => 'Docsyची निरीक्षणे';

  @override
  String get dashHelpful => 'उपयुक्त';

  @override
  String get dashNotUseful => 'उपयुक्त नाही';

  @override
  String get dashPatternsTitle => 'चक्राचे नमुने आणि निरीक्षणे';

  @override
  String get dashPatternNotDiagnosis =>
      'हा तुम्ही नोंदवलेल्या माहितीतील नमुना आहे, निदान किंवा कारण नाही.';

  @override
  String get dashNothingLoggedYet =>
      'अजून काही नोंदवलेले नाही. तुम्ही नोंदवाल ते इथे दिसेल.';

  @override
  String get dashNoCommunityPosts => 'या विषयावर अजून कोणतीही पोस्ट नाही.';

  @override
  String get dashYourConditions => 'तुमच्या स्थिती';

  @override
  String get dashNoReviewedArticle => 'यासाठी अजून पुनरावलोकन केलेला लेख नाही.';

  @override
  String get dashPrepareSummary => 'एक सारांश तयार करा';

  @override
  String get dashBuildMySummary => 'माझा सारांश तयार करा';

  @override
  String get dashSummaryNotDiagnosis =>
      'तुम्ही सांगितलेले आणि अ‍ॅपने पाहिलेले याची नोंद. हे निदान नाही.';

  @override
  String get dashLogWeight => 'वजन नोंदवा';

  @override
  String get dashLogPeriod => 'मासिक पाळी नोंदवा';

  @override
  String get dashDismiss => 'काढून टाका';

  @override
  String get dashNotNow => 'आत्ता नको';

  @override
  String get journalAutoSaving => 'आपोआप जतन होत आहे…';

  @override
  String get journalNewMemory => 'नवीन आठवण';

  @override
  String get journalBackToHome => 'होमवर परत';

  @override
  String get journalReadingYourEntries => 'तुम्ही लिहिलेले पाहत आहोत…';

  @override
  String get journalNothingToReflect =>
      'अजून चिंतन करण्यासारखे काही नाही. काहीतरी लिहा, Docsy ते तुम्हाला वाचून दाखवेल.';

  @override
  String get journalNoMemoriesFound => 'अजून कोणतीही आठवण सापडली नाही';

  @override
  String get journalNoSearchMatch => 'त्या शोधाशी कोणतीही नोंद जुळली नाही.';

  @override
  String get journalRecordVoiceNote => 'व्हॉइस नोट रेकॉर्ड करा';

  @override
  String get journalDoneRecording => 'रेकॉर्डिंग पूर्ण';

  @override
  String get journalAddTextBox => 'मजकूर बॉक्स जोडा';

  @override
  String get journalPaperTheme => 'कागद थीम';

  @override
  String get journalFontStyle => 'फॉन्ट शैली';

  @override
  String get journalApply => 'लागू करा';

  @override
  String get journalAiPrivacyControls => 'एआय आणि गोपनीयता नियंत्रणे';

  @override
  String get journalAiPrivacySub =>
      'तुमच्या जर्नलवर कोणती एआय वैशिष्ट्ये चालावीत ते निवडा';

  @override
  String get journalTitleGeneration => 'शीर्षक सूचना';

  @override
  String get journalSmartSearch => 'शोध आणि संग्रह';

  @override
  String get journalSmartSearchSub =>
      'कीवर्ड आणि संबंधित शब्दांनी तुमच्या नोंदी शोधा';

  @override
  String get journalCloudAi => 'क्लाउड एआय';

  @override
  String get journalCloudAiSub =>
      'Docsyच्या निरीक्षणांसाठी क्लाउड प्रक्रियेस परवानगी द्या';

  @override
  String get journalCloseMemoryBook => 'आठवणींचे पुस्तक बंद करा';

  @override
  String get journalSelectTemplate => 'जर्नल टेम्पलेट निवडा';

  @override
  String get journalCreateNew => 'नवीन जर्नल तयार करा';

  @override
  String get partnerNoConnection => 'कोणतेही सक्रिय जोडीदार कनेक्शन नाही';

  @override
  String get partnerSendInviteExplainer =>
      'अपडेट्स आणि निरीक्षणे शेअर करण्यास सुरुवात करण्यासाठी तुमच्या जोडीदाराला त्यांच्या ईमेलवर आमंत्रण पाठवा.';

  @override
  String get partnerInvalidEmail => 'कृपया वैध ईमेल पत्ता प्रविष्ट करा.';

  @override
  String get partnerInviteSent => 'आमंत्रण पाठवले.';

  @override
  String get partnerInviteLinkTitle => 'शेअर करण्यायोग्य आमंत्रण दुवा';

  @override
  String get partnerHaveInviteCode => 'माझ्याकडे आमंत्रण कोड आहे';

  @override
  String get partnerEnterInviteCode => 'आमंत्रण कोड प्रविष्ट करा';

  @override
  String get partnerNoPendingRequests => 'प्रलंबित विनंत्या नाहीत';

  @override
  String get partnerAccept => 'स्वीकारा';

  @override
  String get partnerDecline => 'नाकारा';

  @override
  String get partnerDisconnect => 'कनेक्शन काढा';

  @override
  String get partnerNoMessages => 'अजून कोणतेही संदेश नाहीत';

  @override
  String get partnerSayHello => 'संवाद सुरू करण्यासाठी नमस्कार म्हणा.';

  @override
  String get partnerSiaDecoding => 'Docsy समजून घेत आहे…';

  @override
  String get partnerSuggestedReply => 'सुचवलेले उत्तर';

  @override
  String get partnerUseReply => 'हे उत्तर वापरा';

  @override
  String get partnerDateIdeas => 'डेट कल्पना';

  @override
  String get partnerSharedActivities => 'सामायिक क्रियाकलाप';

  @override
  String get partnerLettersTitle => 'पत्रे';

  @override
  String get partnerWriteLetter => 'पत्र लिहा';

  @override
  String get partnerNoLetters =>
      'अजून कोणतेही पत्र नाही. एक लिहा, ते इथे तुम्हा दोघांसाठी ठेवले जाईल.';

  @override
  String get partnerMemoryBook => 'आठवणींचे पुस्तक';

  @override
  String get partnerNoMemories =>
      'इथे अजून काही नाही. एकत्र एक क्रियाकलाप पूर्ण करा, तो इथे ठेवला जाईल.';

  @override
  String get partnerSiaAdviceTitle => 'Docsyचा नातेसंबंध सल्ला';

  @override
  String get partnerSiaAdviceExplainer =>
      'तुमच्या मनात जे आहे ते विचारा. तुमच्या जोडीदाराने शेअर करायचे ठरवलेलेच Docsy पाहते.';

  @override
  String get partnerTryAgain => 'पुन्हा प्रयत्न करा';

  @override
  String homeGreetingMorning(String name) {
    return 'सुप्रभात, $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'नमस्कार, $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'शुभ संध्याकाळ, $name';
  }

  @override
  String get homeGreetingSubtitle =>
      'आज कसेही असो, तुला हे एकटीने करायचे नाही.';

  @override
  String get dashLogFirstCheckIn => 'पहिले चेक-इन नोंदवा';

  @override
  String get dashAddCondition => 'स्थिती जोडा';

  @override
  String get onbContinue => 'पुढे चला';

  @override
  String get onbBack => 'मागे';

  @override
  String get onbDontRemember => 'मला आठवत नाही';

  @override
  String get onbLetsGetIntroduced => 'चला ओळख करूया';

  @override
  String get onbCreatingSafeSpace => 'तुमची सुरक्षित जागा तयार होत आहे';

  @override
  String get onbCuratingContent => 'आरोग्य सामग्री निवडत आहोत';

  @override
  String get onbCreatingInsights => 'तुमची दैनंदिन माहिती तयार होत आहे';

  @override
  String get onbPreparingDocsy => 'Docsy तयार होत आहे';

  @override
  String get jrnCancel => 'रद्द करा';

  @override
  String get jrnShare => 'शेअर करा';

  @override
  String get jrnDelete => 'हटवा';

  @override
  String get jrnCouldNotTranscribe => 'ते रेकॉर्डिंग लिहिता आले नाही.';

  @override
  String get jrnNothingRecognised =>
      'त्या रेकॉर्डिंगमध्ये काहीही ओळखले गेले नाही. तुम्ही टाइप करू शकता.';

  @override
  String get jrnCouldNotChangeSharing => 'त्या दिवसाची शेअरिंग बदलता आली नाही.';

  @override
  String get jrnNoLongerShared => 'आता शेअर केलेले नाही.';

  @override
  String get jrnTranscribing => 'लिहिले जात आहे…';

  @override
  String get jrnRecordingVoiceNote => 'आवाज रेकॉर्ड होत आहे…';

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
  String get hDrDocsy => 'Docsy';

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
      'Your cycle length is varying. Log your symptoms daily so Docsy can adjust predictions.';

  @override
  String get cTrackingIsDisabledFocus =>
      'Tracking is disabled. Focus on your daily energy, mood, and sleep.';

  @override
  String get cYourRecommendationsAreAdapted =>
      'Your recommendations are adapted to your current life stage.';

  @override
  String get paTodaySNextStep => 'TODAY\\\'S NEXT STEP';

  @override
  String get smClearDrDocsyMemory => 'Clear Docsy Memory';

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
  String get phDrDocsy => 'Docsy';

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
      'Connect with your partner to unlock personalized Docsy AI insights.';

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

  @override
  String get tourHomeBody =>
      'Your day at a glance: cycle, check-ins and what to expect. Log how you feel here.';

  @override
  String get tourCommunityBody =>
      'Questions and answers from other people going through the same thing.';

  @override
  String get tourSiaBody =>
      'Ask Docsy anything, by typing or by voice. She knows what you have logged.';

  @override
  String get tourStudioBody =>
      'Your journal, guided recovery sessions and time capsules you write to your future self.';

  @override
  String get tourPartnerBody =>
      'Invite a partner and choose exactly what they can see. Nothing is shared until you say so.';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourNext => 'Next';

  @override
  String get tourDone => 'Got it';

  @override
  String get upAnonymousProfile =>
      'This was posted anonymously, so there is no profile to open. Whoever wrote it chose not to be named, and that stays their choice.';
}
