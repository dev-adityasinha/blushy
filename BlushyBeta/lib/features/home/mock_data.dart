import 'package:flutter/material.dart';
import 'models.dart';

final List<CycleInsight> dummyInsights = [
  CycleInsight(
    title: "Mood Pattern",
    observation: "You usually feel more energetic after Day 5.",
    evidence: "Observed across your last 4 cycles.",
    confidenceLevel: "High",
    timestamp: "Updated today",
  ),
  CycleInsight(
    title: "Energy Pattern",
    observation: "Your energy tends to dip slightly around Day 21.",
    evidence: "Correlated with late luteal phase tracking.",
    confidenceLevel: "Medium",
    timestamp: "Updated 2 days ago",
  ),
  CycleInsight(
    title: "Symptom Pattern",
    observation: "Lighter cramps reported when yoga is completed on Day 1-2.",
    evidence: "Based on 3 months of activity logs.",
    confidenceLevel: "High",
    timestamp: "Updated today",
  ),
  CycleInsight(
    title: "Cycle Length Trend",
    observation: "Your cycle length has stabilized around 29-30 days.",
    evidence: "Calculated over past 6 recorded cycles.",
    confidenceLevel: "High",
    timestamp: "Updated last week",
  ),
];

final List<TimelineSummary> dummyTimelineSummaries = [
  TimelineSummary(
    month: "June",
    cycleLength: "29 Day Cycle",
    keyChange: "Lowest cramps recorded",
    aiSummary: "Your sleep improved and cramps were lighter than last month.",
  ),
  TimelineSummary(
    month: "May",
    cycleLength: "31 Day Cycle",
    keyChange: "Better sleep this month",
    aiSummary: "Energy remained steady, and sleep efficiency increased by 15%.",
  ),
];

final List<Recommendation> dummyRecommendations = [
  Recommendation(
    title: "Take a short walk",
    description: "A brisk 15-minute walk outside can boost your energy levels.",
    reason: "Your energy is usually highest during this phase.",
    priority: "Medium",
    category: "energy",
    actionLabel: "Let's Go",
  ),
  Recommendation(
    title: "Herbal Chamomile Tea",
    description: "Chamomile can help settle cramps and prepare you for sleep.",
    reason: "You reported light cramping earlier today.",
    priority: "High",
    category: "nutrition",
    actionLabel: "Brew Now",
  ),
  Recommendation(
    title: "Pre-sleep Wind-down",
    description: "Listen to Sia's deep breathing exercise to relax your mind.",
    reason: "Sleep tracking shows a dip in quality during luteal phase.",
    priority: "High",
    category: "sleep",
    actionLabel: "Start Guide",
  ),
  Recommendation(
    title: "Gentle Stretching",
    description: "Light pelvic stretches help ease lower back tension.",
    reason: "Your body responds well to moderate activity today.",
    priority: "Medium",
    category: "mind",
    actionLabel: "Show Moves",
  ),
];

final List<ReflectionPrompt> dummyReflectionPrompts = [
  ReflectionPrompt(
    title: "Before You Go...",
    question: "Sia has one little question before you head off: How did your energy feel today?",
    placeholder: "Write down how you felt...",
    chips: ["High energy", "A bit sluggish", "Steady focus", "Restless"],
    replyText: "Thanks for sharing! I've noted down your energy flow. Remember, energy naturally fluctuates throughout your cycle. Take care!",
  ),
  ReflectionPrompt(
    title: "Before You Go...",
    question: "Sia has one little question before you head off: What made you smile today?",
    placeholder: "A small detail or a big win...",
    chips: ["Sia chat", "Nice walk", "Good food", "Getting rest"],
    replyText: "Smiling is the best medicine. I'm glad you had a positive touchpoint today. Rest up!",
  ),
  ReflectionPrompt(
    title: "Before You Go...",
    question: "Sia has one little question before you head off: Any body cues you noticed today?",
    placeholder: "Cramps, bloating, or feeling light...",
    chips: ["Light cramping", "Feeling bloated", "Strong & active", "No symptoms"],
    replyText: "Thank you for sharing. Keeping track of body cues helps us recognize your cycle patterns. Have a peaceful evening!",
  ),
];

final List<ConditionInsight> dummyConditionInsights = [
  ConditionInsight(
    title: "Symptom Frequency: Pre-period acne",
    description: "You often experience acne before longer cycles.",
    observationType: "Symptom frequency",
    explanation: "Longer cycles are often linked to delayed ovulation. Delayed ovulation extends the progesterone-androgen balance window, driving higher sebaceous gland activity and pre-period acne.",
    contextLabel: "Based on your tracked symptoms",
  ),
  ConditionInsight(
    title: "Pain Trends: Uterine contractility",
    description: "Your pain usually decreases after Day 3.",
    observationType: "Pain trends",
    explanation: "Prostaglandin hormone releases peak during the first 48 hours of bleeding. As lining shedding progresses past day 3, uterine contractility naturally decreases.",
    contextLabel: "Based on your logged entries",
  ),
  ConditionInsight(
    title: "Fatigue Trends: Stress & cortisol stabilization",
    description: "You report better energy on weeks when you exercise.",
    observationType: "Fatigue trends",
    explanation: "Steady cardiovascular activity balances cortisol and improves insulin sensitivity, countering hormone-driven energy crashes.",
    contextLabel: "Based on your cycle history",
  ),
];

final AppointmentSummary dummyAppointmentSummary = AppointmentSummary(
  title: "Next Appointment Guide",
  summary: "A clinical summary preparing your symptom profiles to help your care team structure diagnostics.",
  recentChanges: [
    "Cycle lengths ranged from 29 to 71 days over the past five cycles.",
    "Pre-period acne was recorded before cycle extensions.",
    "Pain intensity reports show a steady decrease after bleeding Day 3."
  ],
  discussionPoints: [
    "Should we run lab hormone panels for ovulation timing?",
    "Could insulin resistance be causing the longer cycle variations?",
    "Safety check of the magnesium & complex carb nutrition plan."
  ],
  notes: "Remember to export this clinical summary pdf before visiting your doctor.",
  generatedAt: DateTime(2026, 7, 28),
);

final List<CareRecommendation> dummyCareRecommendations = [
  CareRecommendation(
    icon: Icons.water_drop_outlined,
    title: "Hydration Target",
    description: "Keep fluid levels high (2.5L target) to lower luteal water retention.",
    reason: "Luteal phase hormonal fluctuations naturally trigger temporary fluid retention changes.",
    priority: "High",
    category: "nutrition",
  ),
  CareRecommendation(
    icon: Icons.restaurant,
    title: "Nutrition Focus",
    description: "Incorporate magnesium and complex carbs to stabilize energy spikes.",
    reason: "Slow-release carbs regulate energy levels and insulin sensitivity variables.",
    priority: "High",
    category: "nutrition",
  ),
  CareRecommendation(
    icon: Icons.directions_run,
    title: "Movement Plan",
    description: "20-minute gentle walk to improve insulin sensitivity and lower cortisol.",
    reason: "Moderate low-impact activity lowers physiological stress indicators.",
    priority: "Medium",
    category: "energy",
  ),
  CareRecommendation(
    icon: Icons.nightlight_round,
    title: "Sleep Protocol",
    description: "Maintain cool bedroom temperature (19C) to facilitate progesterone drops.",
    reason: "Cool temperatures support natural circadian thermoregulation adjustments.",
    priority: "High",
    category: "sleep",
  ),
];

final List<CommunityPost> dummyCommunityPosts = [
  CommunityPost(
    user: "HormonesGirl",
    content: "Started inositol 3 months ago, cycle dropped from 56 to 34 days!",
    category: "PCOS",
    medicalReview: false,
    misinformationWarning: false,
    professionalGuidance: true,
  ),
  CommunityPost(
    user: "CrampsNoMore",
    content: "Castor oil packs during menstruation were a game changer for cramp pain.",
    category: "Endometriosis",
    medicalReview: true,
    misinformationWarning: false,
    professionalGuidance: false,
  ),
  CommunityPost(
    user: "CycleCaregiver",
    content: "Make sure you track daily basal body temperature if you suspect progesterone deficiency.",
    category: "PMDD",
    medicalReview: false,
    misinformationWarning: true,
    professionalGuidance: false,
  ),
];
