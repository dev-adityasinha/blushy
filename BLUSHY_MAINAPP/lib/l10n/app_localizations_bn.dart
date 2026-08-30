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
  String get navSia => 'সিয়া';

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
  String get languageSheetTitle => 'সিয়া যে ভাষায় বলে';

  @override
  String get languageSheetExplainer =>
      'এটি সিয়ার উত্তরের ভাষা বদলায়। বাকি অ্যাপ আপাতত ইংরেজিতেই থাকবে।';

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
  String get settingsSiaAssistant => 'সিয়া এআই সহকারী';

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
  String get siaAsk => 'সিয়াকে জিজ্ঞাসা করুন';

  @override
  String get siaThinking => 'সিয়া ভাবছে…';

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
  String get dashSiaInsights => 'সিয়ার পর্যবেক্ষণ';

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
      'এখনও ভাবার মতো কিছু নেই। কিছু লিখুন, সিয়া তা আপনাকে পড়ে শোনাবে।';

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
      'সিয়ার পর্যবেক্ষণের জন্য ক্লাউড প্রসেসিং অনুমোদন করুন';

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
  String get partnerSiaDecoding => 'সিয়া বুঝছে…';

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
  String get partnerSiaAdviceTitle => 'সিয়ার সম্পর্ক পরামর্শ';

  @override
  String get partnerSiaAdviceExplainer =>
      'আপনার মনে যা আছে জিজ্ঞাসা করুন। সিয়া কেবল তাই দেখে যা আপনার সঙ্গী শেয়ার করতে বেছে নিয়েছেন।';

  @override
  String get partnerTryAgain => 'আবার চেষ্টা করুন';
}
