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
  String get navSia => 'Docsy';

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
  String get languageSheetTitle => 'Docsy మాట్లాడే భాష';

  @override
  String get languageSheetExplainer =>
      'ఇది Docsy సమాధానం ఇచ్చే భాషను మారుస్తుంది. మిగతా యాప్ ప్రస్తుతానికి ఇంగ్లీషులోనే ఉంటుంది.';

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
  String get settingsSiaAssistant => 'Docsy ఏఐ సహాయకుడు';

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
  String get siaAsk => 'Docsyను అడగండి';

  @override
  String get siaThinking => 'Typing....';

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
  String get dashSiaInsights => 'Docsy పరిశీలనలు';

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
      'ఇంకా ఆలోచించడానికి ఏమీ లేదు. ఏదైనా రాయండి, Docsy దాన్ని మీకు చదివి వినిపిస్తుంది.';

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
      'Docsy పరిశీలనల కోసం క్లౌడ్ ప్రాసెసింగ్‌ను అనుమతించండి';

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
  String get partnerSiaDecoding => 'Docsy అర్థం చేసుకుంటోంది…';

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
  String get partnerSiaAdviceTitle => 'Docsy సంబంధ సలహా';

  @override
  String get partnerSiaAdviceExplainer =>
      'మీ మనసులో ఉన్నది అడగండి. మీ భాగస్వామి పంచుకోవాలని ఎంచుకున్నదాన్ని మాత్రమే Docsy చూస్తుంది.';

  @override
  String get partnerTryAgain => 'మళ్లీ ప్రయత్నించండి';

  @override
  String homeGreetingMorning(String name) {
    return 'శుభోదయం, $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'శుభ మధ్యాహ్నం, $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'శుభ సాయంత్రం, $name';
  }

  @override
  String get homeGreetingSubtitle =>
      'ఈ రోజు ఎలా ఉన్నా, మీరు ఒంటరిగా ఉండనక్కరలేదు.';

  @override
  String get dashLogFirstCheckIn => 'మొదటి చెక్-ఇన్ నమోదు చేయండి';

  @override
  String get dashAddCondition => 'స్థితిని జోడించండి';

  @override
  String get onbContinue => 'కొనసాగించు';

  @override
  String get onbBack => 'వెనుకకు';

  @override
  String get onbDontRemember => 'నాకు గుర్తు లేదు';

  @override
  String get onbLetsGetIntroduced => 'పరిచయం చేసుకుందాం';

  @override
  String get onbCreatingSafeSpace => 'మీ సురక్షిత స్థలాన్ని సృష్టిస్తోంది';

  @override
  String get onbCuratingContent => 'ఆరోగ్య కంటెంట్‌ను ఎంచుకుంటోంది';

  @override
  String get onbCreatingInsights => 'మీ రోజువారీ సమాచారం సిద్ధం అవుతోంది';

  @override
  String get onbPreparingDocsy => 'Docsy సిద్ధమవుతోంది';

  @override
  String get jrnCancel => 'రద్దు';

  @override
  String get jrnShare => 'షేర్';

  @override
  String get jrnDelete => 'తొలగించు';

  @override
  String get jrnCouldNotTranscribe => 'ఆ రికార్డింగ్‌ను రాయలేకపోయాం.';

  @override
  String get jrnNothingRecognised =>
      'ఆ రికార్డింగ్‌లో ఏదీ గుర్తించలేదు. మీరు టైప్ చేయవచ్చు.';

  @override
  String get jrnCouldNotChangeSharing => 'ఆ రోజు షేరింగ్‌ను మార్చలేకపోయాం.';

  @override
  String get jrnNoLongerShared => 'ఇక షేర్ చేయబడదు.';

  @override
  String get jrnTranscribing => 'రాస్తున్నాం…';

  @override
  String get jrnRecordingVoiceNote => 'వాయిస్ రికార్డవుతోంది…';

  @override
  String get csoSignOut => 'సైన్ అవుట్';

  @override
  String get csoCancel => 'రద్దు చేయి';

  @override
  String get crRecordedAgainstEverythingYou =>
      'మీరు అనుమతించిన ప్రతిదానితో నమోదు చేయబడింది.';

  @override
  String get eafWhatSYourEmail => 'మీ ఇమెయిల్ ఏమిటి?';

  @override
  String get eafCreateYourPassword => 'మీ పాస్‌వర్డ్‌ను సృష్టించండి';

  @override
  String get eafCheckYourEmail => 'మీ ఇమెయిల్ చూడండి';

  @override
  String get eafChangeEmail => 'ఇమెయిల్ మార్చు';

  @override
  String get eafWelcomeBack => 'మళ్లీ స్వాగతం';

  @override
  String get eafForgotPassword => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get eafResetPassword => 'పాస్‌వర్డ్ రీసెట్ చేయి';

  @override
  String get eafChooseANewPassword => 'కొత్త పాస్‌వర్డ్ ఎంచుకోండి';

  @override
  String get oPrivacyPolicy => 'గోప్యతా విధానం';

  @override
  String get oIAgreeToThe => 'నేను అంగీకరిస్తున్నాను ';

  @override
  String get oTermsOfService => 'సేవా నిబంధనలు';

  @override
  String get oWhenIsYourBirthday => 'మీ పుట్టినరోజు ఎప్పుడు?';

  @override
  String get oWhereAreYouToday => 'ఈరోజు మీరు ఎక్కడ ఉన్నారు?';

  @override
  String get oWhenDidYourLast => 'మీ చివరి రుతుస్రావం ఎప్పుడు మొదలైంది?';

  @override
  String get oWhatSYourDue => 'మీ అంచనా ప్రసవ తేదీ ఏమిటి?';

  @override
  String get oWhenWasYourBaby => 'మీ బిడ్డ ఎప్పుడు పుట్టింది?';

  @override
  String get oYourPreferredName => 'మీకు నచ్చిన పేరు';

  @override
  String get oWhatWouldYouLike => 'మొదట మీరు ఏమి తెలుసుకోవాలనుకుంటున్నారు?';

  @override
  String get oWhenDidYourFirst => 'మీ మొదటి రుతుస్రావం ఎప్పుడు మొదలైంది?';

  @override
  String get oWhatWouldYouLike2 => 'మీకు దేనిలో సహాయం కావాలి?';

  @override
  String get oHowWouldYouDescribe => 'మీ చక్రాన్ని మీరు ఎలా వర్ణిస్తారు?';

  @override
  String get oWhatWouldYouLike3 => 'Blushy మీకు దేనిలో సహాయపడాలి?';

  @override
  String get oAreYouCurrentlyUsing =>
      'మీరు ప్రస్తుతం హార్మోన్ల గర్భనిరోధకం వాడుతున్నారా?';

  @override
  String get oWhichConditionBestMatches =>
      'ఏ పరిస్థితి మీ స్థితికి బాగా సరిపోతుంది?';

  @override
  String get oWhichSymptomsAffectYou =>
      'ఏ లక్షణాలు మిమ్మల్ని ఎక్కువగా ప్రభావితం చేస్తాయి?';

  @override
  String get oAreYouCurrentlyReceiving => 'మీకు ప్రస్తుతం చికిత్స జరుగుతోందా?';

  @override
  String get oHowLongHaveYou => 'మీరు ఎంతకాలంగా ప్రయత్నిస్తున్నారు?';

  @override
  String get oHowAreYouTracking =>
      'మీరు సంతానోత్పత్తిని ఎలా ట్రాక్ చేస్తున్నారు?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'మీకు ప్రస్తుతం సంతానోత్పత్తి చికిత్స జరుగుతోందా?';

  @override
  String get oIsThisYourFirst => 'ఇది మీ మొదటి గర్భమా?';

  @override
  String get oWhatSupportWouldYou => 'మీకు ఎలాంటి మద్దతు కావాలి?';

  @override
  String get oHowAreYouFeeding => 'మీ బిడ్డకు మీరు ఎలా ఆహారం ఇస్తున్నారు?';

  @override
  String get oHowHaveYourPeriods => 'మీ రుతుస్రావంలో ఏమి మారింది?';

  @override
  String get oWhatWouldYouMost =>
      'మీరు దేనిలో ఎక్కువ మెరుగుదల కోరుకుంటున్నారు?';

  @override
  String get oHowLongHasIt => 'మీ చివరి రుతుస్రావం అయ్యి ఎంతకాలం అయింది?';

  @override
  String get oWhichSymptomsAffectYour =>
      'ఏ లక్షణాలు మీ రోజువారీ జీవితాన్ని ప్రభావితం చేస్తాయి?';

  @override
  String get oWhatWouldYouLike4 => 'Blushy దేనిపై దృష్టి పెట్టాలి?';

  @override
  String get poYourPreferredName => 'మీకు నచ్చిన పేరు';

  @override
  String get sGoToSignIn => 'సైన్ ఇన్‌కు వెళ్లు';

  @override
  String get sVerifyCode => 'కోడ్‌ను ధృవీకరించు';

  @override
  String get sForgotPassword => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get sIAgreeToThe => 'నేను అంగీకరిస్తున్నాను ';

  @override
  String get sTermsConditions => 'నిబంధనలు & షరతులు';

  @override
  String get sTerms => 'నిబంధనలు';

  @override
  String get sPrivacyPolicy => 'గోప్యతా విధానం';

  @override
  String get cPeople => 'వ్యక్తులు';

  @override
  String get cSearchTitleTextTags =>
      'శీర్షిక, వచనం, ట్యాగ్‌లు లేదా వినియోగదారు పేరు/ఇమెయిల్ వెతకండి...';

  @override
  String get cpPublish => 'ప్రచురించు';

  @override
  String get cpAnInterestingTitle => 'ఒక ఆసక్తికరమైన శీర్షిక...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'మీ ఆలోచనలు, అనుభవాలు లేదా ప్రశ్నలను పంచుకోండి...';

  @override
  String get cpEGLutealMoodswings =>
      'ఉదా., లూటియల్, మూడ్‌స్వింగ్స్, స్లీప్‌టిప్స్';

  @override
  String get pdDeleteComment => 'వ్యాఖ్యను తొలగించు';

  @override
  String get pdAreYouSureYou =>
      'ఈ వ్యాఖ్యను తొలగించాలని మీరు ఖచ్చితంగా అనుకుంటున్నారా?';

  @override
  String get pdCancel => 'రద్దు చేయి';

  @override
  String get pdDelete => 'తొలగించు';

  @override
  String get pdDeletePost => 'పోస్ట్‌ను తొలగించు';

  @override
  String get pdAreYouSureYou2 =>
      'ఈ పోస్ట్‌ను తొలగించాలని మీరు ఖచ్చితంగా అనుకుంటున్నారా?';

  @override
  String get pdComments => 'వ్యాఖ్యలు';

  @override
  String get upFailedToLoadProfile => 'ప్రొఫైల్ వివరాలను లోడ్ చేయడం విఫలమైంది.';

  @override
  String get upCancel => 'రద్దు చేయి';

  @override
  String get upSave => 'సేవ్ చేయి';

  @override
  String get hDrDocsy => 'Docsy';

  @override
  String get hClose => 'మూసివేయి';

  @override
  String get dsQuestionsToAsk => 'అడగవలసిన ప్రశ్నలు';

  @override
  String get umsdDailyUnifiedCheckIn => 'రోజువారీ ఏకీకృత చెక్-ఇన్';

  @override
  String get umsdCheckInSavedAnd =>
      'చెక్-ఇన్ సేవ్ అయ్యి మీ ప్రొఫైల్‌తో సమకాలీకరించబడింది! ✨';

  @override
  String get cYourCycleLengthIs =>
      'మీ చక్రం నిడివి మారుతోంది. ప్రతిరోజూ లక్షణాలను నమోదు చేయండి, Docsy అంచనాలను సరిచేస్తుంది.';

  @override
  String get cTrackingIsDisabledFocus =>
      'ట్రాకింగ్ ఆపివేయబడింది. మీ రోజువారీ శక్తి, మానసిక స్థితి మరియు నిద్రపై దృష్టి పెట్టండి.';

  @override
  String get cYourRecommendationsAreAdapted =>
      'మీ సిఫార్సులు మీ ప్రస్తుత జీవిత దశకు అనుగుణంగా అమర్చబడ్డాయి.';

  @override
  String get paTodaySNextStep => 'ఈరోజు తదుపరి అడుగు';

  @override
  String get smClearDrDocsyMemory => 'Docsy జ్ఞాపకాన్ని తొలగించు';

  @override
  String get scClinicalAlignment => 'వైద్య సమన్వయం';

  @override
  String get scCurrentTrack => 'ప్రస్తుత మార్గం';

  @override
  String get scNewTrack => 'కొత్త మార్గం';

  @override
  String get scKeepCurrentTrack => 'ప్రస్తుత మార్గాన్ని ఉంచు';

  @override
  String get scSwitchTrack => 'మార్గాన్ని మార్చు';

  @override
  String get sqWhatWouldYouLike => 'మొదట మీరు ఏమి తెలుసుకోవాలనుకుంటున్నారు?';

  @override
  String get sqWhenDidYourFirst => 'మీ మొదటి రుతుస్రావం ఎప్పుడు మొదలైంది?';

  @override
  String get sqWhatWouldYouLike2 => 'మీకు దేనిలో మద్దతు కావాలి?';

  @override
  String get sqHowWouldYouDescribe => 'మీ చక్రాన్ని మీరు ఎలా వర్ణిస్తారు?';

  @override
  String get sqWhenDidYourLast => 'మీ చివరి రుతుస్రావం ఎప్పుడు మొదలైంది?';

  @override
  String get sqWhatAreYourPrimary => 'మీ ప్రధాన ఆరోగ్య లక్ష్యాలు ఏమిటి?';

  @override
  String get sqAreYouUsingHormonal =>
      'మీరు హార్మోన్ల గర్భనిరోధకం వాడుతున్నారా?';

  @override
  String get sqWhichHormonalConditionS =>
      'ఏ హార్మోన్ల పరిస్థితి మీకు వర్తిస్తుంది?';

  @override
  String get sqWhichSymptomsAffectYou =>
      'ఏ లక్షణాలు మిమ్మల్ని ఎక్కువగా ప్రభావితం చేస్తాయి?';

  @override
  String get sqAreYouCurrentlyReceiving => 'మీకు ప్రస్తుతం చికిత్స జరుగుతోందా?';

  @override
  String get sqHowLongHaveYou =>
      'మీరు ఎంతకాలంగా గర్భధారణకు ప్రయత్నిస్తున్నారు?';

  @override
  String get sqHowAreYouTracking =>
      'మీరు సంతానోత్పత్తిని ఎలా ట్రాక్ చేస్తున్నారు?';

  @override
  String get sqAreYouUndergoingFertility =>
      'మీరు సంతానోత్పత్తి సహాయం పొందుతున్నారా?';

  @override
  String get sqWhatIsYourEstimated => 'మీ అంచనా ప్రసవ తేదీ ఏమిటి?';

  @override
  String get sqIsThisYourFirst => 'ఇది మీ మొదటి గర్భమా?';

  @override
  String get sqWhatSupportWouldYou =>
      'గర్భధారణ సమయంలో మీకు ఎలాంటి మద్దతు కావాలి?';

  @override
  String get sqWhenWasYourBaby => 'మీ బిడ్డ ఎప్పుడు పుట్టింది?';

  @override
  String get sqHowAreYouFeeding => 'మీ బిడ్డకు మీరు ఎలా ఆహారం ఇస్తున్నారు?';

  @override
  String get sqWhatAreasWouldYou => 'ఏ విషయాల్లో మీకు సహాయం కావాలి?';

  @override
  String get sqHowHaveYourPeriods => 'మీ రుతుస్రావంలో ఏమి మారింది?';

  @override
  String get sqWhatWouldYouMost =>
      'మీరు దేనిపై ఎక్కువగా దృష్టి పెట్టాలనుకుంటున్నారు?';

  @override
  String get sqHowLongHasIt => 'మీ చివరి రుతుస్రావం అయ్యి ఎంతకాలం అయింది?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'ఏ లక్షణాలు మీ రోజువారీ జీవితాన్ని ప్రభావితం చేస్తాయి?';

  @override
  String get sqWhatAreYourTop => 'మీ ప్రధాన ఆరోగ్య లక్ష్యాలు ఏమిటి?';

  @override
  String get sjaRegenerate => 'మళ్లీ రూపొందించు';

  @override
  String get jcQuickPreviewQuietMorning =>
      'సంక్షిప్త వీక్షణ: \"ప్రశాంతమైన ఉదయపు నడక మరియు స్నేహితులతో వేడి టీ.\"';

  @override
  String get stUndo => 'రద్దు చేయి';

  @override
  String get stRedo => 'మళ్లీ చేయి';

  @override
  String get stBack => 'వెనుకకు';

  @override
  String get stCopy => 'కాపీ చేయి';

  @override
  String get stDelete => 'తొలగించు';

  @override
  String get ldPrivacyPolicy => 'గోప్యతా విధానం';

  @override
  String get ldTermsConditions => 'నిబంధనలు & షరతులు';

  @override
  String get ldPrivacyPolicy2 => '📜 గోప్యతా విధానం';

  @override
  String get ldRightToErasureDelete => 'తొలగింపు హక్కు (ఖాతాను తొలగించు)';

  @override
  String get ldEmail => 'ఇమెయిల్';

  @override
  String get ldWebsite => 'వెబ్‌సైట్';

  @override
  String get ldTermsAndConditionsTerms =>
      '⚖️ నిబంధనలు మరియు షరతులు (సేవా నిబంధనలు)';

  @override
  String get ldUnauthorizedUse => 'అనధికార వినియోగం';

  @override
  String get msNewTimeCapsule => 'కొత్త టైమ్ క్యాప్సూల్';

  @override
  String get msAmIst => 'ఉదయం 8:00 IST';

  @override
  String get msSave => 'సేవ్ చేయి';

  @override
  String get rspThatIsTheWhole =>
      'ఇదే పూర్తి సెషన్. లేచే ముందు ఒక క్షణం ఆగండి.';

  @override
  String get pPreparingHerEmergencySchool =>
      'ఆమె పాఠశాల అత్యవసర కిట్‌ను సిద్ధం చేయడం';

  @override
  String get pConversationStarters => ' సంభాషణ ప్రారంభాలు';

  @override
  String get pParentFrequentQuestions => 'తల్లిదండ్రుల తరచు ప్రశ్నలు';

  @override
  String get gBouquet => 'పూలగుచ్ఛం';

  @override
  String get gCommunity => '🌸 ఆలోచనలు';

  @override
  String get hBuildABouquet => 'పూలగుచ్ఛం తయారు చేయి';

  @override
  String get hBuildItInBlack => 'నలుపు-తెలుపులో తయారు చేయి';

  @override
  String get pHereAreGeneralWays =>
      'ఈరోజు మీ భాగస్వామికి మద్దతు ఇవ్వడానికి కొన్ని సాధారణ మార్గాలు:';

  @override
  String get pGotIt => 'అర్థమైంది';

  @override
  String get pTips => 'చిట్కాలు';

  @override
  String get pSavePermissions => 'అనుమతులను సేవ్ చేయి';

  @override
  String get pReject => 'తిరస్కరించు';

  @override
  String get pPending => 'పెండింగ్‌లో';

  @override
  String get pShareThisInvitation => 'ఈ ఆహ్వానాన్ని పంచుకోండి';

  @override
  String get pConnect => 'కనెక్ట్ అవ్వు';

  @override
  String get pLiveSynchronized => 'ప్రత్యక్షంగా సమకాలీకరించబడుతోంది';

  @override
  String get pCompleteCheckIn => 'చెక్-ఇన్ పూర్తి చేయి';

  @override
  String get pDigitalFlowerGift => 'డిజిటల్ పూల బహుమతి';

  @override
  String get pAiCommunicationHub => 'AI సంభాషణ కేంద్రం';

  @override
  String get pYourPartnerHasChosen =>
      'మీ భాగస్వామి ప్రస్తుతం వ్యక్తిగత సమాచారాన్ని పంచుకోవద్దని ఎంచుకున్నారు.';

  @override
  String get pWhatWouldYouLike => 'మీకు దేనిలో సహాయం కావాలి?';

  @override
  String get phHereAreGeneralWays =>
      'ఈరోజు మీ భాగస్వామికి మద్దతు ఇవ్వడానికి కొన్ని సాధారణ మార్గాలు:';

  @override
  String get phGotIt => 'అర్థమైంది';

  @override
  String get phSeeHowICan => 'నేను ఎలా సహాయపడగలనో చూడండి';

  @override
  String get phAllTodaySActions => 'ఈరోజు అన్ని పనులు పూర్తయ్యాయి! 🌸';

  @override
  String get phDrDocsy => 'Docsy';

  @override
  String get phNotSharedWithYou => 'మీతో పంచుకోలేదు';

  @override
  String get phConnectionEnded => 'కనెక్షన్ ముగిసింది';

  @override
  String get phNothingSharedRightNow => 'ప్రస్తుతం ఏదీ పంచుకోలేదు';

  @override
  String get plConnectWithPartner => 'భాగస్వామితో కనెక్ట్ అవ్వు';

  @override
  String get plPairingWithYourPartner =>
      'భాగస్వామితో జతకూడితే ప్రత్యక్ష AI సమాచారం, దశ ట్రాకింగ్ మరియు Learn పేజీలో మద్దతు సూచనలు లభిస్తాయి.';

  @override
  String get plSendInvite => 'ఆహ్వానం పంపు';

  @override
  String get plLearnDiscover => 'నేర్చుకో & తెలుసుకో';

  @override
  String get plConnectWithYourPartner =>
      'వ్యక్తిగతీకరించిన Docsy AI సమాచారం కోసం మీ భాగస్వామితో కనెక్ట్ అవ్వండి.';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'శక్తి మరియు అలసట మార్పులను అర్థం చేసుకోవడం';

  @override
  String get plMindfulCommunicationPrinciples => 'సావధాన సంభాషణ సూత్రాలు';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'రోజువారీ నీటి సేవనం మరియు జీవక్రియ సమతుల్యత';

  @override
  String get plManagingStressDailyResilience =>
      'ఒత్తిడి నిర్వహణ మరియు రోజువారీ స్థితిస్థాపకత';

  @override
  String get plBuildingHealthySleepArchitecture =>
      'ఆరోగ్యకరమైన నిద్ర నిర్మాణాన్ని ఏర్పరచడం';

  @override
  String get psAskAboutHerActive => 'ఆమె ప్రస్తుత దశ గురించి అడగండి...';

  @override
  String get puHowSharingWorks => 'పంచుకోవడం ఎలా పనిచేస్తుంది';

  @override
  String get puUnderstand => 'అర్థమైంది';

  @override
  String get sSavesDirectlyToYour => 'నేరుగా మీ డైరీలో సేవ్ అవుతుంది';

  @override
  String get sLutealRecoveryActionChecklist => 'లూటియల్ కోలుకునే పనుల జాబితా';

  @override
  String get sMedicalReportPdf => 'వైద్య నివేదిక / PDF';

  @override
  String get sSleep => 'నిద్ర';

  @override
  String get sEnergy => 'శక్తి';

  @override
  String get sMood => 'మానసిక స్థితి';

  @override
  String get sWriteYourThoughtsBody =>
      'మీ ఆలోచనలు, శారీరక అనుభూతులు లేదా ప్రతిబింబాలను ఇక్కడ రాయండి...';

  @override
  String get vnbVoiceReflection => 'వాయిస్ రిఫ్లెక్షన్';

  @override
  String get vnbYourVoiceTranscriptWill =>
      'మీ స్వరపు లిఖిత రూపం ఇక్కడ కనిపిస్తుంది...';

  @override
  String get gIdeasSubtitle => 'ప్రారంభించడానికి సిద్ధంగా ఉన్న పూలగుచ్ఛాలు.';

  @override
  String get jrnCouldNotAddPhoto =>
      'ఆ ఫోటోను జోడించలేకపోయాము. మరొకటి ప్రయత్నించండి.';

  @override
  String get tourHomeBody =>
      'మీ రోజు ఒక్క చూపులో: చక్రం, చెక్-ఇన్ మరియు ఏమి ఆశించాలి. మీరు ఎలా అనుభూతి చెందుతున్నారో ఇక్కడ నమోదు చేయండి.';

  @override
  String get tourCommunityBody =>
      'అదే అనుభవం గుండా వెళ్తున్న ఇతరుల ప్రశ్నలు మరియు సమాధానాలు.';

  @override
  String get tourSiaBody =>
      'Docsy‌ను ఏదైనా అడగండి, రాసి లేదా మాట్లాడి. మీరు ఏమి నమోదు చేశారో ఆమెకు తెలుసు.';

  @override
  String get tourStudioBody =>
      'మీ డైరీ, మార్గదర్శక కోలుకునే సెషన్‌లు మరియు భవిష్యత్ మీకు రాసే టైమ్ క్యాప్సూల్‌లు.';

  @override
  String get tourPartnerBody =>
      'భాగస్వామిని ఆహ్వానించి, వారు ఏమి చూడగలరో ఎంచుకోండి. మీరు చెప్పే వరకు ఏదీ పంచుకోబడదు.';

  @override
  String get tourSkip => 'దాటవేయి';

  @override
  String get tourNext => 'తదుపరి';

  @override
  String get tourDone => 'అర్థమైంది';

  @override
  String get upAnonymousProfile =>
      'ఇది అనామకంగా పోస్ట్ చేయబడింది, కాబట్టి తెరవడానికి ప్రొఫైల్ లేదు. రాసిన వ్యక్తి పేరు చెప్పవద్దని ఎంచుకున్నారు, అది వారి ఇష్టం.';

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
  String get languageChoiceTitle => 'మీ భాషను ఎంచుకోండి';

  @override
  String get languageChoiceSubtitle =>
      'Blushy మరియు Docsy ఈ భాషలో మాట్లాడతాయి. సెట్టింగ్‌లలో ఎప్పుడైనా మార్చుకోవచ్చు.';

  @override
  String get languageChoiceContinue => 'కొనసాగించు';

  @override
  String get dashLogTodayCheckIn => 'ఈరోజు చెక్-ఇన్ నమోదు చేయండి';
}
