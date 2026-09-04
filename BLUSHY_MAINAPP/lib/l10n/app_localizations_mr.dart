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
  String get csoSignOut => 'साइन आउट करा';

  @override
  String get csoCancel => 'रद्द करा';

  @override
  String get crRecordedAgainstEverythingYou =>
      'तुम्ही मंजूर केलेल्या प्रत्येक गोष्टीसह नोंदवले.';

  @override
  String get eafWhatSYourEmail => 'तुमचा ईमेल काय आहे?';

  @override
  String get eafCreateYourPassword => 'तुमचा पासवर्ड तयार करा';

  @override
  String get eafCheckYourEmail => 'तुमचा ईमेल तपासा';

  @override
  String get eafChangeEmail => 'ईमेल बदला';

  @override
  String get eafWelcomeBack => 'पुन्हा स्वागत आहे';

  @override
  String get eafForgotPassword => 'पासवर्ड विसरलात?';

  @override
  String get eafResetPassword => 'पासवर्ड रीसेट करा';

  @override
  String get eafChooseANewPassword => 'नवीन पासवर्ड निवडा';

  @override
  String get oPrivacyPolicy => 'गोपनीयता धोरण';

  @override
  String get oIAgreeToThe => 'मी सहमत आहे ';

  @override
  String get oTermsOfService => 'सेवा अटी';

  @override
  String get oWhenIsYourBirthday => 'तुमचा वाढदिवस कधी आहे?';

  @override
  String get oWhereAreYouToday => 'आज तुम्ही कुठे आहात?';

  @override
  String get oWhenDidYourLast => 'तुमची शेवटची पाळी कधी सुरू झाली?';

  @override
  String get oWhatSYourDue => 'तुमची अपेक्षित प्रसूती तारीख काय आहे?';

  @override
  String get oWhenWasYourBaby => 'तुमचे बाळ कधी जन्मले?';

  @override
  String get oYourPreferredName => 'तुमचे पसंतीचे नाव';

  @override
  String get oWhatWouldYouLike => 'तुम्हाला सर्वप्रथम काय शिकायचे आहे?';

  @override
  String get oWhenDidYourFirst => 'तुमची पहिली पाळी कधी सुरू झाली?';

  @override
  String get oWhatWouldYouLike2 => 'तुम्हाला कशात मदत हवी आहे?';

  @override
  String get oHowWouldYouDescribe => 'तुम्ही तुमच्या चक्राचे वर्णन कसे कराल?';

  @override
  String get oWhatWouldYouLike3 => 'Blushy ने तुम्हाला कशात मदत करावी?';

  @override
  String get oAreYouCurrentlyUsing =>
      'तुम्ही सध्या हार्मोनल गर्भनिरोधक घेत आहात का?';

  @override
  String get oWhichConditionBestMatches =>
      'कोणती स्थिती तुमच्या परिस्थितीशी जुळते?';

  @override
  String get oWhichSymptomsAffectYou =>
      'कोणती लक्षणे तुम्हाला सर्वाधिक जाणवतात?';

  @override
  String get oAreYouCurrentlyReceiving => 'तुमच्यावर सध्या उपचार सुरू आहेत का?';

  @override
  String get oHowLongHaveYou => 'तुम्ही किती काळापासून प्रयत्न करत आहात?';

  @override
  String get oHowAreYouTracking => 'तुम्ही प्रजननक्षमता कशी नोंदवता?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'तुमच्यावर सध्या प्रजनन उपचार सुरू आहेत का?';

  @override
  String get oIsThisYourFirst => 'ही तुमची पहिली गर्भधारणा आहे का?';

  @override
  String get oWhatSupportWouldYou => 'तुम्हाला कोणत्या प्रकारचा आधार हवा आहे?';

  @override
  String get oHowAreYouFeeding => 'तुम्ही बाळाला कसे दूध देता?';

  @override
  String get oHowHaveYourPeriods => 'तुमच्या पाळीत काय बदल झाले आहेत?';

  @override
  String get oWhatWouldYouMost => 'तुम्हाला सर्वाधिक कशात सुधारणा हवी आहे?';

  @override
  String get oHowLongHasIt => 'तुमच्या शेवटच्या पाळीला किती काळ झाला?';

  @override
  String get oWhichSymptomsAffectYour =>
      'कोणती लक्षणे तुमच्या दैनंदिन जीवनावर परिणाम करतात?';

  @override
  String get oWhatWouldYouLike4 =>
      'Blushy ने कशावर लक्ष द्यावे असे तुम्हाला वाटते?';

  @override
  String get poYourPreferredName => 'तुमचे पसंतीचे नाव';

  @override
  String get sGoToSignIn => 'साइन इनवर जा';

  @override
  String get sVerifyCode => 'कोड पडताळा';

  @override
  String get sForgotPassword => 'पासवर्ड विसरलात?';

  @override
  String get sIAgreeToThe => 'मी सहमत आहे ';

  @override
  String get sTermsConditions => 'नियम आणि अटी';

  @override
  String get sTerms => 'अटी';

  @override
  String get sPrivacyPolicy => 'गोपनीयता धोरण';

  @override
  String get cPeople => 'लोक';

  @override
  String get cSearchTitleTextTags =>
      'शीर्षक, मजकूर, टॅग किंवा वापरकर्तानाव/ईमेल शोधा...';

  @override
  String get cpPublish => 'प्रकाशित करा';

  @override
  String get cpAnInterestingTitle => 'एक रोचक शीर्षक...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'तुमचे विचार, अनुभव किंवा प्रश्न शेअर करा...';

  @override
  String get cpEGLutealMoodswings => 'उदा., ल्युटियल, मूडस्विंग्ज, स्लीपटिप्स';

  @override
  String get pdDeleteComment => 'टिप्पणी हटवा';

  @override
  String get pdAreYouSureYou =>
      'तुम्हाला खात्री आहे की ही टिप्पणी हटवायची आहे?';

  @override
  String get pdCancel => 'रद्द करा';

  @override
  String get pdDelete => 'हटवा';

  @override
  String get pdDeletePost => 'पोस्ट हटवा';

  @override
  String get pdAreYouSureYou2 => 'तुम्हाला खात्री आहे की ही पोस्ट हटवायची आहे?';

  @override
  String get pdComments => 'टिप्पण्या';

  @override
  String get upFailedToLoadProfile => 'प्रोफाइल तपशील लोड करता आले नाहीत.';

  @override
  String get upCancel => 'रद्द करा';

  @override
  String get upSave => 'जतन करा';

  @override
  String get hDrDocsy => 'Docsy';

  @override
  String get hClose => 'बंद करा';

  @override
  String get dsQuestionsToAsk => 'विचारण्यासारखे प्रश्न';

  @override
  String get umsdDailyUnifiedCheckIn => 'दैनंदिन एकत्रित चेक-इन';

  @override
  String get umsdCheckInSavedAnd =>
      'चेक-इन जतन झाले आणि तुमच्या प्रोफाइलशी सिंक झाले! ✨';

  @override
  String get cYourCycleLengthIs =>
      'तुमच्या चक्राची लांबी बदलत आहे. रोज तुमची लक्षणे नोंदवा जेणेकरून Docsy अंदाज सुधारू शकेल.';

  @override
  String get cTrackingIsDisabledFocus =>
      'ट्रॅकिंग बंद आहे. तुमची दैनंदिन ऊर्जा, मनःस्थिती आणि झोप यावर लक्ष द्या.';

  @override
  String get cYourRecommendationsAreAdapted =>
      'तुमच्या शिफारशी तुमच्या सध्याच्या जीवनटप्प्यानुसार जुळवल्या आहेत.';

  @override
  String get paTodaySNextStep => 'आजचे पुढील पाऊल';

  @override
  String get smClearDrDocsyMemory => 'Docsy ची स्मृती साफ करा';

  @override
  String get scClinicalAlignment => 'क्लिनिकल संरेखन';

  @override
  String get scCurrentTrack => 'सध्याचा ट्रॅक';

  @override
  String get scNewTrack => 'नवीन ट्रॅक';

  @override
  String get scKeepCurrentTrack => 'सध्याचा ट्रॅक ठेवा';

  @override
  String get scSwitchTrack => 'ट्रॅक बदला';

  @override
  String get sqWhatWouldYouLike => 'तुम्हाला सर्वप्रथम काय शिकायचे आहे?';

  @override
  String get sqWhenDidYourFirst => 'तुमची पहिली पाळी कधी सुरू झाली?';

  @override
  String get sqWhatWouldYouLike2 => 'तुम्हाला कशात आधार हवा आहे?';

  @override
  String get sqHowWouldYouDescribe => 'तुम्ही तुमच्या चक्राचे वर्णन कसे कराल?';

  @override
  String get sqWhenDidYourLast => 'तुमची शेवटची पाळी कधी सुरू झाली?';

  @override
  String get sqWhatAreYourPrimary => 'तुमची मुख्य आरोग्य उद्दिष्टे कोणती आहेत?';

  @override
  String get sqAreYouUsingHormonal => 'तुम्ही हार्मोनल गर्भनिरोधक घेत आहात का?';

  @override
  String get sqWhichHormonalConditionS =>
      'कोणती हार्मोनल स्थिती तुम्हाला लागू होते?';

  @override
  String get sqWhichSymptomsAffectYou =>
      'कोणती लक्षणे तुम्हाला सर्वाधिक जाणवतात?';

  @override
  String get sqAreYouCurrentlyReceiving =>
      'तुमच्यावर सध्या उपचार सुरू आहेत का?';

  @override
  String get sqHowLongHaveYou =>
      'तुम्ही किती काळापासून गर्भधारणेचा प्रयत्न करत आहात?';

  @override
  String get sqHowAreYouTracking => 'तुम्ही प्रजननक्षमता कशी नोंदवता?';

  @override
  String get sqAreYouUndergoingFertility => 'तुम्ही प्रजनन सहाय्य घेत आहात का?';

  @override
  String get sqWhatIsYourEstimated => 'तुमची अपेक्षित प्रसूती तारीख काय आहे?';

  @override
  String get sqIsThisYourFirst => 'ही तुमची पहिली गर्भधारणा आहे का?';

  @override
  String get sqWhatSupportWouldYou =>
      'गर्भधारणेदरम्यान तुम्हाला कोणता आधार हवा आहे?';

  @override
  String get sqWhenWasYourBaby => 'तुमचे बाळ कधी जन्मले?';

  @override
  String get sqHowAreYouFeeding => 'तुम्ही बाळाला कसे दूध देता?';

  @override
  String get sqWhatAreasWouldYou => 'तुम्हाला कोणत्या क्षेत्रांत मदत हवी आहे?';

  @override
  String get sqHowHaveYourPeriods => 'तुमच्या पाळीत काय बदल झाले आहेत?';

  @override
  String get sqWhatWouldYouMost => 'तुम्हाला सर्वाधिक कशावर लक्ष द्यायचे आहे?';

  @override
  String get sqHowLongHasIt => 'तुमच्या शेवटच्या पाळीला किती काळ झाला?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'कोणती लक्षणे तुमच्या दैनंदिन जीवनावर परिणाम करतात?';

  @override
  String get sqWhatAreYourTop => 'तुमची प्रमुख आरोग्य उद्दिष्टे कोणती आहेत?';

  @override
  String get sjaRegenerate => 'पुन्हा तयार करा';

  @override
  String get jcQuickPreviewQuietMorning =>
      'झलक: \"शांत सकाळचे फिरणे आणि मित्रांसोबत गरम चहा.\"';

  @override
  String get stUndo => 'पूर्ववत करा';

  @override
  String get stRedo => 'पुन्हा करा';

  @override
  String get stBack => 'मागे';

  @override
  String get stCopy => 'कॉपी करा';

  @override
  String get stDelete => 'हटवा';

  @override
  String get ldPrivacyPolicy => 'गोपनीयता धोरण';

  @override
  String get ldTermsConditions => 'नियम आणि अटी';

  @override
  String get ldPrivacyPolicy2 => '📜 गोपनीयता धोरण';

  @override
  String get ldRightToErasureDelete => 'पुसण्याचा अधिकार (खाते हटवा)';

  @override
  String get ldEmail => 'ईमेल';

  @override
  String get ldWebsite => 'वेबसाइट';

  @override
  String get ldTermsAndConditionsTerms => '⚖️ नियम आणि अटी (सेवा अटी)';

  @override
  String get ldUnauthorizedUse => 'अनधिकृत वापर';

  @override
  String get msNewTimeCapsule => 'नवीन टाइम कॅप्सूल';

  @override
  String get msAmIst => 'सकाळी ८:०० IST';

  @override
  String get msSave => 'जतन करा';

  @override
  String get rspThatIsTheWhole =>
      'हे संपूर्ण सत्र होते. उठण्यापूर्वी क्षणभर थांबा.';

  @override
  String get pPreparingHerEmergencySchool =>
      'तिची शाळेतील आपत्कालीन किट तयार करणे';

  @override
  String get pConversationStarters => ' संवाद सुरू करण्याचे मार्ग';

  @override
  String get pParentFrequentQuestions => 'पालकांचे नेहमीचे प्रश्न';

  @override
  String get gBouquet => 'पुष्पगुच्छ';

  @override
  String get gCommunity => '🌸 कल्पना';

  @override
  String get hBuildABouquet => 'पुष्पगुच्छ तयार करा';

  @override
  String get hBuildItInBlack => 'कृष्णधवल मध्ये तयार करा';

  @override
  String get pHereAreGeneralWays =>
      'आज तुमच्या जोडीदाराला आधार देण्याचे काही सामान्य मार्ग:';

  @override
  String get pGotIt => 'समजले';

  @override
  String get pTips => 'टिपा';

  @override
  String get pSavePermissions => 'परवानग्या जतन करा';

  @override
  String get pReject => 'नाकारा';

  @override
  String get pPending => 'प्रलंबित';

  @override
  String get pShareThisInvitation => 'हे आमंत्रण शेअर करा';

  @override
  String get pConnect => 'जोडा';

  @override
  String get pLiveSynchronized => 'थेट सिंक होत आहे';

  @override
  String get pCompleteCheckIn => 'चेक-इन पूर्ण करा';

  @override
  String get pDigitalFlowerGift => 'डिजिटल फुलांची भेट';

  @override
  String get pAiCommunicationHub => 'AI संवाद केंद्र';

  @override
  String get pYourPartnerHasChosen =>
      'तुमच्या जोडीदाराने सध्या वैयक्तिक माहिती शेअर न करण्याचे ठरवले आहे.';

  @override
  String get pWhatWouldYouLike => 'तुम्हाला कशात मदत हवी आहे?';

  @override
  String get phHereAreGeneralWays =>
      'आज तुमच्या जोडीदाराला आधार देण्याचे काही सामान्य मार्ग:';

  @override
  String get phGotIt => 'समजले';

  @override
  String get phSeeHowICan => 'मी कशी मदत करू शकते ते पहा';

  @override
  String get phAllTodaySActions => 'आजची सर्व कामे पूर्ण झाली! 🌸';

  @override
  String get phDrDocsy => 'Docsy';

  @override
  String get phNotSharedWithYou => 'तुमच्यासोबत शेअर केलेले नाही';

  @override
  String get phConnectionEnded => 'कनेक्शन संपले';

  @override
  String get phNothingSharedRightNow => 'सध्या काहीही शेअर केलेले नाही';

  @override
  String get plConnectWithPartner => 'जोडीदाराशी जोडा';

  @override
  String get plPairingWithYourPartner =>
      'जोडीदाराशी जोडल्यावर थेट AI माहिती, टप्पा नोंदणी आणि Learn पानावर आधाराचे सल्ले मिळतात.';

  @override
  String get plSendInvite => 'आमंत्रण पाठवा';

  @override
  String get plLearnDiscover => 'शिका आणि जाणून घ्या';

  @override
  String get plConnectWithYourPartner =>
      'वैयक्तिक Docsy AI माहितीसाठी तुमच्या जोडीदाराशी जोडा.';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'ऊर्जा आणि थकव्यातील बदल समजून घेणे';

  @override
  String get plMindfulCommunicationPrinciples => 'सजग संवादाची तत्त्वे';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'दैनंदिन जलसंतुलन आणि चयापचय संतुलन';

  @override
  String get plManagingStressDailyResilience =>
      'तणाव व्यवस्थापन आणि दैनंदिन लवचिकता';

  @override
  String get plBuildingHealthySleepArchitecture =>
      'निरोगी झोपेची रचना तयार करणे';

  @override
  String get psAskAboutHerActive => 'तिच्या सध्याच्या टप्प्याबद्दल विचारा...';

  @override
  String get puHowSharingWorks => 'शेअरिंग कसे चालते';

  @override
  String get puUnderstand => 'समजले';

  @override
  String get sSavesDirectlyToYour => 'थेट तुमच्या जर्नलमध्ये जतन होते';

  @override
  String get sLutealRecoveryActionChecklist => 'ल्युटियल रिकव्हरी कृती यादी';

  @override
  String get sMedicalReportPdf => 'वैद्यकीय अहवाल / PDF';

  @override
  String get sSleep => 'झोप';

  @override
  String get sEnergy => 'ऊर्जा';

  @override
  String get sMood => 'मनःस्थिती';

  @override
  String get sWriteYourThoughtsBody =>
      'तुमचे विचार, शारीरिक संवेदना किंवा चिंतन इथे लिहा...';

  @override
  String get vnbVoiceReflection => 'व्हॉइस रिफ्लेक्शन';

  @override
  String get vnbYourVoiceTranscriptWill => 'तुमच्या आवाजाचे लेखन इथे दिसेल...';

  @override
  String get gIdeasSubtitle => 'सुरुवात करण्यासाठी तयार पुष्पगुच्छ.';

  @override
  String get jrnCouldNotAddPhoto => 'तो फोटो जोडता आला नाही. दुसरा वापरून पहा.';

  @override
  String get tourHomeBody =>
      'तुमचा दिवस एका नजरेत: चक्र, चेक-इन आणि पुढे काय अपेक्षित आहे. तुम्हाला कसे वाटते ते इथे नोंदवा.';

  @override
  String get tourCommunityBody =>
      'तेच अनुभव घेणाऱ्या इतर लोकांचे प्रश्न आणि उत्तरे.';

  @override
  String get tourSiaBody =>
      'Docsy ला काहीही विचारा, लिहून किंवा बोलून. तुम्ही काय नोंदवले आहे हे तिला माहीत आहे.';

  @override
  String get tourStudioBody =>
      'तुमची जर्नल, मार्गदर्शित रिकव्हरी सत्रे आणि भविष्यातील स्वतःला लिहिलेले टाइम कॅप्सूल.';

  @override
  String get tourPartnerBody =>
      'जोडीदाराला आमंत्रित करा आणि ते काय पाहू शकतात ते ठरवा. तुम्ही सांगेपर्यंत काहीही शेअर होत नाही.';

  @override
  String get tourSkip => 'वगळा';

  @override
  String get tourNext => 'पुढे';

  @override
  String get tourDone => 'समजले';

  @override
  String get upAnonymousProfile =>
      'हे निनावी पोस्ट केले होते, त्यामुळे उघडण्यासाठी प्रोफाइल नाही. लिहिणाऱ्याने नाव न देण्याचे ठरवले, आणि तो त्यांचा निर्णय आहे.';

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
  String get languageChoiceTitle => 'तुमची भाषा निवडा';

  @override
  String get languageChoiceSubtitle =>
      'Blushy आणि Docsy याच भाषेत बोलतील. तुम्ही ते सेटिंग्जमध्ये कधीही बदलू शकता.';

  @override
  String get languageChoiceContinue => 'पुढे जा';

  @override
  String get dashLogTodayCheckIn => 'आजचे चेक-इन नोंदवा';
}
