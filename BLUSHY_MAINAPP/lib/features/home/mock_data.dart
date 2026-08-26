import 'package:flutter/material.dart';
import 'models.dart';

// Authentic models & fallbacks for clean new-user states
final List<CycleInsight> dummyInsights = [];

final List<TimelineSummary> dummyTimelineSummaries = [];

final List<Recommendation> dummyRecommendations = [];

final List<ReflectionPrompt> dummyReflectionPrompts = [
  ReflectionPrompt(
    title: "Daily Reflection",
    question: "How did your energy and body feel today?",
    placeholder: "Record your thoughts...",
    chips: ["Steady Focus", "Gentle Rest", "High Energy", "Mindful Moment"],
    replyText: "Reflection saved. Take a quiet moment to unwind.",
  ),
];

final List<ConditionInsight> dummyConditionInsights = [];

final AppointmentSummary dummyAppointmentSummary = AppointmentSummary(
  title: "Clinical Summary Guide",
  summary: "Export your symptom profile and cycle history for your healthcare team.",
  recentChanges: [],
  discussionPoints: [],
  notes: "Export your summary PDF before visiting your doctor.",
  generatedAt: DateTime.now(),
);

final List<CareRecommendation> dummyCareRecommendations = [];

final List<CommunityPost> dummyCommunityPosts = [];
