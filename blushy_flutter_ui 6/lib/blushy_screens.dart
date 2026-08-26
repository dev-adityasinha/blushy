import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'blushy_design_system.dart';

// ═══════════════════════════════════════════════
// 1. HOME SCREEN (DAILY WELLNESS FEED)
// ═══════════════════════════════════════════════
class ScreenWelcome extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final bool isDemoMode;
  const ScreenWelcome({super.key, this.onNavigate, this.isDemoMode = false});

  @override
  State<ScreenWelcome> createState() => _ScreenWelcomeState();
}

class _ScreenWelcomeState extends State<ScreenWelcome> {
  String _selectedLanguage = 'English';
  int _currentDay = 19; 
  int _cycleLength = 28;
  int _periodLength = 5;
  int _firstDayOfLastPeriod = 1;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LanguageNotifier.activeLanguage.value;
    LanguageNotifier.activeLanguage.addListener(_onLanguageChanged);
    
    // Only cycle timer if in Platform Section Demo Mode (preserves Hero section)
    if (widget.isDemoMode) {
      _currentDay = 2; // Start from menstrual day 2 in demo
      _cycleTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            if (_currentDay == 2) {
              _currentDay = 14;
            } else if (_currentDay == 14) {
              _currentDay = 21;
            } else {
              _currentDay = 2;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    LanguageNotifier.activeLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _selectedLanguage = LanguageNotifier.activeLanguage.value;
      });
    }
  }

  // Language mapping with native unicode escapes to support protobuf safe serialization
  static final Map<String, Map<String, String>> _langs = {
    'English': {
      'greeting': 'Good morning, Taara',
      'menstrual': 'Menstrual Phase',
      'follicular': 'Follicular Phase',
      'ovulation': 'Ovulation Phase',
      'luteal': 'Luteal Phase',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize deep work and self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'हिन्दी': {
      'greeting': 'Shubh Prabhat, Taara',
      'menstrual': 'Menstrual Charan',
      'follicular': 'Follicular Charan',
      'ovulation': 'Ovulation Charan',
      'luteal': 'Luteal Charan',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'తెలుగు': {
      'greeting': 'Shubhodhayam, Taara',
      'menstrual': 'Menstrual Dhasha',
      'follicular': 'Follicular Dhasha',
      'ovulation': 'Ovulation Dhasha',
      'luteal': 'Luteal Dhasha',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'தமிழ்': {
      'greeting': 'Kaalai Vanakkam, Taara',
      'menstrual': 'Menstrual Kattam',
      'follicular': 'Follicular Kattam',
      'ovulation': 'Ovulation Kattam',
      'luteal': 'Luteal Kattam',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'ಕನ್ನಡ': {
      'greeting': 'Shubhodhaya, Taara',
      'menstrual': 'Menstrual Hantha',
      'follicular': 'Follicular Hantha',
      'ovulation': 'Ovulation Hantha',
      'luteal': 'Luteal Hantha',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'മലയാളം': {
      'greeting': 'Suprabhatham, Taara',
      'menstrual': 'Menstrual Ghattam',
      'follicular': 'Follicular Ghattam',
      'ovulation': 'Ovulation Ghattam',
      'luteal': 'Luteal Ghattam',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'मराठी': {
      'greeting': 'Shubh Sakal, Taara',
      'menstrual': 'Menstrual Phase',
      'follicular': 'Follicular Phase',
      'ovulation': 'Ovulation Phase',
      'luteal': 'Luteal Phase',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'বাংলা': {
      'greeting': 'Suprabhat, Taara',
      'menstrual': 'Menstrual Phase',
      'follicular': 'Follicular Phase',
      'ovulation': 'Ovulation Phase',
      'luteal': 'Luteal Phase',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'ગુજરાતી': {
      'greeting': 'Suprabhat, Taara',
      'menstrual': 'Menstrual Phase',
      'follicular': 'Follicular Phase',
      'ovulation': 'Ovulation Phase',
      'luteal': 'Luteal Phase',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    },
    'ਪੰਜਾਬੀ': {
      'greeting': 'Shubh Sabehar, Taara',
      'menstrual': 'Menstrual Phase',
      'follicular': 'Follicular Phase',
      'ovulation': 'Ovulation Phase',
      'luteal': 'Luteal Phase',
      'period_in': 'Period in {n} days',
      'period_today': 'Period today',
      'insight_tag': 'DAILY INSIGHT',
      'insight_text': 'Progesterone is peaking. Expect calmer, reflective energy. Prioritize self-care.',
      'guidance_tag': 'TODAY\'S GUIDANCE',
      'g1': 'Take breaks & schedule meetings for later',
      'g2': 'Stay hydrated — aim for 2.5L',
      'g3': 'Listen to your body & sleep early',
      'community_tag': 'FROM THE COMMUNITY',
      'community_text': 'Does anyone else feel more emotional before their period?',
    }
  };

  // Helper names formatted properly using unicodes for list
  static final List<Map<String, String>> _langList = [
    {'code': 'English', 'native': 'English'},
    {'code': '\u0939\u093f\u0928\u094d\u0926\u0940', 'native': '\u0939\u093f\u0928\u094d\u0926\u0940 (Hindi)'},
    {'code': '\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41', 'native': '\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 (Telugu)'},
    {'code': '\u0b24\u0b2e\u0b3f\u0b34\u0b4d', 'native': '\u0b24\u0b2e\u0b3f\u0b34\u0b4d (Tamil)'},
    {'code': '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1', 'native': '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1 (Kannada)'},
    {'code': '\u0d2e\u0d3abs\u0d4d', 'native': '\u0d2e\u0d3abs\u0d4d (Malayalam)'},
    {'code': '\u092e\u0930\u093e\u0920\u0940', 'native': '\u092e\u0930\u093e\u0920\u0940 (Marathi)'},
    {'code': '\u09ac\u09be\u0982\u09b2\u09be', 'native': '\u09ac\u09be\u0982\u09b2\u09be (Bengali)'},
    {'code': '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0', 'native': '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0 (Gujarati)'},
    {'code': '\u0a2a\u0a70\u0a1c\u0a3e\u0a2c\u0a40', 'native': '\u0a2a\u0a70\u0a1c\u0a3e\u0a2c\u0a40 (Punjabi)'},
  ];

  String _getPhaseForDay(int day) {
    if (day <= _periodLength) return 'Menstrual';
    final ovulationDay = (_cycleLength / 2).round();
    if (day >= ovulationDay - 1 && day <= ovulationDay + 2) return 'Ovulation';
    if (day < ovulationDay - 1) return 'Follicular';
    return 'Luteal';
  }

  void _updateDayFromOffset(Offset localOffset, Size size) {
    final double startX = size.width * 0.15;
    final double endX = size.width * 0.85;
    final double activeWidth = endX - startX;
    final double dx = (localOffset.dx - startX).clamp(0.0, activeWidth);
    final double progress = dx / activeWidth;
    int day = (progress * _cycleLength).round().clamp(1, _cycleLength);
    
    setState(() {
      _currentDay = day;
    });
  }

  void _showEditBottomSheet(BuildContext context) {
    int tempFirstDay = _firstDayOfLastPeriod;
    double tempCycleLen = _cycleLength.toDouble();
    double tempPeriodLen = _periodLength.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: BDColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(color: BDColors.divider, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Edit Cycle Settings',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: BDColors.ink),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'First Day of Last Period: June $tempFirstDay',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink),
                      ),
                      Slider(
                        value: tempFirstDay.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        activeColor: BDColors.red,
                        inactiveColor: BDColors.divider,
                        onChanged: (val) {
                          setModalState(() {
                            tempFirstDay = val.round();
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cycle Length: ${tempCycleLen.round()} days',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink),
                      ),
                      Slider(
                        value: tempCycleLen,
                        min: 21,
                        max: 35,
                        divisions: 14,
                        activeColor: BDColors.red,
                        inactiveColor: BDColors.divider,
                        onChanged: (val) {
                          setModalState(() {
                            tempCycleLen = val;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Period Length: ${tempPeriodLen.round()} days',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink),
                      ),
                      Slider(
                        value: tempPeriodLen,
                        min: 3,
                        max: 10,
                        divisions: 7,
                        activeColor: BDColors.red,
                        inactiveColor: BDColors.divider,
                        onChanged: (val) {
                          setModalState(() {
                            tempPeriodLen = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _firstDayOfLastPeriod = tempFirstDay;
                              _cycleLength = tempCycleLen.round();
                              _periodLength = tempPeriodLen.round();
                              if (_currentDay > _cycleLength) _currentDay = _cycleLength;
                            });
                            Navigator.pop(bc);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BDColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm Changes',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          decoration: const BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(color: BDColors.divider, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Language',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: BDColors.ink),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: _langList.map((langMap) {
                      final langCode = langMap['code']!;
                      final nativeName = langMap['native']!;
                      final isSelected = _selectedLanguage == langCode;
                      return ListTile(
                        onTap: () {
                          setState(() => _selectedLanguage = langCode);
                          Navigator.pop(bc);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          nativeName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? BDColors.red : BDColors.ink,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: BDColors.red, size: 20)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = _langs[_selectedLanguage] ?? _langs['English']!;
    final String activePhase = _getPhaseForDay(_currentDay);
    Color phaseColor = const Color(0xFF8B5CF6); // Luteal
    String statusChip = 'Hormones stabilizing';
    
    if (activePhase == 'Menstrual') {
      phaseColor = const Color(0xFFE53935);
      statusChip = 'Rest & restore';
    } else if (activePhase == 'Follicular') {
      phaseColor = const Color(0xFFFF6B35);
      statusChip = 'Power rising';
    } else if (activePhase == 'Ovulation') {
      phaseColor = const Color(0xFFFFC107);
      statusChip = 'High energy';
    }
    
    String phaseLabel = tr[activePhase.toLowerCase()] ?? activePhase;
    int daysLeftToPeriod = _cycleLength - _currentDay + 1;
    String periodCountdown;
    if (daysLeftToPeriod <= 0 || _currentDay <= _periodLength) {
      periodCountdown = tr['period_today']!;
    } else {
      periodCountdown = tr['period_in']!.replaceAll('{n}', daysLeftToPeriod.toString());
    }

    String subheadText = periodCountdown;
    if (_selectedLanguage == 'English' && periodCountdown.startsWith('Period in')) {
      subheadText = '$daysLeftToPeriod days until period';
    }

    return Container(
      color: BDColors.cream,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Header Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TODAY • JUN 14', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
              const SizedBox(height: 4),
              Text('Good morning, Taara', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BDColors.ink)),
            ],
          ),
          const SizedBox(height: 20),

          // 1. LARGE HERO CYCLE CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BDColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: BDColors.ink.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CYCLE PATH',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: BDColors.inkLight.withOpacity(0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showEditBottomSheet(context),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: BDColors.cream,
                          shape: BoxShape.circle,
                          border: Border.all(color: BDColors.divider),
                        ),
                        child: Icon(Icons.mode_edit_outline_rounded, size: 13, color: phaseColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 260,
                  height: 120,
                  child: GestureDetector(
                    onPanUpdate: (details) => _updateDayFromOffset(details.localPosition, const Size(260, 120)),
                    onTapDown: (details) => _updateDayFromOffset(details.localPosition, const Size(260, 120)),
                    child: CustomPaint(
                      painter: _FallopianTrackPainter(
                        activeProgress: _currentDay / _cycleLength,
                        activePhase: activePhase,
                        cycleLength: _cycleLength,
                        periodLength: _periodLength,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Day $_currentDay',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: BDColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: phaseColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: BDColors.inkLight.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      subheadText,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: BDColors.inkLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(width: double.infinity, height: 1, color: BDColors.divider),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's focus", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink)),
                      const SizedBox(height: 8),
                      if (widget.isDemoMode && activePhase == 'Menstrual') ...[
                        _buildBulletFocus("Recovery mode active"),
                        _buildBulletFocus("Gentle movement suggested"),
                        _buildBulletFocus("Pain management support"),
                        _buildBulletFocus("Iron-rich meal ideas"),
                      ] else if (widget.isDemoMode && activePhase == 'Ovulation') ...[
                        _buildBulletFocus("High energy levels"),
                        _buildBulletFocus("Workout intensity increased"),
                        _buildBulletFocus("Fertility insight available"),
                        _buildBulletFocus("Skin & hydration focus"),
                      ] else if (widget.isDemoMode && activePhase == 'Luteal') ...[
                        _buildBulletFocus("Energy expected to dip"),
                        _buildBulletFocus("Meetings suggested later in the day"),
                        _buildBulletFocus("Higher emotional sensitivity"),
                        _buildBulletFocus("Rest before pushing harder"),
                      ] else ...[
                        _buildBulletFocus("Energy may dip slightly"),
                        _buildBulletFocus("Emotional sensitivity is higher"),
                        _buildBulletFocus("Rest before pushing harder"),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. SIA CONVERSATIONAL INSIGHT
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BDColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: BDColors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('Sia noticed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: BDColors.inkLight)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isDemoMode
                      ? (activePhase == 'Menstrual'
                          ? '"Recovery mode. Focus on gentle stretching, pain management, and warm comfort meals today."'
                          : (activePhase == 'Ovulation'
                              ? '"Your energy is peaking today. Perfect time for social activities and high-intensity workouts!"'
                              : '"Progesterone is peaking. Expect calmer, reflective energy. Prioritize deep work and rest."'))
                      : '"Based on your recent cycle patterns, today is better for slower work than back-to-back meetings."',
                  style: GoogleFonts.playfairDisplay(fontSize: 15, fontStyle: FontStyle.italic, color: BDColors.ink, height: 1.4),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => widget.onNavigate?.call(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: BDColors.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Ask Sia →', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. COMMUNITY CAROUSEL
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('From the Community', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BDColors.ink)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCommunityMagazineCard(
                      title: "Why do hormone changes affect your mood?",
                      tag: "Doctor Reviewed",
                      readTime: "4 min read",
                    ),
                    _buildCommunityMagazineCard(
                      title: "How women manage PMS at work",
                      tag: "Community Story",
                      readTime: "6 min read",
                    ),
                    _buildCommunityMagazineCard(
                      title: "Foods that reduce period fatigue",
                      tag: "Nutrition",
                      readTime: "3 min read",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. QUICK ACTIONS
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Quick Actions', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickActionCircle(Icons.calendar_today_rounded, "Log Period", () => _showEditBottomSheet(context)),
                  _buildQuickActionCircle(Icons.mic_rounded, "Voice Journal", () => widget.onNavigate?.call(3)),
                  _buildQuickActionCircle(Icons.chat_bubble_outline_rounded, "Ask Sia", () => widget.onNavigate?.call(2)),
                  _buildQuickActionCircle(Icons.favorite_outline_rounded, "Partner", () => widget.onNavigate?.call(4)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 5. UPCOMING PERIOD CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BDColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BDColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Period', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
                    const SizedBox(height: 4),
                    Text('24 June', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BDColors.ink)),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showEditBottomSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: BDColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Edit Cycle', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletFocus(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 4, height: 4,
            decoration: const BoxDecoration(color: BDColors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityMagazineCard({required String title, required String tag, required String readTime}) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BDColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BDColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
              const SizedBox(height: 2),
              Text(readTime, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCircle(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: BDColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: BDColors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon, size: 20, color: BDColors.ink),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// 2. COMMUNITY SCREEN (ANONYMOUS KNOWLEDGE SHARE)
// ═══════════════════════════════════════════════
class ScreenCommunity extends StatefulWidget {
  const ScreenCommunity({super.key});

  @override
  State<ScreenCommunity> createState() => _ScreenCommunityState();
}

class _ScreenCommunityState extends State<ScreenCommunity> {
  int _voiceState = 0; // 0: Idle/Prompt, 1: Recording, 2: Transcribing, 3: Preview/Post
  bool _looping = true;
  bool _translatedCard = false;

  @override
  void initState() {
    super.initState();
    _startVoiceComposerLoop();
    _startTranslationLoop();
  }

  void _startVoiceComposerLoop() async {
    while (_looping && mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted || !_looping) break;
      setState(() => _voiceState = 1); // Recording
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_looping) break;
      setState(() => _voiceState = 2); // Transcribing
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_looping) break;
      setState(() => _voiceState = 3); // Preview / Post
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_looping) break;
      setState(() => _voiceState = 0); // Idle
    }
  }

  void _startTranslationLoop() async {
    while (_looping && mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || !_looping) break;
      setState(() => _translatedCard = true);
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || !_looping) break;
      setState(() => _translatedCard = false);
    }
  }

  @override
  void dispose() {
    _looping = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BDColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Community', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BDColors.ink)),
                    Text('Anonymous knowledge exchange', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
                const Icon(Icons.search_rounded, size: 22, color: BDColors.ink),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Top Tabs
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildTab('Trending', true),
                _buildTab('Questions', false),
                _buildTab('Stories', false),
                _buildTab('Articles', false),
                _buildTab('Saved', false),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Create Post Card (Voice Transcription Demo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BDColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BDColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CREATE A POST', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildVoiceComposerState(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Article Card (Translation & Actions Demo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: BDColors.divider)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ARTICLE • PMS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: BDColors.orange)),
                          Text('5 min read', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Understanding Hormonal Changes', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)),
                      Text('Doctor-reviewed expert insights.', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                      const SizedBox(height: 14),
                      const Divider(color: BDColors.divider),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCardAction(Icons.menu_book_rounded, 'Read'),
                          _buildCardAction(Icons.translate_rounded, 'Translate', color: BDColors.red),
                          _buildCardAction(Icons.bookmark_border_rounded, 'Save'),
                          _buildCardAction(Icons.ios_share_rounded, 'Share'),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Multilingual Post Card (Translation Demo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: BDColors.divider)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ANONYMOUS • HINDI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
                          Text('Luteal Phase', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        firstChild: Text(
                          'मुझे पिछले तीन दिनों से बहुत थकान महसूस हो रही है। क्या किसी और को भी ऐसा होता है?',
                          style: GoogleFonts.inter(fontSize: 13, color: BDColors.ink, height: 1.4),
                        ),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'मुझे पिछले तीन दिनों से बहुत थकान महसूस हो रही है। क्या किसी और को भी ऐसा होता है?',
                              style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight, decoration: TextDecoration.lineThrough),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '“I have been feeling extremely exhausted for the past three days. Does this happen to anyone else?”',
                              style: GoogleFonts.inter(fontSize: 13, color: BDColors.red, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        crossFadeState: _translatedCard ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('96 replies', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.translate_rounded, size: 12, color: _translatedCard ? BDColors.red : BDColors.inkLight),
                              const SizedBox(width: 4),
                              Text(_translatedCard ? 'Translated' : 'Translate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _translatedCard ? BDColors.red : BDColors.inkLight)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool active) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? BDColors.ink : BDColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.transparent : BDColors.divider),
      ),
      alignment: Alignment.center,
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: active ? BDColors.cream : BDColors.ink)),
    );
  }

  Widget _buildCardAction(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color ?? BDColors.inkLight),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? BDColors.inkLight)),
      ],
    );
  }

  Widget _buildVoiceComposerState() {
    switch (_voiceState) {
      case 1:
        return Row(
          key: const ValueKey("rec"),
          children: [
            const Icon(Icons.circle, size: 10, color: BDColors.red),
            const SizedBox(width: 8),
            Text('Recording voice note... 0:08', style: GoogleFonts.inter(fontSize: 13, color: BDColors.red, fontWeight: FontWeight.w500)),
          ],
        );
      case 2:
        return Row(
          key: const ValueKey("trans"),
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: BDColors.red)),
            const SizedBox(width: 10),
            Text('Transcribing to text...', style: GoogleFonts.inter(fontSize: 13, color: BDColors.inkLight)),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey("prev"),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“Does anyone else feel exhausted before their period?”', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: BDColors.ink)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Publish Post →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BDColors.red)),
              ],
            )
          ],
        );
      default:
        return Row(
          key: const ValueKey("idle"),
          children: [
            Expanded(child: Text('Write your question or experience...', style: GoogleFonts.inter(fontSize: 13, color: BDColors.inkLight))),
            const Icon(Icons.mic_none_rounded, size: 18, color: BDColors.red),
          ],
        );
    }
  }
}

// ═══════════════════════════════════════════════
// 3. SIA SCREEN (EMPATHIC WELLNESS ASSISTANT)
// ═══════════════════════════════════════════════
class ScreenAI extends StatefulWidget {
  final bool isDemoMode;
  const ScreenAI({super.key, this.isDemoMode = false});
  @override
  State<ScreenAI> createState() => _ScreenAIState();
}

class _ScreenAIState extends State<ScreenAI> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sia', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BDColors.ink)),
                    Text('Your daily wellness guide', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
                const Icon(Icons.history_rounded, size: 20, color: BDColors.inkLight),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Message Stream
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // User Message
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: BDColors.ink,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16)),
                    ),
                    child: Text(
                      widget.isDemoMode
                          ? "Why do I suddenly feel anxious today?"
                          : "I've been feeling really tired lately.",
                      style: GoogleFonts.inter(fontSize: 13, color: BDColors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sia Reply
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    if (_c.value < 0.3) {
                      return Align(alignment: Alignment.centerLeft, child: _TypingIndicator());
                    }
                    double v = ((_c.value - 0.3) / 0.3).clamp(0.0, 1.0);
                    v = Curves.easeOutCubic.transform(v);
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - v)),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: BDColors.white,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                            ),
                            child: Text(
                              widget.isDemoMode
                                  ? "Your hormone patterns suggest you're entering your luteal phase. This is a common time for increased emotional sensitivity. Here are three things that may help today:\n\n1. Deep breathing exercises\n2. Chamomile tea & hydration\n3. Restful environment setup\n\n(I also noticed you've slept less for three days. That may be amplifying today's symptoms.)"
                                  : "That can happen during your luteal phase. Your body naturally needs more rest around this time.",
                              style: GoogleFonts.inter(fontSize: 13, color: BDColors.ink, height: 1.4),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Suggestion Chips
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    double v = ((_c.value - 0.6) / 0.4).clamp(0.0, 1.0);
                    v = Curves.easeOutCubic.transform(v);
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - v)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSuggestionChip('Why does this happen?'),
                            _buildSuggestionChip('How can I feel better?'),
                            _buildSuggestionChip('Should I be concerned?'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Related Resources
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    double v = ((_c.value - 0.8) / 0.2).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: v,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RELATED RESOURCES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
                          const SizedBox(height: 8),
                          _buildResourceItem("Article: Managing Luteal Phase Fatigue"),
                          _buildResourceItem("Community: Tips for beating mood slumps"),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Message Composer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: BDColors.white, border: Border(top: BorderSide(color: BDColors.divider))),
            child: Row(
              children: [
                const Icon(Icons.mic_rounded, size: 20, color: BDColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: BDColors.cream, borderRadius: BorderRadius.circular(20)),
                    child: Text('Ask Sia anything...', style: GoogleFonts.inter(fontSize: 13, color: BDColors.inkLight)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: BDColors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, size: 14, color: BDColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: BDColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BDColors.red.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 14, color: BDColors.red),
            const SizedBox(width: 8),
            Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BDColors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BDColors.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: BDColors.ink))),
          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: BDColors.inkLight),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(20)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: BDColors.inkLight), SizedBox(width: 4),
          Icon(Icons.circle, size: 5, color: BDColors.inkLight), SizedBox(width: 4),
          Icon(Icons.circle, size: 5, color: BDColors.inkLight),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// 4. JOURNAL SCREEN (DIGITAL REFLECTION DIARY)
// ═══════════════════════════════════════════════
class ScrapbookItem {
  final String id;
  final String type; // 'sticker', 'photo', 'text', 'voice', 'tape'
  final dynamic content; // String for text, IconData for sticker, Gradient for photo, etc.
  Offset position;
  double scale;
  double rotation; // in radians
  int zIndex;

  ScrapbookItem({
    required this.id,
    required this.type,
    required this.content,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
  });

  ScrapbookItem copyWith({
    String? id,
    String? type,
    dynamic content,
    Offset? position,
    double? scale,
    double? rotation,
    int? zIndex,
  }) {
    return ScrapbookItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

class JournalEntry {
  final String id;
  final String title;
  final DateTime dateTime;
  final List<ScrapbookItem> items;
  final String themeName;
  final String fontName;
  final String templateName;

  JournalEntry({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.items,
    this.themeName = 'Cream Paper',
    this.fontName = 'Handwriting',
    this.templateName = 'Daily Reflection',
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    List<ScrapbookItem>? items,
    String? themeName,
    String? fontName,
    String? templateName,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      items: items ?? List.from(this.items),
      themeName: themeName ?? this.themeName,
      fontName: fontName ?? this.fontName,
      templateName: templateName ?? this.templateName,
    );
  }
}

class ScreenVoice extends StatefulWidget {
  final bool isDemoMode;
  const ScreenVoice({super.key, this.isDemoMode = false});
  @override
  State<ScreenVoice> createState() => _ScreenVoiceState();
}

class _ScreenVoiceState extends State<ScreenVoice> with TickerProviderStateMixin {
  // Notebook entries list
  final List<JournalEntry> _entries = [];
  String? _currentEntryId; // null shows the home notebook list

  // Editor states (loaded dynamically per entry)
  String _activeTheme = 'Cream Paper';
  String _activeFont = 'Handwriting';
  String _activeTemplate = 'Daily Reflection';
  String _activeToolbar = 'Stickers';

  final List<ScrapbookItem> _items = [];
  String? _selectedItemId;
  int _itemCounter = 0;
  bool _isPlayingVoice = false;

  // Speech-to-text recording overlay states
  bool _showRecordOverlay = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Cream Paper', 'bgColor': Color(0xFFFDFBF7), 'borderColor': Color(0xFFE6DFD3), 'textColor': Color(0xFF1A0F0A), 'paperPattern': true},
    {'name': 'Vintage Paper', 'bgColor': Color(0xFFF4EAD4), 'borderColor': Color(0xFFD4C5A9), 'textColor': Color(0xFF2C1E15), 'paperPattern': true},
    {'name': 'Pink Floral', 'bgColor': Color(0xFFFFF0F5), 'borderColor': Color(0xFFFBCFE8), 'textColor': Color(0xFF831843), 'paperPattern': false},
    {'name': 'Watercolor', 'bgColor': Color(0xFFE0F2FE), 'borderColor': Color(0xFFBAE6FD), 'textColor': Color(0xFF0369A1), 'paperPattern': false},
    {'name': 'Minimal White', 'bgColor': Color(0xFFFFFFFF), 'borderColor': Color(0xFFE5E7EB), 'textColor': Color(0xFF111827), 'paperPattern': false},
    {'name': 'Dark Mode', 'bgColor': Color(0xFF1F2937), 'borderColor': Color(0xFF374151), 'textColor': Color(0xFFF9FAFB), 'paperPattern': false},
  ];

  final List<String> _fonts = ['Elegant Serif', 'Handwriting', 'Modern Sans', 'Brush Script', 'Notebook'];

  final List<Map<String, dynamic>> _stickersList = [
    {'name': '🌸 Flower', 'icon': Icons.local_florist_rounded, 'color': Color(0xFFF472B6)},
    {'name': '🦋 Butterfly', 'icon': Icons.flutter_dash_rounded, 'color': Color(0xFFC084FC)},
    {'name': '🌙 Moon', 'icon': Icons.dark_mode_rounded, 'color': Color(0xFFFCD34D)},
    {'name': '⭐ Star', 'icon': Icons.star_rounded, 'color': Color(0xFFFBBF24)},
    {'name': '☕ Coffee', 'icon': Icons.coffee_rounded, 'color': Color(0xFFB45309)},
    {'name': '📚 Books', 'icon': Icons.menu_book_rounded, 'color': Color(0xFF3B82F6)},
    {'name': '🍃 Leaf', 'icon': Icons.eco_rounded, 'color': Color(0xFF10B981)},
    {'name': '❤️ Heart', 'icon': Icons.favorite_rounded, 'color': Color(0xFFEF4444)},
  ];

  final List<String> _templates = [
    'Daily Reflection',
    'Gratitude',
    'Cycle Reflection',
    'Dream Journal',
    'Weekly Check-in'
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Seed initial notebook entries
    final initialItems = [
      ScrapbookItem(id: 'washi_tape', type: 'tape', content: const Color(0xFFFBCFE8), position: const Offset(20, 16)),
      ScrapbookItem(id: 'polaroid_photo', type: 'photo', content: [Color(0xFFFBCFE8), Color(0xFFC084FC)], position: const Offset(170, 48)),
      ScrapbookItem(id: 'voice_card', type: 'voice', content: '00:24', position: const Offset(10, 180)),
      ScrapbookItem(id: 'text_box', type: 'text', content: "I cried during today's meeting.", position: const Offset(20, 120)),
      ScrapbookItem(id: 'ai_insight_box', type: 'ai_insight', content: '', position: const Offset(10, 230)),
    ];
    _entries.add(JournalEntry(
      id: 'entry_1',
      title: 'Daily Reflection',
      dateTime: DateTime.now().subtract(const Duration(hours: 4)),
      items: initialItems,
    ));

    _entries.add(JournalEntry(
      id: 'entry_2',
      title: 'Gratitude Journal',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      items: [
        ScrapbookItem(id: 'tape_g', type: 'tape', content: const Color(0xFFFEF08A), position: const Offset(20, 16)),
        ScrapbookItem(id: 'text_g', type: 'text', content: "Thankful for the warm sun and tea.", position: const Offset(30, 80)),
      ],
      templateName: 'Gratitude',
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _addItem(String id, String type, dynamic content, Offset position) {
    setState(() {
      _items.add(ScrapbookItem(
        id: id,
        type: type,
        content: content,
        position: position,
        zIndex: _itemCounter++,
      ));
      _selectedItemId = id;
    });
  }

  void _duplicateItem(ScrapbookItem item) {
    final newId = '${item.id}_copy_${_itemCounter}';
    setState(() {
      _items.add(item.copyWith(
        id: newId,
        position: item.position + const Offset(20, 20),
        zIndex: _itemCounter++,
      ));
      _selectedItemId = newId;
    });
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
      if (_selectedItemId == id) {
        _selectedItemId = null;
      }
    });
  }

  void _bringToFront(String id) {
    setState(() {
      final index = _items.indexWhere((item) => item.id == id);
      if (index != -1) {
        final item = _items.removeAt(index);
        _items.add(item.copyWith(zIndex: _itemCounter++));
      }
    });
  }

  void _sendToBack(String id) {
    setState(() {
      final index = _items.indexWhere((item) => item.id == id);
      if (index != -1) {
        final item = _items.removeAt(index);
        _items.insert(0, item);
      }
    });
  }

  TextStyle _getTextStyle(double size, {bool italic = false, Color? color}) {
    Color txtColor = color ?? _themes.firstWhere((t) => t['name'] == _activeTheme)['textColor'];
    if (_activeFont == 'Elegant Serif') {
      return GoogleFonts.playfairDisplay(fontSize: size, color: txtColor, fontWeight: FontWeight.bold, fontStyle: italic ? FontStyle.italic : FontStyle.normal);
    } else if (_activeFont == 'Handwriting') {
      return GoogleFonts.caveat(fontSize: size + 4, color: txtColor, fontWeight: FontWeight.w600);
    } else if (_activeFont == 'Brush Script') {
      return GoogleFonts.dancingScript(fontSize: size + 2, color: txtColor, fontWeight: FontWeight.bold);
    } else if (_activeFont == 'Notebook') {
      return GoogleFonts.architectsDaughter(fontSize: size - 1, color: txtColor, fontWeight: FontWeight.bold);
    } else {
      return GoogleFonts.inter(fontSize: size - 1, color: txtColor, fontWeight: FontWeight.w600);
    }
  }

  // Navigation: Loads a journal entry into editor state
  void _loadEntry(JournalEntry entry) {
    setState(() {
      _currentEntryId = entry.id;
      _activeTheme = entry.themeName;
      _activeFont = entry.fontName;
      _activeTemplate = entry.templateName;
      _items.clear();
      _items.addAll(List.from(entry.items));
      _selectedItemId = null;
      _itemCounter = _items.length;
    });
  }

  // Navigation: Saves active editor state to entries list and returns home
  void _saveAndCloseEntry() {
    if (_currentEntryId != null) {
      final index = _entries.indexWhere((e) => e.id == _currentEntryId);
      if (index != -1) {
        setState(() {
          _entries[index] = _entries[index].copyWith(
            items: List.from(_items),
            themeName: _activeTheme,
            fontName: _activeFont,
            templateName: _activeTemplate,
          );
          _currentEntryId = null;
        });
      }
    }
  }

  // Create New Options Modal
  void _showCreateOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 38, height: 4, decoration: BoxDecoration(color: BDColors.divider, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  Text('Create New Journal', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BDColors.ink)),
                  const SizedBox(height: 12),
                  _buildOptionTile(
                    icon: Icons.edit_note_rounded,
                    title: 'Write',
                    subtitle: 'Start with a blank journal page',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewEntry(title: 'Self Reflection');
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.mic_none_rounded,
                    title: 'Record & Transcribe',
                    subtitle: 'Speak and let Sia transcribe it into your journal',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _showRecordOverlay = true;
                      });
                      _startRecordingFlow();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.space_dashboard_outlined,
                    title: 'Start from Template',
                    subtitle: 'Choose a daily template starting point',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewEntry(title: 'Cycle Reflection', useTemplate: true);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.image_outlined,
                    title: 'Import Photo',
                    subtitle: 'Add a photo as a starting polaroid',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewEntry(title: 'Photo Log', hasPhoto: true);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: BDColors.cream,
        child: Icon(icon, color: BDColors.red),
      ),
      title: Text(title, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
      trailing: const Icon(Icons.chevron_right_rounded, color: BDColors.inkLight),
    );
  }

  // Create new entry utility
  void _createNewEntry({required String title, bool useTemplate = false, bool hasPhoto = false}) {
    final String newId = 'entry_${DateTime.now().millisecondsSinceEpoch}';
    final List<ScrapbookItem> itemsList = [];
    if (useTemplate) {
      itemsList.add(ScrapbookItem(id: 'tape_temp', type: 'tape', content: const Color(0xFFFEF08A), position: const Offset(20, 16)));
      itemsList.add(ScrapbookItem(id: 'text_temp', type: 'text', content: 'What made me smile today?', position: const Offset(30, 80)));
    } else if (hasPhoto) {
      itemsList.add(ScrapbookItem(id: 'photo_temp', type: 'photo', content: [Color(0xFFE0F2FE), Color(0xFF3882F6)], position: const Offset(30, 30)));
    } else {
      itemsList.add(ScrapbookItem(id: 'tape_blank', type: 'tape', content: const Color(0xFFFBCFE8), position: const Offset(20, 16)));
    }

    final newEntry = JournalEntry(
      id: newId,
      title: title,
      dateTime: DateTime.now(),
      items: itemsList,
    );

    setState(() {
      _entries.insert(0, newEntry);
    });
    _loadEntry(newEntry);
  }

  // Recording timer and states handlers
  void _startRecordingFlow() {
    setState(() {
      _isRecording = true;
      _isTranscribing = false;
      _recordingDuration = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _stopRecordingFlow() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    // Simulate Sia Transcription (2 seconds delay)
    Timer(const Duration(seconds: 2), () {
      final String transcribedText = "Today was a busy day, but I took a moment to breathe and check in with myself.";
      
      final String newId = 'entry_${DateTime.now().millisecondsSinceEpoch}';
      final newEntry = JournalEntry(
        id: newId,
        title: 'Voice Reflection',
        dateTime: DateTime.now(),
        items: [
          ScrapbookItem(id: 'tape_v', type: 'tape', content: const Color(0xFFFBCFE8), position: const Offset(20, 16)),
          ScrapbookItem(id: 'text_v', type: 'text', content: transcribedText, position: const Offset(20, 120)),
          ScrapbookItem(id: 'voice_v', type: 'voice', content: '00:08', position: const Offset(10, 180)),
        ],
      );

      setState(() {
        _entries.insert(0, newEntry);
        _showRecordOverlay = false;
        _isTranscribing = false;
      });
      _loadEntry(newEntry);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEntryId == null) {
      return _buildNotebookHome();
    }
    return _buildScrapbookEditor();
  }

  // ──────────────────────────────────────────
  // NOTEBOOK HOME (List View of previous entries)
  // ──────────────────────────────────────────
  Widget _buildNotebookHome() {
    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Journal', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BDColors.ink)),
                    const SizedBox(height: 1),
                    Text('My Wellness Notebook', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
                GestureDetector(
                  onTap: _showCreateOptionsBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BDColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BDColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded, size: 12, color: BDColors.ink),
                        const SizedBox(width: 4),
                        Text('Create New', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: BDColors.ink)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _showRecordOverlay 
                ? _buildRecordingOverlay()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      // Find first text box or template name as description preview
                      final firstText = entry.items.firstWhere(
                        (it) => it.type == 'text', 
                        orElse: () => ScrapbookItem(id: '', type: '', content: '', position: Offset.zero)
                      );
                      final String desc = firstText.content is String && firstText.content.isNotEmpty 
                          ? firstText.content as String 
                          : 'Scrapbook layout entry';
                      
                      final formattedDate = "${entry.dateTime.day} Jun • ${entry.dateTime.hour}:${entry.dateTime.minute.toString().padLeft(2, '0')}";

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _loadEntry(entry),
                          child: BlushyCard(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: BDColors.pinkBg,
                                  child: Icon(
                                    entry.templateName == 'Gratitude' 
                                        ? Icons.favorite_border_rounded 
                                        : Icons.edit_note_rounded, 
                                    color: BDColors.red
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.title, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)),
                                      const SizedBox(height: 2),
                                      Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                                      const SizedBox(height: 4),
                                      Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BDColors.inkLight),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Speech-to-text high fidelity recording page overlay
  Widget _buildRecordingOverlay() {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: BlushyCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isTranscribing ? 'SIA IS TRANSCRIBING...' : 'RECORDING VOICE NOTE', 
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: BDColors.red.withOpacity(_isRecording ? (0.1 + _pulseController.value * 0.15) : 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _isTranscribing ? Icons.autorenew_rounded : Icons.mic_rounded, 
                        color: BDColors.red, size: 36
                      ),
                    ),
                  );
                }
              ),
              const SizedBox(height: 16),
              Text(
                _isTranscribing ? 'Processing speech to English...' : '$minutes:$seconds', 
                style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)
              ),
              const SizedBox(height: 24),
              if (_isRecording)
                ElevatedButton(
                  onPressed: _stopRecordingFlow,
                  style: ElevatedButton.styleFrom(backgroundColor: BDColors.ink),
                  child: Text('Stop Recording', style: GoogleFonts.inter(fontSize: 12, color: BDColors.cream)),
                )
              else if (_isTranscribing)
                const CircularProgressIndicator(color: BDColors.red)
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // SCRAPBOOK EDITOR PAGE
  // ──────────────────────────────────────────
  Widget _buildScrapbookEditor() {
    final themeData = _themes.firstWhere((t) => t['name'] == _activeTheme);
    final bgColor = themeData['bgColor'] as Color;
    final borderColor = themeData['borderColor'] as Color;
    final textColor = themeData['textColor'] as Color;
    final paperPattern = themeData['paperPattern'] as bool;

    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: BDColors.ink),
                      onPressed: _saveAndCloseEntry,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_activeTemplate, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)),
                        const SizedBox(height: 1),
                        Text('Active Workspace', style: GoogleFonts.inter(fontSize: 11, color: BDColors.red, height: 1.3)),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _saveAndCloseEntry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BDColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Save & Close', style: GoogleFonts.inter(fontSize: 11, color: BDColors.cream, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Template Selector
          SizedBox(
            height: 28,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _templates.length,
              itemBuilder: (context, i) {
                final template = _templates[i];
                final isSelected = _activeTemplate == template;
                return GestureDetector(
                  onTap: () => setState(() => _activeTemplate = template),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? BDColors.ink : BDColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.transparent : BDColors.divider),
                    ),
                    child: Center(
                      child: Text(
                        template,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : BDColors.inkLight),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Large Scrapbook Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: BDColors.ink.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Grid/Ruled paper lines pattern
                    if (paperPattern)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PaperLinesPainter(lineColor: borderColor.withOpacity(0.4)),
                        ),
                      ),

                    // Title Header Stamp
                    Positioned(
                      top: 14, left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PAGE • ${_activeTemplate.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, color: textColor.withOpacity(0.5))),
                          const SizedBox(height: 1),
                          Text('14 Jun 2026', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                        ],
                      ),
                    ),

                    // Dynamic Scrapbook Items List
                    Positioned.fill(
                      child: Stack(
                        children: _items.map((item) => _buildDraggableItem(item)).toList(),
                      ),
                    ),

                    // Active Selected Item Toolbar Controls overlay
                    if (_selectedItemId != null) _buildItemEditToolbar(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Editor Control Panel Tray
          Container(
            height: 94,
            decoration: BoxDecoration(
              color: BDColors.white,
              border: Border(top: BorderSide(color: BDColors.divider, width: 1)),
            ),
            child: Column(
              children: [
                // Toolbar Selector Tabs
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _buildToolbarTab('Stickers', Icons.face_retouching_natural_rounded),
                        _buildToolbarTab('Photo Templates', Icons.camera_alt_rounded),
                        _buildToolbarTab('Washi Tape', Icons.linear_scale_rounded),
                        _buildToolbarTab('Fonts', Icons.font_download_rounded),
                      ],
                    ),
                  ),
                ),
                Container(height: 1, color: BDColors.divider),
                // Tool Asset Drawer corresponding to selected tab
                Expanded(
                  child: Container(
                    color: BDColors.white,
                    child: _buildActiveTray(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarTab(String label, IconData icon) {
    final isSelected = _activeToolbar == label;
    return GestureDetector(
      onTap: () => setState(() => _activeToolbar = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? BDColors.red : BDColors.inkLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: isSelected ? BDColors.red : BDColors.inkLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTray() {
    if (_activeToolbar == 'Stickers') {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _stickersList.length,
        itemBuilder: (context, i) {
          final sticker = _stickersList[i];
          return GestureDetector(
            onTap: () {
              _addItem('sticker_${_itemCounter}', 'sticker', sticker, const Offset(60, 100));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: BDColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BDColors.divider),
              ),
              child: Center(
                child: Text(
                  sticker['name'] as String,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: BDColors.ink),
                ),
              ),
            ),
          );
        },
      );
    } else if (_activeToolbar == 'Photo Templates') {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildAssetTrayCard('Blue Tint Photo', () {
            _addItem('photo_${_itemCounter}', 'photo', [Color(0xFFE0F2FE), Color(0xFF3882F6)], const Offset(60, 80));
          }),
          _buildAssetTrayCard('Pink Rose Photo', () {
            _addItem('photo_${_itemCounter}', 'photo', [Color(0xFFFFF0F5), Color(0xFFF472B6)], const Offset(60, 80));
          }),
        ],
      );
    } else if (_activeToolbar == 'Washi Tape') {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildAssetTrayCard('Pink Tape', () {
            _addItem('tape_${_itemCounter}', 'tape', const Color(0xFFFBCFE8), const Offset(50, 60));
          }),
          _buildAssetTrayCard('Yellow Tape', () {
            _addItem('tape_${_itemCounter}', 'tape', const Color(0xFFFEF08A), const Offset(50, 60));
          }),
          _buildAssetTrayCard('Mint Tape', () {
            _addItem('tape_${_itemCounter}', 'tape', const Color(0xFFA7F3D0), const Offset(50, 60));
          }),
        ],
      );
    } else if (_activeToolbar == 'Fonts') {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _fonts.length,
        itemBuilder: (context, i) {
          final fontName = _fonts[i];
          final isSelected = _activeFont == fontName;
          return GestureDetector(
            onTap: () => setState(() => _activeFont = fontName),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? BDColors.ink : BDColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BDColors.divider),
              ),
              child: Center(
                child: Text(
                  fontName,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : BDColors.ink),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return Center(
        child: Text(
          'Customize $_activeToolbar by tapping canvas items',
          style: GoogleFonts.inter(fontSize: 9, color: BDColors.inkLight, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  Widget _buildAssetTrayCard(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: BDColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BDColors.divider),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: BDColors.ink),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableItem(ScrapbookItem item) {
    final bool isSelected = _selectedItemId == item.id;
    Widget childWidget;

    switch (item.type) {
      case 'tape':
        childWidget = Opacity(
          opacity: 0.85,
          child: Container(
            width: 90 * item.scale,
            height: 18 * item.scale,
            color: item.content as Color,
            child: CustomPaint(
              painter: _TapeEdgesPainter(),
            ),
          ),
        );
        break;
      case 'photo':
        final colors = item.content as List<Color>;
        childWidget = Container(
          width: 120 * item.scale,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: BDColors.ink.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Container(
                height: 100 * item.scale,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 80 * item.scale, height: 6 * item.scale, color: BDColors.divider),
            ],
          ),
        );
        break;
      case 'sticker':
        final sticker = item.content as Map<String, dynamic>;
        childWidget = Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            sticker['icon'] as IconData,
            color: sticker['color'] as Color,
            size: 38 * item.scale,
          ),
        );
        break;
      case 'voice':
        childWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: BDColors.ink.withOpacity(0.04), blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isPlayingVoice ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: BDColors.red, size: 24),
                onPressed: () => setState(() => _isPlayingVoice = !_isPlayingVoice),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 60 * item.scale, height: 4 * item.scale, color: BDColors.red.withOpacity(0.2)),
                  const SizedBox(height: 4),
                  Text(item.content as String, style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                ],
              ),
            ],
          ),
        );
        break;
      case 'ai_insight':
        childWidget = Container(
          width: 190 * item.scale,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF), // light violet
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text('Sia Insights', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF7C3AED))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "• Mood: Low\n• Stress: High\n• Possible hormonal correlation (Day 21 Luteal)\n\nPrompt: Try writing down what specific trigger in the meeting made you feel this way.",
                style: GoogleFonts.inter(fontSize: 12, color: BDColors.ink),
              ),
            ],
          ),
        );
        break;
      case 'text':
      default:
        childWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isSelected
              ? BoxDecoration(border: Border.all(color: BDColors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(4))
              : null,
          child: Text(
            item.content as String,
            style: _getTextStyle(11 * item.scale),
          ),
        );
        break;
    }

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedItemId = item.id;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            item.position += details.delta;
            _selectedItemId = item.id;
          });
        },
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            decoration: isSelected ? BoxDecoration(
              border: Border.all(color: BDColors.red, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ) : null,
            child: childWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildItemEditToolbar() {
    final item = _items.firstWhere((it) => it.id == _selectedItemId);
    return Positioned(
      bottom: 12, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: BDColors.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.flip_to_front_rounded, color: Colors.white, size: 14),
              onPressed: () => _bringToFront(item.id),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_to_back_rounded, color: Colors.white, size: 14),
              onPressed: () => _sendToBack(item.id),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
              onPressed: () => setState(() => item.scale = (item.scale + 0.15).clamp(0.5, 2.5)),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 14),
              onPressed: () => setState(() => item.scale = (item.scale - 0.15).clamp(0.5, 2.5)),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 14),
              onPressed: () => setState(() => item.rotation += 0.26),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
              onPressed: () => _duplicateItem(item),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 14),
              onPressed: () => _deleteItem(item.id),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              onPressed: () => setState(() => _selectedItemId = null),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperLinesPainter extends CustomPainter {
  final Color lineColor;
  _PaperLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    double y = 48.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 24.0;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLinesPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}


// ═══════════════════════════════════════════════
// 5. PARTNER SCREEN (SHARED ECOSYSTEM & SANDBOX)
// ═══════════════════════════════════════════════
class FlowerSticker {
  final String type;
  Offset position;
  double scale;
  double rotation;
  bool isFlipped;
  int zIndex;

  FlowerSticker({
    required this.type,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isFlipped = false,
    this.zIndex = 0,
  });

  FlowerSticker copyWith({
    String? type,
    Offset? position,
    double? scale,
    double? rotation,
    bool? isFlipped,
    int? zIndex,
  }) {
    return FlowerSticker(
      type: type ?? this.type,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isFlipped: isFlipped ?? this.isFlipped,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

class ScreenPartner extends StatefulWidget {
  final int initialView; // 0: Woman's App, 1: Partner's App
  final bool isDemoMode;
  const ScreenPartner({super.key, this.initialView = 0, this.isDemoMode = false});

  @override
  State<ScreenPartner> createState() => _ScreenPartnerState();
}

class _ScreenPartnerState extends State<ScreenPartner> with SingleTickerProviderStateMixin {
  static bool isArgumentMode = false;
  static String letterText = "Thinking of you today. Remember to rest.";
  static String letterSender = "Love, Aarav";
  static List<String> receivedFlowers = ['Sunflower', 'Tulip', 'Rose', 'Lavender'];
  static List<FlowerSticker> sharedBouquet = [
    FlowerSticker(type: 'Rose', position: const Offset(80, 100), scale: 1.0, rotation: 0.0, zIndex: 0),
    FlowerSticker(type: 'Tulip', position: const Offset(140, 80), scale: 1.0, rotation: 0.2, zIndex: 1),
    FlowerSticker(type: 'Sunflower', position: const Offset(110, 120), scale: 1.1, rotation: -0.15, zIndex: 2),
  ];
  static List<Offset> drawingPoints = [
    const Offset(100, 110), const Offset(110, 100), const Offset(120, 110),
    const Offset(130, 130), const Offset(120, 150), const Offset(110, 160),
    const Offset(100, 170), const Offset(90, 160), const Offset(80, 150),
    const Offset(70, 130), const Offset(80, 110), const Offset(90, 100),
  ];

  late int _currentView; 
  String? _overlayMode; // null, 'canvas', 'letter', 'bouquet', 'cupid'

  // Canvas drawing state
  List<Offset> _localPoints = [];
  
  // Bouquet Builder state
  int _bouquetStep = 0; // 0: Pick Blooms, 1: Choose Greenery, 2: Write Card
  int? _selectedBouquetStickerIndex;
  String _activeBouquetTab = 'Flowers';

  void _addBouquetSticker(String type) {
    setState(() {
      sharedBouquet.add(FlowerSticker(
        type: type,
        position: const Offset(90, 80),
        scale: 1.0,
        rotation: 0.0,
        zIndex: sharedBouquet.length,
      ));
      _selectedBouquetStickerIndex = sharedBouquet.length - 1;
    });
  }

  void _duplicateBouquetSticker(int index) {
    final sticker = sharedBouquet[index];
    setState(() {
      sharedBouquet.add(sticker.copyWith(
        position: sticker.position + const Offset(15, 15),
        zIndex: sharedBouquet.length,
      ));
      _selectedBouquetStickerIndex = sharedBouquet.length - 1;
    });
  }

  void _bringBouquetStickerToFront(int index) {
    final sticker = sharedBouquet[index];
    setState(() {
      sharedBouquet.removeAt(index);
      sharedBouquet.add(sticker.copyWith(zIndex: sharedBouquet.length));
      _selectedBouquetStickerIndex = sharedBouquet.length - 1;
    });
  }

  void _sendBouquetStickerToBack(int index) {
    final sticker = sharedBouquet[index];
    setState(() {
      sharedBouquet.removeAt(index);
      sharedBouquet.insert(0, sticker);
      _selectedBouquetStickerIndex = 0;
    });
  }

  // Write Letter state
  final TextEditingController _letterController = TextEditingController(text: "Hope you have a beautiful day. Rest well!");

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
    _localPoints = List.from(drawingPoints);
  }

  @override
  Widget build(BuildContext context) {
    if (_overlayMode == 'canvas') return _buildCanvasOverlay();
    if (_overlayMode == 'letter') return _buildLetterOverlay();
    if (_overlayMode == 'bouquet') return _buildBouquetOverlay();
    if (_overlayMode == 'cupid') return _buildCupidOverlay();

    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          // Header / Segmented View Toggle
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: BDColors.divider)),
              child: Row(
                children: [
                  Expanded(child: _buildViewSegment('Taara\'s App', 0)),
                  Expanded(child: _buildViewSegment('Aarav\'s App', 1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _currentView == 0 ? _buildWomansView() : _buildPartnersView(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSegment(String label, int val) {
    final bool active = _currentView == val;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentView = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? BDColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: active ? BDColors.cream : BDColors.inkLight)),
      ),
    );
  }

  // ──────────────────────────────────────────
  // WOMAN'S APP VIEW
  // ──────────────────────────────────────────
  Widget _buildWomansView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Shared space status banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
          child: Row(
            children: [
              const Icon(Icons.spa_outlined, size: 20, color: BDColors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared Space Active', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                    Text('Connected with Aarav', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
              ),
              const Icon(Icons.favorite_rounded, size: 16, color: BDColors.red),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Cycle Progress Ring
        GestureDetector(
          onTap: () => setState(() => _overlayMode = 'cupid'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BDColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BDColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: BDColors.red.withOpacity(0.1),
                  child: const Icon(Icons.favorite_border_rounded, color: BDColors.red, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cupid Messenger', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                      const SizedBox(height: 2),
                      Text('Open direct chat with Aarav', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BDColors.inkLight),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Toggle Argument Mode
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isArgumentMode ? BDColors.red.withOpacity(0.3) : BDColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, size: 20, color: BDColors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Argument Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.ink)),
                    Text(isArgumentMode ? 'Partner receives limited data' : 'Hide cycle details during conflicts', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isArgumentMode,
                onChanged: (val) => setState(() => isArgumentMode = val),
                activeColor: BDColors.red,
              )
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Shared Letters
        GestureDetector(
          onTap: () => setState(() => _overlayMode = 'letter'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, size: 20, color: BDColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shared Letters', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                      Text('Read and write notes', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BDColors.inkLight),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Drawing Canvas
        GestureDetector(
          onTap: () => setState(() => _overlayMode = 'canvas'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
            child: Row(
              children: [
                const Icon(Icons.brush_outlined, size: 20, color: BDColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shared Canvas', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                      Text('Doodle together in real time', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BDColors.inkLight),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bouquet
        GestureDetector(
          onTap: () => setState(() => _overlayMode = 'bouquet'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
            child: Row(
              children: [
                const Icon(Icons.filter_vintage_outlined, size: 20, color: BDColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bouquet Received', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                      Text(receivedFlowers.isEmpty ? 'No bouquets yet' : 'Tap to build & send back', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BDColors.inkLight),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ──────────────────────────────────────────
  // PARTNER'S APP VIEW
  // ──────────────────────────────────────────
  Widget _buildPartnersView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Her Cycle Progress Ring
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
          child: Row(
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CustomPaint(
                  painter: _CycleRingPainter(progress: 19 / 28),
                  child: Center(
                    child: Text('19', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: BDColors.red)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Taara\'s Cycle', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                    Text(isArgumentMode ? 'Cycle details restricted' : 'Luteal Phase • Expected in 9 days', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Wellness Status & Support suggestions
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isArgumentMode ? _buildPartnerArgModeStatus() : _buildPartnerNormalStatus(),
        ),
        const SizedBox(height: 12),

        // Quick Actions Header
        Text('ACTIONS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
        const SizedBox(height: 8),

        // Cupid Phase Decoder Card
        _buildActionButton(Icons.favorite_border_rounded, 'Cupid Messenger', 'Direct messaging with Sia decoder', () => setState(() => _overlayMode = 'cupid')),
        const SizedBox(height: 10),

        // Draw together
        _buildActionButton(Icons.brush_rounded, 'Draw Together', 'Open Shared Canvas', () => setState(() => _overlayMode = 'canvas')),
        const SizedBox(height: 10),

        // Write letter
        _buildActionButton(Icons.create_rounded, 'Write Letter', 'Send a custom note', () => setState(() => _overlayMode = 'letter')),
        const SizedBox(height: 10),

        // Build Bouquet
        _buildActionButton(Icons.local_florist_rounded, 'Build Bouquet', 'Send virtual flowers', () => setState(() => _overlayMode = 'bouquet')),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPartnerNormalStatus() {
    if (widget.isDemoMode) {
      return Container(
        key: const ValueKey("normal_status"),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY\'S WELLNESS STATUS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
            const SizedBox(height: 8),
            Text('• Energy is lower today • Luteal Phase', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
            const SizedBox(height: 8),
            Text('• She may appreciate emotional support.\n• Suggested conversation starter: "How was your meeting today? I\'m here if you want to vent."\n• Avoid planning stressful activities today.\n• Today\'s care suggestion: Bring her some hot chamomile tea.', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BDColors.cream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, size: 10, color: BDColors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('This information is only shared with Taara\'s consent.', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey("normal_status"),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY\'S WELLNESS STATUS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
          const SizedBox(height: 8),
          Text('She is in her Luteal Phase and may feel exhausted or emotional.', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
          const SizedBox(height: 8),
          Text('Suggested: Bring her a hot cup of tea or help around with chores today.', style: GoogleFonts.inter(fontSize: 11, color: BDColors.red, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildPartnerArgModeStatus() {
    return Container(
      key: const ValueKey("arg_status"),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.red.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 12, color: BDColors.red),
              const SizedBox(width: 6),
              Text('WELLNESS STATUS (PRIVACY ON)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Needs space today.', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
          const SizedBox(height: 4),
          Text('Suggested support: Give her time and space for herself.', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, String desc, VoidCallback tap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: BDColors.pinkBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: BDColors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                  Text(desc, style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BDColors.inkLight),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // CUPID MESSENGER / DECODER OVERLAY
  // ──────────────────────────────────────────
  Widget _buildCupidOverlay() {
    final bool isAarav = _currentView == 1; // 1 is Aarav (Partner), 0 is Taara (Woman)

    return Container(
      color: BDColors.cream, // Blushy Cream Background
      child: Column(
        children: [
          // Blushy Style Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _overlayMode = null),
                  icon: const Icon(Icons.arrow_back_rounded, color: BDColors.ink),
                ),
                const SizedBox(width: 4),
                // Avatar circle
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isAarav ? BDColors.red.withOpacity(0.1) : BDColors.ink.withOpacity(0.1),
                  child: Text(
                    isAarav ? 'T' : 'A',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isAarav ? BDColors.red : BDColors.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAarav ? 'Taara' : 'Aarav',
                      style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3),
                    ),
                    Text(
                      isAarav ? 'Luteal Phase • Day 22' : 'Active now',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isAarav ? BDColors.red : BDColors.inkLight,
                        fontWeight: isAarav ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.videocam_outlined, color: BDColors.ink, size: 22),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.phone_outlined, color: BDColors.ink, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: BDColors.divider),

          // Message Stream
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              children: [
                // 1. Her Message
                _chatRow(
                  isLeft: isAarav,
                  senderName: 'Taara',
                  text: 'I\'m okay, just a bit tired today. You don\'t need to come over.',
                  decodeTitle: 'Sia Translation (Luteal Phase - Day 22)',
                  decodeText: 'She says you don\'t need to come, but she is feeling emotionally overwhelmed and would love your company.',
                  decodeTip: 'Tip: Go over anyway. Bring comfort food or a hot tea.',
                  showDecode: isAarav,
                ),

                // 2. His Message
                _chatRow(
                  isLeft: !isAarav,
                  senderName: 'Aarav',
                  text: 'Are you sure? I can stop by and bring that soup you like.',
                  showDecode: false,
                ),

                // 3. Her Message 2
                _chatRow(
                  isLeft: isAarav,
                  senderName: 'Taara',
                  text: 'No it\'s fine, seriously, don\'t worry.',
                  decodeTitle: 'Sia Translation (Luteal Phase - Day 22)',
                  decodeText: 'She is exhausted and doesn\'t want to feel like a burden, but she really needs physical reassurance.',
                  decodeTip: 'Tip: Don\'t ask again. Send a message saying you\'re already on the way.',
                  showDecode: isAarav,
                ),

                // 4. His Message 2
                _chatRow(
                  isLeft: !isAarav,
                  senderName: 'Aarav',
                  text: 'Already on my way with the soup! See you in 15 mins.',
                  showDecode: false,
                ),
              ],
            ),
          ),

          // Message Composer (Blushy Themed Capsule)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: BDColors.white,
              border: Border(top: BorderSide(color: BDColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: BDColors.cream,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: BDColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mic_none_rounded, color: BDColors.inkLight, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Type comfort response...',
                            style: GoogleFonts.inter(fontSize: 13, color: BDColors.inkLight),
                          ),
                        ),
                        const Icon(Icons.image_outlined, color: BDColors.inkLight, size: 20),
                        const SizedBox(width: 10),
                        const Icon(Icons.favorite_border_rounded, color: BDColors.red, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatRow({
    required bool isLeft,
    required String senderName,
    required String text,
    String? decodeTitle,
    String? decodeText,
    String? decodeTip,
    required bool showDecode,
  }) {
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isLeft ? BDColors.white : BDColors.ink,
              border: isLeft ? Border.all(color: BDColors.divider) : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12.5, color: isLeft ? BDColors.ink : BDColors.white, height: 1.3),
            ),
          ),
          if (showDecode && decodeText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BDColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BDColors.red.withOpacity(0.28), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: BDColors.red.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 10, color: BDColors.red),
                        const SizedBox(width: 4),
                        Text(
                          decodeTitle ?? 'Sia Translation',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      decodeText,
                      style: GoogleFonts.inter(fontSize: 9, color: BDColors.ink, height: 1.3),
                    ),
                    if (decodeTip != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        decodeTip,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (!showDecode) const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // SHARED CANVAS OVERLAY
  // ──────────────────────────────────────────
  Widget _buildCanvasOverlay() {
    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          // Overlay header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => _overlayMode = null), icon: const Icon(Icons.close)),
                const SizedBox(width: 8),
                Text('Shared Canvas', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BDColors.ink)),
                const Spacer(),
                TextButton(onPressed: () => setState(() => _localPoints.clear()), child: Text('Clear', style: GoogleFonts.inter(color: BDColors.red))),
              ],
            ),
          ),

          // Canvas Box
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: BDColors.divider)),
              child: GestureDetector(
                onPanUpdate: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  setState(() {
                    _localPoints.add(Offset(localPos.dx.clamp(0, 240), localPos.dy.clamp(0, 300)));
                    drawingPoints = List.from(_localPoints);
                  });
                },
                child: CustomPaint(
                  painter: _CanvasPainter(points: _localPoints),
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 12, left: 12,
                        child: Text('Draw together with Aarav', style: GoogleFonts.inter(fontSize: 12, color: BDColors.inkLight)),
                      ),
                      Positioned(
                        top: 140, left: 160,
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, size: 12, color: BDColors.orange),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: BDColors.orange, borderRadius: BorderRadius.circular(8)),
                              child: Text('Aarav drawing...', style: GoogleFonts.inter(fontSize: 8, color: BDColors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tools row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: const BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildColorTool(Colors.black),
                _buildColorTool(BDColors.red),
                _buildColorTool(BDColors.orange),
                _buildBrushTool(3.0),
                _buildBrushTool(6.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorTool(Color color) {
    return Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
  Widget _buildBrushTool(double size) {
    return Icon(Icons.circle, size: size * 2, color: BDColors.inkLight);
  }

  // ──────────────────────────────────────────
  // LETTER OVERLAY
  // ──────────────────────────────────────────
  Widget _buildLetterOverlay() {
    return Container(
      color: BDColors.cream,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _overlayMode = null), icon: const Icon(Icons.close)),
              const Spacer(),
              Text('Handwritten Letter', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BDColors.ink)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BDColors.divider),
                boxShadow: [BoxShadow(color: BDColors.ink.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SHARED LETTER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
                      const Icon(Icons.verified_user_outlined, size: 16, color: BDColors.inkLight),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Text(
                      letterText,
                      style: GoogleFonts.caveat(fontSize: 22, height: 1.4, color: BDColors.ink),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(letterSender, style: GoogleFonts.caveat(fontSize: 20, color: BDColors.inkLight)),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B0000), 
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: const Center(child: Icon(Icons.favorite_rounded, size: 14, color: BDColors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Write letter Composer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BDColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: BDColors.divider)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _letterController,
                    decoration: InputDecoration(hintText: 'Write a warm note...', border: InputBorder.none, hintStyle: GoogleFonts.inter(fontSize: 12)),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      letterText = _letterController.text;
                      letterSender = "Love, Aarav";
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Letter delivered digitially!')));
                      _overlayMode = null;
                    });
                  },
                  child: Text('Send', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: BDColors.red)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // BOUQUET BUILDER OVERLAY
  // ──────────────────────────────────────────
  Widget _buildBouquetOverlay() {
    Widget body;
    if (_bouquetStep == 0 || _bouquetStep == 1) {
      body = _buildVaseBuilder();
    } else if (_bouquetStep == 2) {
      body = _buildCardStep();
    } else {
      body = _buildBouquetSuccess();
    }

    return Container(
      color: BDColors.cream,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _overlayMode = null;
                      _bouquetStep = 0;
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 8),
                Text('Build a Bouquet', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BDColors.ink)),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildVaseBuilder() {
    return Column(
      children: [
        // Tabs
        Container(
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildBouquetTabBtn('Flowers'),
                _buildBouquetTabBtn('Greenery'),
                _buildBouquetTabBtn('Baby\'s Breath'),
                _buildBouquetTabBtn('Branches'),
                _buildBouquetTabBtn('Wrapping/Ribbon'),
                _buildBouquetTabBtn('Accessories'),
              ],
            ),
          ),
        ),

        // Asset selector tray
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: _buildBouquetAssetTray(),
        ),

        // Main Bouquet Design Canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: BDColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BDColors.divider),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  // Circular Yellow Backdrop (For organic layout reference)
                  Positioned(
                    top: 40, left: 30, right: 30, bottom: 40,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFFBEB).withOpacity(0.55),
                        ),
                      ),
                    ),
                  ),

                  // Placed flowers / greenery / elements in zIndex order
                  ...(() {
                    final sortedList = sharedBouquet.asMap().entries.toList();
                    sortedList.sort((a, b) => a.value.zIndex.compareTo(b.value.zIndex));
                    return sortedList.map((entry) {
                      final int originalIndex = entry.key;
                      final sticker = entry.value;
                      final bool isSelected = _selectedBouquetStickerIndex == originalIndex;

                      return Positioned(
                        left: sticker.position.dx,
                        top: sticker.position.dy,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedBouquetStickerIndex = originalIndex;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              sticker.position += details.delta;
                              _selectedBouquetStickerIndex = originalIndex;
                            });
                          },
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(sticker.rotation)
                              ..scale(sticker.isFlipped ? -sticker.scale : sticker.scale, sticker.scale),
                            child: Container(
                              decoration: isSelected ? BoxDecoration(
                                border: Border.all(color: BDColors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ) : null,
                              child: FlowerStickerWidget(type: sticker.type),
                            ),
                          ),
                        ),
                      );
                    });
                  })(),

                  // Floating Edit Toolbar for Selected Bouquet Item
                  if (_selectedBouquetStickerIndex != null && _selectedBouquetStickerIndex! < sharedBouquet.length)
                    _buildBouquetStickerEditToolbar(),
                ],
              ),
            ),
          ),
        ),

        // Step transition button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: GestureDetector(
            onTap: () {
              if (sharedBouquet.isNotEmpty) {
                setState(() {
                  _bouquetStep = 2; // Go straight to card step
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(999)),
              alignment: Alignment.center,
              child: Text('Next: Write Card', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BDColors.cream)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBouquetTabBtn(String tabName) {
    final bool active = _activeBouquetTab == tabName;
    return GestureDetector(
      onTap: () => setState(() => _activeBouquetTab = tabName),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: active ? BDColors.ink : BDColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.transparent : BDColors.divider),
        ),
        child: Text(
          tabName,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: active ? Colors.white : BDColors.inkLight),
        ),
      ),
    );
  }

  Widget _buildBouquetAssetTray() {
    List<String> assets = [];
    if (_activeBouquetTab == 'Flowers') {
      assets = ['Rose', 'Tulip', 'Sunflower', 'Lavender'];
    } else if (_activeBouquetTab == 'Greenery') {
      assets = ['Eucalyptus', 'Green Leaf'];
    } else if (_activeBouquetTab == 'Baby\'s Breath') {
      assets = ['Babys Breath'];
    } else if (_activeBouquetTab == 'Branches') {
      assets = ['Branch'];
    } else if (_activeBouquetTab == 'Wrapping/Ribbon') {
      assets = ['Wrapping', 'Ribbon'];
    } else {
      assets = ['Butterfly', 'Sparkles'];
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: assets.length,
      itemBuilder: (context, i) {
        final asset = assets[i];
        return GestureDetector(
          onTap: () => _addBouquetSticker(asset),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: BDColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BDColors.divider),
            ),
            child: Center(
              child: Text(
                asset,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BDColors.red),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBouquetStickerEditToolbar() {
    final int index = _selectedBouquetStickerIndex!;
    final sticker = sharedBouquet[index];

    return Positioned(
      bottom: 8, left: 12, right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BDColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // z-ordering controls
            IconButton(
              icon: const Icon(Icons.flip_to_front_rounded, color: Colors.white, size: 13),
              onPressed: () => _bringBouquetStickerToFront(index),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_to_back_rounded, color: Colors.white, size: 13),
              onPressed: () => _sendBouquetStickerToBack(index),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Scaling controls
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
              onPressed: () => setState(() => sticker.scale = (sticker.scale + 0.15).clamp(0.5, 2.5)),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 13),
              onPressed: () => setState(() => sticker.scale = (sticker.scale - 0.15).clamp(0.5, 2.5)),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Rotation controls
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 13),
              onPressed: () => setState(() => sticker.rotation += 0.26),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Horizontal Flip
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 13),
              onPressed: () => setState(() => sticker.isFlipped = !sticker.isFlipped),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Duplicate
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 13),
              onPressed: () => _duplicateBouquetSticker(index),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 13),
              onPressed: () {
                setState(() {
                  sharedBouquet.removeAt(index);
                  _selectedBouquetStickerIndex = null;
                });
              },
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            // Close selection
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
              onPressed: () => setState(() => _selectedBouquetStickerIndex = null),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text(
            "Step 3: Write the Card",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BDColors.red),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BDColors.divider),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dear Taara,', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
              const SizedBox(height: 12),
              TextField(
                controller: _letterController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write something sweet...',
                  border: InputBorder.none,
                ),
                style: GoogleFonts.caveat(fontSize: 20, color: BDColors.ink),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Sincerely, Aarav', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BDColors.inkLight)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            setState(() {
              letterText = _letterController.text;
              letterSender = "Sincerely, Aarav";
              _bouquetStep = 3;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: BDColors.ink, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: Text('Send Bouquet', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: BDColors.cream)),
          ),
        ),
      ],
    );
  }

  Widget _buildBouquetSuccess() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Arranged Bouquet Cluster
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BDColors.divider),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  top: 20, left: 30, right: 30, bottom: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFDF5E6).withOpacity(0.6),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: (() {
                        final sortedList = List<FlowerSticker>.from(sharedBouquet);
                        sortedList.sort((a, b) {
                          final aIsGreen = (a.type == 'Eucalyptus' || a.type == 'Green Leaf') ? 0 : 1;
                          final bIsGreen = (b.type == 'Eucalyptus' || b.type == 'Green Leaf') ? 0 : 1;
                          return aIsGreen.compareTo(bIsGreen);
                        });
                        return sortedList.map((sticker) => Positioned(
                          left: sticker.position.dx,
                          top: sticker.position.dy - 10,
                          child: FlowerStickerWidget(type: sticker.type),
                        )).toList();
                      })(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Envelope Card Mockup Below Bouquet
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BDColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dear Taara,', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
              const SizedBox(height: 8),
              Text(letterText, style: GoogleFonts.caveat(fontSize: 20, color: BDColors.ink)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Sincerely, Aarav', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: BDColors.inkLight)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        TextButton(
          onPressed: () => setState(() {
            _overlayMode = null;
            _bouquetStep = 0;
          }),
          child: Text('Back to Partner Space', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: BDColors.red)),
        )
      ],
    );
  }
}

// ──────────────────────────────────────────
// HELPER DRAW PAINTERS
// ──────────────────────────────────────────
class _CycleRingPainter extends CustomPainter {
  final double progress;
  _CycleRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = BDColors.divider..style = PaintingStyle.stroke..strokeWidth = 6);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2, 2 * math.pi * progress, false,
      Paint()..color = BDColors.red..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
    );
  }
  @override bool shouldRepaint(_CycleRingPainter old) => old.progress != progress;
}

class _CanvasPainter extends CustomPainter {
  final List<Offset> points;
  _CanvasPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BDColors.red
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }
  @override bool shouldRepaint(_CanvasPainter old) => old.points != points;
}

// ──────────────────────────────────────────
// SETTINGS SCREEN (MULTILINGUAL LOCALIZATION)
// ──────────────────────────────────────────
class ScreenIndia extends StatelessWidget {
  const ScreenIndia({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BDColors.cream,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SETTINGS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: BDColors.inkLight)),
                  const SizedBox(height: 4),
                  Text('Accessibility', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BDColors.ink)),
                ],
              ),
              const Icon(Icons.accessibility_new_rounded, size: 20, color: BDColors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Setting item: General
          _buildCollapsedSection('General'),
          const SizedBox(height: 12),

          // Setting item: Language (Expanded & Highlighted)
          Container(
            decoration: BoxDecoration(
              color: BDColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BDColors.red.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: BDColors.red.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 18, color: BDColors.red),
                      const SizedBox(width: 10),
                      Text('Language', style: GoogleFonts.playfairDisplay(fontSize: 13, fontWeight: FontWeight.w700, color: BDColors.ink, height: 1.3)),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: BDColors.inkLight),
                    ],
                  ),
                ),
                const Divider(height: 1, color: BDColors.divider),
                _buildLanguageItem('English', true),
                _buildLanguageItem('हिन्दी (Hindi)', false),
                _buildLanguageItem('తెలుగు (Telugu)', false),
                _buildLanguageItem('தமிழ் (Tamil)', false),
                _buildLanguageItem('ಕನ್ನಡ (Kannada)', false),
                _buildLanguageItem('മലയാളം (Malayalam)', false),
                _buildLanguageItem('मराठी (Marathi)', false),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCollapsedSection(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BDColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BDColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: BDColors.ink)),
          const Icon(Icons.keyboard_arrow_right_rounded, size: 18, color: BDColors.inkLight),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(String language, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(language, style: GoogleFonts.inter(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? BDColors.red : BDColors.ink)),
          if (selected) const Icon(Icons.check_rounded, size: 14, color: BDColors.red),
        ],
      ),
    );
  }
}

class FlowerStickerWidget extends StatelessWidget {
  final String type;
  const FlowerStickerWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 130,
      child: CustomPaint(
        painter: _WatercolorFlowerPainter(type: type),
      ),
    );
  }
}

class _WatercolorFlowerPainter extends CustomPainter {
  final String type;
  _WatercolorFlowerPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 3.5);

    // Realistic ink sketch paint
    final inkPaint = Paint()
      ..color = const Color(0xFF2C2523)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stemPaint = Paint()
      ..color = const Color(0xFF3B4434)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (type == 'Rose') {
      // 1. Organic stem
      final stemPath = Path()
        ..moveTo(w / 2, h)
        ..quadraticBezierTo(w / 2 - 6, h * 0.7, w / 2 - 2, h * 0.4)
        ..lineTo(w / 2, h / 3.5);
      canvas.drawPath(stemPath, stemPaint);

      // Thorns
      canvas.drawPath(Path()..moveTo(w / 2 - 4, h * 0.75)..lineTo(w / 2 - 9, h * 0.73), inkPaint);
      canvas.drawPath(Path()..moveTo(w / 2 - 1, h * 0.60)..lineTo(w / 2 + 4, h * 0.58), inkPaint);

      // 2. Leaf wash & sketch
      final leafWash = Paint()..color = const Color(0xFF556B2F).withOpacity(0.55)..style = PaintingStyle.fill;
      final leftLeaf = Path()
        ..moveTo(w / 2 - 3, h * 0.65)
        ..cubicTo(w / 2 - 18, h * 0.60, w / 2 - 25, h * 0.68, w / 2 - 28, h * 0.64)
        ..cubicTo(w / 2 - 20, h * 0.72, w / 2 - 10, h * 0.70, w / 2 - 3, h * 0.65);
      canvas.drawPath(leftLeaf, leafWash);
      canvas.drawPath(leftLeaf, inkPaint);

      final rightLeaf = Path()
        ..moveTo(w / 2 + 1, h * 0.52)
        ..cubicTo(w / 2 + 15, h * 0.46, w / 2 + 22, h * 0.54, w / 2 + 26, h * 0.50)
        ..cubicTo(w / 2 + 18, h * 0.58, w / 2 + 8, h * 0.56, w / 2 + 1, h * 0.52);
      canvas.drawPath(rightLeaf, leafWash);
      canvas.drawPath(rightLeaf, inkPaint);

      // 3. Rose Head Watercolor Wash (Blotchy & slightly offset)
      final roseWash = Paint()..color = const Color(0xFFE25B6E).withOpacity(0.6)..style = PaintingStyle.fill;
      canvas.drawCircle(center + const Offset(-4, 2), 17, roseWash);
      canvas.drawCircle(center + const Offset(5, -4), 14, roseWash);
      canvas.drawCircle(center + const Offset(2, 6), 15, roseWash);

      // 4. Detailed overlapping petal outlines
      canvas.drawCircle(center, 7, inkPaint);
      
      // Outer petals
      final p1 = Path()..moveTo(center.dx - 6, center.dy - 6)..quadraticBezierTo(center.dx - 18, center.dy - 12, center.dx - 14, center.dy + 8)..quadraticBezierTo(center.dx - 4, center.dy + 16, center.dx, center.dy + 7);
      canvas.drawPath(p1, inkPaint);

      final p2 = Path()..moveTo(center.dx + 6, center.dy - 6)..quadraticBezierTo(center.dx + 18, center.dy - 14, center.dx + 16, center.dy + 8)..quadraticBezierTo(center.dx + 4, center.dy + 17, center.dx - 3, center.dy + 8);
      canvas.drawPath(p2, inkPaint);

      final p3 = Path()..moveTo(center.dx - 12, center.dy - 10)..quadraticBezierTo(center.dx, center.dy - 24, center.dx + 12, center.dy - 12);
      canvas.drawPath(p3, inkPaint);

      final p4 = Path()..moveTo(center.dx - 15, center.dy + 5)..quadraticBezierTo(center.dx, center.dy + 22, center.dx + 15, center.dy + 5);
      canvas.drawPath(p4, inkPaint);

    } else if (type == 'Tulip') {
      final stemPath = Path()
        ..moveTo(w / 2, h)
        ..quadraticBezierTo(w / 2 + 4, h * 0.65, w / 2, h / 3.5);
      canvas.drawPath(stemPath, stemPaint);

      // Leaf Wash & Outline (curved, elegant, pointed leaf)
      final leafWash = Paint()..color = const Color(0xFF4F5E3D).withOpacity(0.5)..style = PaintingStyle.fill;
      final leafPath = Path()
        ..moveTo(w / 2, h * 0.82)
        ..cubicTo(w / 2 - 20, h * 0.58, w / 2 - 18, h * 0.42, w / 2 - 10, h * 0.38)
        ..cubicTo(w / 2 - 10, h * 0.58, w / 2 - 5, h * 0.70, w / 2, h * 0.82);
      canvas.drawPath(leafPath, leafWash);
      canvas.drawPath(leafPath, inkPaint);

      // Tulip Head Watercolor Wash
      final tulipWash = Paint()..color = const Color(0xFFF392B7).withOpacity(0.65)..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromCenter(center: center + const Offset(0, -2), width: 24, height: 30), tulipWash);

      // Sketchy Cup Petals
      final centerPetal = Path()
        ..moveTo(center.dx - 10, center.dy + 12)
        ..cubicTo(center.dx - 14, center.dy - 14, center.dx + 14, center.dy - 14, center.dx + 10, center.dy + 12)
        ..quadraticBezierTo(center.dx, center.dy + 16, center.dx - 10, center.dy + 12);
      canvas.drawPath(centerPetal, inkPaint);

      // Left petal overlay
      canvas.drawPath(Path()..moveTo(center.dx - 9, center.dy + 10)..cubicTo(center.dx - 16, center.dy - 6, center.dx - 2, center.dy - 10, center.dx + 2, center.dy + 4), inkPaint);
      // Right petal overlay
      canvas.drawPath(Path()..moveTo(center.dx + 9, center.dy + 10)..cubicTo(center.dx + 16, center.dy - 6, center.dx + 2, center.dy - 10, center.dx - 2, center.dy + 4), inkPaint);

    } else if (type == 'Sunflower') {
      canvas.drawLine(Offset(w / 2, h), center, stemPaint);

      // 14 Pointed radiating petals
      final petalWash = Paint()..color = const Color(0xFFFBBF24).withOpacity(0.68)..style = PaintingStyle.fill;
      final petalPath = Path();
      
      for (int i = 0; i < 14; i++) {
        final double angle = (i * 2 * math.pi) / 14;
        final double rx = center.dx + math.cos(angle) * 23;
        final double ry = center.dy + math.sin(angle) * 23;
        final double leftAngle = angle - 0.2;
        final double lx = center.dx + math.cos(leftAngle) * 12;
        final double ly = center.dy + math.sin(leftAngle) * 12;
        final double rightAngle = angle + 0.2;
        final double rx2 = center.dx + math.cos(rightAngle) * 12;
        final double ry2 = center.dy + math.sin(rightAngle) * 12;

        petalPath.moveTo(lx, ly);
        petalPath.quadraticBezierTo(rx, ry, rx2, ry2);
      }
      canvas.drawPath(petalPath, petalWash);
      canvas.drawPath(petalPath, inkPaint);

      // Center brown disc wash
      canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF6B4226).withOpacity(0.75)..style = PaintingStyle.fill);
      canvas.drawCircle(center, 11, inkPaint);
      // Center Seed texture grid
      final seedPaint = Paint()..color = const Color(0xFF3C2012)..style = PaintingStyle.fill;
      for (int i = 0; i < 8; i++) {
        final double angle = (i * 2 * math.pi) / 8;
        canvas.drawCircle(Offset(center.dx + math.cos(angle) * 6, center.dy + math.sin(angle) * 6), 1.2, seedPaint);
      }
      canvas.drawCircle(center, 3, seedPaint);
    } else if (type == 'Branch') {
      final branchPaint = Paint()..color = const Color(0xFF78350F)..strokeWidth = 2.0..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w / 2, h), Offset(w / 2 - 12, h / 3), branchPaint);
      canvas.drawLine(Offset(w / 2 - 8, h * 0.6), Offset(w / 2 + 10, h * 0.45), branchPaint);
    } else if (type == 'Ribbon') {
      final ribbonWash = Paint()..color = const Color(0xFFFDA4AF).withOpacity(0.85)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w / 2 - 10, h / 2), 12, ribbonWash);
      canvas.drawCircle(Offset(w / 2 + 10, h / 2), 12, ribbonWash);
      canvas.drawCircle(Offset(w / 2 - 10, h / 2), 12, inkPaint);
      canvas.drawCircle(Offset(w / 2 + 10, h / 2), 12, inkPaint);
    } else if (type == 'Wrapping') {
      final wrappingWash = Paint()..color = const Color(0xFFFEF3C7).withOpacity(0.65)..style = PaintingStyle.fill;
      final wrapPath = Path()..moveTo(w/6, h)..lineTo(w * 5/6, h)..lineTo(w/2, h/4)..close();
      canvas.drawPath(wrapPath, wrappingWash);
      canvas.drawPath(wrapPath, inkPaint);
    } else {
      // Tall green ornamental grass/foliage backdrop (Like the tall dark green leaves in Image 3)
      final grassWash = Paint()..color = const Color(0xFF2E5A44).withOpacity(0.65)..style = PaintingStyle.fill;
      
      // Draw 3 tall sweeping blades of grass curving outward
      final grass1 = Path()
        ..moveTo(w / 2 - 4, h)
        ..quadraticBezierTo(w / 2 - 25, h * 0.5, w / 2 - 32, h / 8)
        ..quadraticBezierTo(w / 2 - 15, h * 0.4, w / 2 + 4, h);
      canvas.drawPath(grass1, grassWash);
      canvas.drawPath(grass1, inkPaint);

      final grass2 = Path()
        ..moveTo(w / 2, h)
        ..quadraticBezierTo(w / 2 + 25, h * 0.55, w / 2 + 30, h / 7)
        ..quadraticBezierTo(w / 2 + 14, h * 0.45, w / 2 - 2, h);
      canvas.drawPath(grass2, grassWash);
      canvas.drawPath(grass2, inkPaint);

      final grass3 = Path()
        ..moveTo(w / 2 - 2, h)
        ..quadraticBezierTo(w / 2 - 5, h * 0.45, w / 2 - 4, h / 10)
        ..quadraticBezierTo(w / 2 + 5, h * 0.4, w / 2 + 2, h);
      canvas.drawPath(grass3, grassWash);
      canvas.drawPath(grass3, inkPaint);
    }
  }

  @override
  bool shouldRepaint(_WatercolorFlowerPainter old) => old.type != type;
}

class _FallopianTrackPainter extends CustomPainter {
  final double activeProgress; 
  final String activePhase;
  final int cycleLength;
  final int periodLength;

  _FallopianTrackPainter({
    required this.activeProgress, 
    required this.activePhase,
    required this.cycleLength,
    required this.periodLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Define colors
    final Color colorMenstrual = const Color(0xFFEF4444); // Red
    final Color colorFollicular = const Color(0xFFF97316); // Orange
    final Color colorOvulation = const Color(0xFFFACC15); // Golden Yellow
    final Color colorLuteal = const Color(0xFF7C3AED); // Purple
    final Color colorInactive = const Color(0xFFD8D6D4); // Soft Neutral Gray

    // 1. Define the Single Continuous Uterus Outline Path (Starts at cervix bottom-left, loops through fallopian tubes/ovaries, ends at cervix bottom-right)
    final Path uterusPath = Path();
    // Start at bottom-left cervix
    uterusPath.moveTo(w * 0.46, h * 0.78);
    // Left uterus wall
    uterusPath.cubicTo(w * 0.44, h * 0.58, w * 0.38, h * 0.44, w * 0.33, h * 0.32);
    // Under-side of left fallopian tube
    uterusPath.cubicTo(w * 0.28, h * 0.28, w * 0.22, h * 0.28, w * 0.17, h * 0.32);
    // Outer fimbriae loop (left ovary)
    uterusPath.cubicTo(w * 0.10, h * 0.36, w * 0.07, h * 0.48, w * 0.14, h * 0.56);
    uterusPath.cubicTo(w * 0.20, h * 0.62, w * 0.23, h * 0.48, w * 0.19, h * 0.38);
    // Top of left tube arching over
    uterusPath.cubicTo(w * 0.15, h * 0.28, w * 0.11, h * 0.16, w * 0.21, h * 0.14);
    uterusPath.cubicTo(w * 0.31, h * 0.12, w * 0.37, h * 0.20, w * 0.43, h * 0.22);
    // Top center dip of uterus
    uterusPath.cubicTo(w * 0.47, h * 0.24, w * 0.49, h * 0.26, w * 0.50, h * 0.26);
    uterusPath.cubicTo(w * 0.51, h * 0.26, w * 0.53, h * 0.24, w * 0.57, h * 0.22);
    // Top of right tube arching over
    uterusPath.cubicTo(w * 0.63, h * 0.20, w * 0.69, h * 0.12, w * 0.79, h * 0.14);
    uterusPath.cubicTo(w * 0.89, h * 0.16, w * 0.85, h * 0.28, w * 0.81, h * 0.38);
    // Outer fimbriae loop (right ovary)
    uterusPath.cubicTo(w * 0.77, h * 0.48, w * 0.80, h * 0.62, w * 0.86, h * 0.56);
    uterusPath.cubicTo(w * 0.93, h * 0.48, w * 0.90, h * 0.36, w * 0.83, h * 0.32);
    // Under-side of right fallopian tube
    uterusPath.cubicTo(w * 0.78, h * 0.28, w * 0.72, h * 0.28, w * 0.67, h * 0.32);
    // Right uterus wall to bottom-right cervix
    uterusPath.cubicTo(w * 0.62, h * 0.44, w * 0.56, h * 0.58, w * 0.54, h * 0.78);

    // Measure the single continuous path
    final ui.PathMetrics pathMetrics = uterusPath.computeMetrics();
    final ui.PathMetric pathMetric = pathMetrics.first;
    final double pathLength = pathMetric.length;

    // 2. Draw full background uterus path in neutral gray
    final bgPaint = Paint()
      ..color = colorInactive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(uterusPath, bgPaint);

    // Calculate phase limits as offsets along the continuous path
    final double menstrualDuration = periodLength.toDouble();
    const double follicularDuration = 9.0;
    const double ovulationDuration = 2.0;
    final double lutealDuration = cycleLength - menstrualDuration - follicularDuration - ovulationDuration;

    final double p1 = menstrualDuration / cycleLength;
    final double p2 = (menstrualDuration + follicularDuration) / cycleLength;
    final double p3 = (menstrualDuration + follicularDuration + ovulationDuration) / cycleLength;

    final double activeOffset = pathLength * activeProgress;

    // Helper to draw a path slice with a flat color
    void drawSlice(double startProgress, double endProgress, Color color) {
      final double startO = pathLength * startProgress;
      final double endO = pathLength * endProgress;
      if (activeOffset > startO) {
        final double limitO = activeOffset.clamp(startO, endO);
        if (limitO > startO) {
          final Path slice = pathMetric.extractPath(startO, limitO);
          canvas.drawPath(
            slice,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9.5
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // 3. Draw active progress segments sequentially (Flat and Solid, no gradients/glows)
    drawSlice(0.0, p1, colorMenstrual);
    drawSlice(p1, p2, colorFollicular);
    drawSlice(p2, p3, colorOvulation);
    drawSlice(p3, 1.0, colorLuteal);

    // 5. Draw traveling white egg
    final tangent = pathMetric.getTangentForOffset(activeOffset);
    final eggOffset = tangent?.position ?? Offset(w * 0.46, h * 0.78);

    Color activeColor = colorLuteal;
    if (activePhase == 'Menstrual') activeColor = colorMenstrual;
    if (activePhase == 'Follicular') activeColor = colorFollicular;
    if (activePhase == 'Ovulation') activeColor = colorOvulation;

    // Soft shadow under the egg
    canvas.drawCircle(
      eggOffset,
      10.5,
      Paint()
        ..color = const Color(0xFF2C2523).withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Colored outer border (matching current phase, 3.5px border outline)
    canvas.drawCircle(
      eggOffset,
      10.5,
      Paint()..color = activeColor..style = PaintingStyle.fill,
    );

    // Matte white egg body
    canvas.drawCircle(
      eggOffset,
      7.0,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Tiny egg center core highlight dot
    canvas.drawCircle(
      eggOffset,
      2.0,
      Paint()..color = activeColor..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FallopianTrackPainter oldDelegate) {
    return oldDelegate.activeProgress != activeProgress || 
           oldDelegate.activePhase != activePhase ||
           oldDelegate.cycleLength != cycleLength ||
           oldDelegate.periodLength != periodLength;
  }
}

class _TapeEdgesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    double step = 3.0;
    for (double y = 0; y <= size.height; y += step) {
      double x = (y % (step * 2) == 0) ? 2.0 : 0.0;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    for (double y = size.height; y >= 0; y -= step) {
      double x = size.width - ((y % (step * 2) == 0) ? 2.0 : 0.0);
      path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
