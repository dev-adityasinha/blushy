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
  String get navSia => 'सिया';

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
  String get languageSheetTitle => 'सिया बोलते ती भाषा';

  @override
  String get languageSheetExplainer =>
      'यामुळे सिया उत्तर देते ती भाषा बदलते. उर्वरित अ‍ॅप सध्या इंग्रजीतच राहील.';

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
  String get settingsSiaAssistant => 'सिया एआय सहाय्यक';

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
  String get siaAsk => 'सियाला विचारा';

  @override
  String get siaThinking => 'सिया विचार करत आहे…';

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
  String get dashSiaInsights => 'सियाची निरीक्षणे';

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
      'अजून चिंतन करण्यासारखे काही नाही. काहीतरी लिहा, सिया ते तुम्हाला वाचून दाखवेल.';

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
      'सियाच्या निरीक्षणांसाठी क्लाउड प्रक्रियेस परवानगी द्या';

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
  String get partnerSiaDecoding => 'सिया समजून घेत आहे…';

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
  String get partnerSiaAdviceTitle => 'सियाचा नातेसंबंध सल्ला';

  @override
  String get partnerSiaAdviceExplainer =>
      'तुमच्या मनात जे आहे ते विचारा. तुमच्या जोडीदाराने शेअर करायचे ठरवलेलेच सिया पाहते.';

  @override
  String get partnerTryAgain => 'पुन्हा प्रयत्न करा';
}
