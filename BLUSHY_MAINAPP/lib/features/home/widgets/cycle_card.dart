import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../core/cycle_calculator.dart';
import '../../../services/api_auth_service.dart';

class BlushyCycleCard extends StatefulWidget {
  final bool purePainterMode;
  const BlushyCycleCard({super.key, this.purePainterMode = false});

  @override
  State<BlushyCycleCard> createState() => _BlushyCycleCardState();
}

class _BlushyCycleCardState extends State<BlushyCycleCard> with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _pulseController;
  late final AnimationController _loopController;
  late final AnimationController _sweepController;

  double _currentDayProgress = 0.5; 
  double _userDragProgress = -1.0;                
  bool _isSweeping = false;
  bool _isInitialized = false;
  String _activePhaseName = 'Follicular Phase';
  String _activeDayLabel = '14';
  String _activePeriodLabel = '14 days';
  String _activeExpectedPeriod = '';
  int _activeCycleLength = 28;

  Path? _cachedPath;
  PathMetrics? _cachedMetrics;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _sweepController.addListener(() {
      if (_isSweeping) {
        _updateLabelsForProgress(_sweepController.value);
      }
    });

    // Lively fetch latest period start date & cycle length from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRemoteCycleData();
    });
  }

  Future<void> _fetchRemoteCycleData() async {
    try {
      final remote = await ApiAuthService().getOnboardingAnswers();
      if (remote.isNotEmpty && mounted) {
        final rawPeriod = remote['last_period'] ?? remote['last_period_date'] ?? remote['period_last_start_date'];
        if (rawPeriod != null) {
          final parsed = BlushyOSState.parseFlexibleDate(rawPeriod);
          if (parsed != null) {
            final state = BlushyOSProvider.of(context);
            if (state.personalContext.lastPeriodStart != parsed) {
              state.updatePersonalContext(PersonalContext(
                userName: state.personalContext.userName,
                dateOfBirth: state.personalContext.dateOfBirth,
                weight: state.personalContext.weight,
                lifeStage: state.personalContext.lifeStage,
                activeLifeStages: state.personalContext.activeLifeStages,
                dueDate: state.personalContext.dueDate,
                babyBirthDate: state.personalContext.babyBirthDate,
                trackingPreference: state.personalContext.trackingPreference,
                cyclePattern: state.personalContext.cyclePattern,
                confidence: state.personalContext.confidence,
                lifeContexts: state.personalContext.lifeContexts,
                userGoals: state.personalContext.userGoals,
                userSymptoms: state.personalContext.userSymptoms,
                medicalConditions: state.personalContext.medicalConditions,
                preferences: state.personalContext.preferences,
                cycleLength: state.personalContext.cycleLength,
                cycleDay: state.personalContext.cycleDay,
                cyclePhase: state.personalContext.cyclePhase,
                lastPeriodStart: parsed,
                medications: state.personalContext.medications,
              ));
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = BlushyOSProvider.of(context);
    _syncWithState(state.personalContext);
  }

  void _syncWithState(PersonalContext pc) {
    DateTime? periodDate = pc.lastPeriodStart;
    int? cycleLen = pc.cycleLength;

    if (periodDate == null) {
      try {
        final profileData = BlushyStorage.read('user_profile.json');
        final profile = (profileData is Map) ? (profileData['profile'] ?? profileData) : {};
        final rawPeriod = profile['lastPeriodStart'] ?? profile['last_period'] ?? profile['last_period_date'] ?? profile['period_last_start_date'];
        if (rawPeriod != null) {
          periodDate = BlushyOSState.parseFlexibleDate(rawPeriod);
        }
        if (cycleLen == null && profile['cycleLength'] != null) {
          cycleLen = int.tryParse(profile['cycleLength'].toString());
        }
      } catch (_) {}
    }

    final calc = CycleCalculation.compute(
      lastPeriodStart: periodDate,
      cycleLength: cycleLen,
    );

    _activeCycleLength = calc.cycleLength;

    if (calc.hasData) {
      final double computedProgress = (calc.currentCycleDay / calc.cycleLength).clamp(0.0, 1.0);
      _currentDayProgress = computedProgress;
      _activePhaseName = calc.currentPhase;
      _activeDayLabel = calc.currentCycleDay.toString();
      _activeExpectedPeriod = calc.formattedNextPeriodDate;
      _activePeriodLabel = calc.daysUntilNextPeriod == 0
          ? 'Today'
          : (calc.daysUntilNextPeriod == 1 ? 'Tomorrow' : '${calc.daysUntilNextPeriod} days');
    } else {
      _currentDayProgress = 0.0;
      _activePhaseName = 'Not Logged';
      _activeDayLabel = '--';
      _activeExpectedPeriod = '--';
      _activePeriodLabel = 'Log your period to see predictions';
    }

    if (!_isInitialized) {
      _isInitialized = true;
      _progressController.value = _currentDayProgress;
      _progressController.animateTo(
        _currentDayProgress,
        curve: Curves.easeOutCubic,
      );
    } else if (_userDragProgress < 0.0 && !_isSweeping) {
      if ((_progressController.value - _currentDayProgress).abs() > 0.005) {
        _progressController.animateTo(
          _currentDayProgress,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _loopController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _updateLabelsForProgress(double t) {
    final length = _activeCycleLength > 0 ? _activeCycleLength : 28;
    final day = (t * length).round().clamp(1, length);
    final ovulationDay = (length / 2).round();

    setState(() {
      _activeDayLabel = day.toString();
      if (day <= 5) {
        _activePhaseName = 'Menstrual Phase';
        _activePeriodLabel = 'Active';
      } else if (day < ovulationDay - 1) {
        _activePhaseName = 'Follicular Phase';
        _activePeriodLabel = '${length - day} days';
      } else if (day >= ovulationDay - 1 && day <= ovulationDay + 1) {
        _activePhaseName = 'Ovulation Phase';
        _activePeriodLabel = '${length - day} days';
      } else {
        _activePhaseName = 'Luteal Phase';
        final diff = length - day;
        _activePeriodLabel = diff == 0 ? 'Tomorrow' : '$diff days';
      }
    });
  }

  Path _generateContinuousBlushyPath(Size size) {
    if (_cachedPath != null && size.width == 260) return _cachedPath!;

    final w = size.width;
    final h = size.height;
    final path = Path();

    // Start at bottom-left leg
    path.moveTo(w * 0.38, h * 0.90);
    
    // Left inner curve up
    path.cubicTo(
      w * 0.37, h * 0.76,
      w * 0.31, h * 0.54,
      w * 0.28, h * 0.44,
    );

    // Left loop/ovary curve
    path.cubicTo(
      w * 0.25, h * 0.34,
      w * 0.18, h * 0.30,
      w * 0.18, h * 0.42,
    );
    path.cubicTo(
      w * 0.18, h * 0.54,
      w * 0.10, h * 0.56,
      w * 0.06, h * 0.42,
    );
    path.cubicTo(
      w * 0.02, h * 0.26,
      w * 0.08, h * 0.14,
      w * 0.14, h * 0.14,
    );

    // Top bridge left to center dip
    path.cubicTo(
      w * 0.22, h * 0.14,
      w * 0.34, h * 0.22,
      w * 0.50, h * 0.26, // Center dip
    );

    // Top bridge right to right loop
    path.cubicTo(
      w * 0.66, h * 0.22,
      w * 0.78, h * 0.14,
      w * 0.86, h * 0.14,
    );

    // Right loop/ovary curve
    path.cubicTo(
      w * 0.92, h * 0.14,
      w * 0.98, h * 0.26,
      w * 0.94, h * 0.42,
    );
    path.cubicTo(
      w * 0.90, h * 0.56,
      w * 0.82, h * 0.54,
      w * 0.82, h * 0.42,
    );
    path.cubicTo(
      w * 0.82, h * 0.30,
      w * 0.75, h * 0.34,
      w * 0.72, h * 0.44,
    );

    // Right inner curve down to end at bottom-right leg
    path.cubicTo(
      w * 0.69, h * 0.54,
      w * 0.63, h * 0.76,
      w * 0.62, h * 0.90,
    );

    _cachedPath = path;
    _cachedMetrics = path.computeMetrics();
    return path;
  }

  void _triggerEducationalSweep() {
    if (_isSweeping) return;
    setState(() {
      _isSweeping = true;
    });
    _sweepController.forward(from: 0.0).then((_) {
      if (mounted) {
        final pc = BlushyOSProvider.of(context).personalContext;
        setState(() {
          _isSweeping = false;
          _userDragProgress = -1.0;
          _syncWithState(pc);
        });
        _progressController.animateTo(
          _currentDayProgress,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Color _getCurrentPhaseColor(String phaseName) {
    if (phaseName.contains('Menstrual')) return const Color(0xFFDD0D22);
    if (phaseName.contains('Follicular')) return const Color(0xFFFF9B9E);
    if (phaseName.contains('Ovulation')) return const Color(0xFFFFB800);
    return const Color(0xFF6F42F5); // Luteal
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    _syncWithState(state.personalContext);
    final mode = ContextResolver.resolve(state.personalContext, state.wellbeingState);

    const canvasSize = Size(260, 120); 
    
    double activeProgress = _progressController.value;
    if (_userDragProgress >= 0.0) {
      activeProgress = _userDragProgress;
    } else if (_isSweeping) {
      activeProgress = _sweepController.value;
    }

    final activeColor = _getCurrentPhaseColor(_activePhaseName);

    if (widget.purePainterMode) {
      return Center(
        child: GestureDetector(
          onTap: _triggerEducationalSweep,
          onHorizontalDragUpdate: (details) {
            final localX = details.localPosition.dx;
            final normalized = (localX / canvasSize.width).clamp(0.0, 1.0);
            setState(() {
              _userDragProgress = normalized;
              _updateLabelsForProgress(normalized);
            });
          },
          onHorizontalDragEnd: (details) {
            final pc = BlushyOSProvider.of(context).personalContext;
            setState(() {
              _userDragProgress = -1.0;
              if (!_isSweeping) {
                _syncWithState(pc);
              }
            });
            _progressController.animateTo(
              _currentDayProgress,
              curve: Curves.easeOutCubic,
            );
          },
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _progressController,
                _pulseController,
                _loopController,
                _sweepController
              ]),
              builder: (context, child) {
                return CustomPaint(
                  painter: SignatureCyclePathPainter(
                    path: _generateContinuousBlushyPath(canvasSize),
                    progress: activeProgress,
                    pulseVal: _pulseController.value,
                    loopAngle: _loopController.value * 2.0 * math.pi,
                    activeColor: activeColor,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: BlushyColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _getTitleForMode(mode),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.info_outline_rounded, size: 14, color: BlushyColors.secondaryText),
                ],
              ),
              if (mode != CycleCardMode.wellbeing)
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: BlushyColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 12, color: BlushyColors.text),
                        const SizedBox(width: 4),
                        Text(
                          'Edit Cycle',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BlushyColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Content based on mode
          _buildContentForMode(mode, activeColor),
          
          if (mode == CycleCardMode.predictable || mode == CycleCardMode.learning) ...[
            const Divider(color: BlushyColors.border, height: 32),
            Center(
              child: GestureDetector(
                onTap: _triggerEducationalSweep,
                onHorizontalDragUpdate: (details) {
                  final localX = details.localPosition.dx;
                  final normalized = (localX / canvasSize.width).clamp(0.0, 1.0);
                  setState(() {
                    _userDragProgress = normalized;
                    _updateLabelsForProgress(normalized);
                  });
                },
                onHorizontalDragEnd: (details) {
                  final pc = BlushyOSProvider.of(context).personalContext;
                  setState(() {
                    _userDragProgress = -1.0;
                    if (!_isSweeping) {
                      _syncWithState(pc);
                    }
                  });
                  _progressController.animateTo(
                    _currentDayProgress,
                    curve: Curves.easeOutCubic,
                  );
                },
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _progressController,
                      _pulseController,
                      _loopController,
                      _sweepController
                    ]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: SignatureCyclePathPainter(
                          path: _generateContinuousBlushyPath(canvasSize),
                          progress: activeProgress,
                          pulseVal: _pulseController.value,
                          loopAngle: _loopController.value * 2.0 * math.pi,
                          activeColor: activeColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendDot('Menstrual', const Color(0xFFEF4444)),
                _buildLegendDot('Follicular', const Color(0xFFF97316)),
                _buildLegendDot('Ovulation', const Color(0xFFFACC15)),
                _buildLegendDot('Luteal', const Color(0xFF7C3AED)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  String _getTitleForMode(CycleCardMode mode) {
    switch(mode) {
      case CycleCardMode.predictable: return 'Your cycle journey';
      case CycleCardMode.variable: return 'Cycle variability detected';
      case CycleCardMode.learning: return 'Sia is learning your patterns';
      case CycleCardMode.wellbeing: return 'Daily Wellbeing';
      case CycleCardMode.lifeContext: return 'Life Stage Focus';
    }
  }

  Widget _buildContentForMode(CycleCardMode mode, Color activeColor) {
    switch (mode) {
      case CycleCardMode.predictable:
      case CycleCardMode.learning:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activePhaseName,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _activeExpectedPeriod.isNotEmpty ? 'Expected Period: $_activeExpectedPeriod' : 'Expected Period: In $_activePeriodLabel',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        );
      case CycleCardMode.variable:
        return Text(
          "Your cycle length is varying. Log your symptoms daily so Sia can adjust predictions.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text),
        );
      case CycleCardMode.wellbeing:
        return Text(
          "Tracking is disabled. Focus on your daily energy, mood, and sleep.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text),
        );
      case CycleCardMode.lifeContext:
        return Text(
          "Your recommendations are adapted to your current life stage.",
          style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text),
        );
    }
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: BlushyColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class SignatureCyclePathPainter extends CustomPainter {
  final double progress;
  final String activePhase;
  final int cycleLength;
  final int periodLength;

  SignatureCyclePathPainter({
    required this.progress,
    this.activePhase = 'Follicular',
    this.cycleLength = 28,
    this.periodLength = 5,
    Path? path,
    double? pulseVal,
    double? loopAngle,
    Color? activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    // Define colors
    final Color colorMenstrual = const Color(0xFFEF4444); // Red
    final Color colorFollicular = const Color(0xFFF97316); // Orange
    final Color colorOvulation = const Color(0xFFFACC15); // Golden Yellow
    final Color colorLuteal = const Color(0xFF7C3AED); // Purple
    final Color colorInactive = const Color(0xFFD8D6D4); // Soft Neutral Gray

    // 1. Define the Single Continuous Uterus Outline Path
    final Path uterusPath = Path();
    uterusPath.moveTo(w * 0.46, h * 0.78);
    uterusPath.cubicTo(w * 0.44, h * 0.58, w * 0.38, h * 0.44, w * 0.33, h * 0.32);
    uterusPath.cubicTo(w * 0.28, h * 0.28, w * 0.22, h * 0.28, w * 0.17, h * 0.32);
    uterusPath.cubicTo(w * 0.10, h * 0.36, w * 0.07, h * 0.48, w * 0.14, h * 0.56);
    uterusPath.cubicTo(w * 0.20, h * 0.62, w * 0.23, h * 0.48, w * 0.19, h * 0.38);
    uterusPath.cubicTo(w * 0.15, h * 0.28, w * 0.11, h * 0.16, w * 0.21, h * 0.14);
    uterusPath.cubicTo(w * 0.31, h * 0.12, w * 0.37, h * 0.20, w * 0.43, h * 0.22);
    uterusPath.cubicTo(w * 0.47, h * 0.24, w * 0.49, h * 0.26, w * 0.50, h * 0.26);
    uterusPath.cubicTo(w * 0.51, h * 0.26, w * 0.53, h * 0.24, w * 0.57, h * 0.22);
    uterusPath.cubicTo(w * 0.63, h * 0.20, w * 0.69, h * 0.12, w * 0.79, h * 0.14);
    uterusPath.cubicTo(w * 0.89, h * 0.16, w * 0.85, h * 0.28, w * 0.81, h * 0.38);
    uterusPath.cubicTo(w * 0.77, h * 0.48, w * 0.80, h * 0.62, w * 0.86, h * 0.56);
    uterusPath.cubicTo(w * 0.93, h * 0.48, w * 0.90, h * 0.36, w * 0.83, h * 0.32);
    uterusPath.cubicTo(w * 0.78, h * 0.28, w * 0.72, h * 0.28, w * 0.67, h * 0.32);
    uterusPath.cubicTo(w * 0.62, h * 0.44, w * 0.56, h * 0.58, w * 0.54, h * 0.78);

    // Measure the single continuous path
    final List<PathMetric> metricsList = uterusPath.computeMetrics().toList();
    if (metricsList.isEmpty) return;
    final PathMetric pathMetric = metricsList.first;
    final double pathLength = pathMetric.length;
    if (pathLength <= 0) return;

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
    const double expectedDuration = 3.0;

    double p1 = menstrualDuration / cycleLength;
    double p2 = (menstrualDuration + follicularDuration) / cycleLength;
    double p3 = (menstrualDuration + follicularDuration + ovulationDuration) / cycleLength;
    double p4 = (cycleLength - expectedDuration) / cycleLength;

    if (p4 < p3) {
      p4 = p3;
    }

    final double activeOffset = pathLength * progress.clamp(0.0, 1.0);

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

    // 3. Draw active progress segments sequentially
    drawSlice(0.0, p1, colorMenstrual);
    drawSlice(p1, p2, colorFollicular);
    drawSlice(p2, p3, colorOvulation);
    drawSlice(p3, p4, colorLuteal);
    drawSlice(p4, 1.0, colorMenstrual);

    // 4. Draw traveling egg
    final tangent = pathMetric.getTangentForOffset(activeOffset);
    final eggOffset = tangent?.position ?? Offset(w * 0.46, h * 0.78);

    Color activeEggColor = colorMenstrual;
    if (progress <= p1) {
      activeEggColor = colorMenstrual;
    } else if (progress <= p2) {
      activeEggColor = colorFollicular;
    } else if (progress <= p3) {
      activeEggColor = colorOvulation;
    } else if (progress <= p4) {
      activeEggColor = colorLuteal;
    } else {
      activeEggColor = colorMenstrual;
    }

    // Soft shadow under the egg
    canvas.drawCircle(
      eggOffset,
      10.5,
      Paint()
        ..color = const Color(0xFF2C2523).withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Colored outer border
    canvas.drawCircle(
      eggOffset,
      10.5,
      Paint()..color = activeEggColor..style = PaintingStyle.fill,
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
      Paint()..color = activeEggColor..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant SignatureCyclePathPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.activePhase != activePhase ||
           oldDelegate.cycleLength != cycleLength ||
           oldDelegate.periodLength != periodLength;
  }
}
