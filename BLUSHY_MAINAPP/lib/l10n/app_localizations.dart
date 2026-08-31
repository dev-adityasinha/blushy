import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navSia.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy'**
  String get navSia;

  /// No description provided for @navStudio.
  ///
  /// In en, this message translates to:
  /// **'M Studio'**
  String get navStudio;

  /// No description provided for @navPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get navPartner;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get actionShared;

  /// No description provided for @actionAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get actionAsk;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get actionPause;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get actionSignOut;

  /// No description provided for @stateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get stateLoading;

  /// No description provided for @stateOfflineWithCache.
  ///
  /// In en, this message translates to:
  /// **'Not connected. Showing your last saved view.'**
  String get stateOfflineWithCache;

  /// No description provided for @stateOfflineNoCache.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server right now. This will load once the connection is back.'**
  String get stateOfflineNoCache;

  /// No description provided for @stateRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get stateRefreshing;

  /// No description provided for @stateNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get stateNothingYet;

  /// No description provided for @stateNotSharedWithYou.
  ///
  /// In en, this message translates to:
  /// **'Not shared with you.'**
  String get stateNotSharedWithYou;

  /// No description provided for @stateCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save that. Please try again.'**
  String get stateCouldNotSave;

  /// No description provided for @languageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy speaks'**
  String get languageSheetTitle;

  /// No description provided for @languageSheetExplainer.
  ///
  /// In en, this message translates to:
  /// **'Changes the language Dr. Docsy replies in. The rest of the app stays in English for now.'**
  String get languageSheetExplainer;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Sharing'**
  String get privacyTitle;

  /// No description provided for @privacyWhatYouReceive.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU RECEIVE'**
  String get privacyWhatYouReceive;

  /// No description provided for @privacyPartnerDecides.
  ///
  /// In en, this message translates to:
  /// **'Your partner decides what reaches this device, one category at a time. They can change it whenever they like, and a change takes effect on your very next request.'**
  String get privacyPartnerDecides;

  /// No description provided for @privacyOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get privacyOn;

  /// No description provided for @privacyOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get privacyOff;

  /// No description provided for @privacyAsked.
  ///
  /// In en, this message translates to:
  /// **'Asked'**
  String get privacyAsked;

  /// No description provided for @connectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect with your partner first.'**
  String get connectFirst;

  /// No description provided for @memoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No memories yet} =1{1 memory} other{{count} memories}}'**
  String memoriesCount(int count);

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String minutesLabel(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings & Privacy Center'**
  String get settingsTitle;

  /// No description provided for @settingsSiaAssistant.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy AI Assistant'**
  String get settingsSiaAssistant;

  /// No description provided for @settingsSiaAssistantSub.
  ///
  /// In en, this message translates to:
  /// **'Typing suggestions & reflection companion'**
  String get settingsSiaAssistantSub;

  /// No description provided for @settingsMemoryBooks.
  ///
  /// In en, this message translates to:
  /// **'Memory Books'**
  String get settingsMemoryBooks;

  /// No description provided for @settingsMemoryBooksSub.
  ///
  /// In en, this message translates to:
  /// **'Weekly and monthly recap scrapbooks'**
  String get settingsMemoryBooksSub;

  /// No description provided for @settingsContentGarden.
  ///
  /// In en, this message translates to:
  /// **'Reflective Content Garden'**
  String get settingsContentGarden;

  /// No description provided for @settingsContentGardenSub.
  ///
  /// In en, this message translates to:
  /// **'Organic garden growth tied to journal diversity'**
  String get settingsContentGardenSub;

  /// No description provided for @settingsTimeCapsules.
  ///
  /// In en, this message translates to:
  /// **'Memory Time Capsules'**
  String get settingsTimeCapsules;

  /// No description provided for @settingsTimeCapsulesSub.
  ///
  /// In en, this message translates to:
  /// **'Sealed memories that open on a day you choose'**
  String get settingsTimeCapsulesSub;

  /// No description provided for @settingsReducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced Motion'**
  String get settingsReducedMotion;

  /// No description provided for @settingsReducedMotionSub.
  ///
  /// In en, this message translates to:
  /// **'Pause non-essential animations'**
  String get settingsReducedMotionSub;

  /// No description provided for @settingsHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast Theme'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastSub.
  ///
  /// In en, this message translates to:
  /// **'Enhance visual contrast for text & borders'**
  String get settingsHighContrastSub;

  /// No description provided for @settingsLargeHandles.
  ///
  /// In en, this message translates to:
  /// **'Large Handle Controls'**
  String get settingsLargeHandles;

  /// No description provided for @settingsLargeHandlesSub.
  ///
  /// In en, this message translates to:
  /// **'Enlarge corner touch handles for easier selection'**
  String get settingsLargeHandlesSub;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Platform Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsSub.
  ///
  /// In en, this message translates to:
  /// **'Inspect storage, cache, search index, and AI queue health'**
  String get settingsDiagnosticsSub;

  /// No description provided for @siaAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask Dr. Docsy'**
  String get siaAsk;

  /// No description provided for @siaThinking.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy is thinking…'**
  String get siaThinking;

  /// No description provided for @siaVoiceTranscribed.
  ///
  /// In en, this message translates to:
  /// **'Voice transcribed into the text field. Review and tap send.'**
  String get siaVoiceTranscribed;

  /// No description provided for @siaNoSpeechRecognised.
  ///
  /// In en, this message translates to:
  /// **'No speech could be recognised. Please try again.'**
  String get siaNoSpeechRecognised;

  /// No description provided for @siaNoAudioRecorded.
  ///
  /// In en, this message translates to:
  /// **'No audio recorded. Please check microphone permissions.'**
  String get siaNoAudioRecorded;

  /// No description provided for @siaConversationStarters.
  ///
  /// In en, this message translates to:
  /// **'CONVERSATION STARTERS'**
  String get siaConversationStarters;

  /// No description provided for @siaHowFeelingToday.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get siaHowFeelingToday;

  /// No description provided for @siaEnergyLevel.
  ///
  /// In en, this message translates to:
  /// **'What is your energy level?'**
  String get siaEnergyLevel;

  /// No description provided for @siaLogSleep.
  ///
  /// In en, this message translates to:
  /// **'Log sleep duration'**
  String get siaLogSleep;

  /// No description provided for @siaLogPeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Log period start date'**
  String get siaLogPeriodStart;

  /// No description provided for @siaPeriodRecorded.
  ///
  /// In en, this message translates to:
  /// **'Period start date recorded.'**
  String get siaPeriodRecorded;

  /// No description provided for @siaLoggedSymptoms.
  ///
  /// In en, this message translates to:
  /// **'LOGGED SYMPTOMS & SIGNALS'**
  String get siaLoggedSymptoms;

  /// No description provided for @siaLogCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Log health check-in'**
  String get siaLogCheckIn;

  /// No description provided for @siaDailyReflection.
  ///
  /// In en, this message translates to:
  /// **'Daily journal reflection'**
  String get siaDailyReflection;

  /// No description provided for @siaOpenJournal.
  ///
  /// In en, this message translates to:
  /// **'Open journal'**
  String get siaOpenJournal;

  /// No description provided for @siaWriteBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Please write your reflection before saving.'**
  String get siaWriteBeforeSaving;

  /// No description provided for @siaEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Your journal entry has been saved.'**
  String get siaEntrySaved;

  /// No description provided for @siaSaveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get siaSaveEntry;

  /// No description provided for @dashHowAreYouToday.
  ///
  /// In en, this message translates to:
  /// **'HOW ARE YOU TODAY?'**
  String get dashHowAreYouToday;

  /// No description provided for @dashMood.
  ///
  /// In en, this message translates to:
  /// **'MOOD'**
  String get dashMood;

  /// No description provided for @dashEnergyLevel.
  ///
  /// In en, this message translates to:
  /// **'ENERGY LEVEL'**
  String get dashEnergyLevel;

  /// No description provided for @dashFlowLevel.
  ///
  /// In en, this message translates to:
  /// **'FLOW LEVEL'**
  String get dashFlowLevel;

  /// No description provided for @dashNotesReflections.
  ///
  /// In en, this message translates to:
  /// **'NOTES & REFLECTIONS'**
  String get dashNotesReflections;

  /// No description provided for @dashCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get dashCheckIn;

  /// No description provided for @dashSiaInsights.
  ///
  /// In en, this message translates to:
  /// **'DR. DOCSY INSIGHTS'**
  String get dashSiaInsights;

  /// No description provided for @dashHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get dashHelpful;

  /// No description provided for @dashNotUseful.
  ///
  /// In en, this message translates to:
  /// **'Not useful'**
  String get dashNotUseful;

  /// No description provided for @dashPatternsTitle.
  ///
  /// In en, this message translates to:
  /// **'CYCLE PATTERNS & INSIGHTS'**
  String get dashPatternsTitle;

  /// No description provided for @dashPatternNotDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'A pattern in what you logged, not a diagnosis or a cause.'**
  String get dashPatternNotDiagnosis;

  /// No description provided for @dashNothingLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. What you record will appear here.'**
  String get dashNothingLoggedYet;

  /// No description provided for @dashNoCommunityPosts.
  ///
  /// In en, this message translates to:
  /// **'No community posts in this topic yet.'**
  String get dashNoCommunityPosts;

  /// No description provided for @dashYourConditions.
  ///
  /// In en, this message translates to:
  /// **'YOUR CONDITIONS'**
  String get dashYourConditions;

  /// No description provided for @dashNoReviewedArticle.
  ///
  /// In en, this message translates to:
  /// **'No reviewed article for this yet.'**
  String get dashNoReviewedArticle;

  /// No description provided for @dashPrepareSummary.
  ///
  /// In en, this message translates to:
  /// **'Prepare a summary'**
  String get dashPrepareSummary;

  /// No description provided for @dashBuildMySummary.
  ///
  /// In en, this message translates to:
  /// **'Build my summary'**
  String get dashBuildMySummary;

  /// No description provided for @dashSummaryNotDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'A record of what you reported and what the app noticed. Not a diagnosis.'**
  String get dashSummaryNotDiagnosis;

  /// No description provided for @dashLogWeight.
  ///
  /// In en, this message translates to:
  /// **'Log weight'**
  String get dashLogWeight;

  /// No description provided for @dashLogPeriod.
  ///
  /// In en, this message translates to:
  /// **'Log period'**
  String get dashLogPeriod;

  /// No description provided for @dashDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dashDismiss;

  /// No description provided for @dashNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get dashNotNow;

  /// No description provided for @journalAutoSaving.
  ///
  /// In en, this message translates to:
  /// **'Auto saving…'**
  String get journalAutoSaving;

  /// No description provided for @journalNewMemory.
  ///
  /// In en, this message translates to:
  /// **'New memory'**
  String get journalNewMemory;

  /// No description provided for @journalBackToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get journalBackToHome;

  /// No description provided for @journalReadingYourEntries.
  ///
  /// In en, this message translates to:
  /// **'Looking at what you have written…'**
  String get journalReadingYourEntries;

  /// No description provided for @journalNothingToReflect.
  ///
  /// In en, this message translates to:
  /// **'Nothing to reflect on yet. Write an entry and Dr. Docsy will read it back to you.'**
  String get journalNothingToReflect;

  /// No description provided for @journalNoMemoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No memories found yet'**
  String get journalNoMemoriesFound;

  /// No description provided for @journalNoSearchMatch.
  ///
  /// In en, this message translates to:
  /// **'No entries matched that search.'**
  String get journalNoSearchMatch;

  /// No description provided for @journalRecordVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Record voice note'**
  String get journalRecordVoiceNote;

  /// No description provided for @journalDoneRecording.
  ///
  /// In en, this message translates to:
  /// **'Done recording'**
  String get journalDoneRecording;

  /// No description provided for @journalAddTextBox.
  ///
  /// In en, this message translates to:
  /// **'Add text box'**
  String get journalAddTextBox;

  /// No description provided for @journalPaperTheme.
  ///
  /// In en, this message translates to:
  /// **'Paper theme'**
  String get journalPaperTheme;

  /// No description provided for @journalFontStyle.
  ///
  /// In en, this message translates to:
  /// **'Font style'**
  String get journalFontStyle;

  /// No description provided for @journalApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get journalApply;

  /// No description provided for @journalAiPrivacyControls.
  ///
  /// In en, this message translates to:
  /// **'AI & privacy controls'**
  String get journalAiPrivacyControls;

  /// No description provided for @journalAiPrivacySub.
  ///
  /// In en, this message translates to:
  /// **'Choose which AI features run on your journal'**
  String get journalAiPrivacySub;

  /// No description provided for @journalTitleGeneration.
  ///
  /// In en, this message translates to:
  /// **'Title suggestions'**
  String get journalTitleGeneration;

  /// No description provided for @journalSmartSearch.
  ///
  /// In en, this message translates to:
  /// **'Search & collections'**
  String get journalSmartSearch;

  /// No description provided for @journalSmartSearchSub.
  ///
  /// In en, this message translates to:
  /// **'Search your entries by keyword and related words'**
  String get journalSmartSearchSub;

  /// No description provided for @journalCloudAi.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI'**
  String get journalCloudAi;

  /// No description provided for @journalCloudAiSub.
  ///
  /// In en, this message translates to:
  /// **'Allow cloud processing for Dr. Docsy insights'**
  String get journalCloudAiSub;

  /// No description provided for @journalCloseMemoryBook.
  ///
  /// In en, this message translates to:
  /// **'Close memory book'**
  String get journalCloseMemoryBook;

  /// No description provided for @journalSelectTemplate.
  ///
  /// In en, this message translates to:
  /// **'Select journal template'**
  String get journalSelectTemplate;

  /// No description provided for @journalCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new journal'**
  String get journalCreateNew;

  /// No description provided for @partnerNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No active partner connection'**
  String get partnerNoConnection;

  /// No description provided for @partnerSendInviteExplainer.
  ///
  /// In en, this message translates to:
  /// **'Send an invitation to your partner using their email address to start sharing updates and insights.'**
  String get partnerSendInviteExplainer;

  /// No description provided for @partnerInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get partnerInvalidEmail;

  /// No description provided for @partnerInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent.'**
  String get partnerInviteSent;

  /// No description provided for @partnerInviteLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Shareable invite link'**
  String get partnerInviteLinkTitle;

  /// No description provided for @partnerHaveInviteCode.
  ///
  /// In en, this message translates to:
  /// **'I have an invite code'**
  String get partnerHaveInviteCode;

  /// No description provided for @partnerEnterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get partnerEnterInviteCode;

  /// No description provided for @partnerNoPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get partnerNoPendingRequests;

  /// No description provided for @partnerAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get partnerAccept;

  /// No description provided for @partnerDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get partnerDecline;

  /// No description provided for @partnerDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get partnerDisconnect;

  /// No description provided for @partnerNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get partnerNoMessages;

  /// No description provided for @partnerSayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello to start the conversation.'**
  String get partnerSayHello;

  /// No description provided for @partnerSiaDecoding.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy is decoding…'**
  String get partnerSiaDecoding;

  /// No description provided for @partnerSuggestedReply.
  ///
  /// In en, this message translates to:
  /// **'Suggested reply'**
  String get partnerSuggestedReply;

  /// No description provided for @partnerUseReply.
  ///
  /// In en, this message translates to:
  /// **'Use reply'**
  String get partnerUseReply;

  /// No description provided for @partnerDateIdeas.
  ///
  /// In en, this message translates to:
  /// **'Date ideas'**
  String get partnerDateIdeas;

  /// No description provided for @partnerSharedActivities.
  ///
  /// In en, this message translates to:
  /// **'SHARED ACTIVITIES'**
  String get partnerSharedActivities;

  /// No description provided for @partnerLettersTitle.
  ///
  /// In en, this message translates to:
  /// **'LETTERS'**
  String get partnerLettersTitle;

  /// No description provided for @partnerWriteLetter.
  ///
  /// In en, this message translates to:
  /// **'Write letter'**
  String get partnerWriteLetter;

  /// No description provided for @partnerNoLetters.
  ///
  /// In en, this message translates to:
  /// **'No letters yet. Write one and it will be kept here for both of you.'**
  String get partnerNoLetters;

  /// No description provided for @partnerMemoryBook.
  ///
  /// In en, this message translates to:
  /// **'MEMORY BOOK'**
  String get partnerMemoryBook;

  /// No description provided for @partnerNoMemories.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Finish a shared activity together and it will be kept here.'**
  String get partnerNoMemories;

  /// No description provided for @partnerSiaAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'DR. DOCSY RELATIONSHIP ADVICE'**
  String get partnerSiaAdviceTitle;

  /// No description provided for @partnerSiaAdviceExplainer.
  ///
  /// In en, this message translates to:
  /// **'Ask about something that is on your mind. Dr. Docsy only sees what your partner has chosen to share.'**
  String get partnerSiaAdviceExplainer;

  /// No description provided for @partnerTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get partnerTryAgain;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String homeGreetingMorning(String name);

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String homeGreetingAfternoon(String name);

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String homeGreetingEvening(String name);

  /// No description provided for @homeGreetingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get homeGreetingSubtitle;

  /// No description provided for @dashLogFirstCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Log your first check-in'**
  String get dashLogFirstCheckIn;

  /// No description provided for @dashAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add a condition'**
  String get dashAddCondition;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// No description provided for @onbBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onbBack;

  /// No description provided for @onbDontRemember.
  ///
  /// In en, this message translates to:
  /// **'I don\'t remember'**
  String get onbDontRemember;

  /// No description provided for @onbLetsGetIntroduced.
  ///
  /// In en, this message translates to:
  /// **'Let’s get introduced'**
  String get onbLetsGetIntroduced;

  /// No description provided for @onbCreatingSafeSpace.
  ///
  /// In en, this message translates to:
  /// **'Creating your safe space'**
  String get onbCreatingSafeSpace;

  /// No description provided for @onbCuratingContent.
  ///
  /// In en, this message translates to:
  /// **'Curating wellness content'**
  String get onbCuratingContent;

  /// No description provided for @onbCreatingInsights.
  ///
  /// In en, this message translates to:
  /// **'Creating your daily insights'**
  String get onbCreatingInsights;

  /// No description provided for @onbPreparingDocsy.
  ///
  /// In en, this message translates to:
  /// **'Preparing Dr. Docsy'**
  String get onbPreparingDocsy;

  /// No description provided for @jrnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get jrnCancel;

  /// No description provided for @jrnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get jrnShare;

  /// No description provided for @jrnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get jrnDelete;

  /// No description provided for @jrnCouldNotTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Could not transcribe that recording.'**
  String get jrnCouldNotTranscribe;

  /// No description provided for @jrnNothingRecognised.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recognised in that recording. You can type it instead.'**
  String get jrnNothingRecognised;

  /// No description provided for @jrnCouldNotChangeSharing.
  ///
  /// In en, this message translates to:
  /// **'Could not change sharing for that day.'**
  String get jrnCouldNotChangeSharing;

  /// No description provided for @jrnNoLongerShared.
  ///
  /// In en, this message translates to:
  /// **'No longer shared.'**
  String get jrnNoLongerShared;

  /// No description provided for @jrnTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing reflection…'**
  String get jrnTranscribing;

  /// No description provided for @jrnRecordingVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Recording voice note…'**
  String get jrnRecordingVoiceNote;

  /// No description provided for @csoSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get csoSignOut;

  /// No description provided for @csoCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get csoCancel;

  /// No description provided for @crRecordedAgainstEverythingYou.
  ///
  /// In en, this message translates to:
  /// **'Recorded against everything you approve.'**
  String get crRecordedAgainstEverythingYou;

  /// No description provided for @eafWhatSYourEmail.
  ///
  /// In en, this message translates to:
  /// **'What\'s your email?'**
  String get eafWhatSYourEmail;

  /// No description provided for @eafCreateYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Create your password'**
  String get eafCreateYourPassword;

  /// No description provided for @eafCheckYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get eafCheckYourEmail;

  /// No description provided for @eafChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get eafChangeEmail;

  /// No description provided for @eafWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get eafWelcomeBack;

  /// No description provided for @eafForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get eafForgotPassword;

  /// No description provided for @eafResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get eafResetPassword;

  /// No description provided for @eafChooseANewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a New Password'**
  String get eafChooseANewPassword;

  /// No description provided for @oPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get oPrivacyPolicy;

  /// No description provided for @oIAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get oIAgreeToThe;

  /// No description provided for @oTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get oTermsOfService;

  /// No description provided for @oWhenIsYourBirthday.
  ///
  /// In en, this message translates to:
  /// **'When is your birthday?'**
  String get oWhenIsYourBirthday;

  /// No description provided for @oWhereAreYouToday.
  ///
  /// In en, this message translates to:
  /// **'Where are you today?'**
  String get oWhereAreYouToday;

  /// No description provided for @oWhenDidYourLast.
  ///
  /// In en, this message translates to:
  /// **'When did your last period begin?'**
  String get oWhenDidYourLast;

  /// No description provided for @oWhatSYourDue.
  ///
  /// In en, this message translates to:
  /// **'What\'s your due date?'**
  String get oWhatSYourDue;

  /// No description provided for @oWhenWasYourBaby.
  ///
  /// In en, this message translates to:
  /// **'When was your baby born?'**
  String get oWhenWasYourBaby;

  /// No description provided for @oYourPreferredName.
  ///
  /// In en, this message translates to:
  /// **'Your preferred name'**
  String get oYourPreferredName;

  /// No description provided for @oWhatWouldYouLike.
  ///
  /// In en, this message translates to:
  /// **'What would you like to learn first?'**
  String get oWhatWouldYouLike;

  /// No description provided for @oWhenDidYourFirst.
  ///
  /// In en, this message translates to:
  /// **'When did your first period start?'**
  String get oWhenDidYourFirst;

  /// No description provided for @oWhatWouldYouLike2.
  ///
  /// In en, this message translates to:
  /// **'What would you like help with?'**
  String get oWhatWouldYouLike2;

  /// No description provided for @oHowWouldYouDescribe.
  ///
  /// In en, this message translates to:
  /// **'How would you describe your cycle?'**
  String get oHowWouldYouDescribe;

  /// No description provided for @oWhatWouldYouLike3.
  ///
  /// In en, this message translates to:
  /// **'What would you like Blushy to help with?'**
  String get oWhatWouldYouLike3;

  /// No description provided for @oAreYouCurrentlyUsing.
  ///
  /// In en, this message translates to:
  /// **'Are you currently using hormonal contraception?'**
  String get oAreYouCurrentlyUsing;

  /// No description provided for @oWhichConditionBestMatches.
  ///
  /// In en, this message translates to:
  /// **'Which condition best matches your situation?'**
  String get oWhichConditionBestMatches;

  /// No description provided for @oWhichSymptomsAffectYou.
  ///
  /// In en, this message translates to:
  /// **'Which symptoms affect you most?'**
  String get oWhichSymptomsAffectYou;

  /// No description provided for @oAreYouCurrentlyReceiving.
  ///
  /// In en, this message translates to:
  /// **'Are you currently receiving treatment?'**
  String get oAreYouCurrentlyReceiving;

  /// No description provided for @oHowLongHaveYou.
  ///
  /// In en, this message translates to:
  /// **'How long have you been trying?'**
  String get oHowLongHaveYou;

  /// No description provided for @oHowAreYouTracking.
  ///
  /// In en, this message translates to:
  /// **'How are you tracking fertility?'**
  String get oHowAreYouTracking;

  /// No description provided for @oAreYouCurrentlyReceiving2.
  ///
  /// In en, this message translates to:
  /// **'Are you currently receiving fertility treatment?'**
  String get oAreYouCurrentlyReceiving2;

  /// No description provided for @oIsThisYourFirst.
  ///
  /// In en, this message translates to:
  /// **'Is this your first pregnancy?'**
  String get oIsThisYourFirst;

  /// No description provided for @oWhatSupportWouldYou.
  ///
  /// In en, this message translates to:
  /// **'What support would you like?'**
  String get oWhatSupportWouldYou;

  /// No description provided for @oHowAreYouFeeding.
  ///
  /// In en, this message translates to:
  /// **'How are you feeding your baby?'**
  String get oHowAreYouFeeding;

  /// No description provided for @oHowHaveYourPeriods.
  ///
  /// In en, this message translates to:
  /// **'How have your periods changed?'**
  String get oHowHaveYourPeriods;

  /// No description provided for @oWhatWouldYouMost.
  ///
  /// In en, this message translates to:
  /// **'What would you most like to improve?'**
  String get oWhatWouldYouMost;

  /// No description provided for @oHowLongHasIt.
  ///
  /// In en, this message translates to:
  /// **'How long has it been since your last period?'**
  String get oHowLongHasIt;

  /// No description provided for @oWhichSymptomsAffectYour.
  ///
  /// In en, this message translates to:
  /// **'Which symptoms affect your daily life?'**
  String get oWhichSymptomsAffectYour;

  /// No description provided for @oWhatWouldYouLike4.
  ///
  /// In en, this message translates to:
  /// **'What would you like Blushy to focus on?'**
  String get oWhatWouldYouLike4;

  /// No description provided for @poYourPreferredName.
  ///
  /// In en, this message translates to:
  /// **'Your preferred name'**
  String get poYourPreferredName;

  /// No description provided for @sGoToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get sGoToSignIn;

  /// No description provided for @sVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get sVerifyCode;

  /// No description provided for @sForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get sForgotPassword;

  /// No description provided for @sIAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get sIAgreeToThe;

  /// No description provided for @sTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get sTermsConditions;

  /// No description provided for @sTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get sTerms;

  /// No description provided for @sPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get sPrivacyPolicy;

  /// No description provided for @cPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get cPeople;

  /// No description provided for @cSearchTitleTextTags.
  ///
  /// In en, this message translates to:
  /// **'Search title, text, tags, or username/email...'**
  String get cSearchTitleTextTags;

  /// No description provided for @cpPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get cpPublish;

  /// No description provided for @cpAnInterestingTitle.
  ///
  /// In en, this message translates to:
  /// **'An interesting title...'**
  String get cpAnInterestingTitle;

  /// No description provided for @cpShareYourThoughtsExperiences.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts, experiences, or questions...'**
  String get cpShareYourThoughtsExperiences;

  /// No description provided for @cpEGLutealMoodswings.
  ///
  /// In en, this message translates to:
  /// **'e.g., Luteal, MoodSwings, SleepTips'**
  String get cpEGLutealMoodswings;

  /// No description provided for @pdDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get pdDeleteComment;

  /// No description provided for @pdAreYouSureYou.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment?'**
  String get pdAreYouSureYou;

  /// No description provided for @pdCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pdCancel;

  /// No description provided for @pdDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pdDelete;

  /// No description provided for @pdDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get pdDeletePost;

  /// No description provided for @pdAreYouSureYou2.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post?'**
  String get pdAreYouSureYou2;

  /// No description provided for @pdComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get pdComments;

  /// No description provided for @upFailedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile details.'**
  String get upFailedToLoadProfile;

  /// No description provided for @upCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get upCancel;

  /// No description provided for @upSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get upSave;

  /// No description provided for @hDrDocsy.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy'**
  String get hDrDocsy;

  /// No description provided for @hClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get hClose;

  /// No description provided for @dsQuestionsToAsk.
  ///
  /// In en, this message translates to:
  /// **'Questions to ask'**
  String get dsQuestionsToAsk;

  /// No description provided for @umsdDailyUnifiedCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Daily Unified Check-in'**
  String get umsdDailyUnifiedCheckIn;

  /// No description provided for @umsdCheckInSavedAnd.
  ///
  /// In en, this message translates to:
  /// **'Check-in saved and synced to your live MongoDB profile! ✨'**
  String get umsdCheckInSavedAnd;

  /// No description provided for @cYourCycleLengthIs.
  ///
  /// In en, this message translates to:
  /// **'Your cycle length is varying. Log your symptoms daily so Dr. Docsy can adjust predictions.'**
  String get cYourCycleLengthIs;

  /// No description provided for @cTrackingIsDisabledFocus.
  ///
  /// In en, this message translates to:
  /// **'Tracking is disabled. Focus on your daily energy, mood, and sleep.'**
  String get cTrackingIsDisabledFocus;

  /// No description provided for @cYourRecommendationsAreAdapted.
  ///
  /// In en, this message translates to:
  /// **'Your recommendations are adapted to your current life stage.'**
  String get cYourRecommendationsAreAdapted;

  /// No description provided for @paTodaySNextStep.
  ///
  /// In en, this message translates to:
  /// **'TODAY\\\'S NEXT STEP'**
  String get paTodaySNextStep;

  /// No description provided for @smClearDrDocsyMemory.
  ///
  /// In en, this message translates to:
  /// **'Clear Dr. Docsy Memory'**
  String get smClearDrDocsyMemory;

  /// No description provided for @scClinicalAlignment.
  ///
  /// In en, this message translates to:
  /// **'Clinical Alignment'**
  String get scClinicalAlignment;

  /// No description provided for @scCurrentTrack.
  ///
  /// In en, this message translates to:
  /// **'CURRENT TRACK'**
  String get scCurrentTrack;

  /// No description provided for @scNewTrack.
  ///
  /// In en, this message translates to:
  /// **'NEW TRACK'**
  String get scNewTrack;

  /// No description provided for @scKeepCurrentTrack.
  ///
  /// In en, this message translates to:
  /// **'Keep Current Track'**
  String get scKeepCurrentTrack;

  /// No description provided for @scSwitchTrack.
  ///
  /// In en, this message translates to:
  /// **'Switch Track'**
  String get scSwitchTrack;

  /// No description provided for @sqWhatWouldYouLike.
  ///
  /// In en, this message translates to:
  /// **'What would you like to learn first?'**
  String get sqWhatWouldYouLike;

  /// No description provided for @sqWhenDidYourFirst.
  ///
  /// In en, this message translates to:
  /// **'When did your first period start?'**
  String get sqWhenDidYourFirst;

  /// No description provided for @sqWhatWouldYouLike2.
  ///
  /// In en, this message translates to:
  /// **'What would you like support with?'**
  String get sqWhatWouldYouLike2;

  /// No description provided for @sqHowWouldYouDescribe.
  ///
  /// In en, this message translates to:
  /// **'How would you describe your cycle?'**
  String get sqHowWouldYouDescribe;

  /// No description provided for @sqWhenDidYourLast.
  ///
  /// In en, this message translates to:
  /// **'When did your last period start?'**
  String get sqWhenDidYourLast;

  /// No description provided for @sqWhatAreYourPrimary.
  ///
  /// In en, this message translates to:
  /// **'What are your primary wellness goals?'**
  String get sqWhatAreYourPrimary;

  /// No description provided for @sqAreYouUsingHormonal.
  ///
  /// In en, this message translates to:
  /// **'Are you using hormonal contraception?'**
  String get sqAreYouUsingHormonal;

  /// No description provided for @sqWhichHormonalConditionS.
  ///
  /// In en, this message translates to:
  /// **'Which hormonal condition(s) apply to you?'**
  String get sqWhichHormonalConditionS;

  /// No description provided for @sqWhichSymptomsAffectYou.
  ///
  /// In en, this message translates to:
  /// **'Which symptoms affect you most?'**
  String get sqWhichSymptomsAffectYou;

  /// No description provided for @sqAreYouCurrentlyReceiving.
  ///
  /// In en, this message translates to:
  /// **'Are you currently receiving treatment?'**
  String get sqAreYouCurrentlyReceiving;

  /// No description provided for @sqHowLongHaveYou.
  ///
  /// In en, this message translates to:
  /// **'How long have you been trying to conceive?'**
  String get sqHowLongHaveYou;

  /// No description provided for @sqHowAreYouTracking.
  ///
  /// In en, this message translates to:
  /// **'How are you tracking fertility?'**
  String get sqHowAreYouTracking;

  /// No description provided for @sqAreYouUndergoingFertility.
  ///
  /// In en, this message translates to:
  /// **'Are you undergoing fertility assistance?'**
  String get sqAreYouUndergoingFertility;

  /// No description provided for @sqWhatIsYourEstimated.
  ///
  /// In en, this message translates to:
  /// **'What is your estimated due date?'**
  String get sqWhatIsYourEstimated;

  /// No description provided for @sqIsThisYourFirst.
  ///
  /// In en, this message translates to:
  /// **'Is this your first pregnancy?'**
  String get sqIsThisYourFirst;

  /// No description provided for @sqWhatSupportWouldYou.
  ///
  /// In en, this message translates to:
  /// **'What support would you like during pregnancy?'**
  String get sqWhatSupportWouldYou;

  /// No description provided for @sqWhenWasYourBaby.
  ///
  /// In en, this message translates to:
  /// **'When was your baby born?'**
  String get sqWhenWasYourBaby;

  /// No description provided for @sqHowAreYouFeeding.
  ///
  /// In en, this message translates to:
  /// **'How are you feeding your baby?'**
  String get sqHowAreYouFeeding;

  /// No description provided for @sqWhatAreasWouldYou.
  ///
  /// In en, this message translates to:
  /// **'What areas would you like help with?'**
  String get sqWhatAreasWouldYou;

  /// No description provided for @sqHowHaveYourPeriods.
  ///
  /// In en, this message translates to:
  /// **'How have your periods changed?'**
  String get sqHowHaveYourPeriods;

  /// No description provided for @sqWhatWouldYouMost.
  ///
  /// In en, this message translates to:
  /// **'What would you most like to focus on?'**
  String get sqWhatWouldYouMost;

  /// No description provided for @sqHowLongHasIt.
  ///
  /// In en, this message translates to:
  /// **'How long has it been since your last period?'**
  String get sqHowLongHasIt;

  /// No description provided for @sqWhichSymptomsAffectYour.
  ///
  /// In en, this message translates to:
  /// **'Which symptoms affect your daily life?'**
  String get sqWhichSymptomsAffectYour;

  /// No description provided for @sqWhatAreYourTop.
  ///
  /// In en, this message translates to:
  /// **'What are your top health goals?'**
  String get sqWhatAreYourTop;

  /// No description provided for @sjaRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get sjaRegenerate;

  /// No description provided for @jcQuickPreviewQuietMorning.
  ///
  /// In en, this message translates to:
  /// **'Quick Preview: \"Quiet morning walks and warm tea with friends.\"'**
  String get jcQuickPreviewQuietMorning;

  /// No description provided for @stUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get stUndo;

  /// No description provided for @stRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get stRedo;

  /// No description provided for @stBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get stBack;

  /// No description provided for @stCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get stCopy;

  /// No description provided for @stDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get stDelete;

  /// No description provided for @ldPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get ldPrivacyPolicy;

  /// No description provided for @ldTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get ldTermsConditions;

  /// No description provided for @ldPrivacyPolicy2.
  ///
  /// In en, this message translates to:
  /// **'📜 Privacy Policy'**
  String get ldPrivacyPolicy2;

  /// No description provided for @ldRightToErasureDelete.
  ///
  /// In en, this message translates to:
  /// **'Right to Erasure (Delete Account)'**
  String get ldRightToErasureDelete;

  /// No description provided for @ldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get ldEmail;

  /// No description provided for @ldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get ldWebsite;

  /// No description provided for @ldTermsAndConditionsTerms.
  ///
  /// In en, this message translates to:
  /// **'⚖️ Terms and Conditions (Terms of Service)'**
  String get ldTermsAndConditionsTerms;

  /// No description provided for @ldUnauthorizedUse.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized Use'**
  String get ldUnauthorizedUse;

  /// No description provided for @msNewTimeCapsule.
  ///
  /// In en, this message translates to:
  /// **'New Time Capsule'**
  String get msNewTimeCapsule;

  /// No description provided for @msAmIst.
  ///
  /// In en, this message translates to:
  /// **'8:00 AM IST'**
  String get msAmIst;

  /// No description provided for @msSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get msSave;

  /// No description provided for @rspThatIsTheWhole.
  ///
  /// In en, this message translates to:
  /// **'That is the whole session. Take a moment before you get up.'**
  String get rspThatIsTheWhole;

  /// No description provided for @pPreparingHerEmergencySchool.
  ///
  /// In en, this message translates to:
  /// **'PREPARING HER EMERGENCY SCHOOL KIT'**
  String get pPreparingHerEmergencySchool;

  /// No description provided for @pConversationStarters.
  ///
  /// In en, this message translates to:
  /// **' CONVERSATION STARTERS'**
  String get pConversationStarters;

  /// No description provided for @pParentFrequentQuestions.
  ///
  /// In en, this message translates to:
  /// **'PARENT FREQUENT QUESTIONS'**
  String get pParentFrequentQuestions;

  /// No description provided for @gBouquet.
  ///
  /// In en, this message translates to:
  /// **'Bouquet'**
  String get gBouquet;

  /// No description provided for @gCommunity.
  ///
  /// In en, this message translates to:
  /// **'🌸 Ideas'**
  String get gCommunity;

  /// No description provided for @hBuildABouquet.
  ///
  /// In en, this message translates to:
  /// **'Build a Bouquet'**
  String get hBuildABouquet;

  /// No description provided for @hBuildItInBlack.
  ///
  /// In en, this message translates to:
  /// **'Build it in Black & White'**
  String get hBuildItInBlack;

  /// No description provided for @pHereAreGeneralWays.
  ///
  /// In en, this message translates to:
  /// **'Here are general ways to support your partner today:'**
  String get pHereAreGeneralWays;

  /// No description provided for @pGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get pGotIt;

  /// No description provided for @pTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get pTips;

  /// No description provided for @pSavePermissions.
  ///
  /// In en, this message translates to:
  /// **'Save Permissions'**
  String get pSavePermissions;

  /// No description provided for @pReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get pReject;

  /// No description provided for @pPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pPending;

  /// No description provided for @pShareThisInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share this invitation'**
  String get pShareThisInvitation;

  /// No description provided for @pConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get pConnect;

  /// No description provided for @pLiveSynchronized.
  ///
  /// In en, this message translates to:
  /// **'Live synchronized'**
  String get pLiveSynchronized;

  /// No description provided for @pCompleteCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Complete Check-in'**
  String get pCompleteCheckIn;

  /// No description provided for @pDigitalFlowerGift.
  ///
  /// In en, this message translates to:
  /// **'Digital Flower Gift'**
  String get pDigitalFlowerGift;

  /// No description provided for @pAiCommunicationHub.
  ///
  /// In en, this message translates to:
  /// **'AI Communication Hub'**
  String get pAiCommunicationHub;

  /// No description provided for @pYourPartnerHasChosen.
  ///
  /// In en, this message translates to:
  /// **'Your partner has chosen not to share personal insights right now.'**
  String get pYourPartnerHasChosen;

  /// No description provided for @pWhatWouldYouLike.
  ///
  /// In en, this message translates to:
  /// **'What would you like help with?'**
  String get pWhatWouldYouLike;

  /// No description provided for @phHereAreGeneralWays.
  ///
  /// In en, this message translates to:
  /// **'Here are general ways to support your partner today:'**
  String get phHereAreGeneralWays;

  /// No description provided for @phGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get phGotIt;

  /// No description provided for @phSeeHowICan.
  ///
  /// In en, this message translates to:
  /// **'See how I can help'**
  String get phSeeHowICan;

  /// No description provided for @phAllTodaySActions.
  ///
  /// In en, this message translates to:
  /// **'All Today\'s Actions Completed! 🌸'**
  String get phAllTodaySActions;

  /// No description provided for @phDrDocsy.
  ///
  /// In en, this message translates to:
  /// **'Dr. Docsy'**
  String get phDrDocsy;

  /// No description provided for @phNotSharedWithYou.
  ///
  /// In en, this message translates to:
  /// **'Not shared with you'**
  String get phNotSharedWithYou;

  /// No description provided for @phConnectionEnded.
  ///
  /// In en, this message translates to:
  /// **'Connection ended'**
  String get phConnectionEnded;

  /// No description provided for @phNothingSharedRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared right now'**
  String get phNothingSharedRightNow;

  /// No description provided for @plConnectWithPartner.
  ///
  /// In en, this message translates to:
  /// **'Connect with Partner'**
  String get plConnectWithPartner;

  /// No description provided for @plPairingWithYourPartner.
  ///
  /// In en, this message translates to:
  /// **'Pairing with your partner enables live AI insights, phase tracking, and support advice on the Learn page.'**
  String get plPairingWithYourPartner;

  /// No description provided for @plSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send Invite'**
  String get plSendInvite;

  /// No description provided for @plLearnDiscover.
  ///
  /// In en, this message translates to:
  /// **'Learn & Discover'**
  String get plLearnDiscover;

  /// No description provided for @plConnectWithYourPartner.
  ///
  /// In en, this message translates to:
  /// **'Connect with your partner to unlock personalized Dr. Docsy AI insights.'**
  String get plConnectWithYourPartner;

  /// No description provided for @plUnderstandingEnergyFatigueShifts.
  ///
  /// In en, this message translates to:
  /// **'Understanding Energy & Fatigue Shifts'**
  String get plUnderstandingEnergyFatigueShifts;

  /// No description provided for @plMindfulCommunicationPrinciples.
  ///
  /// In en, this message translates to:
  /// **'Mindful Communication Principles'**
  String get plMindfulCommunicationPrinciples;

  /// No description provided for @plDailyHydrationMetabolicBalance.
  ///
  /// In en, this message translates to:
  /// **'Daily Hydration & Metabolic Balance'**
  String get plDailyHydrationMetabolicBalance;

  /// No description provided for @plManagingStressDailyResilience.
  ///
  /// In en, this message translates to:
  /// **'Managing Stress & Daily Resilience'**
  String get plManagingStressDailyResilience;

  /// No description provided for @plBuildingHealthySleepArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Building Healthy Sleep Architecture'**
  String get plBuildingHealthySleepArchitecture;

  /// No description provided for @psAskAboutHerActive.
  ///
  /// In en, this message translates to:
  /// **'Ask about her active stage...'**
  String get psAskAboutHerActive;

  /// No description provided for @puHowSharingWorks.
  ///
  /// In en, this message translates to:
  /// **'How Sharing Works'**
  String get puHowSharingWorks;

  /// No description provided for @puUnderstand.
  ///
  /// In en, this message translates to:
  /// **'Understand'**
  String get puUnderstand;

  /// No description provided for @sSavesDirectlyToYour.
  ///
  /// In en, this message translates to:
  /// **'Saves directly to your journal and MongoDB'**
  String get sSavesDirectlyToYour;

  /// No description provided for @sLutealRecoveryActionChecklist.
  ///
  /// In en, this message translates to:
  /// **'Luteal Recovery Action Checklist'**
  String get sLutealRecoveryActionChecklist;

  /// No description provided for @sMedicalReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Medical Report / PDF'**
  String get sMedicalReportPdf;

  /// No description provided for @sSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sSleep;

  /// No description provided for @sEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get sEnergy;

  /// No description provided for @sMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get sMood;

  /// No description provided for @sWriteYourThoughtsBody.
  ///
  /// In en, this message translates to:
  /// **'Write your thoughts, body sensations, or reflections here...'**
  String get sWriteYourThoughtsBody;

  /// No description provided for @vnbVoiceReflection.
  ///
  /// In en, this message translates to:
  /// **'Voice Reflection'**
  String get vnbVoiceReflection;

  /// No description provided for @vnbYourVoiceTranscriptWill.
  ///
  /// In en, this message translates to:
  /// **'Your voice transcript will appear here...'**
  String get vnbYourVoiceTranscriptWill;

  /// No description provided for @gIdeasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready-made bouquets to start from.'**
  String get gIdeasSubtitle;

  /// No description provided for @jrnCouldNotAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be added. Try another one.'**
  String get jrnCouldNotAddPhoto;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'hi',
    'kn',
    'mr',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
