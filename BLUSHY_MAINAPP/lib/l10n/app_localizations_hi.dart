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
  String get navSia => 'सिया';

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
  String get languageSheetTitle => 'सिया की भाषा';

  @override
  String get languageSheetExplainer =>
      'इससे सिया के जवाब की भाषा बदलती है। बाकी ऐप फिलहाल अंग्रेज़ी में ही रहेगा।';

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
  String get settingsSiaAssistant => 'सिया एआई सहायक';

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
  String get siaAsk => 'सिया से पूछें';

  @override
  String get siaThinking => 'सिया सोच रही है…';

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
  String get dashSiaInsights => 'सिया की टिप्पणियाँ';

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
      'अभी चिंतन के लिए कुछ नहीं है। कुछ लिखें और सिया उसे आपको पढ़कर सुनाएगी।';

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
      'सिया की टिप्पणियों के लिए क्लाउड प्रोसेसिंग की अनुमति दें';

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
  String get partnerSiaDecoding => 'सिया समझ रही है…';

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
  String get partnerSiaAdviceTitle => 'सिया की रिश्ते संबंधी सलाह';

  @override
  String get partnerSiaAdviceExplainer =>
      'जो आपके मन में है, वह पूछें। सिया केवल वही देखती है जो आपकी पार्टनर ने साझा करना चुना है।';

  @override
  String get partnerTryAgain => 'फिर कोशिश करें';
}
