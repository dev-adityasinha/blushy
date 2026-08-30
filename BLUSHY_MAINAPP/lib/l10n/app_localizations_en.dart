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
  String get navSia => 'Sia';

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
  String get languageSheetTitle => 'Sia speaks';

  @override
  String get languageSheetExplainer =>
      'Changes the language Sia replies in. The rest of the app stays in English for now.';

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
  String get settingsSiaAssistant => 'Sia AI Assistant';

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
  String get siaAsk => 'Ask Sia';

  @override
  String get siaThinking => 'Sia is thinking…';

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
  String get dashSiaInsights => 'SIA INSIGHTS';

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
      'Nothing to reflect on yet. Write an entry and Sia will read it back to you.';

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
  String get journalCloudAiSub => 'Allow cloud processing for Sia insights';

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
  String get partnerSiaDecoding => 'Sia is decoding…';

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
  String get partnerSiaAdviceTitle => 'SIA RELATIONSHIP ADVICE';

  @override
  String get partnerSiaAdviceExplainer =>
      'Ask about something that is on your mind. Sia only sees what your partner has chosen to share.';

  @override
  String get partnerTryAgain => 'Try again';
}
