import 'package:flutter/material.dart';

class CycleInsight {
  final String title;
  final String observation;
  final String evidence;
  final String confidenceLevel; // e.g. "High", "Medium", "Low"
  final String timestamp;

  CycleInsight({
    required this.title,
    required this.observation,
    required this.evidence,
    required this.confidenceLevel,
    required this.timestamp,
  });

  factory CycleInsight.fromJson(Map<String, dynamic> json) {
    return CycleInsight(
      title: json['title'] ?? '',
      observation: json['observation'] ?? '',
      evidence: json['evidence'] ?? '',
      confidenceLevel: json['confidenceLevel'] ?? 'Medium',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class TimelineSummary {
  final String month;
  final String cycleLength;
  final String keyChange;
  final String aiSummary;

  TimelineSummary({
    required this.month,
    required this.cycleLength,
    required this.keyChange,
    required this.aiSummary,
  });

  factory TimelineSummary.fromJson(Map<String, dynamic> json) {
    return TimelineSummary(
      month: json['month'] ?? '',
      cycleLength: json['cycleLength'] ?? '',
      keyChange: json['keyChange'] ?? '',
      aiSummary: json['aiSummary'] ?? '',
    );
  }
}

class Recommendation {
  final String title;
  final String description;
  final String reason;
  final String priority; // e.g. "High", "Medium", "Low"
  final String category; // e.g. "energy", "nutrition", "sleep", "mind"
  final String actionLabel;

  Recommendation({
    required this.title,
    required this.description,
    required this.reason,
    required this.priority,
    required this.category,
    required this.actionLabel,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      reason: json['reason'] ?? '',
      priority: json['priority'] ?? 'Medium',
      category: json['category'] ?? 'general',
      actionLabel: json['actionLabel'] ?? 'Start',
    );
  }
}

class ReflectionPrompt {
  final String title;
  final String question;
  final String placeholder;
  final List<String> chips;
  final String replyText;

  ReflectionPrompt({
    required this.title,
    required this.question,
    required this.placeholder,
    required this.chips,
    required this.replyText,
  });

  factory ReflectionPrompt.fromJson(Map<String, dynamic> json) {
    return ReflectionPrompt(
      title: json['title'] ?? '',
      question: json['question'] ?? '',
      placeholder: json['placeholder'] ?? '',
      chips: List<String>.from(json['chips'] ?? []),
      replyText: json['replyText'] ?? 'Thanks for sharing that with me. I\'ve noted it down in your diary. Have a beautiful rest of your day!',
    );
  }
}

class PeriodConfirmationState {
  final bool hasLoggedPeriod;
  final DateTime predictedStartDate;
  final DateTime? actualStartDate;
  final bool isDismissed;
  final String status; // "pending", "confirmed", "dismissed"

  PeriodConfirmationState({
    required this.hasLoggedPeriod,
    required this.predictedStartDate,
    this.actualStartDate,
    required this.isDismissed,
    required this.status,
  });

  factory PeriodConfirmationState.fromJson(Map<String, dynamic> json) {
    return PeriodConfirmationState(
      hasLoggedPeriod: json['hasLoggedPeriod'] ?? false,
      predictedStartDate: json['predictedStartDate'] != null 
          ? DateTime.parse(json['predictedStartDate']) 
          : DateTime.now().add(const Duration(days: 9)),
      actualStartDate: json['actualStartDate'] != null 
          ? DateTime.parse(json['actualStartDate']) 
          : null,
      isDismissed: json['isDismissed'] ?? false,
      status: json['status'] ?? 'pending',
    );
  }

  PeriodConfirmationState copyWith({
    bool? hasLoggedPeriod,
    DateTime? predictedStartDate,
    DateTime? actualStartDate,
    bool? isDismissed,
    String? status,
  }) {
    return PeriodConfirmationState(
      hasLoggedPeriod: hasLoggedPeriod ?? this.hasLoggedPeriod,
      predictedStartDate: predictedStartDate ?? this.predictedStartDate,
      actualStartDate: actualStartDate ?? this.actualStartDate,
      isDismissed: isDismissed ?? this.isDismissed,
      status: status ?? this.status,
    );
  }
}

class ConditionInsight {
  final String title;
  final String description;
  final String observationType;
  final String explanation;
  final String contextLabel;

  ConditionInsight({
    required this.title,
    required this.description,
    required this.observationType,
    required this.explanation,
    required this.contextLabel,
  });
}

class AppointmentSummary {
  final String title;
  final String summary;
  final List<String> recentChanges;
  final List<String> discussionPoints;
  final String notes;
  final DateTime generatedAt;

  AppointmentSummary({
    required this.title,
    required this.summary,
    required this.recentChanges,
    required this.discussionPoints,
    required this.notes,
    required this.generatedAt,
  });
}

class CareRecommendation {
  final IconData icon;
  final String title;
  final String description;
  final String reason;
  final String priority; // High, Medium, Low
  final String category; // energy, nutrition, sleep, mind, medical

  CareRecommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.reason,
    required this.priority,
    required this.category,
  });
}

class CommunityPost {
  final String user;
  final String content;
  final String category; // PCOS, Endometriosis, PMDD, Hormonal Health
  final bool medicalReview;
  final bool misinformationWarning;
  final bool professionalGuidance;

  CommunityPost({
    required this.user,
    required this.content,
    required this.category,
    this.medicalReview = false,
    this.misinformationWarning = false,
    this.professionalGuidance = false,
  });
}
