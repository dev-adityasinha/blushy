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

  /// No description provided for @jrSelfReflection.
  ///
  /// In en, this message translates to:
  /// **'Self Reflection'**
  String get jrSelfReflection;

  /// No description provided for @jrReflection.
  ///
  /// In en, this message translates to:
  /// **'Reflection'**
  String get jrReflection;

  /// No description provided for @jrScrapbook.
  ///
  /// In en, this message translates to:
  /// **'Scrapbook'**
  String get jrScrapbook;

  /// No description provided for @jrAccessibilityMotion.
  ///
  /// In en, this message translates to:
  /// **'Accessibility & Motion Settings'**
  String get jrAccessibilityMotion;

  /// No description provided for @jrAmbientSounds.
  ///
  /// In en, this message translates to:
  /// **'Ambient Sounds'**
  String get jrAmbientSounds;

  /// No description provided for @jrPlayBackgroundSounds.
  ///
  /// In en, this message translates to:
  /// **'Play background environment soundscapes.'**
  String get jrPlayBackgroundSounds;

  /// No description provided for @jrLongAnimations.
  ///
  /// In en, this message translates to:
  /// **'Long Animations & Transitions'**
  String get jrLongAnimations;

  /// No description provided for @jrEnable3D.
  ///
  /// In en, this message translates to:
  /// **'Enable 3D cover flipping and opening motion.'**
  String get jrEnable3D;

  /// No description provided for @jrDecorativeEffects.
  ///
  /// In en, this message translates to:
  /// **'Decorative Effects'**
  String get jrDecorativeEffects;

  /// No description provided for @jrCoffeeSteam.
  ///
  /// In en, this message translates to:
  /// **'Coffee steam curves, plant sway, & reflections.'**
  String get jrCoffeeSteam;

  /// No description provided for @jrMyScrapbook.
  ///
  /// In en, this message translates to:
  /// **'My Scrapbook'**
  String get jrMyScrapbook;

  /// No description provided for @jrDreamBig.
  ///
  /// In en, this message translates to:
  /// **'Dream Big. Write Beautifully.'**
  String get jrDreamBig;

  /// No description provided for @jrCover.
  ///
  /// In en, this message translates to:
  /// **'Cover: '**
  String get jrCover;

  /// No description provided for @jrRibbon.
  ///
  /// In en, this message translates to:
  /// **'Ribbon: '**
  String get jrRibbon;

  /// No description provided for @jrDesk.
  ///
  /// In en, this message translates to:
  /// **'Desk: '**
  String get jrDesk;

  /// No description provided for @jrDeskDiaryCover.
  ///
  /// In en, this message translates to:
  /// **'Desk & Diary Cover'**
  String get jrDeskDiaryCover;

  /// No description provided for @jrAmbientSoundEnv.
  ///
  /// In en, this message translates to:
  /// **'Ambient Sound Environment'**
  String get jrAmbientSoundEnv;

  /// No description provided for @jrAccessibilitySettings.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Settings'**
  String get jrAccessibilitySettings;

  /// No description provided for @jrSearchMemories.
  ///
  /// In en, this message translates to:
  /// **'Search memories, stickers & templates...'**
  String get jrSearchMemories;

  /// No description provided for @jrSmartMemoryTimeline.
  ///
  /// In en, this message translates to:
  /// **'Smart Memory Timeline'**
  String get jrSmartMemoryTimeline;

  /// No description provided for @jrTapNewMemory.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New Memory\" or record a voice reflection.'**
  String get jrTapNewMemory;

  /// No description provided for @jrDailyAmbientSounds.
  ///
  /// In en, this message translates to:
  /// **'Daily Ambient Environment Sounds'**
  String get jrDailyAmbientSounds;

  /// No description provided for @jrScrapbookMemory.
  ///
  /// In en, this message translates to:
  /// **'Scrapbook Memory'**
  String get jrScrapbookMemory;

  /// No description provided for @jrWriteReflection.
  ///
  /// In en, this message translates to:
  /// **'Write Reflection'**
  String get jrWriteReflection;

  /// No description provided for @jrFreshCanvas.
  ///
  /// In en, this message translates to:
  /// **'Start on a fresh scrapbook canvas'**
  String get jrFreshCanvas;

  /// No description provided for @jrRecordTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Record & Transcribe'**
  String get jrRecordTranscribe;

  /// No description provided for @jrSpeakDocsyTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Speak and let Docsy transcribe into your journal'**
  String get jrSpeakDocsyTranscribe;

  /// No description provided for @jrStartFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from Template'**
  String get jrStartFromTemplate;

  /// No description provided for @jrChooseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose a guided journaling template'**
  String get jrChooseTemplate;

  /// No description provided for @jrSmartAiSearch.
  ///
  /// In en, this message translates to:
  /// **'Smart AI Search'**
  String get jrSmartAiSearch;

  /// No description provided for @jrSemanticSearch.
  ///
  /// In en, this message translates to:
  /// **'Contextual semantic search across memories'**
  String get jrSemanticSearch;

  /// No description provided for @jrMemoryVault.
  ///
  /// In en, this message translates to:
  /// **'Memory Vault'**
  String get jrMemoryVault;

  /// No description provided for @jrStarredMemories.
  ///
  /// In en, this message translates to:
  /// **'Starred memories & custom collections'**
  String get jrStarredMemories;

  /// No description provided for @jrSmartCalendarMap.
  ///
  /// In en, this message translates to:
  /// **'Smart Calendar & Map'**
  String get jrSmartCalendarMap;

  /// No description provided for @jrVisualMoodGrid.
  ///
  /// In en, this message translates to:
  /// **'Visual mood grid & location pins'**
  String get jrVisualMoodGrid;

  /// No description provided for @jrContentGarden.
  ///
  /// In en, this message translates to:
  /// **'Reflective Content Garden'**
  String get jrContentGarden;

  /// No description provided for @jrGardenGrowth.
  ///
  /// In en, this message translates to:
  /// **'Organic garden growth tied to reflection depth'**
  String get jrGardenGrowth;

  /// No description provided for @jrInsightsDashboard.
  ///
  /// In en, this message translates to:
  /// **'Journal Insights Dashboard'**
  String get jrInsightsDashboard;

  /// No description provided for @jrWritingStats.
  ///
  /// In en, this message translates to:
  /// **'Writing statistics, word count & active hours'**
  String get jrWritingStats;

  /// No description provided for @jrYearInReview.
  ///
  /// In en, this message translates to:
  /// **'Year in Review Scrapbook'**
  String get jrYearInReview;

  /// No description provided for @jrGuidedRecap.
  ///
  /// In en, this message translates to:
  /// **'Guided multi-page yearly recap'**
  String get jrGuidedRecap;

  /// No description provided for @jrMemoryTimeCapsule.
  ///
  /// In en, this message translates to:
  /// **'Memory Time Capsule'**
  String get jrMemoryTimeCapsule;

  /// No description provided for @jrEncryptedFuture.
  ///
  /// In en, this message translates to:
  /// **'Encrypted future memories with ceremonial unlock'**
  String get jrEncryptedFuture;

  /// No description provided for @jrExportStudio.
  ///
  /// In en, this message translates to:
  /// **'Export Studio (6 Layouts)'**
  String get jrExportStudio;

  /// No description provided for @jrExportFormats.
  ///
  /// In en, this message translates to:
  /// **'Export PDF, Markdown, JSON, HTML'**
  String get jrExportFormats;

  /// No description provided for @jrExportStudioPreview.
  ///
  /// In en, this message translates to:
  /// **'Export Studio Preview'**
  String get jrExportStudioPreview;

  /// No description provided for @jrEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry Title...'**
  String get jrEntryTitle;

  /// No description provided for @jrAiTitleSuggestions.
  ///
  /// In en, this message translates to:
  /// **'AI Title Suggestions'**
  String get jrAiTitleSuggestions;

  /// No description provided for @jrWeeklyMemoryBook.
  ///
  /// In en, this message translates to:
  /// **'Weekly Memory Book'**
  String get jrWeeklyMemoryBook;

  /// No description provided for @jrAiPrivacySettings.
  ///
  /// In en, this message translates to:
  /// **'AI & Privacy Settings'**
  String get jrAiPrivacySettings;

  /// No description provided for @jrSaveClose.
  ///
  /// In en, this message translates to:
  /// **'Save & close'**
  String get jrSaveClose;

  /// No description provided for @jrDocsyInsights.
  ///
  /// In en, this message translates to:
  /// **'DOCSY INSIGHTS'**
  String get jrDocsyInsights;

  /// No description provided for @jrBringToFront.
  ///
  /// In en, this message translates to:
  /// **'Bring to Front'**
  String get jrBringToFront;

  /// No description provided for @jrSendToBack.
  ///
  /// In en, this message translates to:
  /// **'Send to Back'**
  String get jrSendToBack;

  /// No description provided for @jrZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get jrZoomIn;

  /// No description provided for @jrZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get jrZoomOut;

  /// No description provided for @jrRotate15.
  ///
  /// In en, this message translates to:
  /// **'Rotate 15°'**
  String get jrRotate15;

  /// No description provided for @jrObjectColor.
  ///
  /// In en, this message translates to:
  /// **'Object Color'**
  String get jrObjectColor;

  /// No description provided for @jrDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get jrDuplicate;

  /// No description provided for @jrDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get jrDeselect;

  /// No description provided for @jrAddPolaroid.
  ///
  /// In en, this message translates to:
  /// **'Add Polaroid Frame'**
  String get jrAddPolaroid;

  /// No description provided for @jrPinkRoseFrame.
  ///
  /// In en, this message translates to:
  /// **'Pink Rose Frame'**
  String get jrPinkRoseFrame;

  /// No description provided for @jrDictateToText.
  ///
  /// In en, this message translates to:
  /// **'Dictate to Text (STT)'**
  String get jrDictateToText;

  /// No description provided for @jrAddReflectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Add Reflection Summary'**
  String get jrAddReflectionSummary;

  /// No description provided for @jrDocsyTitleSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Docsy Title Suggestions'**
  String get jrDocsyTitleSuggestions;

  /// No description provided for @jrPickTitleMood.
  ///
  /// In en, this message translates to:
  /// **'Pick a title that matches your reflection mood:'**
  String get jrPickTitleMood;

  /// No description provided for @jrSuggestTitles.
  ///
  /// In en, this message translates to:
  /// **'Suggest thoughtful entry titles'**
  String get jrSuggestTitles;

  /// No description provided for @jrMemoryLinks.
  ///
  /// In en, this message translates to:
  /// **'Memory Links'**
  String get jrMemoryLinks;

  /// No description provided for @jrDiscoverLinks.
  ///
  /// In en, this message translates to:
  /// **'Discover explainable links between memories'**
  String get jrDiscoverLinks;

  /// No description provided for @jrSmartContextSearch.
  ///
  /// In en, this message translates to:
  /// **'Smart Context Search'**
  String get jrSmartContextSearch;

  /// No description provided for @jrSearchExamples.
  ///
  /// In en, this message translates to:
  /// **'Search (e.g. Beach, Happy, Exams)...'**
  String get jrSearchExamples;

  /// No description provided for @jrHexCode.
  ///
  /// In en, this message translates to:
  /// **'Hex Code'**
  String get jrHexCode;

  /// No description provided for @jrRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get jrRed;

  /// No description provided for @jrGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get jrGreen;

  /// No description provided for @jrBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get jrBlue;

  /// No description provided for @jrBasicColors.
  ///
  /// In en, this message translates to:
  /// **'Basic Colors'**
  String get jrBasicColors;

  /// No description provided for @msRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get msRecovery;

  /// No description provided for @msTimeCapsules.
  ///
  /// In en, this message translates to:
  /// **'Time Capsules'**
  String get msTimeCapsules;

  /// No description provided for @msStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start a Session'**
  String get msStartSession;

  /// No description provided for @msNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions available yet.'**
  String get msNoSessions;

  /// No description provided for @msCreateNewCapsule.
  ///
  /// In en, this message translates to:
  /// **'Create New Capsule'**
  String get msCreateNewCapsule;

  /// No description provided for @msNameIt.
  ///
  /// In en, this message translates to:
  /// **'Name it'**
  String get msNameIt;

  /// No description provided for @msWhatToSay.
  ///
  /// In en, this message translates to:
  /// **'What do you want to say?'**
  String get msWhatToSay;

  /// No description provided for @msOpenItIn.
  ///
  /// In en, this message translates to:
  /// **'Open it in'**
  String get msOpenItIn;

  /// No description provided for @msSeal.
  ///
  /// In en, this message translates to:
  /// **'Seal'**
  String get msSeal;

  /// No description provided for @msKeepsakeSaved.
  ///
  /// In en, this message translates to:
  /// **'Journal keepsake saved!'**
  String get msKeepsakeSaved;

  /// No description provided for @msStartWriting.
  ///
  /// In en, this message translates to:
  /// **'Start writing or speak your thoughts...'**
  String get msStartWriting;

  /// No description provided for @authEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmailAddress;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPassword;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get authConfirmNewPassword;

  /// No description provided for @authUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get authUpdatePassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in instead?'**
  String get authSignInInstead;

  /// No description provided for @authUseAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Use another email'**
  String get authUseAnotherEmail;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authSendRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Send Recovery Code'**
  String get authSendRecoveryCode;

  /// No description provided for @authCodeSentIfExists.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a code is on its way.'**
  String get authCodeSentIfExists;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in.'**
  String get authPasswordUpdated;

  /// No description provided for @authNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'A new verification code has been sent.'**
  String get authNewCodeSent;

  /// No description provided for @setAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get setAccountSettings;

  /// No description provided for @setAccountProfile.
  ///
  /// In en, this message translates to:
  /// **'Account & Profile'**
  String get setAccountProfile;

  /// No description provided for @setPreferredName.
  ///
  /// In en, this message translates to:
  /// **'Preferred Name'**
  String get setPreferredName;

  /// No description provided for @setAddName.
  ///
  /// In en, this message translates to:
  /// **'Add name'**
  String get setAddName;

  /// No description provided for @setDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get setDateOfBirth;

  /// No description provided for @setEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get setEmail;

  /// No description provided for @setCycleBodyBaseline.
  ///
  /// In en, this message translates to:
  /// **'Cycle & Body Baseline'**
  String get setCycleBodyBaseline;

  /// No description provided for @setCurrentLifeStage.
  ///
  /// In en, this message translates to:
  /// **'Current Life Stage'**
  String get setCurrentLifeStage;

  /// No description provided for @setCycleTracking.
  ///
  /// In en, this message translates to:
  /// **'Cycle Tracking'**
  String get setCycleTracking;

  /// No description provided for @setCycleLength.
  ///
  /// In en, this message translates to:
  /// **'Cycle Length'**
  String get setCycleLength;

  /// No description provided for @setPeriodLength.
  ///
  /// In en, this message translates to:
  /// **'Period Length'**
  String get setPeriodLength;

  /// No description provided for @setHealthMedicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Health & Medical Profile'**
  String get setHealthMedicalProfile;

  /// No description provided for @setNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get setNotSet;

  /// No description provided for @setAppPreferencesDocsy.
  ///
  /// In en, this message translates to:
  /// **'App Preferences & Docsy AI'**
  String get setAppPreferencesDocsy;

  /// No description provided for @setDocsyMemory.
  ///
  /// In en, this message translates to:
  /// **'Docsy Memory'**
  String get setDocsyMemory;

  /// No description provided for @setSupportAccount.
  ///
  /// In en, this message translates to:
  /// **'Support & Account'**
  String get setSupportAccount;

  /// No description provided for @setHelpFaq.
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get setHelpFaq;

  /// No description provided for @setPrivacyDataReset.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data Reset'**
  String get setPrivacyDataReset;

  /// No description provided for @setLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get setLogOut;

  /// No description provided for @setDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String setDaysValue(num count);

  /// No description provided for @setEditItems.
  ///
  /// In en, this message translates to:
  /// **'Edit {count} items'**
  String setEditItems(num count);

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
  /// **'Docsy'**
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
  /// **'Docsy speaks'**
  String get languageSheetTitle;

  /// No description provided for @languageSheetExplainer.
  ///
  /// In en, this message translates to:
  /// **'Changes the language Docsy replies in. The rest of the app stays in English for now.'**
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
  /// **'Docsy AI Assistant'**
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
  /// **'Ask Docsy'**
  String get siaAsk;

  /// No description provided for @siaThinking.
  ///
  /// In en, this message translates to:
  /// **'Typing....'**
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
  /// **'DOCSY INSIGHTS'**
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
  /// **'Nothing to reflect on yet. Write an entry and Docsy will read it back to you.'**
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
  /// **'Allow cloud processing for Docsy insights'**
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
  /// **'Docsy is decoding…'**
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
  /// **'DOCSY RELATIONSHIP ADVICE'**
  String get partnerSiaAdviceTitle;

  /// No description provided for @partnerSiaAdviceExplainer.
  ///
  /// In en, this message translates to:
  /// **'Ask about something that is on your mind. Docsy only sees what your partner has chosen to share.'**
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
  /// **'Whatever today looks like, you don\'t have to do it alone.'**
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
  /// **'Preparing Docsy'**
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

  /// No description provided for @oMedicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Medical Disclaimer'**
  String get oMedicalDisclaimer;

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
  /// **'Docsy'**
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
  /// **'Your cycle length is varying. Log your symptoms daily so Docsy can adjust predictions.'**
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
  /// **'Clear Docsy Memory'**
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

  /// No description provided for @ldMedicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Medical Disclaimer'**
  String get ldMedicalDisclaimer;

  /// No description provided for @ldTabPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get ldTabPrivacy;

  /// No description provided for @ldTabTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get ldTabTerms;

  /// No description provided for @ldTabDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get ldTabDisclaimer;

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
  /// **'Docsy'**
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
  /// **'Connect with your partner to unlock personalized Docsy AI insights.'**
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

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Your day at a glance: cycle, check-ins and what to expect. Log how you feel here.'**
  String get tourHomeBody;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Questions and answers from other people going through the same thing.'**
  String get tourCommunityBody;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy anything, by typing or by voice. She knows what you have logged.'**
  String get tourSiaBody;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Your journal, guided recovery sessions and time capsules you write to your future self.'**
  String get tourStudioBody;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Invite a partner and choose exactly what they can see. Nothing is shared until you say so.'**
  String get tourPartnerBody;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// First-run product tour.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tourDone;

  /// Shown instead of a profile when a post has no author to show.
  ///
  /// In en, this message translates to:
  /// **'This was posted anonymously, so there is no profile to open. Whoever wrote it chose not to be named, and that stays their choice.'**
  String get upAnonymousProfile;

  /// No description provided for @dashFocusTopic.
  ///
  /// In en, this message translates to:
  /// **'FOCUS TOPIC'**
  String get dashFocusTopic;

  /// No description provided for @dashScrollDownContinueLearning.
  ///
  /// In en, this message translates to:
  /// **'Scroll down to Continue Learning section'**
  String get dashScrollDownContinueLearning;

  /// No description provided for @dashSmallLessonsDesignedStage.
  ///
  /// In en, this message translates to:
  /// **'Small lessons designed for your stage.'**
  String get dashSmallLessonsDesignedStage;

  /// No description provided for @dashDailyDiscovery.
  ///
  /// In en, this message translates to:
  /// **'DAILY DISCOVERY'**
  String get dashDailyDiscovery;

  /// No description provided for @dashSweatGlandsBecomeMore.
  ///
  /// In en, this message translates to:
  /// **'Sweat glands become more active during puberty. Drinking plenty of water and washing daily helps keep you fresh, confident, and clean.'**
  String get dashSweatGlandsBecomeMore;

  /// No description provided for @dashRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get dashRead;

  /// No description provided for @dashLinkCopiedShareFamily.
  ///
  /// In en, this message translates to:
  /// **'Link copied to share with family!'**
  String get dashLinkCopiedShareFamily;

  /// No description provided for @dashQuestionsGirlsOftenAsk.
  ///
  /// In en, this message translates to:
  /// **'Questions Girls Often Ask'**
  String get dashQuestionsGirlsOftenAsk;

  /// No description provided for @dashGirls.
  ///
  /// In en, this message translates to:
  /// **'Girls'**
  String get dashGirls;

  /// No description provided for @dashGrowingTogether.
  ///
  /// In en, this message translates to:
  /// **'Growing Together'**
  String get dashGrowingTogether;

  /// No description provided for @dashSupportiveCommunityPreview.
  ///
  /// In en, this message translates to:
  /// **'Supportive Community Preview'**
  String get dashSupportiveCommunityPreview;

  /// No description provided for @dashHowDoITrack.
  ///
  /// In en, this message translates to:
  /// **'How do I track if I haven\'t got my period yet?'**
  String get dashHowDoITrack;

  /// No description provided for @dashCanFocusLearningDischarge.
  ///
  /// In en, this message translates to:
  /// **'You can focus on learning, discharge changes and kits here! Docsy helps guide you.'**
  String get dashCanFocusLearningDischarge;

  /// No description provided for @dashReadWhatOthersAre.
  ///
  /// In en, this message translates to:
  /// **'Read what others are sharing'**
  String get dashReadWhatOthersAre;

  /// No description provided for @dashRealConversationsFromCommunity.
  ///
  /// In en, this message translates to:
  /// **'Real conversations from the community, not examples.'**
  String get dashRealConversationsFromCommunity;

  /// No description provided for @dashRedirectingCommunitySpace.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to Community Space...'**
  String get dashRedirectingCommunitySpace;

  /// No description provided for @dashJoinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join Community'**
  String get dashJoinCommunity;

  /// No description provided for @dashSharedReading.
  ///
  /// In en, this message translates to:
  /// **'SHARED READING'**
  String get dashSharedReading;

  /// No description provided for @dashShareArticlesAboutGrowing.
  ///
  /// In en, this message translates to:
  /// **'Share articles about growing up with your parent safely.'**
  String get dashShareArticlesAboutGrowing;

  /// No description provided for @dashArticleSharedParentAccount.
  ///
  /// In en, this message translates to:
  /// **'Article shared with Parent account!'**
  String get dashArticleSharedParentAccount;

  /// No description provided for @dashSendParent.
  ///
  /// In en, this message translates to:
  /// **'Send to Parent'**
  String get dashSendParent;

  /// No description provided for @dashOpeningSharedLibrary.
  ///
  /// In en, this message translates to:
  /// **'Opening Shared Library...'**
  String get dashOpeningSharedLibrary;

  /// No description provided for @dashSharedLibrary.
  ///
  /// In en, this message translates to:
  /// **'Shared Library'**
  String get dashSharedLibrary;

  /// No description provided for @dashLetSTalkWeekly.
  ///
  /// In en, this message translates to:
  /// **'LET\'S TALK • WEEKLY PROMPT'**
  String get dashLetSTalkWeekly;

  /// No description provided for @dashFirstPeriodKitChecklist.
  ///
  /// In en, this message translates to:
  /// **'FIRST PERIOD KIT CHECKLIST'**
  String get dashFirstPeriodKitChecklist;

  /// No description provided for @dashSharedJourney.
  ///
  /// In en, this message translates to:
  /// **'SHARED JOURNEY'**
  String get dashSharedJourney;

  /// No description provided for @dashDisplayLearningProgressCompleted.
  ///
  /// In en, this message translates to:
  /// **'Display learning progress completed together. The child decides what is visible.'**
  String get dashDisplayLearningProgressCompleted;

  /// No description provided for @dashLearningCycleCompanion.
  ///
  /// In en, this message translates to:
  /// **'Your learning cycle companion.'**
  String get dashLearningCycleCompanion;

  /// No description provided for @dashPastDays.
  ///
  /// In en, this message translates to:
  /// **'PAST 30 DAYS'**
  String get dashPastDays;

  /// No description provided for @dashSCompletelyNormalFirst.
  ///
  /// In en, this message translates to:
  /// **'It\'s completely normal for your first few cycles to be irregular. Your body is gently finding its own natural rhythm.'**
  String get dashSCompletelyNormalFirst;

  /// No description provided for @dashVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice Note'**
  String get dashVoiceNote;

  /// No description provided for @dashMStudio.
  ///
  /// In en, this message translates to:
  /// **'M Studio'**
  String get dashMStudio;

  /// No description provided for @dashCommunityDiscussionsStories.
  ///
  /// In en, this message translates to:
  /// **'Community Discussions & Stories'**
  String get dashCommunityDiscussionsStories;

  /// No description provided for @dashQuestionsPeopleAreAsking.
  ///
  /// In en, this message translates to:
  /// **'Questions people are asking'**
  String get dashQuestionsPeopleAreAsking;

  /// No description provided for @dashOpenCommunityReadReply.
  ///
  /// In en, this message translates to:
  /// **'Open the community to read and reply.'**
  String get dashOpenCommunityReadReply;

  /// No description provided for @dashTipsPeopleAreSharing.
  ///
  /// In en, this message translates to:
  /// **'Tips people are sharing'**
  String get dashTipsPeopleAreSharing;

  /// No description provided for @dashOpenDiscussions.
  ///
  /// In en, this message translates to:
  /// **'Open Discussions'**
  String get dashOpenDiscussions;

  /// No description provided for @dashSharedReadingParentResources.
  ///
  /// In en, this message translates to:
  /// **'SHARED READING & PARENT RESOURCES'**
  String get dashSharedReadingParentResources;

  /// No description provided for @dashSendCycleArticlesParent.
  ///
  /// In en, this message translates to:
  /// **'Send cycle articles to parent or consult conversation guides.'**
  String get dashSendCycleArticlesParent;

  /// No description provided for @dashArticleSharedParent.
  ///
  /// In en, this message translates to:
  /// **'Article shared with Parent!'**
  String get dashArticleSharedParent;

  /// No description provided for @dashShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get dashShare;

  /// No description provided for @dashOpeningParentResourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Opening Parent Resource library...'**
  String get dashOpeningParentResourceLibrary;

  /// No description provided for @dashGuides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get dashGuides;

  /// No description provided for @dashConversationPrompt.
  ///
  /// In en, this message translates to:
  /// **'CONVERSATION PROMPT'**
  String get dashConversationPrompt;

  /// No description provided for @dashFirstPeriodKitStatus.
  ///
  /// In en, this message translates to:
  /// **'FIRST PERIOD KIT STATUS'**
  String get dashFirstPeriodKitStatus;

  /// No description provided for @dashDocsySafetyParentNever.
  ///
  /// In en, this message translates to:
  /// **' Docsy Safety: Your parent never has access to your private chat logs, notes, or moods.'**
  String get dashDocsySafetyParentNever;

  /// No description provided for @dashTodaySLoggedSignals.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S LOGGED SIGNALS'**
  String get dashTodaySLoggedSignals;

  /// No description provided for @dashLogEditPeriod.
  ///
  /// In en, this message translates to:
  /// **'Log / Edit Period'**
  String get dashLogEditPeriod;

  /// No description provided for @dashConfirmCorrectPeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Confirm or correct your period start and end dates below.'**
  String get dashConfirmCorrectPeriodStart;

  /// No description provided for @dashPeriodStartDate.
  ///
  /// In en, this message translates to:
  /// **'PERIOD START DATE'**
  String get dashPeriodStartDate;

  /// No description provided for @dashPeriodEndDateOptional.
  ///
  /// In en, this message translates to:
  /// **'PERIOD END DATE (OPTIONAL)'**
  String get dashPeriodEndDateOptional;

  /// No description provided for @dashCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dashCancel;

  /// No description provided for @dashSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dashSave;

  /// No description provided for @dashExplainInsight.
  ///
  /// In en, this message translates to:
  /// **'Explain Insight'**
  String get dashExplainInsight;

  /// No description provided for @dashDocsySReflection.
  ///
  /// In en, this message translates to:
  /// **'DOCSY\'S REFLECTION'**
  String get dashDocsySReflection;

  /// No description provided for @dashHormonalRhythmTracker.
  ///
  /// In en, this message translates to:
  /// **'Hormonal Rhythm Tracker'**
  String get dashHormonalRhythmTracker;

  /// No description provided for @dashRecentCycleHistory.
  ///
  /// In en, this message translates to:
  /// **'RECENT CYCLE HISTORY'**
  String get dashRecentCycleHistory;

  /// No description provided for @dashNextPeriodMayArrive.
  ///
  /// In en, this message translates to:
  /// **'Your next period may arrive within the next few weeks. Because your cycles vary, this is only an estimate.'**
  String get dashNextPeriodMayArrive;

  /// No description provided for @dashWeightOptional.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT (OPTIONAL)'**
  String get dashWeightOptional;

  /// No description provided for @dashFromLogs.
  ///
  /// In en, this message translates to:
  /// **'FROM YOUR LOGS'**
  String get dashFromLogs;

  /// No description provided for @dashBlushyCanPullTogether.
  ///
  /// In en, this message translates to:
  /// **'Blushy can pull together what you have logged over a date range you choose. You decide what stays in before you share it.'**
  String get dashBlushyCanPullTogether;

  /// No description provided for @dashRecordWhatReportedWhat.
  ///
  /// In en, this message translates to:
  /// **'A record of what you reported and what the app noticed. Not a diagnosis.'**
  String get dashRecordWhatReportedWhat;

  /// No description provided for @dashAiGeneratedTrendsAcross.
  ///
  /// In en, this message translates to:
  /// **'AI-generated trends across multiple cycle logs'**
  String get dashAiGeneratedTrendsAcross;

  /// No description provided for @dashAskDocsy.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy'**
  String get dashAskDocsy;

  /// No description provided for @dashWhyMatters.
  ///
  /// In en, this message translates to:
  /// **'Why This Matters'**
  String get dashWhyMatters;

  /// No description provided for @dashPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get dashPriority;

  /// No description provided for @dashReviewedGuidance.
  ///
  /// In en, this message translates to:
  /// **'Reviewed guidance'**
  String get dashReviewedGuidance;

  /// No description provided for @dashDerived.
  ///
  /// In en, this message translates to:
  /// **'Derived'**
  String get dashDerived;

  /// No description provided for @dashFertilityJourney.
  ///
  /// In en, this message translates to:
  /// **'Your Fertility Journey'**
  String get dashFertilityJourney;

  /// No description provided for @dashOvulationLoggedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ovulation logged successfully!'**
  String get dashOvulationLoggedSuccessfully;

  /// No description provided for @dashLogOvulation.
  ///
  /// In en, this message translates to:
  /// **'Log Ovulation'**
  String get dashLogOvulation;

  /// No description provided for @dashBasalBodyTemperatureBbt.
  ///
  /// In en, this message translates to:
  /// **'BASAL BODY TEMPERATURE (BBT)'**
  String get dashBasalBodyTemperatureBbt;

  /// No description provided for @dashNotesMStudio.
  ///
  /// In en, this message translates to:
  /// **'NOTES & M STUDIO'**
  String get dashNotesMStudio;

  /// No description provided for @dashTtcMStudioEntry.
  ///
  /// In en, this message translates to:
  /// **'TTC M Studio Entry'**
  String get dashTtcMStudioEntry;

  /// No description provided for @dashSharedTimelineReminders.
  ///
  /// In en, this message translates to:
  /// **'Shared Timeline & Reminders'**
  String get dashSharedTimelineReminders;

  /// No description provided for @dashEncouragingMessage.
  ///
  /// In en, this message translates to:
  /// **'Encouraging Message:'**
  String get dashEncouragingMessage;

  /// No description provided for @dashPartnerTasksConversationStarters.
  ///
  /// In en, this message translates to:
  /// **'PARTNER TASKS & CONVERSATION STARTERS'**
  String get dashPartnerTasksConversationStarters;

  /// No description provided for @dashLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get dashLearnMore;

  /// No description provided for @dashKickCountDaily.
  ///
  /// In en, this message translates to:
  /// **'KICK COUNT (DAILY)'**
  String get dashKickCountDaily;

  /// No description provided for @dashOptionalHealthData.
  ///
  /// In en, this message translates to:
  /// **'OPTIONAL HEALTH DATA'**
  String get dashOptionalHealthData;

  /// No description provided for @dashLogBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Log Blood Pressure'**
  String get dashLogBloodPressure;

  /// No description provided for @dashBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get dashBloodPressure;

  /// No description provided for @dashLogBloodSugar.
  ///
  /// In en, this message translates to:
  /// **'Log Blood Sugar'**
  String get dashLogBloodSugar;

  /// No description provided for @dashBloodSugar.
  ///
  /// In en, this message translates to:
  /// **'Blood Sugar'**
  String get dashBloodSugar;

  /// No description provided for @dashPregnancyMStudioEntry.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy M Studio Entry'**
  String get dashPregnancyMStudioEntry;

  /// No description provided for @dashPregnancyPrepLists.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy Prep & Lists'**
  String get dashPregnancyPrepLists;

  /// No description provided for @dashSharedPregnancyTimeline.
  ///
  /// In en, this message translates to:
  /// **'Shared Pregnancy Timeline'**
  String get dashSharedPregnancyTimeline;

  /// No description provided for @dashCoordinatedChecklistsTasks.
  ///
  /// In en, this message translates to:
  /// **'Coordinated Checklists & Tasks:'**
  String get dashCoordinatedChecklistsTasks;

  /// No description provided for @dashPostpartumMStudioEntry.
  ///
  /// In en, this message translates to:
  /// **'Postpartum M Studio Entry'**
  String get dashPostpartumMStudioEntry;

  /// No description provided for @dashMotherBabyCoordinatedTasks.
  ///
  /// In en, this message translates to:
  /// **'Mother-Baby Coordinated Tasks'**
  String get dashMotherBabyCoordinatedTasks;

  /// No description provided for @dashTransitionTrackingHistory.
  ///
  /// In en, this message translates to:
  /// **'Transition Tracking & History'**
  String get dashTransitionTrackingHistory;

  /// No description provided for @dashViewFullHistory.
  ///
  /// In en, this message translates to:
  /// **'View Full History'**
  String get dashViewFullHistory;

  /// No description provided for @dashMStudioReflection.
  ///
  /// In en, this message translates to:
  /// **'M Studio Reflection'**
  String get dashMStudioReflection;

  /// No description provided for @dashLongTermWellnessOverview.
  ///
  /// In en, this message translates to:
  /// **'Long-Term Wellness Overview'**
  String get dashLongTermWellnessOverview;

  /// No description provided for @dashTodaySCheck.
  ///
  /// In en, this message translates to:
  /// **'Log Today\'s Symptoms'**
  String get dashTodaySCheck;

  /// No description provided for @dashViewHealthHistory.
  ///
  /// In en, this message translates to:
  /// **'View Health History'**
  String get dashViewHealthHistory;

  /// No description provided for @dashBloodPressureOptional.
  ///
  /// In en, this message translates to:
  /// **'BLOOD PRESSURE (OPTIONAL)'**
  String get dashBloodPressureOptional;

  /// No description provided for @dashEmpoweredPostMenopauseWellness.
  ///
  /// In en, this message translates to:
  /// **'EMPOWERED POST-MENOPAUSE WELLNESS CARDS'**
  String get dashEmpoweredPostMenopauseWellness;

  /// No description provided for @dashWhyMattersEncouragesSustainable.
  ///
  /// In en, this message translates to:
  /// **'Why This Matters: Encourages sustainable heart, joint and bone vitalities.'**
  String get dashWhyMattersEncouragesSustainable;

  /// No description provided for @dashDailyLifestyleOverview.
  ///
  /// In en, this message translates to:
  /// **'Daily Lifestyle Overview'**
  String get dashDailyLifestyleOverview;

  /// No description provided for @dashCycleOverview.
  ///
  /// In en, this message translates to:
  /// **'CYCLE OVERVIEW'**
  String get dashCycleOverview;

  /// No description provided for @dashViewWellnessHistory.
  ///
  /// In en, this message translates to:
  /// **'View Wellness History'**
  String get dashViewWellnessHistory;

  /// No description provided for @dashRecordCurrentWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Record your current weight in kg to track trends over time.'**
  String get dashRecordCurrentWeightKg;

  /// No description provided for @dashAiGeneratedHabitInsights.
  ///
  /// In en, this message translates to:
  /// **'AI-Generated Habit Insights'**
  String get dashAiGeneratedHabitInsights;

  /// No description provided for @dashWhyMattersSupportsOverall.
  ///
  /// In en, this message translates to:
  /// **'Why This Matters: Supports overall physical health and emotional vitality.'**
  String get dashWhyMattersSupportsOverall;

  /// Heading of the first-run language picker.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageChoiceTitle;

  /// Explains that the choice covers both the interface and Docsy.
  ///
  /// In en, this message translates to:
  /// **'Blushy and Docsy will speak this language. You can change it any time in Settings.'**
  String get languageChoiceSubtitle;

  /// Confirms the language and leaves the picker.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languageChoiceContinue;

  /// Action on an insight that needs more days of data, where the user has already logged at least once.
  ///
  /// In en, this message translates to:
  /// **'Log today\'s check-in'**
  String get dashLogTodayCheckIn;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get lwmcTodayWithDocsy;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy'**
  String get lwmcAskDocsy;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'No period logged yet'**
  String get lwmcNoPeriodLoggedYet;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'DOCSY’S SUGGESTION'**
  String get lwmcDocsySSuggestion;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy →'**
  String get lwmcAskDocsy2;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Try →'**
  String get lwmcTry;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'View Plan →'**
  String get lwmcViewPlan;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Read →'**
  String get lwmcRead;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Prepare my visit summary'**
  String get lwmcPrepareMyVisitSummary;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Something Feels Different'**
  String get lwmcSomethingFeelsDifferent;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Tell Docsy What Happened'**
  String get lwmcTellDocsyWhatHappened;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Submit to Docsy'**
  String get lwmcSubmitToDocsy;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinical Visit Summary'**
  String get lwmcClinicalVisitSummary;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get lwmcClose;

  /// Interface chrome on the lwmc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Expand with Docsy'**
  String get lwmcExpandWithDocsy;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get fpnsChange;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'First-Period Kit'**
  String get fpnsFirstPeriodKit;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save & Done'**
  String get fpnsSaveDone;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log a period start'**
  String get fpnsLogAPeriodStart;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Your body, lately'**
  String get fpnsYourBodyLately;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get fpnsMilestones;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'First-period kit'**
  String get fpnsFirstPeriodKit2;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'If it happens today'**
  String get fpnsIfItHappensToday;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'See full 5-step guide'**
  String get fpnsSeeFull5StepGuide;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Talk →'**
  String get fpnsTalk;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Share with Mom'**
  String get fpnsShareWithMom;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get fpnsNextQuestion;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Keep exploring'**
  String get fpnsKeepExploring;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Updated Daily'**
  String get fpnsUpdatedDaily;

  /// Interface chrome on the fpns dashboard.
  ///
  /// In en, this message translates to:
  /// **'Read article'**
  String get fpnsReadArticle;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'No period logged yet'**
  String get fpsNoPeriodLoggedYet;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Insights for your phase'**
  String get fpsInsightsForYourPhase;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Quick Guides'**
  String get fpsQuickGuides;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cramp Rescue →'**
  String get fpsCrampRescue;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'School Tips'**
  String get fpsSchoolTips;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'My School Bag Kit'**
  String get fpsMySchoolBagKit;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Things I’m noticing lately'**
  String get fpsThingsIMNoticingLately;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Understand with Docsy →'**
  String get fpsUnderstandWithDocsy;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cramp Rescue'**
  String get fpsCrampRescue2;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'I feel better'**
  String get fpsIFeelBetter;

  /// Interface chrome on the fps dashboard.
  ///
  /// In en, this message translates to:
  /// **'Share with Mom →'**
  String get fpsShareWithMom;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log Period Date'**
  String get hhLogPeriodDate;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Flow Intensity'**
  String get hhFlowIntensity;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Period Date'**
  String get hhSavePeriodDate;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get hhTodayWithDocsy;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Explore with Docsy'**
  String get hhExploreWithDocsy;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'YOUR CYCLE'**
  String get hhYourCycle;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'No period logged yet'**
  String get hhNoPeriodLoggedYet;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'FLARE COMFORT MODE ACTIVE'**
  String get hhFlareComfortModeActive;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Exit Flare Mode'**
  String get hhExitFlareMode;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'DAILY SIGNALS'**
  String get hhDailySignals;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Voice / Notes'**
  String get hhVoiceNotes;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Analyze with Docsy'**
  String get hhAnalyzeWithDocsy;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Pattern Memory Building'**
  String get hhPatternMemoryBuilding;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy'**
  String get hhAskDocsy;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'No treatments recorded yet'**
  String get hhNoTreatmentsRecordedYet;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add Treatment / Protocol'**
  String get hhAddTreatmentProtocol;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Treatment'**
  String get hhSaveTreatment;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy ›'**
  String get hhAskDocsy2;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Upload another record'**
  String get hhUploadAnotherRecord;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Record'**
  String get hhSaveRecord;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'DOCTOR VISIT BRIEF'**
  String get hhDoctorVisitBrief;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Create doctor summary'**
  String get hhCreateDoctorSummary;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinical Brief'**
  String get hhClinicalBrief;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get hhClose;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get hhUpdate;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add trusted contact'**
  String get hhAddTrustedContact;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add Support Contact'**
  String get hhAddSupportContact;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Contact'**
  String get hhSaveContact;

  /// Interface chrome on the hh dashboard.
  ///
  /// In en, this message translates to:
  /// **'Check with Docsy'**
  String get hhCheckWithDocsy;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get menoTodayWithDocsy;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'ASK DOCSY TODAY'**
  String get menoAskDocsyToday;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Today\'s Log'**
  String get menoSaveTodaySLog;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Nothing much today'**
  String get menoNothingMuchToday;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S STEADY'**
  String get menoWhatSSteady;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Learn guidance →'**
  String get menoLearnGuidance;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY NORMAL'**
  String get menoMyNormal;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY TREATMENT JOURNEY'**
  String get menoMyTreatmentJourney;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get menoAdd;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get menoActive;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY QUESTIONS INBOX'**
  String get menoMyQuestionsInbox;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Question'**
  String get menoSaveQuestion;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Read 30s summary →'**
  String get menoRead30sSummary;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Something feels different'**
  String get menoSomethingFeelsDifferent;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Prepare Doctor Consultation'**
  String get menoPrepareDoctorConsultation;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Understand Note'**
  String get menoUnderstandNote;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Confirm What You Logged'**
  String get menoConfirmWhatYouLogged;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get menoCancel;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Save'**
  String get menoConfirmSave;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy'**
  String get menoAskDocsy;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Prepare Doctor Summary'**
  String get menoPrepareDoctorSummary;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save question for doctor'**
  String get menoSaveQuestionForDoctor;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save to Questions Inbox'**
  String get menoSaveToQuestionsInbox;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add medication or supplement'**
  String get menoAddMedicationOrSupplement;

  /// Interface chrome on the meno dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Treatment'**
  String get menoSaveTreatment;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get periTodayWithDocsy;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Midlife Companion Intelligence'**
  String get periMidlifeCompanionIntelligence;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY CHANGING CYCLE'**
  String get periMyChangingCycle;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Non-Predictive Midlife Rhythm'**
  String get periNonPredictiveMidlifeRhythm;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log Period'**
  String get periLogPeriod;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get periStatus;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Recent Cycle Intervals'**
  String get periRecentCycleIntervals;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU\'VE BEEN NOTICING'**
  String get periWhatYouVeBeenNoticing;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log Check-In'**
  String get periLogCheckIn;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT CHANGED & CONNECTIONS'**
  String get periWhatChangedConnections;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Weekly Shift'**
  String get periWeeklyShift;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Discovered Connections'**
  String get periDiscoveredConnections;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'YOUR CURRENT FOCUS'**
  String get periYourCurrentFocus;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get periAdd;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Tell'**
  String get periTell;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Your 1-Page Appointment Brief'**
  String get periYour1PageAppointmentBrief;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'View Brief'**
  String get periViewBrief;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Copy for Doctor'**
  String get periCopyForDoctor;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'INTIMATE & SEXUAL HEALTH'**
  String get periIntimateSexualHealth;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY STORY · TIMELINE'**
  String get periMyStoryTimeline;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'KEEP EXPLORING'**
  String get periKeepExploring;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log Period Start Date'**
  String get periLogPeriodStartDate;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Observation'**
  String get periSaveObservation;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Daily Transition Check-In'**
  String get periDailyTransitionCheckIn;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Complete Check-In'**
  String get periCompleteCheckIn;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add Treatment / Support'**
  String get periAddTreatmentSupport;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get periCancel;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get periSave;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinician Brief Preview'**
  String get periClinicianBriefPreview;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get periClose;

  /// Interface chrome on the peri dashboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get periCopy;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get ppTodayWithDocsy;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Your 4th Trimester Companion'**
  String get ppYour4thTrimesterCompanion;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Saved & Synced'**
  String get ppSavedSynced;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Talk to Docsy →'**
  String get ppTalkToDocsy;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY, I\'D PRIORITIZE'**
  String get ppTodayIDPrioritize;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'NOTICED SHIFTS'**
  String get ppNoticedShifts;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S BEEN STEADY'**
  String get ppWhatSBeenSteady;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Observing Initial Baseline'**
  String get ppObservingInitialBaseline;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'I\'M DONE FOR TODAY'**
  String get ppIMDoneForToday;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'TONIGHT WIND-DOWN'**
  String get ppTonightWindDown;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Active Nursing Stopwatch'**
  String get ppActiveNursingStopwatch;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Logged Wet Diaper 💧'**
  String get ppLoggedWetDiaper;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Logged Soiled Diaper 💩'**
  String get ppLoggedSoiledDiaper;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'DAILY RECOVERY PROGRESSION'**
  String get ppDailyRecoveryProgression;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Build Doctor Summary →'**
  String get ppBuildDoctorSummary;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'TIMELINE GUIDELINE'**
  String get ppTimelineGuideline;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDATION'**
  String get ppRecommendation;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask Docsy More →'**
  String get ppAskDocsyMore;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get ppClose;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Talk to Docsy'**
  String get ppTalkToDocsy2;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Ask for Help'**
  String get ppAskForHelp;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Resume Normal Mode'**
  String get ppResumeNormalMode;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Calibrate Postpartum Path'**
  String get ppCalibratePostpartumPath;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'BABY\'S BIRTH DATE'**
  String get ppBabySBirthDate;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'DELIVERY PATH'**
  String get ppDeliveryPath;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Vaginal Birth'**
  String get ppVaginalBirth;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'C-Section'**
  String get ppCSection;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'FEEDING METHOD'**
  String get ppFeedingMethod;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ppCancel;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save & Calibrate'**
  String get ppSaveCalibrate;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'I Need Help Today'**
  String get ppINeedHelpToday;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Generate & Share'**
  String get ppGenerateShare;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinical Safety Triage'**
  String get ppClinicalSafetyTriage;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Talk to Docsy Now'**
  String get ppTalkToDocsyNow;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENED (EVENT)'**
  String get ppWhatHappenedEvent;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT CHANGED (OBSERVED SHIFT)'**
  String get ppWhatChangedObservedShift;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'Understand with Docsy →'**
  String get ppUnderstandWithDocsy;

  /// Interface chrome on the pp dashboard.
  ///
  /// In en, this message translates to:
  /// **'CLINICAL SAFETY ALERT'**
  String get ppClinicalSafetyAlert;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add to Pregnancy Story'**
  String get pregAddToPregnancyStory;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pregCancel;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Save Memory'**
  String get pregSaveMemory;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY WITH DOCSY'**
  String get pregTodayWithDocsy;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Your Body Today'**
  String get pregYourBodyToday;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Baby This Week'**
  String get pregBabyThisWeek;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'ONE THING TO KNOW'**
  String get pregOneThingToKnow;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'ONE THING TO DO'**
  String get pregOneThingToDo;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'YOUR GESTATIONAL TIMELINE'**
  String get pregYourGestationalTimeline;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Setup Required'**
  String get pregSetupRequired;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Set Estimated Due Date'**
  String get pregSetEstimatedDueDate;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'DAILY MATERNAL CHECK-IN'**
  String get pregDailyMaternalCheckIn;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Explore with Docsy'**
  String get pregExploreWithDocsy;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S HAPPENING THIS WEEK'**
  String get pregWhatSHappeningThisWeek;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Set Due Date'**
  String get pregSetDueDate;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'YOUR NEXT APPOINTMENT'**
  String get pregYourNextAppointment;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Build Doctor Summary'**
  String get pregBuildDoctorSummary;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add Doctor Question'**
  String get pregAddDoctorQuestion;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get pregAdd;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Share with Partner'**
  String get pregShareWithPartner;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'MY PREGNANCY STORY'**
  String get pregMyPregnancyStory;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'+ Add Moment'**
  String get pregAddMoment;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'No Moments Recorded Yet'**
  String get pregNoMomentsRecordedYet;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'Add First Moment'**
  String get pregAddFirstMoment;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'30-SECOND EXPLAINER'**
  String get preg30SecondExplainer;

  /// Interface chrome on the preg dashboard.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get pregAdd2;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S BIOMARKER LOG'**
  String get ttcTodaySBiomarkerLog;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Natural Cycle-to-Cycle Rhythm'**
  String get ttcNaturalCycleToCycleRhythm;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Honest Signal Coverage'**
  String get ttcHonestSignalCoverage;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Generate Clinical Report'**
  String get ttcGenerateClinicalReport;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Log Period Date'**
  String get ttcLogPeriodDate;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Pause Fertility Tracking'**
  String get ttcPauseFertilityTracking;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Pause for 1 week'**
  String get ttcPauseFor1Week;

  /// Interface chrome on the ttc dashboard.
  ///
  /// In en, this message translates to:
  /// **'Pause until next period'**
  String get ttcPauseUntilNextPeriod;
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
