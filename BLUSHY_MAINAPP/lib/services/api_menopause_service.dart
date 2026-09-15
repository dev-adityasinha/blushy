import 'dart:async';
import '../core/storage.dart';
import 'api_contract_client.dart';

class MenopauseTodayBrief {
  final String openingHeadline;
  final String doNothingAffirmation;
  final List<String> whatMattersToday;
  final String whyToday;
  final List<String> promptPills;

  MenopauseTodayBrief({
    required this.openingHeadline,
    required this.doNothingAffirmation,
    required this.whatMattersToday,
    required this.whyToday,
    required this.promptPills,
  });

  factory MenopauseTodayBrief.fromJson(Map<String, dynamic> json) {
    return MenopauseTodayBrief(
      openingHeadline: json['openingHeadline']?.toString() ?? 'Understanding your body. Protecting your vitality.',
      doNothingAffirmation: json['doNothingAffirmation']?.toString() ?? '',
      whatMattersToday: (json['whatMattersToday'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Keep moving comfortably: daily walking promotes vascular health.', 'Protect bone density with dietary calcium and natural sunlight.'],
      whyToday: json['whyToday']?.toString() ?? 'Tailored to your current baseline and stage.',
      promptPills: (json['promptPills'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Is 3 AM waking common?', 'How can I protect bone health?', 'Tell me about GSM options'],
    );
  }

  Map<String, dynamic> toJson() => {
        'openingHeadline': openingHeadline,
        'doNothingAffirmation': doNothingAffirmation,
        'whatMattersToday': whatMattersToday,
        'whyToday': whyToday,
        'promptPills': promptPills,
      };
}

class MenopauseNormalMarker {
  final String domain;
  final String baseline;
  final String status;

  MenopauseNormalMarker({
    required this.domain,
    required this.baseline,
    required this.status,
  });

  factory MenopauseNormalMarker.fromJson(Map<String, dynamic> json) {
    return MenopauseNormalMarker(
      domain: json['domain']?.toString() ?? '',
      baseline: json['baseline']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'baseline': baseline,
        'status': status,
      };
}

class MenopauseMyNormal {
  final String status;
  final String description;
  final String confidence;
  final List<MenopauseNormalMarker> markers;

  MenopauseMyNormal({
    required this.status,
    required this.description,
    required this.confidence,
    required this.markers,
  });

  factory MenopauseMyNormal.fromJson(Map<String, dynamic> json) {
    return MenopauseMyNormal(
      status: json['status']?.toString() ?? 'Building your baseline',
      description: json['description']?.toString() ?? 'Your body has its own individual rhythms.',
      confidence: json['confidence']?.toString() ?? 'Initial Calibration',
      markers: (json['markers'] as List?)
              ?.map((m) => MenopauseNormalMarker.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'description': description,
        'confidence': confidence,
        'markers': markers.map((m) => m.toJson()).toList(),
      };
}

class MenopauseShiftItem {
  final String id;
  final String title;
  final String detail;
  final String timeframe;
  final String icon;
  final String colorHex;

  MenopauseShiftItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.timeframe,
    required this.icon,
    required this.colorHex,
  });

  factory MenopauseShiftItem.fromJson(Map<String, dynamic> json) {
    return MenopauseShiftItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      timeframe: json['timeframe']?.toString() ?? 'Recent',
      icon: json['icon']?.toString() ?? 'check_circle_rounded',
      colorHex: json['colorHex']?.toString() ?? '0xFF0D9488',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'timeframe': timeframe,
        'icon': icon,
        'colorHex': colorHex,
      };
}

class MenopauseDomain {
  final String key;
  final String title;
  final String shortLabel;
  final String icon;
  final String colorHex;
  final String bgHex;
  final String description;
  final String clinicalFocus;
  final String screening;

  MenopauseDomain({
    required this.key,
    required this.title,
    required this.shortLabel,
    required this.icon,
    required this.colorHex,
    required this.bgHex,
    required this.description,
    required this.clinicalFocus,
    required this.screening,
  });

  factory MenopauseDomain.fromJson(Map<String, dynamic> json) {
    return MenopauseDomain(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      shortLabel: json['shortLabel']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'spa_rounded',
      colorHex: json['colorHex']?.toString() ?? '0xFF0D9488',
      bgHex: json['bgHex']?.toString() ?? '0xFFCCFBF1',
      description: json['description']?.toString() ?? '',
      clinicalFocus: json['clinicalFocus']?.toString() ?? '',
      screening: json['screening']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'shortLabel': shortLabel,
        'icon': icon,
        'colorHex': colorHex,
        'bgHex': bgHex,
        'description': description,
        'clinicalFocus': clinicalFocus,
        'screening': screening,
      };

  static List<MenopauseDomain> defaults() => [
        MenopauseDomain(
          key: 'bone_muscle',
          title: 'Bone & Muscle',
          shortLabel: 'Bone & Muscle',
          icon: 'fitness_center_rounded',
          colorHex: '0xFF0D9488',
          bgHex: '0xFFCCFBF1',
          description: 'Protecting bone mineral density and preserving lean muscle mass after estrogen decline.',
          clinicalFocus: 'Resistance training triggers osteoblasts to preserve bone mass; adequate protein combats sarcopenia.',
          screening: 'Consider a baseline DEXA bone density scan starting at age 60–65, or earlier with risk factors.',
        ),
        MenopauseDomain(
          key: 'heart_metabolic',
          title: 'Heart & Metabolic',
          shortLabel: 'Heart & Metabolic',
          icon: 'favorite_rounded',
          colorHex: '0xFF2563EB',
          bgHex: '0xFFDBEAFE',
          description: 'Nurturing endothelial elasticity, healthy blood lipids, and stable metabolic energy.',
          clinicalFocus: 'Estrogen cessation alters lipid metabolism; brisk daily walking promotes microvascular health.',
          screening: 'Annual lipid panel (LDL, HDL, triglycerides) and fasting blood glucose / HbA1c review.',
        ),
        MenopauseDomain(
          key: 'sleep_rest',
          title: 'Sleep & Rest',
          shortLabel: 'Sleep & Rest',
          icon: 'nightlight_round',
          colorHex: '0xFF7209B7',
          bgHex: '0xFFF3E8FF',
          description: 'Stabilizing deep restorative sleep and managing lingering nighttime flushes.',
          clinicalFocus: 'Thermoregulatory threshold shifts can disrupt slow-wave sleep. Evening cooling is restorative.',
          screening: 'Screen for sleep apnea if morning headaches, snoring, or unrefreshing sleep persist.',
        ),
        MenopauseDomain(
          key: 'intimate_urinary',
          title: 'Intimate & Urinary',
          shortLabel: 'Intimate & Urinary',
          icon: 'spa_rounded',
          colorHex: '0xFFF72585',
          bgHex: '0xFFFFE5F0',
          description: 'Sustaining pelvic vitality, vaginal elasticity, and urinary tract comfort (GSM).',
          clinicalFocus: 'Genitourinary Syndrome of Menopause (GSM) is chronic but highly treatable with local moisturizers or therapy.',
          screening: 'Annual pelvic exam and routine checkups. Any postmenopausal bleeding requires prompt ultrasound.',
        ),
        MenopauseDomain(
          key: 'mood_cognition',
          title: 'Mood & Cognition',
          shortLabel: 'Mood & Cognition',
          icon: 'psychology_rounded',
          colorHex: '0xFFD97706',
          bgHex: '0xFFFEF3C7',
          description: 'Supporting emotional equilibrium, cognitive resilience, and mental clarity.',
          clinicalFocus: 'Estrogen receptors are concentrated in the hippocampus and prefrontal cortex; sleep consolidation supports brain fog recovery.',
          screening: 'Discuss unyielding low mood or pervasive anxiety with a primary clinician.',
        ),
      ];
}

class MenopauseTreatment {
  final String id;
  final String name;
  final String category;
  final String dose;
  final String startDate;
  final String notes;

  MenopauseTreatment({
    required this.id,
    required this.name,
    required this.category,
    required this.dose,
    required this.startDate,
    required this.notes,
  });

  factory MenopauseTreatment.fromJson(Map<String, dynamic> json) {
    return MenopauseTreatment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'dose': dose,
        'startDate': startDate,
        'notes': notes,
      };
}

class MenopauseTreatmentResponse {
  final String treatmentId;
  final String name;
  final String category;
  final String dose;
  final String startDate;
  final int daysActive;
  final Map<String, dynamic> beforeSummary;
  final Map<String, dynamic> afterSummary;
  final String attributionNote;

  MenopauseTreatmentResponse({
    required this.treatmentId,
    required this.name,
    required this.category,
    required this.dose,
    required this.startDate,
    required this.daysActive,
    required this.beforeSummary,
    required this.afterSummary,
    required this.attributionNote,
  });

  factory MenopauseTreatmentResponse.fromJson(Map<String, dynamic> json) {
    return MenopauseTreatmentResponse(
      treatmentId: json['treatmentId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      daysActive: (json['daysActive'] as num?)?.toInt() ?? 0,
      beforeSummary: Map<String, dynamic>.from(json['beforeSummary'] as Map? ?? {}),
      afterSummary: Map<String, dynamic>.from(json['afterSummary'] as Map? ?? {}),
      attributionNote: json['attributionNote']?.toString() ??
          'These patterns changed after starting this treatment. Blushy observes longitudinal correlations.',
    );
  }

  Map<String, dynamic> toJson() => {
        'treatmentId': treatmentId,
        'name': name,
        'category': category,
        'dose': dose,
        'startDate': startDate,
        'daysActive': daysActive,
        'beforeSummary': beforeSummary,
        'afterSummary': afterSummary,
        'attributionNote': attributionNote,
      };
}

class MenopauseQuestion {
  final String id;
  final String text;
  final String category;
  final String createdAt;

  MenopauseQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.createdAt,
  });

  factory MenopauseQuestion.fromJson(Map<String, dynamic> json) {
    return MenopauseQuestion(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'category': category,
        'createdAt': createdAt,
      };
}

class MenopauseTeachMeItem {
  final String id;
  final String topic;
  final String title;
  final String badge;
  final String icon;
  final String colorHex;
  final String bgHex;
  final String summary;
  final String visualCue;
  final String whatItFeelsLike;
  final String whenToTalkToDoctor;
  final String whatTreatmentsExist;

  MenopauseTeachMeItem({
    required this.id,
    required this.topic,
    required this.title,
    required this.badge,
    required this.icon,
    required this.colorHex,
    required this.bgHex,
    required this.summary,
    required this.visualCue,
    required this.whatItFeelsLike,
    required this.whenToTalkToDoctor,
    required this.whatTreatmentsExist,
  });

  factory MenopauseTeachMeItem.fromJson(Map<String, dynamic> json) {
    return MenopauseTeachMeItem(
      id: json['id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '30s Read',
      icon: json['icon']?.toString() ?? 'spa_rounded',
      colorHex: json['colorHex']?.toString() ?? '0xFF0D9488',
      bgHex: json['bgHex']?.toString() ?? '0xFFCCFBF1',
      summary: json['summary']?.toString() ?? '',
      visualCue: json['visualCue']?.toString() ?? '',
      whatItFeelsLike: json['whatItFeelsLike']?.toString() ?? '',
      whenToTalkToDoctor: json['whenToTalkToDoctor']?.toString() ?? '',
      whatTreatmentsExist: json['whatTreatmentsExist']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'title': title,
        'badge': badge,
        'icon': icon,
        'colorHex': colorHex,
        'bgHex': bgHex,
        'summary': summary,
        'visualCue': visualCue,
        'whatItFeelsLike': whatItFeelsLike,
        'whenToTalkToDoctor': whenToTalkToDoctor,
        'whatTreatmentsExist': whatTreatmentsExist,
      };

  static List<MenopauseTeachMeItem> defaults() => [
        MenopauseTeachMeItem(
          id: 'gsm_explained',
          topic: 'Intimate & Urinary',
          title: 'What is GSM?',
          badge: '30s Read',
          icon: 'spa_rounded',
          colorHex: '0xFFF72585',
          bgHex: '0xFFFFE5F0',
          summary: 'GSM stands for Genitourinary Syndrome of Menopause — changes in vaginal tissue and urinary comfort caused by reduced estrogen.',
          visualCue: 'Lower estrogen thins mucosal lining and reduces moisture, changing pH and elasticity.',
          whatItFeelsLike: 'Dryness, mild friction or burning, discomfort during intimacy, or needing to pee more often.',
          whenToTalkToDoctor: 'If discomfort interferes with daily movement, intimacy, or if you notice any spotting.',
          whatTreatmentsExist: 'Non-hormonal hyaluronic acid moisturizers, silicone lubricants, and localized low-dose vaginal estrogen (creams, pessaries, or rings) which have virtually zero systemic absorption.',
        ),
        MenopauseTeachMeItem(
          id: 'bone_density_dexa',
          topic: 'Bone & Muscle',
          title: 'Why Bone Density Matters Now',
          badge: '30s Read',
          icon: 'fitness_center_rounded',
          colorHex: '0xFF0D9488',
          bgHex: '0xFFCCFBF1',
          summary: 'Estrogen slows bone breakdown. After periods end, bone remodeling shifts toward faster breakdown for the first 5 years.',
          visualCue: 'Bones remodel constantly. Resistance and impact exercises act like a signal telling osteoblasts to keep bones dense.',
          whatItFeelsLike: 'Bone loss itself is silent and has no symptoms until a fracture occurs.',
          whenToTalkToDoctor: 'Ask your doctor about a DEXA bone density scan if you are post-menopause or have a family history of osteoporosis.',
          whatTreatmentsExist: 'Strength exercises (weights, resistance bands), 1000–1200mg dietary calcium, Vitamin D3 + K2, and clinical bone therapies if diagnosed with osteopenia/osteoporosis.',
        ),
        MenopauseTeachMeItem(
          id: 'heart_health_shift',
          topic: 'Heart & Metabolic',
          title: 'Your Heart in Menopause',
          badge: '30s Read',
          icon: 'favorite_rounded',
          colorHex: '0xFF2563EB',
          bgHex: '0xFFDBEAFE',
          summary: 'Before menopause, estrogen keeps blood vessels flexible and helps maintain higher protective HDL cholesterol.',
          visualCue: 'As natural hormone levels settle, LDL cholesterol can drift upward and blood vessels become slightly stiffer.',
          whatItFeelsLike: 'Gradual shifts in stamina, resting pulse variations, or blood pressure changes.',
          whenToTalkToDoctor: 'Have your blood pressure and fasting cholesterol checked at your routine annual wellness checkup.',
          whatTreatmentsExist: 'Consistent brisk walking, fiber-rich colorful plants, extra virgin olive oil, stress management, and medical therapy when indicated by your doctor.',
        ),
        MenopauseTeachMeItem(
          id: 'sleep_thermoregulation',
          topic: 'Sleep & Rest',
          title: 'Why Sleep Disrupts at 3 AM',
          badge: '30s Read',
          icon: 'nightlight_round',
          colorHex: '0xFF7209B7',
          bgHex: '0xFFF3E8FF',
          summary: 'The hypothalamic thermoregulatory center becomes hypersensitive, misinterpreting normal nighttime core temperature shifts.',
          visualCue: 'Around 3 AM, cortisol naturally starts a slow rise while core body temperature fluctuates, easily waking light sleepers.',
          whatItFeelsLike: 'Waking suddenly, feeling warm, heart beating faster, difficulty nodding back off.',
          whenToTalkToDoctor: 'If poor sleep persists more than 3 nights a week for over a month despite sleep hygiene routines.',
          whatTreatmentsExist: 'Drop room temp to 18–19°C, breathable bamboo layers, magnesium glycinate before bed, and discussing MHT or non-hormonal options with your clinician.',
        ),
        MenopauseTeachMeItem(
          id: 'mht_window_opportunity',
          topic: 'Medical Care',
          title: 'The Menopause Hormone Therapy Window',
          badge: '30s Read',
          icon: 'medication_rounded',
          colorHex: '0xFFDD0D22',
          bgHex: '0xFFFFECEB',
          summary: 'Modern evidence shows MHT is safest and most effective when initiated within 10 years of menopause onset or before age 60.',
          visualCue: 'Guidelines from the North American Menopause Society (NAMS) emphasize individualized benefit/risk profiles.',
          whatItFeelsLike: 'Relief from hot flashes, night sweats, sleep disruption, and prevention of early bone loss.',
          whenToTalkToDoctor: 'Schedule a dedicated discussion with your gynecologist to review your personal medical history and options.',
          whatTreatmentsExist: 'Body-identical transdermal 17β-estradiol (patches/gels) paired with micronized progesterone (if uterus is present), or non-hormonal prescription alternatives.',
        ),
      ];
}

class MenopauseSafetyAlert {
  final bool isRedFlag;
  final String severity;
  final String title;
  final String eyebrow;
  final String icon;
  final String colorHex;
  final String bgHex;
  final String headline;
  final String explanation;

  MenopauseSafetyAlert({
    required this.isRedFlag,
    required this.severity,
    required this.title,
    required this.eyebrow,
    required this.icon,
    required this.colorHex,
    required this.bgHex,
    required this.headline,
    required this.explanation,
  });

  factory MenopauseSafetyAlert.fromJson(Map<String, dynamic> json) {
    return MenopauseSafetyAlert(
      isRedFlag: json['isRedFlag'] == true,
      severity: json['severity']?.toString() ?? 'urgent',
      title: json['title']?.toString() ?? 'Clinical Safety Check',
      eyebrow: json['eyebrow']?.toString() ?? 'CLINICAL SAFETY CHECK',
      icon: json['icon']?.toString() ?? 'emergency_rounded',
      colorHex: json['colorHex']?.toString() ?? '0xFFDD0D22',
      bgHex: json['bgHex']?.toString() ?? '0xFFFFECEB',
      headline: json['headline']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'isRedFlag': isRedFlag,
        'severity': severity,
        'title': title,
        'eyebrow': eyebrow,
        'icon': icon,
        'colorHex': colorHex,
        'bgHex': bgHex,
        'headline': headline,
        'explanation': explanation,
      };
}

class MenopauseHealthStoryItem {
  final String stage;
  final String timing;
  final String title;
  final String desc;
  final String icon;
  final String colorHex;

  MenopauseHealthStoryItem({
    required this.stage,
    required this.timing,
    required this.title,
    required this.desc,
    required this.icon,
    required this.colorHex,
  });

  factory MenopauseHealthStoryItem.fromJson(Map<String, dynamic> json) {
    return MenopauseHealthStoryItem(
      stage: json['stage']?.toString() ?? '',
      timing: json['timing']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      desc: json['desc']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'spa_rounded',
      colorHex: json['colorHex']?.toString() ?? '0xFF0D9488',
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'timing': timing,
        'title': title,
        'desc': desc,
        'icon': icon,
        'colorHex': colorHex,
      };

  static List<MenopauseHealthStoryItem> defaults() => [
        MenopauseHealthStoryItem(
          stage: 'Perimenopause',
          timing: 'Prior Years',
          title: 'Cycle Rhythms Shifted',
          desc: 'Periods became spaced and variable as ovulation timing fluctuated naturally.',
          icon: 'change_circle_rounded',
          colorHex: '0xFF7209B7',
        ),
        MenopauseHealthStoryItem(
          stage: 'Transition Milestone',
          timing: '12 Months Without Bleeding',
          title: 'Menopause Reached',
          desc: 'A full 365 days passed without a period, confirming transition into postmenopause.',
          icon: 'task_alt_rounded',
          colorHex: '0xFF0D9488',
        ),
        MenopauseHealthStoryItem(
          stage: 'New Chapter',
          timing: 'Present Day',
          title: 'Protecting Long-Term Health',
          desc: 'Focus has shifted to bone density, cardiovascular elasticity, intimate comfort, and restful sleep.',
          icon: 'spa_rounded',
          colorHex: '0xFF2563EB',
        ),
      ];
}

class MenopauseOverviewData {
  final String lifeStage;
  final String chapterTitle;
  final String subheading;
  final String lifeMode;
  final bool privateMode;
  final List<String> sectionOrder;
  final MenopauseSafetyAlert? safetyAlert;
  final MenopauseTodayBrief todayWithDocsy;
  final MenopauseMyNormal myNormal;
  final List<MenopauseShiftItem> whatChanged;
  final List<MenopauseShiftItem> whatBeenSteady;
  final List<MenopauseDomain> healthDomains;
  final List<MenopauseTreatment> treatments;
  final List<MenopauseTreatmentResponse> treatmentResponse;
  final List<MenopauseQuestion> questions;
  final List<MenopauseTeachMeItem> teachMeIn30Seconds;
  final List<MenopauseHealthStoryItem> healthStory;
  final int recentCheckinsCount;

  MenopauseOverviewData({
    required this.lifeStage,
    required this.chapterTitle,
    required this.subheading,
    required this.lifeMode,
    required this.privateMode,
    required this.sectionOrder,
    this.safetyAlert,
    required this.todayWithDocsy,
    required this.myNormal,
    required this.whatChanged,
    required this.whatBeenSteady,
    required this.healthDomains,
    required this.treatments,
    required this.treatmentResponse,
    required this.questions,
    required this.teachMeIn30Seconds,
    required this.healthStory,
    required this.recentCheckinsCount,
  });

  factory MenopauseOverviewData.fromJson(Map<String, dynamic> json) {
    return MenopauseOverviewData(
      lifeStage: json['lifeStage']?.toString() ?? 'menopause',
      chapterTitle: json['chapterTitle']?.toString() ?? 'Your New Chapter',
      subheading: json['subheading']?.toString() ?? 'Understanding your body. Protecting your health. Living fully.',
      lifeMode: json['lifeMode']?.toString() ?? 'normal',
      privateMode: json['privateMode'] == true,
      sectionOrder: (json['sectionOrder'] as List?)?.map((s) => s.toString()).toList() ??
          const [
            'editorial_greeting',
            'today_with_docsy',
            'how_am_i_today',
            'what_changed',
            'what_been_steady',
            'what_do_i_need_actions',
            'my_health_domains',
            'my_normal',
            'my_treatment',
            'my_questions',
            'prepare_for_care',
            'my_health_story',
            'teach_me_30s',
          ],
      safetyAlert: json['safetyAlert'] != null
          ? MenopauseSafetyAlert.fromJson(Map<String, dynamic>.from(json['safetyAlert'] as Map))
          : null,
      todayWithDocsy: json['todayWithDocsy'] != null
          ? MenopauseTodayBrief.fromJson(Map<String, dynamic>.from(json['todayWithDocsy'] as Map))
          : MenopauseTodayBrief.fromJson({}),
      myNormal: json['myNormal'] != null
          ? MenopauseMyNormal.fromJson(Map<String, dynamic>.from(json['myNormal'] as Map))
          : MenopauseMyNormal.fromJson({}),
      whatChanged: (json['whatChanged'] as List?)
              ?.map((c) => MenopauseShiftItem.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          const [],
      whatBeenSteady: (json['whatBeenSteady'] as List?)
              ?.map((s) => MenopauseShiftItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          const [],
      healthDomains: () {
        final list = (((json['healthDomains'] ?? json['domains'])) as List?)
            ?.map((d) => MenopauseDomain.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList();
        return (list != null && list.isNotEmpty) ? list : MenopauseDomain.defaults();
      }(),
      treatments: (json['treatments'] as List?)
              ?.map((t) => MenopauseTreatment.fromJson(Map<String, dynamic>.from(t as Map)))
              .toList() ??
          const [],
      treatmentResponse: (json['treatmentResponse'] as List?)
              ?.map((r) => MenopauseTreatmentResponse.fromJson(Map<String, dynamic>.from(r as Map)))
              .toList() ??
          const [],
      questions: (json['questions'] as List?)
              ?.map((q) => MenopauseQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList() ??
          const [],
      teachMeIn30Seconds: () {
        final list = (json['teachMeIn30Seconds'] as List?)
            ?.map((tm) => MenopauseTeachMeItem.fromJson(Map<String, dynamic>.from(tm as Map)))
            .toList();
        return (list != null && list.isNotEmpty) ? list : MenopauseTeachMeItem.defaults();
      }(),
      healthStory: () {
        final list = (json['healthStory'] as List?)
            ?.map((h) => MenopauseHealthStoryItem.fromJson(Map<String, dynamic>.from(h as Map)))
            .toList();
        return (list != null && list.isNotEmpty) ? list : MenopauseHealthStoryItem.defaults();
      }(),
      recentCheckinsCount: (json['recentCheckinsCount'] as num?)?.toInt() ?? 0,
    );
  }


  Map<String, dynamic> toJson() => {
        'lifeStage': lifeStage,
        'chapterTitle': chapterTitle,
        'subheading': subheading,
        'lifeMode': lifeMode,
        'privateMode': privateMode,
        'sectionOrder': sectionOrder,
        'safetyAlert': safetyAlert?.toJson(),
        'todayWithDocsy': todayWithDocsy.toJson(),
        'myNormal': myNormal.toJson(),
        'whatChanged': whatChanged.map((c) => c.toJson()).toList(),
        'whatBeenSteady': whatBeenSteady.map((s) => s.toJson()).toList(),
        'healthDomains': healthDomains.map((d) => d.toJson()).toList(),
        'treatments': treatments.map((t) => t.toJson()).toList(),
        'treatmentResponse': treatmentResponse.map((r) => r.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'teachMeIn30Seconds': teachMeIn30Seconds.map((tm) => tm.toJson()).toList(),
        'healthStory': healthStory.map((h) => h.toJson()).toList(),
        'recentCheckinsCount': recentCheckinsCount,
      };
}

class MenopauseIsThisNormalResult {
  final String whatYouToldMe;
  final String whatWeKnow;
  final String whatMightBeGoingOn;
  final String whatYouCanTry;
  final String whenToCheckWithDoctor;
  final String suggestedTracking;

  MenopauseIsThisNormalResult({
    required this.whatYouToldMe,
    required this.whatWeKnow,
    required this.whatMightBeGoingOn,
    required this.whatYouCanTry,
    required this.whenToCheckWithDoctor,
    required this.suggestedTracking,
  });

  factory MenopauseIsThisNormalResult.fromJson(Map<String, dynamic> json) {
    return MenopauseIsThisNormalResult(
      whatYouToldMe: json['whatYouToldMe']?.toString() ?? '',
      whatWeKnow: json['whatWeKnow']?.toString() ?? '',
      whatMightBeGoingOn: json['whatMightBeGoingOn']?.toString() ?? '',
      whatYouCanTry: json['whatYouCanTry']?.toString() ?? '',
      whenToCheckWithDoctor: json['whenToCheckWithDoctor']?.toString() ?? '',
      suggestedTracking: json['suggestedTracking']?.toString() ?? '',
    );
  }
}

class MenopauseNoteParseResult {
  final List<String> extractedEntities;
  final String confirmationMessage;
  final Map<String, dynamic> parsedCheckin;

  MenopauseNoteParseResult({
    required this.extractedEntities,
    required this.confirmationMessage,
    required this.parsedCheckin,
  });

  factory MenopauseNoteParseResult.fromJson(Map<String, dynamic> json) {
    return MenopauseNoteParseResult(
      extractedEntities: (json['extractedEntities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      confirmationMessage: json['confirmationMessage']?.toString() ?? '',
      parsedCheckin: Map<String, dynamic>.from(json['parsedCheckin'] as Map? ?? {}),
    );
  }
}

class MenopauseClinicianBrief {
  final String title;
  final String generatedAt;
  final String rawSummaryText;
  final int totalQuestions;
  final int activeTreatmentsCount;
  final int recentShiftsCount;

  MenopauseClinicianBrief({
    required this.title,
    required this.generatedAt,
    required this.rawSummaryText,
    required this.totalQuestions,
    required this.activeTreatmentsCount,
    required this.recentShiftsCount,
  });

  factory MenopauseClinicianBrief.fromJson(Map<String, dynamic> json) {
    return MenopauseClinicianBrief(
      title: json['title']?.toString() ?? 'Clinician Summary',
      generatedAt: json['generatedAt']?.toString() ?? '',
      rawSummaryText: json['rawSummaryText']?.toString() ?? '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      activeTreatmentsCount: (json['activeTreatmentsCount'] as num?)?.toInt() ?? 0,
      recentShiftsCount: (json['recentShiftsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MenopauseWhyAmISeeingThis {
  final String youLogged;
  final String wereNoticing;
  final String whyItMayMatter;
  final String whatBlushyDoesntKnow;
  final String whatYouCanDo;

  MenopauseWhyAmISeeingThis({
    required this.youLogged,
    required this.wereNoticing,
    required this.whyItMayMatter,
    required this.whatBlushyDoesntKnow,
    required this.whatYouCanDo,
  });

  factory MenopauseWhyAmISeeingThis.fromJson(Map<String, dynamic> json) {
    return MenopauseWhyAmISeeingThis(
      youLogged: json['youLogged']?.toString() ?? '',
      wereNoticing: json['wereNoticing']?.toString() ?? '',
      whyItMayMatter: json['whyItMayMatter']?.toString() ?? '',
      whatBlushyDoesntKnow: json['whatBlushyDoesntKnow']?.toString() ?? '',
      whatYouCanDo: json['whatYouCanDo']?.toString() ?? '',
    );
  }
}

class ApiMenopauseService {
  static const String _overviewKey = 'menopause_overview_cache.json';

  /// The menopause overview, with the server's own state preserved.
  ///
  /// This used to collapse every outcome into a nullable and, when it had
  /// nothing, return `MenopauseOverviewData.fallback()` -- 123 lines that
  /// manufactured an entire personal history: a "My Normal" baseline ("Usually
  /// 6-7 hrs", "Usually 0-1/day"), findings over the "Past 7 Days" saying sleep
  /// had stayed steady and no hot flashes were reported, and an active
  /// transdermal patch treatment. None of it measured, all of it shown to
  /// anyone whose request failed. That constructor is gone.
  ///
  /// Now the caller can tell the four cases apart: fresh data, cached data
  /// after a failure (stale), no data, and an actual error or offline.
  static Future<ApiResult<MenopauseOverviewData>> getOverview() async {
    final res = await ApiContractClient.get<MenopauseOverviewData>(
      '/menopause/overview',
      parse: (data) => MenopauseOverviewData.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    if (res.data != null) {
      try {
        BlushyStorage.write(_overviewKey, res.data!.toJson());
      } catch (_) {}
      return res;
    }

    // The request did not come back with anything usable. A cached copy is
    // worth showing, but it is labelled stale rather than passed off as fresh.
    final cached = BlushyStorage.read(_overviewKey);
    if (cached.isNotEmpty) {
      try {
        return ApiResult<MenopauseOverviewData>(
          data: MenopauseOverviewData.fromJson(cached),
          state: ApiState.stale,
          lastUpdated: res.lastUpdated,
          source: res.source,
        );
      } catch (_) {}
    }

    // Nothing cached either, so the real reason travels to the caller.
    return res;
  }

  static Future<bool> recordCheckin(Map<String, dynamic> checkinData) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/checkin',
        body: checkinData,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setLifeMode(String mode) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/life-mode',
        body: {'lifeMode': mode},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setPrivateMode(bool enabled) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/private-mode',
        body: {'enabled': enabled},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  static Future<MenopauseIsThisNormalResult?> askIsThisNormal(String query) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/is-this-normal',
        body: {'query': query},
        parse: (data) => MenopauseIsThisNormalResult.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  static Future<MenopauseNoteParseResult?> parseNaturalNote(String note) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/parse-note',
        body: {'note': note},
        parse: (data) => MenopauseNoteParseResult.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> addQuestion(String text, {String category = 'General'}) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/questions',
        body: {'text': text, 'category': category},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteQuestion(String id) async {
    try {
      await ApiContractClient.delete('/menopause/questions/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> addTreatment(Map<String, dynamic> data) async {
    try {
      final res = await ApiContractClient.post(
        '/menopause/treatment',
        body: data,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeTreatment(String id) async {
    try {
      await ApiContractClient.delete('/menopause/treatment/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<MenopauseClinicianBrief?> getClinicianBrief() async {
    try {
      final res = await ApiContractClient.get(
        '/menopause/clinician-brief',
        parse: (data) => MenopauseClinicianBrief.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  static Future<MenopauseWhyAmISeeingThis?> getWhyAmISeeingThis(String moduleKey) async {
    try {
      final res = await ApiContractClient.get(
        '/menopause/why-am-i-seeing-this/$moduleKey',
        parse: (data) => MenopauseWhyAmISeeingThis.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }
}
