import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../core/cycle_calculator.dart';
import '../../../services/api_auth_service.dart';
import '../../../l10n/app_localizations.dart';
import 'cycle_tracker_image.dart';

class BlushyCycleCard extends StatefulWidget {
  final bool purePainterMode;
  const BlushyCycleCard({super.key, this.purePainterMode = false});

  @override
  State<BlushyCycleCard> createState() => _BlushyCycleCardState();
}

class _BlushyCycleCardState extends State<BlushyCycleCard> with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _sweepController;

  double _currentDayProgress = 0.5;
  double _userDragProgress = -1.0;
  bool _isSweeping = false;
  bool _isInitialized = false;
  String _activePhaseName = 'Follicular Phase';
  String _activePeriodLabel = '14 days';
  String _activeExpectedPeriod = '';
  int _activeCycleLength = 28;


  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

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
        final profile = profileData['profile'] ?? profileData;
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
      _activeExpectedPeriod = calc.formattedNextPeriodDate;
      _activePeriodLabel = calc.daysUntilNextPeriod == 0
          ? 'Today'
          : (calc.daysUntilNextPeriod == 1 ? 'Tomorrow' : '${calc.daysUntilNextPeriod} days');
    } else {
      _currentDayProgress = 0.0;
      _activePhaseName = 'Not Logged';
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
    _sweepController.dispose();
    super.dispose();
  }

  void _updateLabelsForProgress(double t) {
    final length = _activeCycleLength > 0 ? _activeCycleLength : 28;
    final day = (t * length).round().clamp(1, length);
    final ovulationDay = (length / 2).round();

    setState(() {
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

  /// Says that the drawing can be scrubbed.
  ///
  /// The drag and the tap both worked before this; nothing told anyone they
  /// were there, so neither was ever used.
  Widget _buildExploreHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_rounded,
                size: 13, color: BlushyColors.primary),
            const SizedBox(width: 6),
            Text(
              'Drag along the tube to explore days, or tap to play the cycle',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                color: BlushyColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Day 1 to the end of the cycle, with the day being looked at on it.
  ///
  /// Drives `_userDragProgress`, the same value the drag on the drawing sets,
  /// so the two cannot disagree about which day is showing.
  Widget _buildDayScrubber(double progress) {
    final length = _activeCycleLength <= 0 ? 28 : _activeCycleLength;
    // Day 1 is the first day, not the zeroth: at progress 0 this must read
    // Day 1, and at the far end it must read the last day rather than one past
    // the end of the cycle.
    final day = (progress * length).floor().clamp(0, length - 1) + 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Day 1',
                style: GoogleFonts.manrope(
                    fontSize: 10, color: BlushyColors.secondaryText)),
            Text(
              'Day $day',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
              ),
            ),
            Text('Day $length',
                style: GoogleFonts.manrope(
                    fontSize: 10, color: BlushyColors.secondaryText)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: BlushyColors.primary,
            inactiveTrackColor: BlushyColors.border,
            thumbColor: BlushyColors.primary,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) => setState(() {
              _userDragProgress = value;
              _updateLabelsForProgress(value);
            }),
            // Deliberately no release on let-go.
            //
            // A quick drag across the drawing is a glance, so that one springs
            // back. Moving a slider is a decision: snapping it home the moment
            // it is let go reads as the control refusing the input. It stays
            // where it is put, and the button below goes back.
          ),
        ),
        if (_userDragProgress >= 0.0)
          TextButton(
            onPressed: _releaseScrub,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Back to today',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BlushyColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// Lets go of the scrubbed day and eases back to today.
  ///
  /// The same ending the drag on the drawing has, so releasing either returns
  /// to the real day rather than leaving the card on whichever was last looked
  /// at.
  void _releaseScrub() {
    final pc = BlushyOSProvider.of(context).personalContext;
    setState(() {
      _userDragProgress = -1.0;
      if (!_isSweeping) _syncWithState(pc);
    });
    _progressController.animateTo(
      _currentDayProgress,
      curve: Curves.easeOutCubic,
    );
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
    if (phaseName.contains('Menstrual')) return BlushyColors.primary;
    if (phaseName.contains('Follicular')) return const Color(0xFFFF9B9E);
    if (phaseName.contains('Ovulation')) return const Color(0xFFFFB800);
    return BlushyColors.accent; // Luteal
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    _syncWithState(state.personalContext);
    final mode = ContextResolver.resolve(state.personalContext, state.wellbeingState);

    const canvasSize = Size(240, 240);

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
          onHorizontalDragEnd: (_) => _releaseScrub(),
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _progressController,
                _sweepController
              ]),
              builder: (context, child) {
                // The supplied drawing, with the cycle traced along it.
                // The controller that settles to today and runs the tap
                // sweep drives it.
                return CycleTrackerImage(progress: activeProgress);
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
        borderRadius: BorderRadius.circular(12),
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
                    style: GoogleFonts.manrope(
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 12, color: BlushyColors.text),
                        const SizedBox(width: 4),
                        Text(
                          'Edit Cycle',
                          style: GoogleFonts.manrope(
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
                onHorizontalDragEnd: (_) => _releaseScrub(),
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _progressController,
                      _sweepController
                    ]),
                    builder: (context, child) {
                      return CycleTrackerImage(progress: activeProgress);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildExploreHint(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendDot('Menstrual', const Color(0xFFEF4444)),
                _buildLegendDot('Follicular', const Color(0xFFF97316)),
                _buildLegendDot('Ovulation', const Color(0xFFFACC15)),
                _buildLegendDot('Luteal', BlushyColors.accent),
              ],
            ),
            const SizedBox(height: 14),
            _buildDayScrubber(activeProgress),
          ]
        ],
      ),
    );
  }

  String _getTitleForMode(CycleCardMode mode) {
    switch(mode) {
      case CycleCardMode.predictable: return 'Your cycle journey';
      case CycleCardMode.variable: return 'Cycle variability detected';
      case CycleCardMode.learning: return 'Docsy is learning your patterns';
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
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _activeExpectedPeriod.isNotEmpty ? 'Expected Period: $_activeExpectedPeriod' : 'Expected Period: In $_activePeriodLabel',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        );
      case CycleCardMode.variable:
        return Text(
          AppLocalizations.of(context).cYourCycleLengthIs,
          style: GoogleFonts.manrope(fontSize: 14, color: BlushyColors.text),
        );
      case CycleCardMode.wellbeing:
        return Text(
          AppLocalizations.of(context).cTrackingIsDisabledFocus,
          style: GoogleFonts.manrope(fontSize: 14, color: BlushyColors.text),
        );
      case CycleCardMode.lifeContext:
        return Text(
          AppLocalizations.of(context).cYourRecommendationsAreAdapted,
          style: GoogleFonts.manrope(fontSize: 14, color: BlushyColors.text),
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
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: BlushyColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

