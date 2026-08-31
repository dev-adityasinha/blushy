// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navCommunity => 'Community';

  @override
  String get navSia => 'Dr. Docsy';

  @override
  String get navStudio => 'M Studio';

  @override
  String get navPartner => 'Partner';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionShare => 'Share';

  @override
  String get actionShared => 'Shared';

  @override
  String get actionAsk => 'Ask';

  @override
  String get actionStart => 'Start';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionSignOut => 'Sign Out';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateOfflineWithCache =>
      'Not connected. Showing your last saved view.';

  @override
  String get stateOfflineNoCache =>
      'Can\'t reach the server right now. This will load once the connection is back.';

  @override
  String get stateRefreshing => 'Refreshing…';

  @override
  String get stateNothingYet => 'Nothing logged yet.';

  @override
  String get stateNotSharedWithYou => 'Not shared with you.';

  @override
  String get stateCouldNotSave => 'Could not save that. Please try again.';

  @override
  String get languageSheetTitle => 'Dr. Docsy speaks';

  @override
  String get languageSheetExplainer =>
      'Changes the language Dr. Docsy replies in. The rest of the app stays in English for now.';

  @override
  String get privacyTitle => 'Privacy & Sharing';

  @override
  String get privacyWhatYouReceive => 'WHAT YOU RECEIVE';

  @override
  String get privacyPartnerDecides =>
      'Your partner decides what reaches this device, one category at a time. They can change it whenever they like, and a change takes effect on your very next request.';

  @override
  String get privacyOn => 'On';

  @override
  String get privacyOff => 'Off';

  @override
  String get privacyAsked => 'Asked';

  @override
  String get connectFirst => 'Connect with your partner first.';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memories',
      one: '1 memory',
      zero: 'No memories yet',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Settings & Privacy Center';

  @override
  String get settingsSiaAssistant => 'Dr. Docsy AI Assistant';

  @override
  String get settingsSiaAssistantSub =>
      'Typing suggestions & reflection companion';

  @override
  String get settingsMemoryBooks => 'Memory Books';

  @override
  String get settingsMemoryBooksSub => 'Weekly and monthly recap scrapbooks';

  @override
  String get settingsContentGarden => 'Reflective Content Garden';

  @override
  String get settingsContentGardenSub =>
      'Organic garden growth tied to journal diversity';

  @override
  String get settingsTimeCapsules => 'Memory Time Capsules';

  @override
  String get settingsTimeCapsulesSub =>
      'Sealed memories that open on a day you choose';

  @override
  String get settingsReducedMotion => 'Reduced Motion';

  @override
  String get settingsReducedMotionSub => 'Pause non-essential animations';

  @override
  String get settingsHighContrast => 'High Contrast Theme';

  @override
  String get settingsHighContrastSub =>
      'Enhance visual contrast for text & borders';

  @override
  String get settingsLargeHandles => 'Large Handle Controls';

  @override
  String get settingsLargeHandlesSub =>
      'Enlarge corner touch handles for easier selection';

  @override
  String get settingsDiagnostics => 'Platform Diagnostics';

  @override
  String get settingsDiagnosticsSub =>
      'Inspect storage, cache, search index, and AI queue health';

  @override
  String get siaAsk => 'Ask Dr. Docsy';

  @override
  String get siaThinking => 'Dr. Docsy is thinking…';

  @override
  String get siaVoiceTranscribed =>
      'Voice transcribed into the text field. Review and tap send.';

  @override
  String get siaNoSpeechRecognised =>
      'No speech could be recognised. Please try again.';

  @override
  String get siaNoAudioRecorded =>
      'No audio recorded. Please check microphone permissions.';

  @override
  String get siaConversationStarters => 'CONVERSATION STARTERS';

  @override
  String get siaHowFeelingToday => 'How are you feeling today?';

  @override
  String get siaEnergyLevel => 'What is your energy level?';

  @override
  String get siaLogSleep => 'Log sleep duration';

  @override
  String get siaLogPeriodStart => 'Log period start date';

  @override
  String get siaPeriodRecorded => 'Period start date recorded.';

  @override
  String get siaLoggedSymptoms => 'LOGGED SYMPTOMS & SIGNALS';

  @override
  String get siaLogCheckIn => 'Log health check-in';

  @override
  String get siaDailyReflection => 'Daily journal reflection';

  @override
  String get siaOpenJournal => 'Open journal';

  @override
  String get siaWriteBeforeSaving =>
      'Please write your reflection before saving.';

  @override
  String get siaEntrySaved => 'Your journal entry has been saved.';

  @override
  String get siaSaveEntry => 'Save entry';

  @override
  String get dashHowAreYouToday => 'HOW ARE YOU TODAY?';

  @override
  String get dashMood => 'MOOD';

  @override
  String get dashEnergyLevel => 'ENERGY LEVEL';

  @override
  String get dashFlowLevel => 'FLOW LEVEL';

  @override
  String get dashNotesReflections => 'NOTES & REFLECTIONS';

  @override
  String get dashCheckIn => 'Check in';

  @override
  String get dashSiaInsights => 'DR. DOCSY INSIGHTS';

  @override
  String get dashHelpful => 'Helpful';

  @override
  String get dashNotUseful => 'Not useful';

  @override
  String get dashPatternsTitle => 'CYCLE PATTERNS & INSIGHTS';

  @override
  String get dashPatternNotDiagnosis =>
      'A pattern in what you logged, not a diagnosis or a cause.';

  @override
  String get dashNothingLoggedYet =>
      'Nothing logged yet. What you record will appear here.';

  @override
  String get dashNoCommunityPosts => 'No community posts in this topic yet.';

  @override
  String get dashYourConditions => 'YOUR CONDITIONS';

  @override
  String get dashNoReviewedArticle => 'No reviewed article for this yet.';

  @override
  String get dashPrepareSummary => 'Prepare a summary';

  @override
  String get dashBuildMySummary => 'Build my summary';

  @override
  String get dashSummaryNotDiagnosis =>
      'A record of what you reported and what the app noticed. Not a diagnosis.';

  @override
  String get dashLogWeight => 'Log weight';

  @override
  String get dashLogPeriod => 'Log period';

  @override
  String get dashDismiss => 'Dismiss';

  @override
  String get dashNotNow => 'Not now';

  @override
  String get journalAutoSaving => 'Auto saving…';

  @override
  String get journalNewMemory => 'New memory';

  @override
  String get journalBackToHome => 'Back to home';

  @override
  String get journalReadingYourEntries => 'Looking at what you have written…';

  @override
  String get journalNothingToReflect =>
      'Nothing to reflect on yet. Write an entry and Dr. Docsy will read it back to you.';

  @override
  String get journalNoMemoriesFound => 'No memories found yet';

  @override
  String get journalNoSearchMatch => 'No entries matched that search.';

  @override
  String get journalRecordVoiceNote => 'Record voice note';

  @override
  String get journalDoneRecording => 'Done recording';

  @override
  String get journalAddTextBox => 'Add text box';

  @override
  String get journalPaperTheme => 'Paper theme';

  @override
  String get journalFontStyle => 'Font style';

  @override
  String get journalApply => 'Apply';

  @override
  String get journalAiPrivacyControls => 'AI & privacy controls';

  @override
  String get journalAiPrivacySub =>
      'Choose which AI features run on your journal';

  @override
  String get journalTitleGeneration => 'Title suggestions';

  @override
  String get journalSmartSearch => 'Search & collections';

  @override
  String get journalSmartSearchSub =>
      'Search your entries by keyword and related words';

  @override
  String get journalCloudAi => 'Cloud AI';

  @override
  String get journalCloudAiSub =>
      'Allow cloud processing for Dr. Docsy insights';

  @override
  String get journalCloseMemoryBook => 'Close memory book';

  @override
  String get journalSelectTemplate => 'Select journal template';

  @override
  String get journalCreateNew => 'Create new journal';

  @override
  String get partnerNoConnection => 'No active partner connection';

  @override
  String get partnerSendInviteExplainer =>
      'Send an invitation to your partner using their email address to start sharing updates and insights.';

  @override
  String get partnerInvalidEmail => 'Please enter a valid email address.';

  @override
  String get partnerInviteSent => 'Invitation sent.';

  @override
  String get partnerInviteLinkTitle => 'Shareable invite link';

  @override
  String get partnerHaveInviteCode => 'I have an invite code';

  @override
  String get partnerEnterInviteCode => 'Enter an invite code';

  @override
  String get partnerNoPendingRequests => 'No pending requests';

  @override
  String get partnerAccept => 'Accept';

  @override
  String get partnerDecline => 'Decline';

  @override
  String get partnerDisconnect => 'Disconnect';

  @override
  String get partnerNoMessages => 'No messages yet';

  @override
  String get partnerSayHello => 'Say hello to start the conversation.';

  @override
  String get partnerSiaDecoding => 'Dr. Docsy is decoding…';

  @override
  String get partnerSuggestedReply => 'Suggested reply';

  @override
  String get partnerUseReply => 'Use reply';

  @override
  String get partnerDateIdeas => 'Date ideas';

  @override
  String get partnerSharedActivities => 'SHARED ACTIVITIES';

  @override
  String get partnerLettersTitle => 'LETTERS';

  @override
  String get partnerWriteLetter => 'Write letter';

  @override
  String get partnerNoLetters =>
      'No letters yet. Write one and it will be kept here for both of you.';

  @override
  String get partnerMemoryBook => 'MEMORY BOOK';

  @override
  String get partnerNoMemories =>
      'Nothing here yet. Finish a shared activity together and it will be kept here.';

  @override
  String get partnerSiaAdviceTitle => 'DR. DOCSY RELATIONSHIP ADVICE';

  @override
  String get partnerSiaAdviceExplainer =>
      'Ask about something that is on your mind. Dr. Docsy only sees what your partner has chosen to share.';

  @override
  String get partnerTryAgain => 'Try again';

  @override
  String homeGreetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get homeGreetingSubtitle => 'How are you feeling today?';

  @override
  String get dashLogFirstCheckIn => 'Log your first check-in';

  @override
  String get dashAddCondition => 'Add a condition';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbBack => 'Back';

  @override
  String get onbDontRemember => 'I don\'t remember';

  @override
  String get onbLetsGetIntroduced => 'Let’s get introduced';

  @override
  String get onbCreatingSafeSpace => 'Creating your safe space';

  @override
  String get onbCuratingContent => 'Curating wellness content';

  @override
  String get onbCreatingInsights => 'Creating your daily insights';

  @override
  String get onbPreparingDocsy => 'Preparing Dr. Docsy';

  @override
  String get jrnCancel => 'Cancel';

  @override
  String get jrnShare => 'Share';

  @override
  String get jrnDelete => 'Delete';

  @override
  String get jrnCouldNotTranscribe => 'Could not transcribe that recording.';

  @override
  String get jrnNothingRecognised =>
      'Nothing was recognised in that recording. You can type it instead.';

  @override
  String get jrnCouldNotChangeSharing =>
      'Could not change sharing for that day.';

  @override
  String get jrnNoLongerShared => 'No longer shared.';

  @override
  String get jrnTranscribing => 'Transcribing reflection…';

  @override
  String get jrnRecordingVoiceNote => 'Recording voice note…';

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
