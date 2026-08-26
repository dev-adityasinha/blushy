import 'package:flutter/material.dart';

class PartnerProfile {
  final String name;
  final String relationshipType; // Partner, Husband, Boyfriend, Other
  final List<String> supportGoals;
  final String learningDepth; // Just tell me, I'd like to understand more, I want to learn properly

  PartnerProfile({
    required this.name,
    required this.relationshipType,
    required this.supportGoals,
    required this.learningDepth,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationshipType': relationshipType,
        'supportGoals': supportGoals,
        'learningDepth': learningDepth,
      };

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      name: json['name'] ?? '',
      relationshipType: json['relationshipType'] ?? '',
      supportGoals: List<String>.from(json['supportGoals'] ?? []),
      learningDepth: json['learningDepth'] ?? '',
    );
  }
}

class PartnerPermissions {
  final bool generalAiInsights;
  final bool cycleInsights;
  final bool fertilityInsights;
  final bool pregnancyUpdates;
  final bool postpartumUpdates;
  final bool energy;
  final bool symptoms;
  final bool mood;
  final bool appointments;
  final bool careRequests;
  final bool journal;
  final bool siaConversations;

  PartnerPermissions({
    this.generalAiInsights = false,
    this.cycleInsights = false,
    this.fertilityInsights = false,
    this.pregnancyUpdates = false,
    this.postpartumUpdates = false,
    this.energy = false,
    this.symptoms = false,
    this.mood = false,
    this.appointments = false,
    this.careRequests = false,
    this.journal = false,
    this.siaConversations = false,
  });

  Map<String, dynamic> toJson() => {
        'generalAiInsights': generalAiInsights,
        'cycleInsights': cycleInsights,
        'fertilityInsights': fertilityInsights,
        'pregnancyUpdates': pregnancyUpdates,
        'postpartumUpdates': postpartumUpdates,
        'energy': energy,
        'symptoms': symptoms,
        'mood': mood,
        'appointments': appointments,
        'careRequests': careRequests,
        'journal': journal,
        'siaConversations': siaConversations,
      };

  factory PartnerPermissions.fromJson(Map<String, dynamic> json) {
    return PartnerPermissions(
      generalAiInsights: json['generalAiInsights'] ?? false,
      cycleInsights: json['cycleInsights'] ?? false,
      fertilityInsights: json['fertilityInsights'] ?? false,
      pregnancyUpdates: json['pregnancyUpdates'] ?? false,
      postpartumUpdates: json['postpartumUpdates'] ?? false,
      energy: json['energy'] ?? false,
      symptoms: json['symptoms'] ?? false,
      mood: json['mood'] ?? false,
      appointments: json['appointments'] ?? false,
      careRequests: json['careRequests'] ?? false,
      journal: json['journal'] ?? false,
      siaConversations: json['siaConversations'] ?? false,
    );
  }
}

class SharedInsight {
  final String id;
  final String type; // 'about_her' or 'how_to_support'
  final String title;
  final String description;
  final String sourcePermission;
  final String lifeStage;
  final DateTime createdAt;
  final bool isShared;

  SharedInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.sourcePermission,
    required this.lifeStage,
    required this.createdAt,
    required this.isShared,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'sourcePermission': sourcePermission,
        'lifeStage': lifeStage,
        'createdAt': createdAt.toIso8601String(),
        'isShared': isShared,
      };

  factory SharedInsight.fromJson(Map<String, dynamic> json) {
    return SharedInsight(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      sourcePermission: json['sourcePermission'] ?? '',
      lifeStage: json['lifeStage'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isShared: json['isShared'] ?? false,
    );
  }
}

class PartnerContext {
  final String relationship;
  final String womansLifeStage;
  final PartnerPermissions enabledPermissions;
  final List<SharedInsight> sharedInsights;
  final List<String> sharedMilestones;
  final List<String> supportRequests;
  final String learningContext;

  PartnerContext({
    required this.relationship,
    required this.womansLifeStage,
    required this.enabledPermissions,
    required this.sharedInsights,
    required this.sharedMilestones,
    required this.supportRequests,
    required this.learningContext,
  });

  Map<String, dynamic> toJson() => {
        'relationship': relationship,
        'womansLifeStage': womansLifeStage,
        'enabledPermissions': enabledPermissions.toJson(),
        'sharedInsights': sharedInsights.map((e) => e.toJson()).toList(),
        'sharedMilestones': sharedMilestones,
        'supportRequests': supportRequests,
        'learningContext': learningContext,
      };

  factory PartnerContext.fromJson(Map<String, dynamic> json) {
    return PartnerContext(
      relationship: json['relationship'] ?? '',
      womansLifeStage: json['womansLifeStage'] ?? 'everydayWellness',
      enabledPermissions: PartnerPermissions.fromJson(json['enabledPermissions'] ?? {}),
      sharedInsights: (json['sharedInsights'] as List?)
              ?.map((e) => SharedInsight.fromJson(e))
              .toList() ??
          [],
      sharedMilestones: List<String>.from(json['sharedMilestones'] ?? []),
      supportRequests: List<String>.from(json['supportRequests'] ?? []),
      learningContext: json['learningContext'] ?? '',
    );
  }
}
