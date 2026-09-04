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
  String get csoSignOut => 'সাইন আউট করুন';

  @override
  String get csoCancel => 'বাতিল করুন';

  @override
  String get crRecordedAgainstEverythingYou =>
      'আপনি যা অনুমোদন করেছেন তার সবকিছুর সঙ্গে নথিভুক্ত।';

  @override
  String get eafWhatSYourEmail => 'আপনার ইমেল কী?';

  @override
  String get eafCreateYourPassword => 'আপনার পাসওয়ার্ড তৈরি করুন';

  @override
  String get eafCheckYourEmail => 'আপনার ইমেল দেখুন';

  @override
  String get eafChangeEmail => 'ইমেল পরিবর্তন করুন';

  @override
  String get eafWelcomeBack => 'আবার স্বাগতম';

  @override
  String get eafForgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get eafResetPassword => 'পাসওয়ার্ড রিসেট করুন';

  @override
  String get eafChooseANewPassword => 'নতুন পাসওয়ার্ড বাছুন';

  @override
  String get oPrivacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get oIAgreeToThe => 'আমি সম্মত ';

  @override
  String get oTermsOfService => 'পরিষেবার শর্তাবলী';

  @override
  String get oWhenIsYourBirthday => 'আপনার জন্মদিন কবে?';

  @override
  String get oWhereAreYouToday => 'আজ আপনি কোথায় আছেন?';

  @override
  String get oWhenDidYourLast => 'আপনার শেষ ঋতুস্রাব কবে শুরু হয়েছিল?';

  @override
  String get oWhatSYourDue => 'আপনার সম্ভাব্য প্রসবের তারিখ কী?';

  @override
  String get oWhenWasYourBaby => 'আপনার শিশু কবে জন্মেছে?';

  @override
  String get oYourPreferredName => 'আপনার পছন্দের নাম';

  @override
  String get oWhatWouldYouLike => 'আপনি প্রথমে কী জানতে চান?';

  @override
  String get oWhenDidYourFirst => 'আপনার প্রথম ঋতুস্রাব কবে শুরু হয়েছিল?';

  @override
  String get oWhatWouldYouLike2 => 'আপনি কীসে সাহায্য চান?';

  @override
  String get oHowWouldYouDescribe => 'আপনি আপনার চক্রকে কীভাবে বর্ণনা করবেন?';

  @override
  String get oWhatWouldYouLike3 => 'Blushy আপনাকে কীসে সাহায্য করুক?';

  @override
  String get oAreYouCurrentlyUsing =>
      'আপনি কি বর্তমানে হরমোনাল জন্মনিয়ন্ত্রণ নিচ্ছেন?';

  @override
  String get oWhichConditionBestMatches =>
      'কোন অবস্থাটি আপনার পরিস্থিতির সঙ্গে সবচেয়ে মেলে?';

  @override
  String get oWhichSymptomsAffectYou =>
      'কোন উপসর্গগুলি আপনাকে সবচেয়ে বেশি প্রভাবিত করে?';

  @override
  String get oAreYouCurrentlyReceiving => 'আপনার কি বর্তমানে চিকিৎসা চলছে?';

  @override
  String get oHowLongHaveYou => 'আপনি কতদিন ধরে চেষ্টা করছেন?';

  @override
  String get oHowAreYouTracking => 'আপনি প্রজনন ক্ষমতা কীভাবে নথিভুক্ত করছেন?';

  @override
  String get oAreYouCurrentlyReceiving2 =>
      'আপনার কি বর্তমানে প্রজনন চিকিৎসা চলছে?';

  @override
  String get oIsThisYourFirst => 'এটি কি আপনার প্রথম গর্ভাবস্থা?';

  @override
  String get oWhatSupportWouldYou => 'আপনি কী ধরনের সহায়তা চান?';

  @override
  String get oHowAreYouFeeding => 'আপনি আপনার শিশুকে কীভাবে খাওয়াচ্ছেন?';

  @override
  String get oHowHaveYourPeriods => 'আপনার ঋতুস্রাবে কী পরিবর্তন হয়েছে?';

  @override
  String get oWhatWouldYouMost => 'আপনি সবচেয়ে বেশি কীসে উন্নতি চান?';

  @override
  String get oHowLongHasIt => 'আপনার শেষ ঋতুস্রাবের কত দিন হয়েছে?';

  @override
  String get oWhichSymptomsAffectYour =>
      'কোন উপসর্গগুলি আপনার দৈনন্দিন জীবনে প্রভাব ফেলে?';

  @override
  String get oWhatWouldYouLike4 => 'আপনি চান Blushy কীসে মনোযোগ দিক?';

  @override
  String get poYourPreferredName => 'আপনার পছন্দের নাম';

  @override
  String get sGoToSignIn => 'সাইন ইনে যান';

  @override
  String get sVerifyCode => 'কোড যাচাই করুন';

  @override
  String get sForgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get sIAgreeToThe => 'আমি সম্মত ';

  @override
  String get sTermsConditions => 'নিয়ম ও শর্তাবলী';

  @override
  String get sTerms => 'শর্তাবলী';

  @override
  String get sPrivacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get cPeople => 'মানুষ';

  @override
  String get cSearchTitleTextTags =>
      'শিরোনাম, লেখা, ট্যাগ বা ব্যবহারকারীর নাম/ইমেল খুঁজুন...';

  @override
  String get cpPublish => 'প্রকাশ করুন';

  @override
  String get cpAnInterestingTitle => 'একটি আকর্ষণীয় শিরোনাম...';

  @override
  String get cpShareYourThoughtsExperiences =>
      'আপনার ভাবনা, অভিজ্ঞতা বা প্রশ্ন ভাগ করুন...';

  @override
  String get cpEGLutealMoodswings => 'যেমন, লুটিয়াল, মুডসুইংস, স্লিপটিপস';

  @override
  String get pdDeleteComment => 'মন্তব্য মুছুন';

  @override
  String get pdAreYouSureYou => 'আপনি কি নিশ্চিত যে এই মন্তব্যটি মুছতে চান?';

  @override
  String get pdCancel => 'বাতিল করুন';

  @override
  String get pdDelete => 'মুছুন';

  @override
  String get pdDeletePost => 'পোস্ট মুছুন';

  @override
  String get pdAreYouSureYou2 => 'আপনি কি নিশ্চিত যে এই পোস্টটি মুছতে চান?';

  @override
  String get pdComments => 'মন্তব্য';

  @override
  String get upFailedToLoadProfile => 'প্রোফাইলের বিবরণ লোড করা যায়নি।';

  @override
  String get upCancel => 'বাতিল করুন';

  @override
  String get upSave => 'সংরক্ষণ করুন';

  @override
  String get hDrDocsy => 'Docsy';

  @override
  String get hClose => 'বন্ধ করুন';

  @override
  String get dsQuestionsToAsk => 'জিজ্ঞাসা করার মতো প্রশ্ন';

  @override
  String get umsdDailyUnifiedCheckIn => 'দৈনিক সমন্বিত চেক-ইন';

  @override
  String get umsdCheckInSavedAnd =>
      'চেক-ইন সংরক্ষিত হয়েছে এবং আপনার প্রোফাইলে সিঙ্ক হয়েছে! ✨';

  @override
  String get cYourCycleLengthIs =>
      'আপনার চক্রের দৈর্ঘ্য বদলাচ্ছে। প্রতিদিন উপসর্গ নথিভুক্ত করুন যাতে Docsy পূর্বাভাস ঠিক করতে পারে।';

  @override
  String get cTrackingIsDisabledFocus =>
      'ট্র্যাকিং বন্ধ আছে। আপনার দৈনন্দিন শক্তি, মেজাজ ও ঘুমে মনোযোগ দিন।';

  @override
  String get cYourRecommendationsAreAdapted =>
      'আপনার পরামর্শগুলি আপনার বর্তমান জীবনপর্যায় অনুযায়ী সাজানো হয়েছে।';

  @override
  String get paTodaySNextStep => 'আজকের পরবর্তী ধাপ';

  @override
  String get smClearDrDocsyMemory => 'Docsy-র স্মৃতি মুছুন';

  @override
  String get scClinicalAlignment => 'ক্লিনিক্যাল সামঞ্জস্য';

  @override
  String get scCurrentTrack => 'বর্তমান ট্র্যাক';

  @override
  String get scNewTrack => 'নতুন ট্র্যাক';

  @override
  String get scKeepCurrentTrack => 'বর্তমান ট্র্যাক রাখুন';

  @override
  String get scSwitchTrack => 'ট্র্যাক বদলান';

  @override
  String get sqWhatWouldYouLike => 'আপনি প্রথমে কী জানতে চান?';

  @override
  String get sqWhenDidYourFirst => 'আপনার প্রথম ঋতুস্রাব কবে শুরু হয়েছিল?';

  @override
  String get sqWhatWouldYouLike2 => 'আপনি কীসে সহায়তা চান?';

  @override
  String get sqHowWouldYouDescribe => 'আপনি আপনার চক্রকে কীভাবে বর্ণনা করবেন?';

  @override
  String get sqWhenDidYourLast => 'আপনার শেষ ঋতুস্রাব কবে শুরু হয়েছিল?';

  @override
  String get sqWhatAreYourPrimary => 'আপনার প্রধান স্বাস্থ্য লক্ষ্যগুলি কী?';

  @override
  String get sqAreYouUsingHormonal => 'আপনি কি হরমোনাল জন্মনিয়ন্ত্রণ নিচ্ছেন?';

  @override
  String get sqWhichHormonalConditionS =>
      'কোন হরমোনাল অবস্থা আপনার ক্ষেত্রে প্রযোজ্য?';

  @override
  String get sqWhichSymptomsAffectYou =>
      'কোন উপসর্গগুলি আপনাকে সবচেয়ে বেশি প্রভাবিত করে?';

  @override
  String get sqAreYouCurrentlyReceiving => 'আপনার কি বর্তমানে চিকিৎসা চলছে?';

  @override
  String get sqHowLongHaveYou => 'আপনি কতদিন ধরে গর্ভধারণের চেষ্টা করছেন?';

  @override
  String get sqHowAreYouTracking => 'আপনি প্রজনন ক্ষমতা কীভাবে নথিভুক্ত করছেন?';

  @override
  String get sqAreYouUndergoingFertility => 'আপনি কি প্রজনন সহায়তা নিচ্ছেন?';

  @override
  String get sqWhatIsYourEstimated => 'আপনার সম্ভাব্য প্রসবের তারিখ কী?';

  @override
  String get sqIsThisYourFirst => 'এটি কি আপনার প্রথম গর্ভাবস্থা?';

  @override
  String get sqWhatSupportWouldYou => 'গর্ভাবস্থায় আপনি কী ধরনের সহায়তা চান?';

  @override
  String get sqWhenWasYourBaby => 'আপনার শিশু কবে জন্মেছে?';

  @override
  String get sqHowAreYouFeeding => 'আপনি আপনার শিশুকে কীভাবে খাওয়াচ্ছেন?';

  @override
  String get sqWhatAreasWouldYou => 'আপনি কোন বিষয়ে সাহায্য চান?';

  @override
  String get sqHowHaveYourPeriods => 'আপনার ঋতুস্রাবে কী পরিবর্তন হয়েছে?';

  @override
  String get sqWhatWouldYouMost => 'আপনি সবচেয়ে বেশি কীসে মনোযোগ দিতে চান?';

  @override
  String get sqHowLongHasIt => 'আপনার শেষ ঋতুস্রাবের কত দিন হয়েছে?';

  @override
  String get sqWhichSymptomsAffectYour =>
      'কোন উপসর্গগুলি আপনার দৈনন্দিন জীবনে প্রভাব ফেলে?';

  @override
  String get sqWhatAreYourTop => 'আপনার প্রধান স্বাস্থ্য লক্ষ্যগুলি কী?';

  @override
  String get sjaRegenerate => 'আবার তৈরি করুন';

  @override
  String get jcQuickPreviewQuietMorning =>
      'ঝলক: \"শান্ত সকালের হাঁটা আর বন্ধুদের সঙ্গে গরম চা।\"';

  @override
  String get stUndo => 'পূর্বাবস্থায় ফিরুন';

  @override
  String get stRedo => 'আবার করুন';

  @override
  String get stBack => 'পিছনে';

  @override
  String get stCopy => 'কপি করুন';

  @override
  String get stDelete => 'মুছুন';

  @override
  String get ldPrivacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get ldTermsConditions => 'নিয়ম ও শর্তাবলী';

  @override
  String get ldPrivacyPolicy2 => '📜 গোপনীয়তা নীতি';

  @override
  String get ldRightToErasureDelete => 'মুছে ফেলার অধিকার (অ্যাকাউন্ট মুছুন)';

  @override
  String get ldEmail => 'ইমেল';

  @override
  String get ldWebsite => 'ওয়েবসাইট';

  @override
  String get ldTermsAndConditionsTerms => '⚖️ নিয়ম ও শর্তাবলী (পরিষেবার শর্ত)';

  @override
  String get ldUnauthorizedUse => 'অননুমোদিত ব্যবহার';

  @override
  String get msNewTimeCapsule => 'নতুন টাইম ক্যাপসুল';

  @override
  String get msAmIst => 'সকাল ৮:০০ IST';

  @override
  String get msSave => 'সংরক্ষণ করুন';

  @override
  String get rspThatIsTheWhole => 'এটাই পুরো সেশন। ওঠার আগে এক মুহূর্ত থামুন।';

  @override
  String get pPreparingHerEmergencySchool =>
      'তার স্কুলের জরুরি কিট প্রস্তুত করা';

  @override
  String get pConversationStarters => ' কথা শুরু করার উপায়';

  @override
  String get pParentFrequentQuestions => 'অভিভাবকদের সাধারণ প্রশ্ন';

  @override
  String get gBouquet => 'তোড়া';

  @override
  String get gCommunity => '🌸 ভাবনা';

  @override
  String get hBuildABouquet => 'একটি তোড়া তৈরি করুন';

  @override
  String get hBuildItInBlack => 'সাদা-কালোয় তৈরি করুন';

  @override
  String get pHereAreGeneralWays =>
      'আজ আপনার সঙ্গীকে সহায়তা করার কিছু সাধারণ উপায়:';

  @override
  String get pGotIt => 'বুঝেছি';

  @override
  String get pTips => 'পরামর্শ';

  @override
  String get pSavePermissions => 'অনুমতি সংরক্ষণ করুন';

  @override
  String get pReject => 'প্রত্যাখ্যান করুন';

  @override
  String get pPending => 'অপেক্ষমাণ';

  @override
  String get pShareThisInvitation => 'এই আমন্ত্রণ ভাগ করুন';

  @override
  String get pConnect => 'যুক্ত হন';

  @override
  String get pLiveSynchronized => 'লাইভ সিঙ্ক হচ্ছে';

  @override
  String get pCompleteCheckIn => 'চেক-ইন সম্পূর্ণ করুন';

  @override
  String get pDigitalFlowerGift => 'ডিজিটাল ফুলের উপহার';

  @override
  String get pAiCommunicationHub => 'AI যোগাযোগ কেন্দ্র';

  @override
  String get pYourPartnerHasChosen =>
      'আপনার সঙ্গী এখন ব্যক্তিগত তথ্য ভাগ না করার সিদ্ধান্ত নিয়েছেন।';

  @override
  String get pWhatWouldYouLike => 'আপনি কীসে সাহায্য চান?';

  @override
  String get phHereAreGeneralWays =>
      'আজ আপনার সঙ্গীকে সহায়তা করার কিছু সাধারণ উপায়:';

  @override
  String get phGotIt => 'বুঝেছি';

  @override
  String get phSeeHowICan => 'দেখুন আমি কীভাবে সাহায্য করতে পারি';

  @override
  String get phAllTodaySActions => 'আজকের সব কাজ সম্পন্ন! 🌸';

  @override
  String get phDrDocsy => 'Docsy';

  @override
  String get phNotSharedWithYou => 'আপনার সঙ্গে ভাগ করা হয়নি';

  @override
  String get phConnectionEnded => 'সংযোগ শেষ হয়েছে';

  @override
  String get phNothingSharedRightNow => 'এখন কিছুই ভাগ করা হয়নি';

  @override
  String get plConnectWithPartner => 'সঙ্গীর সঙ্গে যুক্ত হন';

  @override
  String get plPairingWithYourPartner =>
      'সঙ্গীর সঙ্গে যুক্ত হলে লাইভ AI তথ্য, পর্যায় ট্র্যাকিং এবং Learn পাতায় সহায়তার পরামর্শ পাওয়া যায়।';

  @override
  String get plSendInvite => 'আমন্ত্রণ পাঠান';

  @override
  String get plLearnDiscover => 'শিখুন ও জানুন';

  @override
  String get plConnectWithYourPartner =>
      'ব্যক্তিগত Docsy AI তথ্যের জন্য আপনার সঙ্গীর সঙ্গে যুক্ত হন।';

  @override
  String get plUnderstandingEnergyFatigueShifts =>
      'শক্তি ও ক্লান্তির পরিবর্তন বোঝা';

  @override
  String get plMindfulCommunicationPrinciples => 'সচেতন যোগাযোগের নীতি';

  @override
  String get plDailyHydrationMetabolicBalance =>
      'দৈনিক জলপান ও বিপাকীয় ভারসাম্য';

  @override
  String get plManagingStressDailyResilience =>
      'চাপ সামলানো ও দৈনন্দিন সহনশীলতা';

  @override
  String get plBuildingHealthySleepArchitecture => 'সুস্থ ঘুমের কাঠামো গড়া';

  @override
  String get psAskAboutHerActive =>
      'তার বর্তমান পর্যায় সম্পর্কে জিজ্ঞাসা করুন...';

  @override
  String get puHowSharingWorks => 'ভাগ করা কীভাবে কাজ করে';

  @override
  String get puUnderstand => 'বুঝেছি';

  @override
  String get sSavesDirectlyToYour => 'সরাসরি আপনার জার্নালে সংরক্ষিত হয়';

  @override
  String get sLutealRecoveryActionChecklist => 'লুটিয়াল রিকভারি কাজের তালিকা';

  @override
  String get sMedicalReportPdf => 'মেডিকেল রিপোর্ট / PDF';

  @override
  String get sSleep => 'ঘুম';

  @override
  String get sEnergy => 'শক্তি';

  @override
  String get sMood => 'মেজাজ';

  @override
  String get sWriteYourThoughtsBody =>
      'আপনার ভাবনা, শারীরিক অনুভূতি বা প্রতিফলন এখানে লিখুন...';

  @override
  String get vnbVoiceReflection => 'ভয়েস রিফ্লেকশন';

  @override
  String get vnbYourVoiceTranscriptWill =>
      'আপনার কণ্ঠের লিখিত রূপ এখানে দেখা যাবে...';

  @override
  String get gIdeasSubtitle => 'শুরু করার জন্য তৈরি তোড়া।';

  @override
  String get jrnCouldNotAddPhoto =>
      'সেই ছবিটি যোগ করা যায়নি। অন্য একটি চেষ্টা করুন।';

  @override
  String get tourHomeBody =>
      'এক নজরে আপনার দিন: চক্র, চেক-ইন এবং কী আশা করবেন। আপনি কেমন বোধ করছেন তা এখানে লিখুন।';

  @override
  String get tourCommunityBody =>
      'একই অভিজ্ঞতার মধ্য দিয়ে যাওয়া অন্যদের প্রশ্ন ও উত্তর।';

  @override
  String get tourSiaBody =>
      'Docsy-কে যা খুশি জিজ্ঞাসা করুন, লিখে বা বলে। আপনি কী নথিভুক্ত করেছেন তা সে জানে।';

  @override
  String get tourStudioBody =>
      'আপনার জার্নাল, নির্দেশিত রিকভারি সেশন এবং ভবিষ্যতের নিজেকে লেখা টাইম ক্যাপসুল।';

  @override
  String get tourPartnerBody =>
      'সঙ্গীকে আমন্ত্রণ জানান এবং ঠিক করুন তারা কী দেখতে পাবেন। আপনি না বলা পর্যন্ত কিছুই ভাগ হয় না।';

  @override
  String get tourSkip => 'এড়িয়ে যান';

  @override
  String get tourNext => 'পরবর্তী';

  @override
  String get tourDone => 'বুঝেছি';

  @override
  String get upAnonymousProfile =>
      'এটি বেনামে পোস্ট করা হয়েছিল, তাই খোলার মতো কোনো প্রোফাইল নেই। যিনি লিখেছেন তিনি নাম না দেওয়ার সিদ্ধান্ত নিয়েছেন, আর সেটি তাঁরই পছন্দ।';

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
  String get languageChoiceTitle => 'আপনার ভাষা বাছুন';

  @override
  String get languageChoiceSubtitle =>
      'Blushy আর Docsy এই ভাষাতেই কথা বলবে। আপনি সেটিংসে যেকোনো সময় এটি বদলাতে পারেন।';

  @override
  String get languageChoiceContinue => 'এগিয়ে যান';

  @override
  String get dashLogTodayCheckIn => 'আজকের চেক-ইন লিখুন';
}
