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
  /// **'Sia'**
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
  /// **'Sia speaks'**
  String get languageSheetTitle;

  /// No description provided for @languageSheetExplainer.
  ///
  /// In en, this message translates to:
  /// **'Changes the language Sia replies in. The rest of the app stays in English for now.'**
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
  /// **'Sia AI Assistant'**
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
  /// **'Ask Sia'**
  String get siaAsk;

  /// No description provided for @siaThinking.
  ///
  /// In en, this message translates to:
  /// **'Sia is thinking…'**
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
  /// **'SIA INSIGHTS'**
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
  /// **'Nothing to reflect on yet. Write an entry and Sia will read it back to you.'**
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
  /// **'Allow cloud processing for Sia insights'**
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
  /// **'Sia is decoding…'**
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
  /// **'SIA RELATIONSHIP ADVICE'**
  String get partnerSiaAdviceTitle;

  /// No description provided for @partnerSiaAdviceExplainer.
  ///
  /// In en, this message translates to:
  /// **'Ask about something that is on your mind. Sia only sees what your partner has chosen to share.'**
  String get partnerSiaAdviceExplainer;

  /// No description provided for @partnerTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get partnerTryAgain;
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
