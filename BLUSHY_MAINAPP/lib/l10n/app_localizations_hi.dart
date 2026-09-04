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
  String get navSia => 'Docsy';

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
  String get languageSheetTitle => 'Docsy की भाषा';

  @override
  String get languageSheetExplainer =>
      'इससे Docsy के जवाब की भाषा बदलती है। बाकी ऐप फिलहाल अंग्रेज़ी में ही रहेगा।';

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
  String get settingsSiaAssistant => 'Docsy एआई सहायक';

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
  String get siaAsk => 'Docsy से पूछें';

  @override
  String get siaThinking => 'Typing....';

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
  String get dashSiaInsights => 'Docsy की टिप्पणियाँ';

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
      'अभी चिंतन के लिए कुछ नहीं है। कुछ लिखें और Docsy उसे आपको पढ़कर सुनाएगी।';

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
      'Docsy की टिप्पणियों के लिए क्लाउड प्रोसेसिंग की अनुमति दें';

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
  String get partnerSiaDecoding => 'Docsy समझ रही है…';

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
  String get partnerSiaAdviceTitle => 'Docsy की रिश्ते संबंधी सलाह';

  @override
  String get partnerSiaAdviceExplainer =>
      'जो आपके मन में है, वह पूछें। Docsy केवल वही देखती है जो आपकी पार्टनर ने साझा करना चुना है।';

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
  String get homeGreetingSubtitle =>
      'आज जैसा भी हो, आपको यह अकेले नहीं करना है।';

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
  String get onbPreparingDocsy => 'Docsy तैयार हो रही हैं';

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
  String get csoSignOut => 'साइन आउट करें';

  @override
  String get csoCancel => 'रद्द करें';

  @override
  String get crRecordedAgainstEverythingYou =>
      'आपके द्वारा स्वीकृत हर चीज़ के साथ दर्ज किया गया।';

  @override
  String get eafWhatSYourEmail => 'आपका ईमेल क्या है?';

  @override
  String get eafCreateYourPassword => 'अपना पासवर्ड बनाएं';

  @override
  String get eafCheckYourEmail => 'अपना ईमेल देखें';

  @override
  String get eafChangeEmail => 'ईमेल बदलें';

  @override
  String get eafWelcomeBack => 'वापस स्वागत है';

  @override
  String get eafForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get eafResetPassword => 'पासवर्ड रीसेट करें';

  @override
  String get eafChooseANewPassword => 'नया पासवर्ड चुनें';

  @override
  String get oPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get oIAgreeToThe => 'मैं सहमत हूँ ';

  @override
  String get oTermsOfService => 'सेवा की शर्तें';

  @override
  String get oWhenIsYourBirthday => 'आपका जन्मदिन कब है?';

  @override
  String get oWhereAreYouToday => 'आज आप कहाँ हैं?';

  @override
  String get oWhenDidYourLast => 'आपका पिछला मासिक धर्म कब शुरू हुआ था?';

  @override
  String get oWhatSYourDue => 'आपकी अनुमानित प्रसव तिथि क्या है?';

  @override
  String get oWhenWasYourBaby => 'आपका शिशु कब जन्मा था?';

  @override
  String get oYourPreferredName => 'आपका पसंदीदा नाम';

  @override
  String get oWhatWouldYouLike => 'आप सबसे पहले क्या जानना चाहेंगी?';

  @override
  String get oWhenDidYourFirst => 'आपका पहला मासिक धर्म कब शुरू हुआ था?';

  @override
  String get oWhatWouldYouLike2 => 'आप किसमें मदद चाहेंगी?';

  @override
  String get oHowWouldYouDescribe => 'आप अपने चक्र का वर्णन कैसे करेंगी?';

  @override
  String get oWhatWouldYouLike3 => 'आप Blushy से किसमें मदद चाहेंगी?';

  @override
  String get oAreYouCurrentlyUsing =>
      'क्या आप अभी हार्मोनल गर्भनिरोधक ले रही हैं?';

  @override
  String get oWhichConditionBestMatches =>
      'कौन सी स्थिति आपके अनुभव से सबसे मेल खाती है?';

  @override
  String get oWhichSymptomsAffectYou =>
      'कौन से लक्षण आपको सबसे अधिक प्रभावित करते हैं?';

  @override
  String get oAreYouCurrentlyReceiving => 'क्या आपका अभी इलाज चल रहा है?';

  @override
  String get oHowLongHaveYou => 'आप कब से कोशिश कर रही हैं?';

  @override
  String get oHowAreYouTracking => 'आप प्रजनन क्षमता को कैसे ट्रैक कर रही हैं?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'क्या आपका अभी प्रजनन उपचार चल रहा है?';

  @override
  String get oIsThisYourFirst => 'क्या यह आपकी पहली गर्भावस्था है?';

  @override
  String get oWhatSupportWouldYou => 'आप किस तरह का सहयोग चाहेंगी?';

  @override
  String get oHowAreYouFeeding => 'आप अपने शिशु को कैसे दूध पिला रही हैं?';

  @override
  String get oHowHaveYourPeriods => 'आपके मासिक धर्म में क्या बदलाव आया है?';

  @override
  String get oWhatWouldYouMost => 'आप सबसे अधिक किसमें सुधार चाहेंगी?';

  @override
  String get oHowLongHasIt => 'आपके पिछले मासिक धर्म को कितना समय हो गया है?';

  @override
  String get oWhichSymptomsAffectYour =>
      'कौन से लक्षण आपके दैनिक जीवन को प्रभावित करते हैं?';

  @override
  String get oWhatWouldYouLike4 => 'आप चाहेंगी कि Blushy किस पर ध्यान दे?';

  @override
  String get poYourPreferredName => 'आपका पसंदीदा नाम';

  @override
  String get sGoToSignIn => 'साइन इन पर जाएं';

  @override
  String get sVerifyCode => 'कोड सत्यापित करें';

  @override
  String get sForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get sIAgreeToThe => 'मैं सहमत हूँ ';

  @override
  String get sTermsConditions => 'नियम और शर्तें';

  @override
  String get sTerms => 'शर्तें';

  @override
  String get sPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get cPeople => 'लोग';

  @override
  String get cSearchTitleTextTags =>
      'शीर्षक, टेक्स्ट, टैग या उपयोगकर्ता नाम/ईमेल खोजें...';

  @override
  String get cpPublish => 'प्रकाशित करें';

  @override
  String get cpAnInterestingTitle => 'एक दिलचस्प शीर्षक...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'अपने विचार, अनुभव या सवाल साझा करें...';

  @override
  String get cpEGLutealMoodswings => 'जैसे, ल्यूटियल, मूडस्विंग्स, स्लीपटिप्स';

  @override
  String get pdDeleteComment => 'टिप्पणी हटाएं';

  @override
  String get pdAreYouSureYou => 'क्या आप वाकई यह टिप्पणी हटाना चाहती हैं?';

  @override
  String get pdCancel => 'रद्द करें';

  @override
  String get pdDelete => 'हटाएं';

  @override
  String get pdDeletePost => 'पोस्ट हटाएं';

  @override
  String get pdAreYouSureYou2 => 'क्या आप वाकई यह पोस्ट हटाना चाहती हैं?';

  @override
  String get pdComments => 'टिप्पणियाँ';

  @override
  String get upFailedToLoadProfile => 'प्रोफ़ाइल विवरण लोड नहीं हो सके।';

  @override
  String get upCancel => 'रद्द करें';

  @override
  String get upSave => 'सहेजें';

  @override
  String get hDrDocsy => 'Docsy';

  @override
  String get hClose => 'बंद करें';

  @override
  String get dsQuestionsToAsk => 'पूछने लायक सवाल';

  @override
  String get umsdDailyUnifiedCheckIn => 'दैनिक एकीकृत चेक-इन';

  @override
  String get umsdCheckInSavedAnd =>
      'चेक-इन सहेजा गया और आपकी प्रोफ़ाइल से सिंक हो गया! ✨';

  @override
  String get cYourCycleLengthIs =>
      'आपके चक्र की अवधि बदल रही है। रोज़ अपने लक्षण दर्ज करें ताकि Docsy अनुमान सुधार सके।';

  @override
  String get cTrackingIsDisabledFocus =>
      'ट्रैकिंग बंद है। अपनी दैनिक ऊर्जा, मनोदशा और नींद पर ध्यान दें।';

  @override
  String get cYourRecommendationsAreAdapted =>
      'आपके सुझाव आपके मौजूदा जीवन चरण के अनुसार ढाले गए हैं।';

  @override
  String get paTodaySNextStep => 'आज का अगला कदम';

  @override
  String get smClearDrDocsyMemory => 'Docsy की मेमोरी साफ़ करें';

  @override
  String get scClinicalAlignment => 'क्लिनिकल संरेखण';

  @override
  String get scCurrentTrack => 'मौजूदा ट्रैक';

  @override
  String get scNewTrack => 'नया ट्रैक';

  @override
  String get scKeepCurrentTrack => 'मौजूदा ट्रैक रखें';

  @override
  String get scSwitchTrack => 'ट्रैक बदलें';

  @override
  String get sqWhatWouldYouLike => 'आप सबसे पहले क्या जानना चाहेंगी?';

  @override
  String get sqWhenDidYourFirst => 'आपका पहला मासिक धर्म कब शुरू हुआ था?';

  @override
  String get sqWhatWouldYouLike2 => 'आप किसमें सहयोग चाहेंगी?';

  @override
  String get sqHowWouldYouDescribe => 'आप अपने चक्र का वर्णन कैसे करेंगी?';

  @override
  String get sqWhenDidYourLast => 'आपका पिछला मासिक धर्म कब शुरू हुआ था?';

  @override
  String get sqWhatAreYourPrimary => 'आपके मुख्य स्वास्थ्य लक्ष्य क्या हैं?';

  @override
  String get sqAreYouUsingHormonal => 'क्या आप हार्मोनल गर्भनिरोधक ले रही हैं?';

  @override
  String get sqWhichHormonalConditionS =>
      'कौन सी हार्मोनल स्थिति आप पर लागू होती है?';

  @override
  String get sqWhichSymptomsAffectYou =>
      'कौन से लक्षण आपको सबसे अधिक प्रभावित करते हैं?';

  @override
  String get sqAreYouCurrentlyReceiving => 'क्या आपका अभी इलाज चल रहा है?';

  @override
  String get sqHowLongHaveYou => 'आप कब से गर्भधारण की कोशिश कर रही हैं?';

  @override
  String get sqHowAreYouTracking =>
      'आप प्रजनन क्षमता को कैसे ट्रैक कर रही हैं?';

  @override
  String get sqAreYouUndergoingFertility => 'क्या आप प्रजनन सहायता ले रही हैं?';

  @override
  String get sqWhatIsYourEstimated => 'आपकी अनुमानित प्रसव तिथि क्या है?';

  @override
  String get sqIsThisYourFirst => 'क्या यह आपकी पहली गर्भावस्था है?';

  @override
  String get sqWhatSupportWouldYou =>
      'गर्भावस्था के दौरान आप किस तरह का सहयोग चाहेंगी?';

  @override
  String get sqWhenWasYourBaby => 'आपका शिशु कब जन्मा था?';

  @override
  String get sqHowAreYouFeeding => 'आप अपने शिशु को कैसे दूध पिला रही हैं?';

  @override
  String get sqWhatAreasWouldYou => 'आप किन क्षेत्रों में मदद चाहेंगी?';

  @override
  String get sqHowHaveYourPeriods => 'आपके मासिक धर्म में क्या बदलाव आया है?';

  @override
  String get sqWhatWouldYouMost => 'आप सबसे अधिक किस पर ध्यान देना चाहेंगी?';

  @override
  String get sqHowLongHasIt => 'आपके पिछले मासिक धर्म को कितना समय हो गया है?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'कौन से लक्षण आपके दैनिक जीवन को प्रभावित करते हैं?';

  @override
  String get sqWhatAreYourTop => 'आपके प्रमुख स्वास्थ्य लक्ष्य क्या हैं?';

  @override
  String get sjaRegenerate => 'फिर से बनाएं';

  @override
  String get jcQuickPreviewQuietMorning =>
      'झलक: \"शांत सुबह की सैर और दोस्तों के साथ गर्म चाय।\"';

  @override
  String get stUndo => 'पहले जैसा करें';

  @override
  String get stRedo => 'फिर से करें';

  @override
  String get stBack => 'पीछे';

  @override
  String get stCopy => 'कॉपी करें';

  @override
  String get stDelete => 'हटाएं';

  @override
  String get ldPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get ldTermsConditions => 'नियम और शर्तें';

  @override
  String get ldPrivacyPolicy2 => '📜 गोपनीयता नीति';

  @override
  String get ldRightToErasureDelete => 'मिटाने का अधिकार (खाता हटाएं)';

  @override
  String get ldEmail => 'ईमेल';

  @override
  String get ldWebsite => 'वेबसाइट';

  @override
  String get ldTermsAndConditionsTerms => '⚖️ नियम और शर्तें (सेवा की शर्तें)';

  @override
  String get ldUnauthorizedUse => 'अनधिकृत उपयोग';

  @override
  String get msNewTimeCapsule => 'नया टाइम कैप्सूल';

  @override
  String get msAmIst => 'सुबह 8:00 बजे IST';

  @override
  String get msSave => 'सहेजें';

  @override
  String get rspThatIsTheWhole => 'यह पूरा सत्र था। उठने से पहले एक पल रुकें।';

  @override
  String get pPreparingHerEmergencySchool =>
      'उसकी स्कूल इमरजेंसी किट तैयार करना';

  @override
  String get pConversationStarters => ' बातचीत शुरू करने के तरीके';

  @override
  String get pParentFrequentQuestions => 'अभिभावकों के आम सवाल';

  @override
  String get gBouquet => 'गुलदस्ता';

  @override
  String get gCommunity => '🌸 विचार';

  @override
  String get hBuildABouquet => 'गुलदस्ता बनाएं';

  @override
  String get hBuildItInBlack => 'इसे श्वेत-श्याम में बनाएं';

  @override
  String get pHereAreGeneralWays =>
      'आज अपनी साथी का साथ देने के कुछ सामान्य तरीके:';

  @override
  String get pGotIt => 'समझ गई';

  @override
  String get pTips => 'सुझाव';

  @override
  String get pSavePermissions => 'अनुमतियाँ सहेजें';

  @override
  String get pReject => 'अस्वीकार करें';

  @override
  String get pPending => 'प्रतीक्षारत';

  @override
  String get pShareThisInvitation => 'यह निमंत्रण साझा करें';

  @override
  String get pConnect => 'जुड़ें';

  @override
  String get pLiveSynchronized => 'लाइव सिंक हो रहा है';

  @override
  String get pCompleteCheckIn => 'चेक-इन पूरा करें';

  @override
  String get pDigitalFlowerGift => 'डिजिटल फूलों का उपहार';

  @override
  String get pAiCommunicationHub => 'AI संवाद केंद्र';

  @override
  String get pYourPartnerHasChosen =>
      'आपकी साथी ने अभी निजी जानकारी साझा न करने का विकल्प चुना है।';

  @override
  String get pWhatWouldYouLike => 'आप किसमें मदद चाहेंगी?';

  @override
  String get phHereAreGeneralWays =>
      'आज अपनी साथी का साथ देने के कुछ सामान्य तरीके:';

  @override
  String get phGotIt => 'समझ गई';

  @override
  String get phSeeHowICan => 'देखें मैं कैसे मदद कर सकती हूँ';

  @override
  String get phAllTodaySActions => 'आज के सभी काम पूरे हो गए! 🌸';

  @override
  String get phDrDocsy => 'Docsy';

  @override
  String get phNotSharedWithYou => 'आपके साथ साझा नहीं किया गया';

  @override
  String get phConnectionEnded => 'कनेक्शन समाप्त हो गया';

  @override
  String get phNothingSharedRightNow => 'अभी कुछ भी साझा नहीं किया गया';

  @override
  String get plConnectWithPartner => 'साथी से जुड़ें';

  @override
  String get plPairingWithYourPartner =>
      'अपनी साथी से जुड़ने पर लाइव AI जानकारी, चरण ट्रैकिंग और Learn पेज पर सहयोग संबंधी सुझाव मिलते हैं।';

  @override
  String get plSendInvite => 'निमंत्रण भेजें';

  @override
  String get plLearnDiscover => 'सीखें और जानें';

  @override
  String get plConnectWithYourPartner =>
      'व्यक्तिगत Docsy AI जानकारी पाने के लिए अपनी साथी से जुड़ें।';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'ऊर्जा और थकान में बदलाव को समझना';

  @override
  String get plMindfulCommunicationPrinciples => 'सजग संवाद के सिद्धांत';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'दैनिक जलयोजन और चयापचय संतुलन';

  @override
  String get plManagingStressDailyResilience =>
      'तनाव प्रबंधन और दैनिक सहनशक्ति';

  @override
  String get plBuildingHealthySleepArchitecture =>
      'स्वस्थ नींद की संरचना बनाना';

  @override
  String get psAskAboutHerActive => 'उसके मौजूदा चरण के बारे में पूछें...';

  @override
  String get puHowSharingWorks => 'साझा करना कैसे काम करता है';

  @override
  String get puUnderstand => 'समझ गई';

  @override
  String get sSavesDirectlyToYour => 'सीधे आपकी जर्नल में सहेजा जाता है';

  @override
  String get sLutealRecoveryActionChecklist => 'ल्यूटियल रिकवरी कार्य सूची';

  @override
  String get sMedicalReportPdf => 'मेडिकल रिपोर्ट / PDF';

  @override
  String get sSleep => 'नींद';

  @override
  String get sEnergy => 'ऊर्जा';

  @override
  String get sMood => 'मनोदशा';

  @override
  String get sWriteYourThoughtsBody =>
      'अपने विचार, शारीरिक संवेदनाएं या चिंतन यहाँ लिखें...';

  @override
  String get vnbVoiceReflection => 'वॉइस रिफ्लेक्शन';

  @override
  String get vnbYourVoiceTranscriptWill =>
      'आपकी आवाज़ का लिखित रूप यहाँ दिखेगा...';

  @override
  String get gIdeasSubtitle => 'शुरुआत के लिए तैयार गुलदस्ते।';

  @override
  String get jrnCouldNotAddPhoto =>
      'वह फ़ोटो जोड़ी नहीं जा सकी। कोई दूसरी आज़माएं।';

  @override
  String get tourHomeBody =>
      'आपका दिन एक नज़र में: चक्र, चेक-इन और आगे क्या उम्मीद करें। यहाँ दर्ज करें कि आप कैसा महसूस कर रही हैं।';

  @override
  String get tourCommunityBody =>
      'उन्हीं अनुभवों से गुज़र रहे दूसरे लोगों के सवाल और जवाब।';

  @override
  String get tourSiaBody =>
      'Docsy से कुछ भी पूछें, लिखकर या बोलकर। उसे पता है कि आपने क्या दर्ज किया है।';

  @override
  String get tourStudioBody =>
      'आपकी जर्नल, निर्देशित रिकवरी सत्र और भविष्य की अपने लिए लिखे टाइम कैप्सूल।';

  @override
  String get tourPartnerBody =>
      'साथी को आमंत्रित करें और तय करें कि वे क्या देख सकते हैं। जब तक आप न कहें, कुछ भी साझा नहीं होता।';

  @override
  String get tourSkip => 'छोड़ें';

  @override
  String get tourNext => 'आगे';

  @override
  String get tourDone => 'समझ गई';

  @override
  String get upAnonymousProfile =>
      'यह गुमनाम रूप से पोस्ट किया गया था, इसलिए खोलने के लिए कोई प्रोफ़ाइल नहीं है। लिखने वाले ने नाम न बताने का चुनाव किया, और वह उनका चुनाव है।';

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
  String get languageChoiceTitle => 'अपनी भाषा चुनें';

  @override
  String get languageChoiceSubtitle =>
      'Blushy और Docsy इसी भाषा में बात करेंगे। आप इसे कभी भी सेटिंग्स में बदल सकती हैं।';

  @override
  String get languageChoiceContinue => 'आगे बढ़ें';

  @override
  String get dashLogTodayCheckIn => 'आज का चेक-इन दर्ज करें';
}
