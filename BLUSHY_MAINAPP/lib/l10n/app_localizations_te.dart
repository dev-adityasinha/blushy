// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get navHome => 'హోమ్';

  @override
  String get navCommunity => 'సముదాయం';

  @override
  String get navSia => 'సియా';

  @override
  String get navStudio => 'ఎం స్టూడియో';

  @override
  String get navPartner => 'భాగస్వామి';

  @override
  String get actionSave => 'సేవ్ చేయి';

  @override
  String get actionCancel => 'రద్దు చేయి';

  @override
  String get actionClose => 'మూసివేయి';

  @override
  String get actionRetry => 'మళ్లీ ప్రయత్నించు';

  @override
  String get actionDelete => 'తొలగించు';

  @override
  String get actionShare => 'పంచుకో';

  @override
  String get actionShared => 'పంచుకున్నారు';

  @override
  String get actionAsk => 'అడుగు';

  @override
  String get actionStart => 'ప్రారంభించు';

  @override
  String get actionPause => 'విరామం';

  @override
  String get actionDone => 'పూర్తయింది';

  @override
  String get actionRefresh => 'రిఫ్రెష్ చేయి';

  @override
  String get actionSignOut => 'సైన్ అవుట్';

  @override
  String get stateLoading => 'లోడ్ అవుతోంది…';

  @override
  String get stateOfflineWithCache =>
      'కనెక్షన్ లేదు. మీరు చివరిగా సేవ్ చేసిన వీక్షణ చూపుతోంది.';

  @override
  String get stateOfflineNoCache =>
      'ఇప్పుడు సర్వర్‌ను చేరుకోలేకపోతున్నాం. కనెక్షన్ తిరిగి రాగానే ఇది లోడ్ అవుతుంది.';

  @override
  String get stateRefreshing => 'రిఫ్రెష్ అవుతోంది…';

  @override
  String get stateNothingYet => 'ఇంకా ఏమీ నమోదు కాలేదు.';

  @override
  String get stateNotSharedWithYou => 'మీతో పంచుకోలేదు.';

  @override
  String get stateCouldNotSave => 'సేవ్ చేయలేకపోయాం. మళ్లీ ప్రయత్నించండి.';

  @override
  String get languageSheetTitle => 'సియా మాట్లాడే భాష';

  @override
  String get languageSheetExplainer =>
      'ఇది సియా సమాధానం ఇచ్చే భాషను మారుస్తుంది. మిగతా యాప్ ప్రస్తుతానికి ఇంగ్లీషులోనే ఉంటుంది.';

  @override
  String get privacyTitle => 'గోప్యత మరియు భాగస్వామ్యం';

  @override
  String get privacyWhatYouReceive => 'మీకు ఏమి అందుతుంది';

  @override
  String get privacyPartnerDecides =>
      'ఈ పరికరానికి ఏమి చేరాలో మీ భాగస్వామి ఒక్కో విభాగంగా నిర్ణయిస్తారు. వారు ఎప్పుడైనా మార్చవచ్చు, ఆ మార్పు మీ తదుపరి అభ్యర్థనకే అమలులోకి వస్తుంది.';

  @override
  String get privacyOn => 'ఆన్';

  @override
  String get privacyOff => 'ఆఫ్';

  @override
  String get privacyAsked => 'అడిగారు';

  @override
  String get connectFirst => 'ముందుగా మీ భాగస్వామితో కనెక్ట్ అవ్వండి.';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count జ్ఞాపకాలు',
      one: '1 జ్ఞాపకం',
      zero: 'ఇంకా జ్ఞాపకాలు లేవు',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count నిమిషాలు',
      one: '1 నిమిషం',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'సెట్టింగ్‌లు మరియు గోప్యతా కేంద్రం';

  @override
  String get settingsSiaAssistant => 'సియా ఏఐ సహాయకుడు';

  @override
  String get settingsSiaAssistantSub => 'టైపింగ్ సూచనలు మరియు ఆలోచన తోడు';

  @override
  String get settingsMemoryBooks => 'జ్ఞాపకాల పుస్తకాలు';

  @override
  String get settingsMemoryBooksSub => 'వారపు మరియు నెలవారీ సారాంశ పుస్తకాలు';

  @override
  String get settingsContentGarden => 'ఆలోచనల తోట';

  @override
  String get settingsContentGardenSub => 'మీ జర్నల్ వైవిధ్యంతో పెరిగే తోట';

  @override
  String get settingsTimeCapsules => 'జ్ఞాపకాల టైమ్ క్యాప్సూల్స్';

  @override
  String get settingsTimeCapsulesSub =>
      'మీరు ఎంచుకున్న రోజున తెరుచుకునే సీల్ చేసిన జ్ఞాపకాలు';

  @override
  String get settingsReducedMotion => 'తక్కువ కదలిక';

  @override
  String get settingsReducedMotionSub => 'అనవసర యానిమేషన్లను ఆపండి';

  @override
  String get settingsHighContrast => 'అధిక కాంట్రాస్ట్ థీమ్';

  @override
  String get settingsHighContrastSub =>
      'టెక్స్ట్ మరియు అంచుల కాంట్రాస్ట్ పెంచండి';

  @override
  String get settingsLargeHandles => 'పెద్ద హ్యాండిల్ నియంత్రణలు';

  @override
  String get settingsLargeHandlesSub =>
      'సులభంగా ఎంచుకోవడానికి మూల హ్యాండిల్స్‌ను పెద్దవి చేయండి';

  @override
  String get settingsDiagnostics => 'ప్లాట్‌ఫారమ్ డయాగ్నస్టిక్స్';

  @override
  String get settingsDiagnosticsSub =>
      'స్టోరేజ్, కాష్, సెర్చ్ ఇండెక్స్ మరియు ఏఐ క్యూ స్థితిని చూడండి';

  @override
  String get siaAsk => 'సియాను అడగండి';

  @override
  String get siaThinking => 'సియా ఆలోచిస్తోంది…';

  @override
  String get siaVoiceTranscribed =>
      'వాయిస్ టెక్స్ట్‌గా మార్చబడింది. చూసి పంపండి.';

  @override
  String get siaNoSpeechRecognised =>
      'మాట గుర్తించలేకపోయాం. మళ్లీ ప్రయత్నించండి.';

  @override
  String get siaNoAudioRecorded =>
      'ఆడియో రికార్డ్ కాలేదు. మైక్రోఫోన్ అనుమతులు తనిఖీ చేయండి.';

  @override
  String get siaConversationStarters => 'సంభాషణ ప్రారంభించండి';

  @override
  String get siaHowFeelingToday => 'ఈరోజు మీకు ఎలా అనిపిస్తోంది?';

  @override
  String get siaEnergyLevel => 'మీ శక్తి స్థాయి ఎలా ఉంది?';

  @override
  String get siaLogSleep => 'నిద్ర వ్యవధిని నమోదు చేయండి';

  @override
  String get siaLogPeriodStart => 'పీరియడ్ ప్రారంభ తేదీని నమోదు చేయండి';

  @override
  String get siaPeriodRecorded => 'పీరియడ్ ప్రారంభ తేదీ నమోదైంది.';

  @override
  String get siaLoggedSymptoms => 'నమోదు చేసిన లక్షణాలు మరియు సంకేతాలు';

  @override
  String get siaLogCheckIn => 'ఆరోగ్య చెక్-ఇన్ నమోదు చేయండి';

  @override
  String get siaDailyReflection => 'రోజువారీ జర్నల్ ఆలోచన';

  @override
  String get siaOpenJournal => 'జర్నల్ తెరవండి';

  @override
  String get siaWriteBeforeSaving => 'సేవ్ చేయడానికి ముందు మీ ఆలోచనను రాయండి.';

  @override
  String get siaEntrySaved => 'మీ జర్నల్ ఎంట్రీ సేవ్ అయింది.';

  @override
  String get siaSaveEntry => 'ఎంట్రీ సేవ్ చేయండి';

  @override
  String get dashHowAreYouToday => 'ఈరోజు మీరు ఎలా ఉన్నారు?';

  @override
  String get dashMood => 'మానసిక స్థితి';

  @override
  String get dashEnergyLevel => 'శక్తి స్థాయి';

  @override
  String get dashFlowLevel => 'ప్రవాహ స్థాయి';

  @override
  String get dashNotesReflections => 'గమనికలు మరియు ఆలోచనలు';

  @override
  String get dashCheckIn => 'చెక్-ఇన్ చేయండి';

  @override
  String get dashSiaInsights => 'సియా పరిశీలనలు';

  @override
  String get dashHelpful => 'ఉపయోగకరం';

  @override
  String get dashNotUseful => 'ఉపయోగపడలేదు';

  @override
  String get dashPatternsTitle => 'చక్ర నమూనాలు మరియు పరిశీలనలు';

  @override
  String get dashPatternNotDiagnosis =>
      'ఇది మీరు నమోదు చేసిన దానిలోని ఒక నమూనా, రోగనిర్ధారణ లేదా కారణం కాదు.';

  @override
  String get dashNothingLoggedYet =>
      'ఇంకా ఏమీ నమోదు కాలేదు. మీరు నమోదు చేసినది ఇక్కడ కనిపిస్తుంది.';

  @override
  String get dashNoCommunityPosts => 'ఈ అంశంపై ఇంకా పోస్ట్‌లు లేవు.';

  @override
  String get dashYourConditions => 'మీ పరిస్థితులు';

  @override
  String get dashNoReviewedArticle => 'దీనికి ఇంకా సమీక్షించిన వ్యాసం లేదు.';

  @override
  String get dashPrepareSummary => 'ఒక సారాంశం సిద్ధం చేయండి';

  @override
  String get dashBuildMySummary => 'నా సారాంశం రూపొందించండి';

  @override
  String get dashSummaryNotDiagnosis =>
      'మీరు తెలిపినది మరియు యాప్ గమనించినదాని రికార్డు. ఇది రోగనిర్ధారణ కాదు.';

  @override
  String get dashLogWeight => 'బరువు నమోదు చేయండి';

  @override
  String get dashLogPeriod => 'పీరియడ్ నమోదు చేయండి';

  @override
  String get dashDismiss => 'తీసివేయండి';

  @override
  String get dashNotNow => 'ఇప్పుడు వద్దు';

  @override
  String get journalAutoSaving => 'స్వయంచాలకంగా సేవ్ అవుతోంది…';

  @override
  String get journalNewMemory => 'కొత్త జ్ఞాపకం';

  @override
  String get journalBackToHome => 'హోమ్‌కు తిరిగి వెళ్లండి';

  @override
  String get journalReadingYourEntries => 'మీరు రాసినదాన్ని చూస్తున్నాం…';

  @override
  String get journalNothingToReflect =>
      'ఇంకా ఆలోచించడానికి ఏమీ లేదు. ఏదైనా రాయండి, సియా దాన్ని మీకు చదివి వినిపిస్తుంది.';

  @override
  String get journalNoMemoriesFound => 'ఇంకా జ్ఞాపకాలు ఏవీ లేవు';

  @override
  String get journalNoSearchMatch => 'ఆ శోధనకు ఏ ఎంట్రీ సరిపోలలేదు.';

  @override
  String get journalRecordVoiceNote => 'వాయిస్ నోట్ రికార్డ్ చేయండి';

  @override
  String get journalDoneRecording => 'రికార్డింగ్ పూర్తయింది';

  @override
  String get journalAddTextBox => 'టెక్స్ట్ బాక్స్ జోడించండి';

  @override
  String get journalPaperTheme => 'కాగితం థీమ్';

  @override
  String get journalFontStyle => 'ఫాంట్ శైలి';

  @override
  String get journalApply => 'వర్తింపజేయండి';

  @override
  String get journalAiPrivacyControls => 'ఏఐ మరియు గోప్యతా నియంత్రణలు';

  @override
  String get journalAiPrivacySub =>
      'మీ జర్నల్‌పై ఏ ఏఐ ఫీచర్లు నడవాలో ఎంచుకోండి';

  @override
  String get journalTitleGeneration => 'శీర్షిక సూచనలు';

  @override
  String get journalSmartSearch => 'శోధన మరియు సేకరణలు';

  @override
  String get journalSmartSearchSub =>
      'కీవర్డ్ మరియు సంబంధిత పదాలతో మీ ఎంట్రీలను వెతకండి';

  @override
  String get journalCloudAi => 'క్లౌడ్ ఏఐ';

  @override
  String get journalCloudAiSub =>
      'సియా పరిశీలనల కోసం క్లౌడ్ ప్రాసెసింగ్‌ను అనుమతించండి';

  @override
  String get journalCloseMemoryBook => 'జ్ఞాపకాల పుస్తకాన్ని మూసివేయండి';

  @override
  String get journalSelectTemplate => 'జర్నల్ టెంప్లేట్ ఎంచుకోండి';

  @override
  String get journalCreateNew => 'కొత్త జర్నల్ సృష్టించండి';

  @override
  String get partnerNoConnection => 'క్రియాశీల భాగస్వామి కనెక్షన్ లేదు';

  @override
  String get partnerSendInviteExplainer =>
      'అప్‌డేట్‌లు మరియు పరిశీలనలు పంచుకోవడం ప్రారంభించడానికి మీ భాగస్వామికి వారి ఇమెయిల్‌కు ఆహ్వానం పంపండి.';

  @override
  String get partnerInvalidEmail =>
      'దయచేసి చెల్లుబాటు అయ్యే ఇమెయిల్ చిరునామాను నమోదు చేయండి.';

  @override
  String get partnerInviteSent => 'ఆహ్వానం పంపబడింది.';

  @override
  String get partnerInviteLinkTitle => 'పంచుకోగల ఆహ్వాన లింక్';

  @override
  String get partnerHaveInviteCode => 'నా దగ్గర ఆహ్వాన కోడ్ ఉంది';

  @override
  String get partnerEnterInviteCode => 'ఆహ్వాన కోడ్ నమోదు చేయండి';

  @override
  String get partnerNoPendingRequests => 'పెండింగ్ అభ్యర్థనలు లేవు';

  @override
  String get partnerAccept => 'అంగీకరించండి';

  @override
  String get partnerDecline => 'తిరస్కరించండి';

  @override
  String get partnerDisconnect => 'కనెక్షన్ తొలగించండి';

  @override
  String get partnerNoMessages => 'ఇంకా సందేశాలు లేవు';

  @override
  String get partnerSayHello => 'సంభాషణ ప్రారంభించడానికి హలో చెప్పండి.';

  @override
  String get partnerSiaDecoding => 'సియా అర్థం చేసుకుంటోంది…';

  @override
  String get partnerSuggestedReply => 'సూచించిన సమాధానం';

  @override
  String get partnerUseReply => 'ఈ సమాధానం ఉపయోగించండి';

  @override
  String get partnerDateIdeas => 'డేట్ ఆలోచనలు';

  @override
  String get partnerSharedActivities => 'భాగస్వామ్య కార్యకలాపాలు';

  @override
  String get partnerLettersTitle => 'ఉత్తరాలు';

  @override
  String get partnerWriteLetter => 'ఉత్తరం రాయండి';

  @override
  String get partnerNoLetters =>
      'ఇంకా ఉత్తరాలు లేవు. ఒకటి రాయండి, అది ఇక్కడ మీ ఇద్దరి కోసం ఉంచబడుతుంది.';

  @override
  String get partnerMemoryBook => 'జ్ఞాపకాల పుస్తకం';

  @override
  String get partnerNoMemories =>
      'ఇక్కడ ఇంకా ఏమీ లేదు. కలిసి ఒక కార్యకలాపం పూర్తి చేయండి, అది ఇక్కడ ఉంచబడుతుంది.';

  @override
  String get partnerSiaAdviceTitle => 'సియా సంబంధ సలహా';

  @override
  String get partnerSiaAdviceExplainer =>
      'మీ మనసులో ఉన్నది అడగండి. మీ భాగస్వామి పంచుకోవాలని ఎంచుకున్నదాన్ని మాత్రమే సియా చూస్తుంది.';

  @override
  String get partnerTryAgain => 'మళ్లీ ప్రయత్నించండి';
}
