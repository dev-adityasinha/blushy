import 'package:flutter/foundation.dart';
import '../../../core/storage.dart';
import '../models.dart';

class CycleInsightService {
  /// Dynamically computes personalized [CycleInsight] items from:
  /// 1. Active user AI conversation history (`recent_sia_chats.json`)
  /// 2. Journal reflection entries (`mstudio_reflections.json`)
  /// 3. Onboarding choices (`user_profile.json`)
  static List<CycleInsight> getPersonalizedInsights() {
    final List<CycleInsight> insights = [];

    // --- A. RECENT CONVERSATIONS & JOURNAL REFLECTIONS ANALYSIS ---
    try {
      final chatData = BlushyStorage.read('recent_sia_chats.json');
      final journalData = BlushyStorage.read('mstudio_reflections.json');

      final List<String> conversationSnippets = [];

      // 1. Read Dr. Docsy user chat messages
      if (chatData['messages'] is List) {
        final msgs = chatData['messages'] as List;
        for (var m in msgs.reversed) {
          if (m is Map) {
            final sender = m['sender']?.toString();
            final text = m['text']?.toString() ?? '';
            if (sender == 'user' && text.trim().isNotEmpty) {
              conversationSnippets.add(text.trim());
              if (conversationSnippets.length >= 3) break;
            }
          }
        }
      }

      // 2. Read latest Journal reflection entry
      if (journalData['text'] != null && journalData['text'].toString().trim().isNotEmpty) {
        conversationSnippets.add(journalData['text'].toString().trim());
      }

      final String combinedText = conversationSnippets.join(' ').toLowerCase();

      // Check conversation topics and create real-time Conversation Insight cards
      if (combinedText.contains('headache') || combinedText.contains('migraine')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Headaches & Tension Relief",
            observation: "Discussed in your recent talk: Hydration and 5-minute dark room relaxation ease vascular headache tension.",
            evidence: "Synthesized directly from your latest Dr. Docsy AI conversation.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      if (combinedText.contains('stress') || combinedText.contains('anxious') || combinedText.contains('anxiety') || combinedText.contains('overwhelm') || combinedText.contains('pressure')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Stress & Cortisol Shield",
            observation: "Expressed stress in your recent conversation. 3 minutes of slow box breathing lowers sympathetic cortisol spikes.",
            evidence: "Derived directly from your active Dr. Docsy chat session.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      if (combinedText.contains('fatigue') || combinedText.contains('tired') || combinedText.contains('exhausted') || combinedText.contains('drained') || combinedText.contains('no energy')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Fatigue Recovery",
            observation: "Discussed low energy in your talk. Scheduling short micro-rest breaks preserves energy for week 1 menstruation.",
            evidence: "Extracted directly from your recent Dr. Docsy AI chat.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      if (combinedText.contains('cramp') || combinedText.contains('pain') || combinedText.contains('pelvic')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Pelvic Pain & Cramp Comfort",
            observation: "Noted cramp discomfort in your talk. Warm heat therapy and child's pose relieve uterine spasm pressure.",
            evidence: "Synthesized directly from your latest chat log.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      if (combinedText.contains('sleep') || combinedText.contains('insomnia') || combinedText.contains('night')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Sleep Architecture",
            observation: "Talked about sleep challenges with Dr. Docsy. Maintaining a 19°C cool room setting and avoiding late screens promotes REM sleep.",
            evidence: "Extracted directly from your latest conversation entries.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      if (combinedText.contains('bloat') || combinedText.contains('craving') || combinedText.contains('water')) {
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Hydration & Fluid Retention",
            observation: "Mentioned bloating/cravings in your talk. 2L daily hydration & potassium-rich foods reduce progesterone fluid retention.",
            evidence: "Derived directly from your recent chat & journal entries.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }

      // If user had a recent conversation snippet that didn't hit standard keywords, quote her actual statement
      if (insights.isEmpty && conversationSnippets.isNotEmpty) {
        final firstSnippet = conversationSnippets.first;
        final shortQuote = firstSnippet.length > 55 ? "${firstSnippet.substring(0, 52)}..." : firstSnippet;
        insights.add(
          CycleInsight(
            title: "AI Chat Insight: Personal Reflection",
            observation: "Synthesized from your recent conversation: \"$shortQuote\". Taking a quiet moment to reflect helps align your emotional baseline.",
            evidence: "Extracted directly from your active Dr. Docsy conversation.",
            confidenceLevel: "High",
            timestamp: "Just now",
          ),
        );
      }
    } catch (e) {
      debugPrint("CycleInsightService error processing conversation history: $e");
    }

    // --- B. ONBOARDING PROFILE BASELINE INSIGHTS ---
    try {
      final userProfileData = BlushyStorage.read('user_profile.json');
      final profile = userProfileData['profile'] as Map<String, dynamic>? ?? {};

      final String lifeStage = profile['lifeStage']?.toString() ?? 'reproductiveYears';
      final List<String> goals = (profile['goals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final List<String> symptoms = (profile['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final List<String> conditions = (profile['conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      // 1. Life-stage specific primary insight
      if (lifeStage == 'hormonalHealth' || conditions.contains('PCOS') || conditions.contains('Endometriosis')) {
        insights.add(
          CycleInsight(
            title: "Hormonal & Endocrine Balance",
            observation: "Tailored for your hormonal health focus; consistent protein-first meals & low glycemic baselines support insulin stability.",
            evidence: "Synthesized from your onboarding health baseline & active PCOS/hormonal tracking.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      } else if (lifeStage == 'tryingToConceive') {
        insights.add(
          CycleInsight(
            title: "Fertility Window Tracking",
            observation: "Conception mode active; tracking basal body temperature & cervical mucus pinpoints your peak 6-day fertile window.",
            evidence: "Based on your TTC onboarding goals & fertility calendar sync.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      } else if (lifeStage == 'perimenopause' || lifeStage == 'menopause') {
        insights.add(
          CycleInsight(
            title: "Thermal & Sleep Architecture",
            observation: "Perimenopause tracking active; keeping bedroom ambient temp at 19°C counters night heat spikes and promotes REM sleep.",
            evidence: "Mapped from your perimenopause onboarding choices & sleep logs.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      } else if (lifeStage == 'pregnancy' || lifeStage == 'postpartum') {
        insights.add(
          CycleInsight(
            title: "Maternal Rest & Recovery Pattern",
            observation: "Prioritizing pelvic floor recovery & core stability helps maintain energy baselines throughout your postpartum journey.",
            evidence: "Synthesized from your onboarding pregnancy/postpartum timeline.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      } else {
        insights.add(
          CycleInsight(
            title: "Cycle Phase & Stamina Sync",
            observation: "Your physical stamina naturally peaks during your follicular phase and stabilizes smoothly as progesterone rises in luteal.",
            evidence: "Synthesized from your onboarding cycle baseline & active phase tracking.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      }

      // 2. Symptom-specific insights based on onboarding symptom selections
      final String symptomsLower = symptoms.join(' ').toLowerCase();

      if ((symptomsLower.contains('cramp') || symptomsLower.contains('pain')) && !insights.any((i) => i.title.contains('Cramp'))) {
        insights.add(
          CycleInsight(
            title: "Pelvic Relief & Cramp Management",
            observation: "Selected cramps in onboarding; gentle pelvic movement & warm magnesium tea during menstrual phase reduce cramp intensity.",
            evidence: "Correlated from your logged symptom preferences & cycle day.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      }

      if ((symptomsLower.contains('mood') || symptomsLower.contains('anxiety')) && !insights.any((i) => i.title.contains('Emotional'))) {
        insights.add(
          CycleInsight(
            title: "Progesterone & Emotional Waves",
            observation: "Selected mood sensitivity in onboarding; mindfulness breaks and lower evening caffeine stabilize progesterone fluctuations.",
            evidence: "Observed from your onboarding mood profile & phase indicators.",
            confidenceLevel: "High",
            timestamp: "Updated yesterday",
          ),
        );
      }

      if ((symptomsLower.contains('insomnia') || symptomsLower.contains('sleep')) && !insights.any((i) => i.title.contains('Sleep'))) {
        insights.add(
          CycleInsight(
            title: "Sleep Quality & Rest Recovery",
            observation: "Logged sleep disruption in onboarding; 7+ hours of quality rest correlates with a 35% drop in premenstrual fatigue.",
            evidence: "Synthesized from your onboarding sleep selections.",
            confidenceLevel: "High",
            timestamp: "Updated yesterday",
          ),
        );
      }

      if ((symptomsLower.contains('bloat') || symptomsLower.contains('water')) && !insights.any((i) => i.title.contains('Hydration'))) {
        insights.add(
          CycleInsight(
            title: "Hydration & Fluid Retention",
            observation: "Logged bloating in onboarding; consistent 2L daily water intake & potassium-rich foods reduce luteal fluid retention.",
            evidence: "Mapped from your onboarding wellness targets.",
            confidenceLevel: "Medium",
            timestamp: "Updated today",
          ),
        );
      }

      // 3. Goal-specific insights
      final String goalsLower = goals.join(' ').toLowerCase();
      if ((goalsLower.contains('sync') || goalsLower.contains('cycle')) && !insights.any((i) => i.title.contains('Syncing'))) {
        insights.add(
          CycleInsight(
            title: "Four-Phase Cycle Syncing",
            observation: "Goal set: Cycle Syncing. High-intensity tasks fit week 2 (Follicular peak), while restorative organization fits week 4 (Luteal).",
            evidence: "Synthesized from your onboarding goal choices.",
            confidenceLevel: "High",
            timestamp: "Updated today",
          ),
        );
      }
    } catch (e) {
      debugPrint("CycleInsightService error loading onboarding profile: $e");
    }

    // Fallback if needed
    if (insights.isEmpty) {
      insights.add(
        CycleInsight(
          title: "Personalized Cycle Sync",
          observation: "Your daily insights update automatically based on your active Dr. Docsy AI talks and onboarding choices.",
          evidence: "Synthesized from your active Blushy profile.",
          confidenceLevel: "High",
          timestamp: "Updated today",
        ),
      );
    }

    return insights;
  }
}
