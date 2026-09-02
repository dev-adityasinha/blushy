// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get navHome => 'হোম';

  @override
  String get navCommunity => 'কমিউনিটি';

  @override
  String get navSia => 'Docsy';

  @override
  String get navStudio => 'এম স্টুডিও';

  @override
  String get navPartner => 'পার্টনার';

  @override
  String get actionSave => 'সংরক্ষণ করুন';

  @override
  String get actionCancel => 'বাতিল করুন';

  @override
  String get actionClose => 'বন্ধ করুন';

  @override
  String get actionRetry => 'আবার চেষ্টা করুন';

  @override
  String get actionDelete => 'মুছে ফেলুন';

  @override
  String get actionShare => 'শেয়ার করুন';

  @override
  String get actionShared => 'শেয়ার করা হয়েছে';

  @override
  String get actionAsk => 'জিজ্ঞাসা করুন';

  @override
  String get actionStart => 'শুরু করুন';

  @override
  String get actionPause => 'বিরতি';

  @override
  String get actionDone => 'সম্পন্ন';

  @override
  String get actionRefresh => 'রিফ্রেশ করুন';

  @override
  String get actionSignOut => 'সাইন আউট';

  @override
  String get stateLoading => 'লোড হচ্ছে…';

  @override
  String get stateOfflineWithCache =>
      'সংযোগ নেই। আপনার সর্বশেষ সংরক্ষিত দৃশ্য দেখানো হচ্ছে।';

  @override
  String get stateOfflineNoCache =>
      'এখন সার্ভারে পৌঁছানো যাচ্ছে না। সংযোগ ফিরে এলেই এটি লোড হবে।';

  @override
  String get stateRefreshing => 'রিফ্রেশ হচ্ছে…';

  @override
  String get stateNothingYet => 'এখনও কিছু লেখা হয়নি।';

  @override
  String get stateNotSharedWithYou => 'আপনার সাথে শেয়ার করা হয়নি।';

  @override
  String get stateCouldNotSave => 'সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get languageSheetTitle => 'Docsy যে ভাষায় বলে';

  @override
  String get languageSheetExplainer =>
      'এটি Docsyর উত্তরের ভাষা বদলায়। বাকি অ্যাপ আপাতত ইংরেজিতেই থাকবে।';

  @override
  String get privacyTitle => 'গোপনীয়তা ও শেয়ারিং';

  @override
  String get privacyWhatYouReceive => 'আপনি যা পান';

  @override
  String get privacyPartnerDecides =>
      'আপনার সঙ্গী ঠিক করেন এই ডিভাইসে কী পৌঁছাবে, এক একটি বিভাগ ধরে। তিনি যেকোনো সময় তা বদলাতে পারেন, এবং পরিবর্তন আপনার পরবর্তী অনুরোধেই কার্যকর হয়।';

  @override
  String get privacyOn => 'চালু';

  @override
  String get privacyOff => 'বন্ধ';

  @override
  String get privacyAsked => 'জিজ্ঞাসা করা হয়েছে';

  @override
  String get connectFirst => 'আগে আপনার সঙ্গীর সাথে যুক্ত হোন।';

  @override
  String memoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি স্মৃতি',
      one: '১টি স্মৃতি',
      zero: 'এখনও কোনো স্মৃতি নেই',
    );
    return '$_temp0';
  }

  @override
  String minutesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count মিনিট',
      one: '১ মিনিট',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'সেটিংস ও গোপনীয়তা কেন্দ্র';

  @override
  String get settingsSiaAssistant => 'Docsy এআই সহকারী';

  @override
  String get settingsSiaAssistantSub => 'টাইপিং পরামর্শ ও প্রতিফলনের সঙ্গী';

  @override
  String get settingsMemoryBooks => 'স্মৃতির বই';

  @override
  String get settingsMemoryBooksSub =>
      'সাপ্তাহিক ও মাসিক সারসংক্ষেপ স্ক্র্যাপবুক';

  @override
  String get settingsContentGarden => 'প্রতিফলনের বাগান';

  @override
  String get settingsContentGardenSub =>
      'আপনার জার্নালের বৈচিত্র্যের সাথে বেড়ে ওঠা বাগান';

  @override
  String get settingsTimeCapsules => 'স্মৃতির টাইম ক্যাপসুল';

  @override
  String get settingsTimeCapsulesSub =>
      'সিল করা স্মৃতি, আপনার বেছে নেওয়া দিনে খোলে';

  @override
  String get settingsReducedMotion => 'কম অ্যানিমেশন';

  @override
  String get settingsReducedMotionSub => 'অপ্রয়োজনীয় অ্যানিমেশন বন্ধ করুন';

  @override
  String get settingsHighContrast => 'উচ্চ কনট্রাস্ট থিম';

  @override
  String get settingsHighContrastSub => 'লেখা ও সীমানার কনট্রাস্ট বাড়ান';

  @override
  String get settingsLargeHandles => 'বড় হ্যান্ডেল নিয়ন্ত্রণ';

  @override
  String get settingsLargeHandlesSub =>
      'সহজে নির্বাচনের জন্য কোণের হ্যান্ডেল বড় করুন';

  @override
  String get settingsDiagnostics => 'প্ল্যাটফর্ম ডায়াগনস্টিকস';

  @override
  String get settingsDiagnosticsSub =>
      'স্টোরেজ, ক্যাশে, সার্চ ইনডেক্স ও এআই সারির অবস্থা দেখুন';

  @override
  String get siaAsk => 'Docsyকে জিজ্ঞাসা করুন';

  @override
  String get siaThinking => 'Typing....';

  @override
  String get siaVoiceTranscribed =>
      'কণ্ঠস্বর লেখায় রূপান্তরিত হয়েছে। দেখে নিয়ে পাঠান।';

  @override
  String get siaNoSpeechRecognised =>
      'কোনো কথা শনাক্ত করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get siaNoAudioRecorded =>
      'কোনো অডিও রেকর্ড হয়নি। মাইক্রোফোনের অনুমতি দেখুন।';

  @override
  String get siaConversationStarters => 'আলাপ শুরু করুন';

  @override
  String get siaHowFeelingToday => 'আজ আপনার কেমন লাগছে?';

  @override
  String get siaEnergyLevel => 'আপনার শক্তির মাত্রা কেমন?';

  @override
  String get siaLogSleep => 'ঘুমের সময় নথিভুক্ত করুন';

  @override
  String get siaLogPeriodStart => 'মাসিক শুরুর তারিখ নথিভুক্ত করুন';

  @override
  String get siaPeriodRecorded => 'মাসিক শুরুর তারিখ নথিভুক্ত হয়েছে।';

  @override
  String get siaLoggedSymptoms => 'নথিভুক্ত উপসর্গ ও সংকেত';

  @override
  String get siaLogCheckIn => 'স্বাস্থ্য চেক-ইন নথিভুক্ত করুন';

  @override
  String get siaDailyReflection => 'দৈনিক জার্নাল প্রতিফলন';

  @override
  String get siaOpenJournal => 'জার্নাল খুলুন';

  @override
  String get siaWriteBeforeSaving => 'সংরক্ষণের আগে আপনার ভাবনা লিখুন।';

  @override
  String get siaEntrySaved => 'আপনার জার্নাল এন্ট্রি সংরক্ষিত হয়েছে।';

  @override
  String get siaSaveEntry => 'এন্ট্রি সংরক্ষণ করুন';

  @override
  String get dashHowAreYouToday => 'আজ আপনি কেমন আছেন?';

  @override
  String get dashMood => 'মেজাজ';

  @override
  String get dashEnergyLevel => 'শক্তির মাত্রা';

  @override
  String get dashFlowLevel => 'রক্তস্রাবের মাত্রা';

  @override
  String get dashNotesReflections => 'নোট ও ভাবনা';

  @override
  String get dashCheckIn => 'চেক-ইন করুন';

  @override
  String get dashSiaInsights => 'Docsyর পর্যবেক্ষণ';

  @override
  String get dashHelpful => 'সহায়ক';

  @override
  String get dashNotUseful => 'সহায়ক নয়';

  @override
  String get dashPatternsTitle => 'চক্রের প্যাটার্ন ও পর্যবেক্ষণ';

  @override
  String get dashPatternNotDiagnosis =>
      'এটি আপনার নথিভুক্ত তথ্যের একটি প্যাটার্ন, কোনো রোগনির্ণয় বা কারণ নয়।';

  @override
  String get dashNothingLoggedYet =>
      'এখনও কিছু নথিভুক্ত হয়নি। আপনি যা লিখবেন তা এখানে দেখা যাবে।';

  @override
  String get dashNoCommunityPosts => 'এই বিষয়ে এখনও কোনো পোস্ট নেই।';

  @override
  String get dashYourConditions => 'আপনার অবস্থা';

  @override
  String get dashNoReviewedArticle =>
      'এর জন্য এখনও পর্যালোচিত কোনো নিবন্ধ নেই।';

  @override
  String get dashPrepareSummary => 'একটি সারসংক্ষেপ তৈরি করুন';

  @override
  String get dashBuildMySummary => 'আমার সারসংক্ষেপ তৈরি করুন';

  @override
  String get dashSummaryNotDiagnosis =>
      'আপনি যা জানিয়েছেন এবং অ্যাপ যা লক্ষ্য করেছে তার নথি। এটি রোগনির্ণয় নয়।';

  @override
  String get dashLogWeight => 'ওজন নথিভুক্ত করুন';

  @override
  String get dashLogPeriod => 'মাসিক নথিভুক্ত করুন';

  @override
  String get dashDismiss => 'সরান';

  @override
  String get dashNotNow => 'এখন নয়';

  @override
  String get journalAutoSaving => 'স্বয়ংক্রিয়ভাবে সংরক্ষিত হচ্ছে…';

  @override
  String get journalNewMemory => 'নতুন স্মৃতি';

  @override
  String get journalBackToHome => 'হোমে ফিরে যান';

  @override
  String get journalReadingYourEntries => 'আপনি যা লিখেছেন তা দেখা হচ্ছে…';

  @override
  String get journalNothingToReflect =>
      'এখনও ভাবার মতো কিছু নেই। কিছু লিখুন, Docsy তা আপনাকে পড়ে শোনাবে।';

  @override
  String get journalNoMemoriesFound => 'এখনও কোনো স্মৃতি পাওয়া যায়নি';

  @override
  String get journalNoSearchMatch => 'সেই অনুসন্ধানে কোনো এন্ট্রি মেলেনি।';

  @override
  String get journalRecordVoiceNote => 'ভয়েস নোট রেকর্ড করুন';

  @override
  String get journalDoneRecording => 'রেকর্ডিং সম্পন্ন';

  @override
  String get journalAddTextBox => 'টেক্সট বক্স যোগ করুন';

  @override
  String get journalPaperTheme => 'কাগজের থিম';

  @override
  String get journalFontStyle => 'ফন্ট শৈলী';

  @override
  String get journalApply => 'প্রয়োগ করুন';

  @override
  String get journalAiPrivacyControls => 'এআই ও গোপনীয়তা নিয়ন্ত্রণ';

  @override
  String get journalAiPrivacySub =>
      'আপনার জার্নালে কোন এআই সুবিধা চলবে তা বেছে নিন';

  @override
  String get journalTitleGeneration => 'শিরোনামের পরামর্শ';

  @override
  String get journalSmartSearch => 'অনুসন্ধান ও সংগ্রহ';

  @override
  String get journalSmartSearchSub =>
      'কীওয়ার্ড ও সম্পর্কিত শব্দ দিয়ে আপনার এন্ট্রি খুঁজুন';

  @override
  String get journalCloudAi => 'ক্লাউড এআই';

  @override
  String get journalCloudAiSub =>
      'Docsyর পর্যবেক্ষণের জন্য ক্লাউড প্রসেসিং অনুমোদন করুন';

  @override
  String get journalCloseMemoryBook => 'স্মৃতির বই বন্ধ করুন';

  @override
  String get journalSelectTemplate => 'জার্নাল টেমপ্লেট নির্বাচন করুন';

  @override
  String get journalCreateNew => 'নতুন জার্নাল তৈরি করুন';

  @override
  String get partnerNoConnection => 'কোনো সক্রিয় পার্টনার সংযোগ নেই';

  @override
  String get partnerSendInviteExplainer =>
      'আপডেট ও পর্যবেক্ষণ শেয়ার শুরু করতে আপনার সঙ্গীকে তাদের ইমেল ঠিকানায় আমন্ত্রণ পাঠান।';

  @override
  String get partnerInvalidEmail => 'একটি বৈধ ইমেল ঠিকানা লিখুন।';

  @override
  String get partnerInviteSent => 'আমন্ত্রণ পাঠানো হয়েছে।';

  @override
  String get partnerInviteLinkTitle => 'শেয়ারযোগ্য আমন্ত্রণ লিঙ্ক';

  @override
  String get partnerHaveInviteCode => 'আমার কাছে একটি আমন্ত্রণ কোড আছে';

  @override
  String get partnerEnterInviteCode => 'একটি আমন্ত্রণ কোড লিখুন';

  @override
  String get partnerNoPendingRequests => 'কোনো অপেক্ষমাণ অনুরোধ নেই';

  @override
  String get partnerAccept => 'গ্রহণ করুন';

  @override
  String get partnerDecline => 'প্রত্যাখ্যান করুন';

  @override
  String get partnerDisconnect => 'সংযোগ বিচ্ছিন্ন করুন';

  @override
  String get partnerNoMessages => 'এখনও কোনো বার্তা নেই';

  @override
  String get partnerSayHello => 'কথা শুরু করতে হ্যালো বলুন।';

  @override
  String get partnerSiaDecoding => 'Docsy বুঝছে…';

  @override
  String get partnerSuggestedReply => 'প্রস্তাবিত উত্তর';

  @override
  String get partnerUseReply => 'এই উত্তর ব্যবহার করুন';

  @override
  String get partnerDateIdeas => 'ডেটের পরামর্শ';

  @override
  String get partnerSharedActivities => 'যৌথ কার্যক্রম';

  @override
  String get partnerLettersTitle => 'চিঠি';

  @override
  String get partnerWriteLetter => 'চিঠি লিখুন';

  @override
  String get partnerNoLetters =>
      'এখনও কোনো চিঠি নেই। একটি লিখুন, তা এখানে আপনাদের দুজনের জন্য রাখা হবে।';

  @override
  String get partnerMemoryBook => 'স্মৃতির বই';

  @override
  String get partnerNoMemories =>
      'এখানে এখনও কিছু নেই। একসাথে একটি কার্যক্রম শেষ করুন, তা এখানে রাখা হবে।';

  @override
  String get partnerSiaAdviceTitle => 'Docsyর সম্পর্ক পরামর্শ';

  @override
  String get partnerSiaAdviceExplainer =>
      'আপনার মনে যা আছে জিজ্ঞাসা করুন। Docsy কেবল তাই দেখে যা আপনার সঙ্গী শেয়ার করতে বেছে নিয়েছেন।';

  @override
  String get partnerTryAgain => 'আবার চেষ্টা করুন';

  @override
  String homeGreetingMorning(String name) {
    return 'সুপ্রভাত, $name';
  }

  @override
  String homeGreetingAfternoon(String name) {
    return 'শুভ অপরাহ্ণ, $name';
  }

  @override
  String homeGreetingEvening(String name) {
    return 'শুভ সন্ধ্যা, $name';
  }

  @override
  String get homeGreetingSubtitle =>
      'আজ যেমনই হোক, এটা আপনাকে একা করতে হবে না।';

  @override
  String get dashLogFirstCheckIn => 'প্রথম চেক-ইন লিখুন';

  @override
  String get dashAddCondition => 'অবস্থা যোগ করুন';

  @override
  String get onbContinue => 'চালিয়ে যান';

  @override
  String get onbBack => 'ফিরে যান';

  @override
  String get onbDontRemember => 'আমার মনে নেই';

  @override
  String get onbLetsGetIntroduced => 'চলুন পরিচিত হই';

  @override
  String get onbCreatingSafeSpace => 'আপনার নিরাপদ জায়গা তৈরি হচ্ছে';

  @override
  String get onbCuratingContent => 'সুস্থতার বিষয়বস্তু বাছাই হচ্ছে';

  @override
  String get onbCreatingInsights => 'আপনার দৈনন্দিন তথ্য তৈরি হচ্ছে';

  @override
  String get onbPreparingDocsy => 'Docsy প্রস্তুত হচ্ছে';

  @override
  String get jrnCancel => 'বাতিল';

  @override
  String get jrnShare => 'শেয়ার';

  @override
  String get jrnDelete => 'মুছুন';

  @override
  String get jrnCouldNotTranscribe => 'সেই রেকর্ডিং লেখা যায়নি।';

  @override
  String get jrnNothingRecognised =>
      'সেই রেকর্ডিংয়ে কিছু শনাক্ত হয়নি। আপনি টাইপ করতে পারেন।';

  @override
  String get jrnCouldNotChangeSharing =>
      'সেই দিনের শেয়ারিং পরিবর্তন করা যায়নি।';

  @override
  String get jrnNoLongerShared => 'আর শেয়ার করা হয় না।';

  @override
  String get jrnTranscribing => 'লিখে নেওয়া হচ্ছে…';

  @override
  String get jrnRecordingVoiceNote => 'ভয়েস রেকর্ড হচ্ছে…';

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
