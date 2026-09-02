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
