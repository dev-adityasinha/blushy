import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import '../../../services/api_base_url.dart';

class DiscoverArticle {
  final String title;
  final String desc;
  final String? content;

  DiscoverArticle({
    required this.title,
    required this.desc,
    this.content,
  });

  factory DiscoverArticle.fromJson(Map<String, dynamic> json) {
    return DiscoverArticle(
      title: json['title'] ?? 'Educational Tip',
      desc: json['desc'] ?? '',
      content: json['content'] ?? json['desc'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'desc': desc,
      'content': content,
    };
  }
}

class DiscoverPayload {
  final String featuredTopic;
  final List<String> topics;
  final Map<String, List<DiscoverArticle>> topicArticles;
  final bool isPersonalized;
  final int dayIndex;
  final String lastUpdated;

  DiscoverPayload({
    required this.featuredTopic,
    required this.topics,
    required this.topicArticles,
    required this.isPersonalized,
    required this.dayIndex,
    required this.lastUpdated,
  });

  factory DiscoverPayload.fromJson(Map<String, dynamic> json) {
    final rawTopics = (json['topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    
    final Map<String, List<DiscoverArticle>> articlesMap = {};
    if (json['topicArticles'] is Map<String, dynamic>) {
      final map = json['topicArticles'] as Map<String, dynamic>;
      map.forEach((key, val) {
        if (val is List) {
          articlesMap[key] = val.map((item) => DiscoverArticle.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      });
    }

    return DiscoverPayload(
      featuredTopic: json['featuredTopic'] ?? (rawTopics.isNotEmpty ? rawTopics.first : "Women's Health"),
      topics: rawTopics.isNotEmpty
          ? rawTopics
          : [
              "Women's Health",
              "Nutrition",
              "Exercise",
              "Mental Wellbeing",
              "Sleep",
              "Stress",
              "Productivity",
              "Cycle Health",
              "Movement",
              "Sexual Wellness",
              "Relationships"
            ],
      topicArticles: articlesMap,
      isPersonalized: json['isPersonalized'] == true,
      dayIndex: json['dayIndex'] ?? 0,
      lastUpdated: json['lastUpdated'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class DiscoverService {
  static String get _baseUrl => resolveApiBaseUrl();
  static const String _userCacheKey = 'blushy_daily_discover_cache';
  static const String _guestCacheKey = 'generic_discover_cache.json';

  static const String _seenTitlesKey = 'blushy_seen_discover_titles';

  /// Fetches the daily AI discover recommendations, rotating at 12:00 AM midnight.
  /// Guarantees non-repeating cards by supplying previously seen titles to AI.
  static Future<DiscoverPayload> fetchDailyDiscoverPayload({String? authToken}) async {
    try {
      final cacheKey = (authToken != null && authToken.isNotEmpty) ? _userCacheKey : _guestCacheKey;
      final cachedData = BlushyStorage.read(cacheKey);
      final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final currentDateStr = "${nowIST.year}-${nowIST.month.toString().padLeft(2, '0')}-${nowIST.day.toString().padLeft(2, '0')}";

      if (cachedData.isNotEmpty && cachedData['dateStr'] == currentDateStr) {
        return DiscoverPayload.fromJson(cachedData);
      }

      final seenData = BlushyStorage.read(_seenTitlesKey);
      final List<String> seenList = (seenData['titles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final seenQuery = Uri.encodeComponent(seenList.take(30).join(','));

      final uri = Uri.parse('$_baseUrl/ai/discover${seenQuery.isNotEmpty ? '?seenTitles=$seenQuery' : ''}');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded is Map<String, dynamic>) {
          decoded['dateStr'] = currentDateStr;
          BlushyStorage.write(cacheKey, decoded);

          final payload = DiscoverPayload.fromJson(decoded);
          final newTitles = <String>[...seenList];
          for (final list in payload.topicArticles.values) {
            for (var article in list) {
              if (!newTitles.contains(article.title)) {
                newTitles.add(article.title);
              }
            }
          }
          BlushyStorage.write(_seenTitlesKey, {'titles': newTitles.take(60).toList()});

          return payload;
        }
      }
    } catch (e) {
      // Ignore network timeout/error and fallback to static/cached
    }

    return _getFallbackPayload();
  }

  static DiscoverPayload _getFallbackPayload() {
    final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final dateStr = "${nowIST.year}-${nowIST.month.toString().padLeft(2, '0')}-${nowIST.day.toString().padLeft(2, '0')}";
    int dayIndex = 0;
    for (int i = 0; i < dateStr.length; i++) {
      dayIndex = (dayIndex * 31 + dateStr.codeUnitAt(i)) % 1000000;
    }

    final defaultTopics = [
      "Women's Health",
      "Nutrition",
      "Exercise",
      "Mental Wellbeing",
      "Sleep",
      "Stress",
      "Productivity",
      "Cycle Health",
      "Movement",
      "Sexual Wellness",
      "Relationships"
    ];

    List<String> topics = List.from(defaultTopics);
    bool isPersonalized = false;
    String featuredTopic = defaultTopics[dayIndex % defaultTopics.length];

    try {
      final userProfileData = BlushyStorage.read('user_profile.json');
      final profile = userProfileData['profile'] as Map<String, dynamic>? ?? {};
      final String lifeStage = profile['lifeStage']?.toString() ?? '';
      final List<String> goals = (profile['goals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final List<String> symptoms = (profile['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final List<String> conditions = (profile['conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      final chatData = BlushyStorage.read('recent_sia_chats.json');
      final journalData = BlushyStorage.read('mstudio_reflections.json');

      final List<String> conversationSnippets = [];
      if (chatData['messages'] is List) {
        for (var m in (chatData['messages'] as List).reversed) {
          if (m is Map && m['sender'] == 'user') {
            conversationSnippets.add(m['text']?.toString() ?? '');
            if (conversationSnippets.length >= 3) break;
          }
        }
      }
      if (journalData['text'] != null) {
        conversationSnippets.add(journalData['text'].toString());
      }

      final String allText = "${lifeStage} ${goals.join(' ')} ${symptoms.join(' ')} ${conditions.join(' ')} ${conversationSnippets.join(' ')}".toLowerCase();

      final List<String> prioritized = [];
      if (allText.contains('hormon') || allText.contains('pcos') || allText.contains('endo') || allText.contains('cycle')) {
        prioritized.add("Cycle Health");
      }
      if (allText.contains('sleep') || allText.contains('insomnia') || allText.contains('rest')) {
        prioritized.add("Sleep");
      }
      if (allText.contains('stress') || allText.contains('anxiety') || allText.contains('mood') || allText.contains('overwhelm')) {
        prioritized.add("Stress");
        prioritized.add("Mental Wellbeing");
      }
      if (allText.contains('nutrition') || allText.contains('bloat') || allText.contains('diet') || allText.contains('cramps') || allText.contains('food')) {
        prioritized.add("Nutrition");
      }
      if (allText.contains('exercise') || allText.contains('workout') || allText.contains('stamina') || allText.contains('energy') || allText.contains('gym')) {
        prioritized.add("Exercise");
        prioritized.add("Movement");
      }

      if (prioritized.isNotEmpty) {
        isPersonalized = true;
        // Place prioritized topics first while preserving unique order
        final newTopics = <String>[];
        for (var p in prioritized) {
          if (!newTopics.contains(p) && topics.contains(p)) {
            newTopics.add(p);
          }
        }
        for (var t in topics) {
          if (!newTopics.contains(t)) {
            newTopics.add(t);
          }
        }
        topics = newTopics;
        featuredTopic = topics.first;
      }
    } catch (_) {}

    return DiscoverPayload(
      featuredTopic: featuredTopic,
      topics: topics,
      topicArticles: {
        "Women's Health": [
          DiscoverArticle(title: "Balancing Daily Schedules", desc: "How tracking non-reproductive health symptoms (mood, focus, sleep) builds body awareness.", content: "Consistent symptom logging helps identify hormone sensitivity across your 28-day cycle."),
          DiscoverArticle(title: "Hormones & Lifestyle baselines", desc: "Understanding minor endocrine cycles and adjusting exercise patterns accordingly.", content: "Dynamic rest days during luteal phases improve recovery and baseline metabolic health.")
        ],
        "Nutrition": [
          DiscoverArticle(title: "Curbing Luteal Cravings", desc: "Magnesium-rich foods to natural calm sugar spikes.", content: "Dark chocolate, pumpkin seeds, and spinach balance blood sugar naturally during PMS."),
          DiscoverArticle(title: "Hydration During Bleeding", desc: "How water intake balances fluid retention during menstruation.", content: "Increasing potassium and hydration prevents hormonal water retention during bleeding.")
        ],
        "Exercise": [
          DiscoverArticle(title: "Yoga for Menstruation", desc: "Gentle poses to relax the pelvic floor and lower back muscles.", content: "Child pose and cat-cow relieve uterine spasm pressure."),
          DiscoverArticle(title: "High Energy Follicular Workouts", desc: "Capitalizing on high estrogen for strength training.", content: "Estrogen surges enable peak strength PRs in week 2.")
        ],
        "Mental Wellbeing": [
          DiscoverArticle(title: "Managing PMS Mood Swings", desc: "Journaling prompts to separate emotional waves from reality.", content: "Acknowledge feelings without judgment during progesterone drops."),
          DiscoverArticle(title: "The Post-Ovulation Calm", desc: "How hormone spikes balance mood levels during the follicular peak.", content: "Reduce evening screen exposure to keep baseline anxiety low.")
        ],
        "Sleep": [
          DiscoverArticle(title: "Progesterone and Insomnia", desc: "Why falling asleep is harder in the week leading up to your period.", content: "Basal body temperature increases slightly in luteal phase; cool room settings promote deep sleep."),
          DiscoverArticle(title: "Optimizing Luteal Sleep", desc: "Cool bedroom strategies to counter hormone-driven heat rises.", content: "A warm tea ritual 45 mins before bedtime boosts slow-wave sleep quality.")
        ],
        "Stress": [
          DiscoverArticle(title: "Cortisol & Progesterone Shield", desc: "How acute stress alters cycle timing and ovulation.", content: "Box breathing for 3 minutes dampens sympathetic nervous system activation."),
          DiscoverArticle(title: "Boundaries for Burnout Prevention", desc: "Protecting your calendar during high-sensitivity days.", content: "Saying no to extra evening events safeguards cortisol spikes.")
        ],
        "Productivity": [
          DiscoverArticle(title: "The Follicular Focus Peak", desc: "Planning complex tasks during your high-concentration days.", content: "Schedule brain-heavy strategy sessions when estrogen is rising."),
          DiscoverArticle(title: "Luteal Phase Reflection Cycles", desc: "Slowing down output to prioritize administration and planning.", content: "Use late-cycle weeks for editing and organization rather than launching new initiatives.")
        ],
        "Cycle Health": [
          DiscoverArticle(title: "Decoding Estrogen Drop", desc: "How sudden shifts drive premenstrual fatigue and headaches.", content: "Consistent symptom logging helps identify hormone sensitivity across your 28-day cycle."),
          DiscoverArticle(title: "Understanding Cycle Lengths", desc: "Why normal cycles fluctuate between 21 and 35 days.", content: "Dynamic rest days during luteal phases improve recovery and baseline metabolic health.")
        ],
        "Movement": [
          DiscoverArticle(title: "Incorporating Movement Breaks", desc: "Combat sedentary habits with micro-moves.", content: "Stand and stretch every 30 minutes or walk during calls."),
          DiscoverArticle(title: "Functional Movement for Daily Life", desc: "Build strength for everyday activities.", content: "Practice squats, lunges, and core twists 3 times weekly.")
        ],
        "Sexual Wellness": [
          DiscoverArticle(title: "Libido Fluctuations Explained", desc: "How hormonal peaks guide intimacy drives during ovulation.", content: "Discuss desires and boundaries regularly in a safe space."),
          DiscoverArticle(title: "Nurturing Body Confidence", desc: "Reconnecting with physical comfort during menstrual bloat.", content: "Dedicate time for mindful self-touch and pelvic floor exercises.")
        ],
        "Relationships": [
          DiscoverArticle(title: "Sharing Your Cycle Status", desc: "Easy communication guides to help partners support you during PMS.", content: "Active listening and open communication deepen connection."),
          DiscoverArticle(title: "Cycle Syncing Conversations", desc: "Talking about emotional boundaries with family.", content: "Set boundaries with empathy to protect your mental energy.")
        ]
      },
      isPersonalized: isPersonalized,
      dayIndex: dayIndex,
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }
}

