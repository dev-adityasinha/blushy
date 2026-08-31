import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart' hide BlushyColors;

import '../../services/api_sia_service.dart';
import '../../services/api_blushy_service.dart';
import '../../services/html_audio_helper.dart';
import '../../services/sia_dashboard_service.dart';
import '../../services/auth_storage.dart';
import '../../core/storage.dart';
import '../../core/state.dart';
import '../../core/cycle_calculator.dart';
import '../../core/stage_config.dart';
import '../../services/api_auth_service.dart';
import '../../services/journal_quick_entry.dart';
import '../../services/api_period_service.dart';
import '../../shared/voice_note_bottom_sheet.dart';
import '../community/community_screen.dart';
import '../partner/presentation/partner_community.dart';
import '../journal/journal_screen.dart';
import '../home/widgets/cycle_card.dart';
import '../../services/html_file_helper.dart';

String _getTimeBasedGreetingPrefix() {
  final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = istNow.hour;
  if (hour < 12) {
    return "Good Morning";
  } else if (hour < 17) {
    return "Good Afternoon";
  } else {
    return "Good Evening";
  }
}

class BlushySiaScreen extends StatefulWidget {
  final String? initialQuestion;
  final VoidCallback? onRedirectToMood;
  final VoidCallback? onRedirectToEnergy;
  final VoidCallback? onRedirectToCycle;
  final VoidCallback? onRedirectToSleep;

  const BlushySiaScreen({
    super.key,
    this.initialQuestion,
    this.onRedirectToMood,
    this.onRedirectToEnergy,
    this.onRedirectToCycle,
    this.onRedirectToSleep,
  });

  @override
  State<BlushySiaScreen> createState() => _BlushySiaScreenState();
}

class _BlushySiaScreenState extends State<BlushySiaScreen> with TickerProviderStateMixin {
  final List<Map<String, String>> _messages = [];

  /// Exchanges whose share state is currently being written.
  final Set<String> _sharingConversationIds = <String>{};
  final TextEditingController _chatController = TextEditingController();
  final ApiSiaService _siaService = ApiSiaService();

  late final AnimationController _waveController;
  bool _isListeningVoice = false;
  bool _isThinking = false;
  PickedBlushyFile? _attachedFile;

  late final Timer _placeholderTimer;
  int _placeholderIndex = 0;
  List<String> _placeholders = [
    "Why am I feeling emotional today?",
    "Should I work out today?",
    "Explain my cycle.",
    "Why am I so tired?",
  ];

  void _showAttachmentOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: BlushyColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.attachment_rounded, color: Color(0xFF6F42F5), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "Upload Health Document or Scan",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Dr. Docsy will read, analyze, and explain your medical reports, lab results, and health scans with doctor-level clarity.",
                style: GoogleFonts.poppins(fontSize: 11.5, color: BlushyColors.secondaryText, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildAttachmentOptionTile(
                      ctx,
                      icon: Icons.picture_as_pdf_rounded,
                      title: AppLocalizations.of(context).sMedicalReportPdf,
                      subtitle: "Lab tests, blood work, prescriptions",
                      color: const Color(0xFFDC2626),
                      accept: '.pdf,application/pdf',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAttachmentOptionTile(
                      ctx,
                      icon: Icons.image_rounded,
                      title: "Health Scan / Photo",
                      subtitle: "Ultrasound, doctor note, symptoms",
                      color: const Color(0xFF6F42F5),
                      accept: 'image/*,.jpg,.jpeg,.png,.webp',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOptionTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String accept,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        final file = await pickFileFromDevice(accept: accept);
        if (file != null && mounted) {
          setState(() {
            _attachedFile = file;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attached: ${file.name} (${file.formattedSize}). Ask Dr. Docsy a question or press Send!'),
              backgroundColor: const Color(0xFF6F42F5),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = BlushyOSProvider.of(context);
    String stage = 'everydayWellness';
    try {
      if (state.selectedRole == 'partner') {
        stage = 'partner';
      } else {
        final profile = BlushyStorage.read('user_profile.json');
        if (profile['profile'] != null) {
          stage = profile['profile']['lifeStage']?.toString() ?? 'everydayWellness';
        }
      }
    } catch (_) {}
    setState(() {
      _placeholders = StageConfig.forStage(stage).siaSuggestions;
    });
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _placeholderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _placeholders.isNotEmpty) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
        });
      }
    });

    _loadChatHistory();

    if (widget.initialQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendUserMessage(widget.initialQuestion!);
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final history = await _siaService.getChatHistory();
    if (mounted && history.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _waveController.dispose();
    _placeholderTimer.cancel();
    SiaDashboardService().syncAllDashboardsFromBackend();
    super.dispose();
  }

  HtmlAudioRecorder? _audioRecorder;
  int _recordingSeconds = 0;

  void _extractAndSaveWellbeingFromUserMessage(String query) {
    try {
      final state = BlushyOSProvider.of(context);
      final wb = state.wellbeingState;
      final q = query.toLowerCase();

      int? newEnergy = wb.energy;
      if (q.contains('high energy') || q.contains('lots of energy') || q.contains('very energetic') || q.contains('full of energy') || q.contains('great energy') || q.contains('energetic')) {
        newEnergy = 8;
      } else if (q.contains('medium energy') || q.contains('moderate energy') || q.contains('normal energy') || q.contains('okay energy') || q.contains('balanced energy') || q.contains('average energy')) {
        newEnergy = 5;
      } else if (q.contains('low energy') || q.contains('tired') || q.contains('exhausted') || q.contains('drained') || q.contains('fatigue') || q.contains('no energy') || q.contains('little energy') || q.contains('sluggish') || q.contains('wiped out')) {
        newEnergy = 3;
      }

      int? newMood = wb.mood;
      String? feelingString;
      if (q.contains('happy') || q.contains('great') || q.contains('good') || q.contains('joyful') || q.contains('excited') || q.contains('awesome') || q.contains('wonderful')) {
        newMood = 9;
        feelingString = 'Happy';
      } else if (q.contains('calm') || q.contains('peaceful') || q.contains('relaxed') || q.contains('balanced') || q.contains('serene') || q.contains('chill')) {
        newMood = 8;
        feelingString = 'Calm';
      } else if (q.contains('okay') || q.contains('fine') || q.contains('alright') || q.contains('normal') || q.contains('so so')) {
        newMood = 6;
        feelingString = 'Okay';
      } else if (q.contains('sad') || q.contains('down') || q.contains('depressed') || q.contains('crying') || q.contains('lonely') || q.contains('heartbroken') || q.contains('gloomy')) {
        newMood = 3;
        feelingString = 'Sad';
      } else if (q.contains('angry') || q.contains('irritat') || q.contains('mad') || q.contains('annoyed') || q.contains('frustrated') || q.contains('cranky') || q.contains('grumpy')) {
        newMood = 3;
        feelingString = 'Irritable';
      } else if (q.contains('anxious') || q.contains('nervous') || q.contains('worried') || q.contains('panic') || q.contains('overthinking') || q.contains('tense') || q.contains('stressed') || q.contains('overwhelm')) {
        newMood = 4;
        feelingString = 'Anxious';
      }

      // Check for sleep mentions (e.g. "slept 7 hours", "7.5h sleep", "8 hours of sleep")
      final sleepMatch = RegExp(r'(\d+(\.\d+)?)\s*(hours|hrs|hr|h)\s*(of\s*)?sleep|slept\s*(\d+(\.\d+)?)').firstMatch(q);
      int? newSleep = wb.sleepQuality;
      if (sleepMatch != null) {
        final val = double.tryParse(sleepMatch.group(1) ?? sleepMatch.group(5) ?? '');
        if (val != null && val > 0 && val <= 24) {
          newSleep = val.round().clamp(1, 10);
        }
      }

      // Comprehensive symptom detections
      final List<String> detectedSymptoms = [];
      if (q.contains('cramp')) detectedSymptoms.add('Cramps');
      if (q.contains('headache') || q.contains('migraine')) detectedSymptoms.add('Headache');
      if (q.contains('bloat')) detectedSymptoms.add('Bloating');
      if (q.contains('acne') || q.contains('breakout') || q.contains('pimple')) detectedSymptoms.add('Acne');
      if (q.contains('hot flash') || q.contains('hot flashes')) detectedSymptoms.add('Hot Flashes');
      if (q.contains('night sweat')) detectedSymptoms.add('Night Sweats');
      if (q.contains('brain fog') || q.contains('foggy')) detectedSymptoms.add('Brain Fog');
      if (q.contains('fatigue') || q.contains('exhaustion')) detectedSymptoms.add('Fatigue');
      if (q.contains('joint pain') || q.contains('body ache')) detectedSymptoms.add('Joint Pain');
      if (q.contains('backache') || q.contains('back pain')) detectedSymptoms.add('Back Pain');
      if (q.contains('nausea') || q.contains('nauseous') || q.contains('vomit')) detectedSymptoms.add('Nausea');
      if (q.contains('breast tenderness') || q.contains('tender breast') || q.contains('sore breast')) detectedSymptoms.add('Breast Tenderness');
      if (q.contains('pelvic pain')) detectedSymptoms.add('Pelvic Pain');
      if (q.contains('mood swing')) detectedSymptoms.add('Mood Swings');
      if (q.contains('insomnia') || q.contains('cannot sleep') || q.contains("can't sleep")) detectedSymptoms.add('Insomnia');
      if (q.contains('dizzy') || q.contains('dizziness')) detectedSymptoms.add('Dizziness');
      if (q.contains('spotting')) detectedSymptoms.add('Spotting');
      if (q.contains('craving')) detectedSymptoms.add('Cravings');

      List<String> symptoms = List.from(wb.symptoms);
      for (final sym in detectedSymptoms) {
        if (!symptoms.contains(sym)) {
          symptoms.insert(0, sym);
        }
      }
      if (feelingString != null && !symptoms.contains(feelingString)) {
        symptoms.insert(0, feelingString);
      }

      if (newEnergy != wb.energy || newMood != wb.mood || newSleep != wb.sleepQuality || feelingString != null || detectedSymptoms.isNotEmpty) {
        state.updateWellbeingState(CurrentWellbeingState(
          energy: newEnergy,
          mood: newMood,
          sleepQuality: newSleep,
          symptoms: symptoms,
          lastCheckIn: DateTime.now(),
          lastSiaConversation: DateTime.now(),
          periodActive: wb.periodActive,
        ));
      }
    } catch (_) {}
  }

  Future<void> _sendUserMessage(String query) async {
    final PickedBlushyFile? currentAttachment = _attachedFile;
    final String promptText = query.trim().isNotEmpty
        ? query.trim()
        : (currentAttachment != null ? "Please analyze this uploaded document and explain what it shows." : "");

    if (promptText.isEmpty && currentAttachment == null) return;
    _extractAndSaveWellbeingFromUserMessage(promptText);

    final state = BlushyOSProvider.of(context);
    dynamic savedWeight;
    try {
      savedWeight = BlushyStorage.read('logged_weight.json')['weight'] ?? state.personalContext.weight;
    } catch (_) {
      savedWeight = state.personalContext.weight;
    }

    String stage = 'everydayWellness';
    try {
      if (state.selectedRole == 'partner') {
        stage = 'partner';
      } else {
        final profile = BlushyStorage.read('user_profile.json');
        if (profile['profile'] != null) {
          stage = profile['profile']['lifeStage']?.toString() ?? 'everydayWellness';
        }
      }
    } catch (_) {}

    final contextData = <String, dynamic>{
      'userName': state.personalContext.userName,
      'lifeStage': stage,
      'activeLifeStages': state.personalContext.activeLifeStages.toList(),
      'cycleDay': state.personalContext.cycleDay,
      'cyclePhase': state.personalContext.cyclePhase,
      'lastPeriodStart': state.personalContext.lastPeriodStart?.toIso8601String(),
      'energy': state.wellbeingState.energy,
      'mood': state.wellbeingState.mood,
      'symptoms': state.wellbeingState.symptoms,
      'userGoals': state.personalContext.userGoals.toList(),
      'goals': state.personalContext.userGoals.toList(),
      'medicalConditions': state.personalContext.medicalConditions.toList(),
      'conditions': state.personalContext.medicalConditions.toList(),
      if (state.personalContext.dueDate != null) 'dueDate': state.personalContext.dueDate?.toIso8601String(),
      if (state.personalContext.babyBirthDate != null) 'babyBirthDate': state.personalContext.babyBirthDate?.toIso8601String(),
      if (savedWeight != null) 'currentWeight': '$savedWeight kg',
      if (savedWeight != null) 'weight': '$savedWeight kg',
    };

    final activeUserId = AuthStorage.getUserId();
    setState(() {
      final userEntry = <String, String>{
        'sender': 'user',
        'text': promptText,
      };
      if (currentAttachment != null) {
        userEntry['fileName'] = currentAttachment.name;
        userEntry['fileSize'] = currentAttachment.formattedSize;
        userEntry['isPdf'] = currentAttachment.isPdf.toString();
      }
      _messages.add(userEntry);
      try {
        BlushyStorage.write('recent_sia_chats.json', {
          'messages': _messages,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      _chatController.clear();
      _attachedFile = null;
      _isThinking = true;
    });

    try {
      final SiaChatResult chatResult;
      if (currentAttachment != null) {
        chatResult = await _siaService.uploadDocumentAndChat(
          fileBytes: currentAttachment.bytes,
          fileName: currentAttachment.name,
          mimeType: currentAttachment.mimeType,
          userMessage: promptText,
          healthContext: contextData,
        );
      } else {
        chatResult = await _siaService.sendMessageDetailed(promptText, healthContext: contextData);
      }

      if (!mounted) return;
      if (AuthStorage.getUserId() != activeUserId) {
        // Discard reply: account switched while request was in-flight
        return;
      }
      
      // Merge any backend captures into BlushyOSState
      if (chatResult.moodCapture != null && chatResult.moodCapture!['updated'] == true) {
        final moodStr = chatResult.moodCapture!['mood']?.toString();
        final energyStr = chatResult.moodCapture!['energyLevel']?.toString();
        final List<dynamic>? symList = chatResult.moodCapture!['symptoms'] as List<dynamic>?;

        int? moodScore = state.wellbeingState.mood;
        if (moodStr == 'great') {
          moodScore = 9;
        } else if (moodStr == 'calm') {
          moodScore = 8;
        } else if (moodStr == 'okay') {
          moodScore = 6;
        } else if (moodStr == 'low') {
          moodScore = 3;
        } else if (moodStr == 'anxious' || moodStr == 'irritated') {
          moodScore = 4;
        }

        int? energyScore = state.wellbeingState.energy;
        if (energyStr == 'high') {
          energyScore = 8;
        } else if (energyStr == 'medium') {
          energyScore = 5;
        } else if (energyStr == 'low') {
          energyScore = 3;
        }

        final List<String> currentSymptoms = List<String>.from(state.wellbeingState.symptoms);
        if (symList != null) {
          for (final s in symList) {
            final sStr = s.toString();
            if (!currentSymptoms.contains(sStr)) currentSymptoms.insert(0, sStr);
          }
        }

        state.updateWellbeing(
          mood: moodScore,
          energy: energyScore,
          symptoms: currentSymptoms,
        );
      }

      if (chatResult.sleepCapture != null && chatResult.sleepCapture!['updated'] == true) {
        final durationMinutes = chatResult.sleepCapture!['durationMinutes'];
        if (durationMinutes is num && durationMinutes > 0) {
          final hours = (durationMinutes / 60).round().clamp(1, 12);
          state.updateWellbeing(sleepQuality: hours);
        }
      }

      setState(() {
        _isThinking = false;

        // A red flag rule fired on the server. When it suppresses ordinary
        // content the message is the clinically reviewed instruction, not a
        // generated reply, so it is rendered as safety guidance rather than as
        // a chat bubble from Dr. Docsy.
        if (chatResult.hasSafety) {
          final safety = chatResult.safety!;
          final step = safety.steps.first;
          _messages.add(<String, String>{
            'sender': 'safety',
            'text': step.instruction,
            'title': step.title,
            'level': safety.level ?? step.level,
            if (step.source != null) 'source': step.source!,
            if (safety.emergencyNumber != null) 'emergencyNumber': safety.emergencyNumber!,
            'resources': safety.resources
                .where((r) => r.contact != null && r.contact!.isNotEmpty)
                .map((r) => '${r.name}: ${r.contact}')
                .join('\n'),
          });

          // When wellness content is suppressed the reviewed guidance is the
          // whole response, so no Dr. Docsy bubble is appended after it. The notify
          // call after this setState still runs.
          if (chatResult.suppressesChat) return;
        }

        final siaEntry = <String, String>{
          'sender': 'sia',
          'text': chatResult.message,
        };
        if (currentAttachment != null) {
          siaEntry['analyzedFile'] = currentAttachment.name;
        }
        _messages.add(siaEntry);
      });
      SiaDashboardService().notifyChatUpdated();
    } catch (e) {
      if (!mounted) return;
      if (AuthStorage.getUserId() != activeUserId) return;

      setState(() {
        _isThinking = false;
        _messages.add({
          'sender': 'sia',
          'text': "I'm having a little trouble connecting right now, but I'm still here with you.",
        });
      });
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListeningVoice && _audioRecorder != null) {
      setState(() {
        _isListeningVoice = false;
        _isThinking = true;
      });

      try {
        final recordResult = await _audioRecorder!.stop();
        final audioBytes = recordResult?.bytes ?? [];
        if (audioBytes.isNotEmpty) {
          final transcribedText = await _siaService.transcribeAudioBytes(
            audioBytes,
            'sia_voice_${DateTime.now().millisecondsSinceEpoch}'
                '.${_audioRecorder!.fileExtension}',
            mimeType: _audioRecorder!.mimeType,
          );

          if (mounted) {
            setState(() {
              _isThinking = false;
            });
            if (transcribedText.trim().isNotEmpty) {
              _chatController.text = transcribedText.trim();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).siaVoiceTranscribed)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).siaNoSpeechRecognised)),
              );
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isThinking = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).siaNoAudioRecorded)),
            );
          }
        }
      } on TranscriptionUnavailable catch (e) {
        // The recording succeeded; the transcription service did not.
        if (mounted) {
          setState(() {
            _isThinking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${e.message} You can type your message instead.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isThinking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Voice note error: $e")),
          );
        }
      }
    } else {
      try {
        _audioRecorder = HtmlAudioRecorder();
        _recordingSeconds = 0;
        _audioRecorder!.onProgress = (sec) {
          if (mounted) {
            setState(() {
              _recordingSeconds = sec;
            });
          }
        };
        await _audioRecorder!.start();
        if (mounted) {
          setState(() {
            _isListeningVoice = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListeningVoice = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Microphone access denied or unsupported: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        SiaDashboardService().syncAllDashboardsFromBackend(state: state);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6F0), // Warm Cream Editorial Background
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF6F0),
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: BlushyColors.text, size: 20),
                  onPressed: () {
                    SiaDashboardService().syncAllDashboardsFromBackend(state: state);
                    Navigator.pop(context, true);
                  },
                )
              : null,
        title: Text(
          AppLocalizations.of(context).siaAsk,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 1. Animated Breathing Orb Identity Section
                    Center(child: const _SiaBreathingOrb()),
                    const SizedBox(height: 12),

                    // 2. Personalized Context Greeting
                    Center(
                      child: Text(
                        '${_getTimeBasedGreetingPrefix()}, ${state.personalContext.userName ?? "there"}.',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.text,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),



                    // 4. Redesigned Today's Context Cards Grid (Non-spreadsheet style)
                    Text(
                      "TODAY'S CONTEXT",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final pc = state.personalContext;
                        final wb = state.wellbeingState;

                        DateTime? pStart = pc.lastPeriodStart;
                        if (pStart == null) {
                          try {
                            final profileData = BlushyStorage.read('user_profile.json');
                            final answers = profileData['profile'] ?? profileData ?? {};
                            final pStr = answers['period_last_start_date'] ?? answers['lastPeriodStart'];
                            if (pStr != null) {
                              pStart = DateTime.tryParse(pStr.toString());
                            }
                          } catch (_) {}
                        }

                        final String cyclePhaseText;
                        final String cycleDayText;
                        final double progressVal;
                        if (pStart != null) {
                          final calc = CycleCalculation.compute(
                            lastPeriodStart: pStart,
                            cycleLength: pc.cycleLength ?? 28,
                          );
                          cyclePhaseText = calc.currentPhase;
                          cycleDayText = "Day ${calc.currentCycleDay}";
                          progressVal = ((DateTime.now().difference(pStart).inDays % (pc.cycleLength ?? 28)) / (pc.cycleLength ?? 28)).clamp(0.0, 1.0);
                        } else {
                          cyclePhaseText = "Cycle Tracking";
                          cycleDayText = "Not Logged";
                          progressVal = 0.0;
                        }

                        final String sleepText = (wb.sleepQuality != null && wb.sleepQuality! > 0) 
                            ? "${wb.sleepQuality}h logged" 
                            : "Not Logged";

                        // Show what she picked, not the number it was scored as.
                        //
                        // The check-in offers words -- High/Medium/Low, and
                        // Happy/Okay/Cramps/Tired/Irritable -- and stores the
                        // label alongside a score used for charting. This card
                        // read only the score, so choosing "High" came back as
                        // "Level 2/10": a number she was never shown, against a
                        // scale she was never given. The home page already
                        // prefers the label; this now matches it.
                        final checkin = BlushyStorage.read('daily_checkin.json');
                        final String savedEnergy =
                            checkin['energy']?.toString().trim() ?? '';
                        final String savedMood =
                            (checkin['feeling'] ?? checkin['mood'])
                                    ?.toString()
                                    .trim() ??
                                '';

                        final String energyText = savedEnergy.isNotEmpty
                            ? savedEnergy
                            : (wb.energy != null && wb.energy! > 0)
                                ? "Level ${wb.energy}/10"
                                : "Not Logged";

                        final String moodText = savedMood.isNotEmpty
                            ? savedMood
                            : (wb.mood != null && wb.mood! > 0)
                                ? "Level ${wb.mood}/10"
                                : (wb.symptoms.isNotEmpty
                                    ? wb.symptoms.first
                                    : "Not Logged");

                        // Matched against the labels the picker actually
                        // offers. While this card showed "Level 4/10" none of
                        // these could ever match, so every mood drew the same
                        // face.
                        final String moodKey = moodText.toLowerCase();
                        String moodEmoji = "😌";
                        if (moodKey.contains("happy")) moodEmoji = "😊";
                        if (moodKey.contains("okay")) moodEmoji = "🙂";
                        if (moodKey.contains("cramp")) moodEmoji = "😖";
                        if (moodKey.contains("tired")) moodEmoji = "🥱";
                        if (moodKey.contains("anxious")) moodEmoji = "😰";
                        if (moodKey.contains("sleep")) moodEmoji = "😴";
                        if (moodKey.contains("irrit")) moodEmoji = "😤";
                        if (moodText == "Not Logged") moodEmoji = "📋";

                        String stageStr = 'everydayWellness';
                        try {
                          final profileData = BlushyStorage.read('user_profile.json');
                          final answers = profileData['profile'] ?? profileData ?? {};
                          stageStr = (pc.lifeStage ?? answers['lifeStage'] ?? answers['life_stage'] ?? 'everydayWellness')
                              .toString()
                              .trim()
                              .replaceAll('_', '')
                              .replaceAll(' ', '')
                              .toLowerCase();
                        } catch (_) {}

                        final String card1Title;
                        final String card1Value;
                        final Widget card1Body;

                        if (stageStr == 'pregnancy' || stageStr == 'pregnant') {
                          final int weeks = pc.dueDate != null
                              ? (40 - (pc.dueDate!.difference(DateTime.now()).inDays / 7).floor()).clamp(1, 40)
                              : 24;
                          final int trimester = weeks <= 12 ? 1 : (weeks <= 27 ? 2 : 3);
                          card1Title = "Trimester $trimester • Week $weeks";
                          card1Value = pc.dueDate != null ? "Due ${pc.dueDate!.month}/${pc.dueDate!.day}" : "Pregnancy Stage";
                          card1Body = Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.child_care_rounded, size: 28, color: BlushyColors.primary),
                                const SizedBox(height: 4),
                                Text("Week $weeks", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                              ],
                            ),
                          );
                        } else if (stageStr == 'postpartum') {
                          card1Title = "Postpartum Journey";
                          card1Value = "Fourth Trimester";
                          card1Body = Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.favorite_rounded, size: 28, color: BlushyColors.primary),
                                const SizedBox(height: 4),
                                Text("Recovery Phase", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                              ],
                            ),
                          );
                        } else if (stageStr == 'tryingtoconceive' || stageStr == 'ttc') {
                          card1Title = "Fertility Journey";
                          card1Value = pStart != null
                              ? "Day ${CycleCalculation.compute(lastPeriodStart: pStart, cycleLength: pc.cycleLength ?? 28).currentCycleDay}"
                              : "TTC Active";
                          card1Body = Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.favorite_border_rounded, size: 28, color: BlushyColors.primary),
                                const SizedBox(height: 4),
                                Text("Fertility Tracking", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                              ],
                            ),
                          );
                        } else if (stageStr == 'perimenopause' || stageStr == 'menopause') {
                          card1Title = stageStr == 'perimenopause' ? "Perimenopause" : "Menopause";
                          card1Value = "Hormonal Health";
                          card1Body = Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.spa_rounded, size: 28, color: BlushyColors.primary),
                                const SizedBox(height: 4),
                                Text("Wellness Balance", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                              ],
                            ),
                          );
                        } else {
                          card1Title = cyclePhaseText;
                          card1Value = cycleDayText;
                          card1Body = SizedBox(
                            height: 42,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: 160,
                                height: 60,
                                child: CustomPaint(
                                  painter: SignatureCyclePathPainter(
                                    progress: progressVal,
                                    activePhase: cyclePhaseText,
                                    cycleLength: pc.cycleLength ?? 28,
                                    periodLength: 5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final normalizedStage = (state.personalContext.lifeStage ?? state.selectedRole).toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
                        final bool shouldHideSleep = normalizedStage.contains('notstarted') ||
                            normalizedStage.contains('firstperiod') ||
                            normalizedStage.contains('tryingtoconceive') ||
                            normalizedStage.contains('ttc');

                        final double screenWidth = MediaQuery.of(context).size.width;
                        final int responsiveColumns = shouldHideSleep
                            ? (screenWidth > 900 ? 3 : (screenWidth > 600 ? 3 : 1))
                            : (screenWidth > 900 ? 4 : 2);
                        final double responsiveAspectRatio = shouldHideSleep
                            ? (screenWidth > 900 ? 1.55 : (screenWidth > 600 ? 1.4 : 1.2))
                            : (screenWidth > 900 ? 1.35 : (screenWidth > 600 ? 1.45 : 1.15));

                        final contextCards = <Widget>[
                          // 1. Stage-Adaptive Context Card
                          _buildEditorialContextCard(
                            title: card1Title,
                            body: card1Body,
                            value: card1Value,
                            onTap: () {
                              if (widget.onRedirectToCycle != null) {
                                widget.onRedirectToCycle!();
                              } else {
                                _showCycleDetailsModal(context, state, card1Title, card1Value);
                              }
                            },
                          ),

                          // 2. Sleep Card (Only shown if sleep is required for this stage)
                          if (!shouldHideSleep)
                            _buildEditorialContextCard(
                              title: AppLocalizations.of(context).sSleep,
                              body: _MiniWeeklySleepBarChart(sleepVal: sleepText),
                              value: sleepText,
                              onTap: () {
                                if (widget.onRedirectToSleep != null) {
                                  widget.onRedirectToSleep!();
                                } else {
                                  _showSleepCheckInModal(context, state, sleepText);
                                }
                              },
                            ),

                          // 3. Energy Card with Redirection
                          _buildEditorialContextCard(
                            title: AppLocalizations.of(context).sEnergy,
                            body: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 22, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  energyText,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                ),
                              ],
                            ),
                            value: energyText,
                            onTap: () {
                              if (widget.onRedirectToEnergy != null) {
                                widget.onRedirectToEnergy!();
                              } else {
                                _showEnergyCheckInModal(context, state);
                              }
                            },
                          ),

                          // 4. Mood Card with Redirection
                          _buildEditorialContextCard(
                            title: AppLocalizations.of(context).sMood,
                            body: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  moodEmoji,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  moodText,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                ),
                              ],
                            ),
                            value: moodText,
                            onTap: () {
                              if (widget.onRedirectToMood != null) {
                                widget.onRedirectToMood!();
                              } else {
                                _showMoodCheckInModal(context, state);
                              }
                            },
                          ),
                        ];

                        return GridView.count(
                          crossAxisCount: responsiveColumns,
                          shrinkWrap: true,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: responsiveAspectRatio,
                          physics: const NeverScrollableScrollPhysics(),
                          children: contextCards,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 5. Chat timeline or suggestions
                    if (_messages.isEmpty && !_isThinking) ...[
                      Text(
                        AppLocalizations.of(context).siaConversationStarters,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildStarterChip('Explain today\'s fatigue'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Create today\'s recovery plan'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Compare with last month'),
                            const SizedBox(width: 8),
                            _buildStarterChip('Why am I emotional today?'),
                          ],
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: [
                          ..._messages.map((msg) => _buildMessageBubble(msg)),
                          if (_isThinking) _buildThinkingBubble(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),

                    // 6. Continuous Premium Editorial Sections (Dynamic from MongoDB)
                    Builder(
                      builder: (context) {
                        final pc = state.personalContext;
                        final stageKey = pc.lifeStage ?? state.selectedRole;
                        final stageConfig = StageConfig.forStage(stageKey);

                        DateTime? periodStart = pc.lastPeriodStart;
                        if (periodStart == null) {
                          try {
                            final profileData = BlushyStorage.read('user_profile.json');
                            final answers = profileData['profile'] ?? profileData ?? {};
                            final pStr = answers['period_last_start_date'] ?? answers['lastPeriodStart'] ?? answers['last_period'];
                            if (pStr != null) {
                              periodStart = DateTime.tryParse(pStr.toString());
                            }
                          } catch (_) {}
                        }

                        final calc = CycleCalculation.compute(
                          lastPeriodStart: periodStart,
                          cycleLength: pc.cycleLength ?? 28,
                        );
                        final String activePhase = calc.hasData ? calc.currentPhase : stageConfig.displayName;


                        // Dynamic 4: Community discussion text
                        // The count here was invented too; nothing tallies community activity.
                        final String communityDesc = "People are sharing their ${stageConfig.displayName} and $activePhase experiences. Tap to join the discussion.";

                        return Column(
                          children: [
                            _buildJournalContinuousSection(
                              "Community Discussion",
                              communityDesc,
                              Icons.forum_outlined,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => state.selectedRole == 'partner'
                                        ? const PartnerCommunityScreen()
                                        : const BlushyCommunityScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 7. Redesigned alive chat input panel
            _buildInputControlPanel(),
          ],
        ),
      ),
    ),
  );
}

  void _showMoodCheckInModal(BuildContext context, BlushyOSState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<Map<String, dynamic>> moods = [
          {'emoji': '😌', 'label': 'Balanced', 'level': 7},
          {'emoji': '🥱', 'label': 'Tired', 'level': 4},
          {'emoji': '😴', 'label': 'Sleepy', 'level': 3},
          {'emoji': '😰', 'label': 'Anxious', 'level': 3},
          {'emoji': '😤', 'label': 'Irritated', 'level': 2},
          {'emoji': '💖', 'label': 'Happy', 'level': 9},
          {'emoji': '🧘', 'label': 'Calm', 'level': 8},
          {'emoji': '🌧️', 'label': 'Sad', 'level': 2},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('😌', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).siaHowFeelingToday,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: moods.map((m) {
                  final label = m['label'] as String;
                  final emoji = m['emoji'] as String;
                  final level = m['level'] as int;
                  return InkWell(
                    onTap: () {
                      state.updateWellbeing(mood: level, symptoms: [label]);
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logged mood: $emoji $label')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEnergyCheckInModal(BuildContext context, BlushyOSState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<Map<String, dynamic>> energies = [
          {'icon': Icons.battery_1_bar_rounded, 'label': 'Very Low', 'level': 2, 'color': Colors.red},
          {'icon': Icons.battery_3_bar_rounded, 'label': 'Low', 'level': 4, 'color': Colors.orange},
          {'icon': Icons.bolt_rounded, 'label': 'Balanced', 'level': 6, 'color': const Color(0xFFF59E0B)},
          {'icon': Icons.battery_full_rounded, 'label': 'High', 'level': 8, 'color': Colors.green},
          {'icon': Icons.rocket_launch_rounded, 'label': 'Peak', 'level': 10, 'color': Colors.purple},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).siaEnergyLevel,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: energies.map((e) {
                  final label = e['label'] as String;
                  final level = e['level'] as int;
                  final icon = e['icon'] as IconData;
                  final color = e['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        state.updateWellbeing(energy: level);
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged energy: $label ($level/10)')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BlushyColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 22),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                            ),
                            const Spacer(),
                            Text(
                              'Level $level/10',
                              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSleepCheckInModal(BuildContext context, BlushyOSState state, String currentSleep) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<double> sleepOptions = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bedtime_rounded, color: Color(0xFF6F42F5), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).siaLogSleep,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select how many hours of rest you logged last night:',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sleepOptions.map((hours) {
                  return InkWell(
                    onTap: () {
                      state.updateWellbeing(sleepQuality: hours.toInt());
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logged sleep: ${hours}h')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${hours}h',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCycleDetailsModal(BuildContext context, BlushyOSState state, String phaseText, String dayText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pc = state.personalContext;
        final cycleLen = pc.cycleLength ?? 28;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: BlushyColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Cycle Phase Overview',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlushyColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$phaseText • $dayText',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Average Cycle Length: $cycleLen days',
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'During the $phaseText, your progesterone levels peak. Gentle walks, hydration, and light stretching can help manage any energy dips.',
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    // Resolved before the date picker awaits, for the same
                    // reason messenger is: the context may be gone after.
                    final recordedMessage = AppLocalizations.of(context).siaPeriodRecorded;
                    final couldNotSaveMessage = AppLocalizations.of(context).stateCouldNotSave;
                    final nav = Navigator.of(ctx);
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: pc.lastPeriodStart ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      nav.pop();
                      state.updatePersonalContext(pc.copyWith(lastPeriodStart: picked));

                      var saved = false;
                      try {
                        final profileData = BlushyStorage.read('user_profile.json');
                        final profileMap = Map<String, dynamic>.from(profileData['profile'] ?? profileData);
                        profileMap['period_last_start_date'] = picked.toIso8601String();
                        profileMap['last_period'] = picked.toIso8601String();
                        BlushyStorage.write('user_profile.json', {'profile': profileMap});
                        // The result decides. This awaited the call and then
                        // set saved = true regardless, so a refused write --
                        // which returns null rather than throwing -- still
                        // told her the date had been recorded, while the
                        // server kept predicting from the old one.
                        final entry = await ApiPeriodService()
                            .logPeriodEntry(periodStartDate: picked, source: 'sia_drawer');
                        saved = entry != null;
                      } catch (_) {
                        // Falls through to the failure message below. This used
                        // to be swallowed silently, so a failed write still
                        // told her the date had been recorded.
                      }

                      if (saved) {
                        // The dashboard keeps its own copy of the cycle, fetched
                        // from the server, and updating PersonalContext does not
                        // invalidate it. Without this the chart kept showing the
                        // old cycle until something else happened to reload it.
                        //
                        // Home refreshes when Sia is closed, but only when Sia
                        // was pushed as a route from the home FAB -- reaching it
                        // from the bottom navigation is a tab switch, which pops
                        // nothing and so refreshed nothing.
                        SiaDashboardService().markDashboardDirty();
                      }

                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(saved ? recordedMessage : couldNotSaveMessage)),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).siaLogPeriodStart, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorialContextCard({
    required String title,
    required Widget body,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: BlushyColors.primary),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: body,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: BlushyColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalContinuousSection(String title, String desc, IconData icon, {VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.text.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap ?? () {
            if (title.contains("Journal")) {
              _showJournalPromptSheet(context, desc);
            } else if (title.contains("Voice")) {
              VoiceNoteBottomSheet.show(context);
            } else {
              _sendUserMessage(desc);
            }
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: const Color(0xFF6F42F5),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6F42F5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 20, color: const Color(0xFF6F42F5)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BlushyColors.secondaryText),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                desc,
                                style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJournalPromptSheet(BuildContext context, String prompt) {
    final textController = TextEditingController();
    String selectedMood = 'Reflective';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
                maxWidth: 640,
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF6F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: BlushyColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6F42F5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF6F42F5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).siaDailyReflection,
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Text(
                                AppLocalizations.of(context).sSavesDirectlyToYour,
                                style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prompt card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF6F42F5).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            "“$prompt”",
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6F42F5), height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mood Pills
                        Text(
                          "HOW ARE YOU FEELING RIGHT NOW?",
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Reflective', 'Calm', 'Joyful', 'Tired', 'Anxious', 'Grounded'].map((mood) {
                            final isSel = selectedMood == mood;
                            return InkWell(
                              onTap: () => setModalState(() => selectedMood = mood),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF6F42F5) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSel ? const Color(0xFF6F42F5) : BlushyColors.border),
                                ),
                                child: Text(
                                  mood,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white : BlushyColors.text,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Text Field
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: BlushyColors.border),
                          ),
                          child: TextField(
                            controller: textController,
                            maxLines: 5,
                            style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).sWriteYourThoughtsBody,
                              hintStyle: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(modalCtx);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const BlushyJournalScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                                  label: Text(AppLocalizations.of(context).siaOpenJournal, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: BlushyColors.text,
                                    side: const BorderSide(color: BlushyColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final text = textController.text.trim();
                                    if (text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context).siaWriteBeforeSaving)),
                                      );
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(context);

                                    // Into the journal store the journal screen
                                    // reads. addJournal writes to a list whose
                                    // only reader is dead code, so entries saved
                                    // here never appeared anywhere.
                                    final saved = await JournalQuickEntry.save(
                                      text: text,
                                      title: prompt.isNotEmpty ? prompt : 'Reflection',
                                      moodKey: selectedMood,
                                    );

                                    ApiAuthService().saveOnboardingAnswers({
                                      'last_journal_prompt': prompt,
                                      'last_journal_entry': text,
                                      'last_journal_mood': selectedMood,
                                      'last_journal_timestamp': DateTime.now().toIso8601String(),
                                    }).catchError((_) => <String, dynamic>{});

                                    if (!saved) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not save your entry. Please try again.'),
                                        ),
                                      );
                                      return;
                                    }

                                    if (modalCtx.mounted) Navigator.pop(modalCtx);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('✨ Your journal entry has been saved!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6F42F5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    AppLocalizations.of(context).siaSaveEntry,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStarterChip(String label) {
    return GestureDetector(
      onTap: () => _sendUserMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ),
    );
  }

  /// Reviewed safety guidance, shown instead of a chat bubble.
  ///
  /// This wording comes from the clinically reviewed red flag rule, not from
  /// the model, so it is presented distinctly rather than as something Dr. Docsy
  /// said.
  Widget _buildSafetyMessage(Map<String, String> msg) {
    final bool urgent = msg['level'] == 'emergency';
    final Color accent = urgent ? const Color(0xFFB3261E) : const Color(0xFFB26A00);
    final resources = (msg['resources'] ?? '').split('\n').where((r) => r.trim().isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(urgent ? Icons.emergency_outlined : Icons.warning_amber_rounded,
                    color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg['title'] ?? 'Please seek care',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              msg['text'] ?? '',
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: const Color(0xFF2B2B2B)),
            ),
            if (msg['emergencyNumber'] != null) ...[
              const SizedBox(height: 14),
              Text(
                'Emergency number: ${msg['emergencyNumber']}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
              ),
            ],
            if (resources.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...resources.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    r,
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5A5A5A)),
                  ),
                ),
              ),
            ],
            if (msg['source'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Source: ${msg['source']}',
                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF8A8A8A)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shares one Dr. Docsy exchange with a partner, or takes it back.
  ///
  /// Dr. Docsy is where people say the things they have not told anyone, so this is
  /// per exchange and never a blanket release. It also only reaches a partner
  /// who holds the `sia_conversations` permission -- both gates must be open.
  Widget _buildShareExchangeButton(Map<String, String> msg) {
    final conversationId = msg['conversationId'] ?? '';
    // A message that has not been persisted yet has no id to share.
    if (conversationId.isEmpty) return const SizedBox.shrink();

    final shared = msg['shared'] == '1';
    final busy = _sharingConversationIds.contains(conversationId);

    return InkWell(
      onTap: busy ? null : () => _toggleExchangeShared(conversationId, !shared),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shared ? Icons.people_alt_rounded : Icons.people_outline_rounded,
                    size: 13,
                    color: shared ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    shared ? 'Shared' : 'Share',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: shared ? FontWeight.w700 : FontWeight.w500,
                      color: shared ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _toggleExchangeShared(String conversationId, bool shared) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharingConversationIds.add(conversationId));

    final ok = await ApiAuthService().setSiaConversationShared(
      conversationId: conversationId,
      shared: shared,
    );

    if (!mounted) return;
    setState(() {
      _sharingConversationIds.remove(conversationId);
      if (ok) {
        // Both halves of the exchange carry the same id, so both flip.
        for (final message in _messages) {
          if (message['conversationId'] == conversationId) {
            message['shared'] = shared ? '1' : '0';
          }
        }
      }
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'Could not change sharing for that message.'
              : shared
                  ? 'Shared. Your partner sees this only if you have turned on Dr. Docsy conversation sharing for them.'
                  : 'No longer shared.',
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    if (msg['sender'] == 'safety') {
      return _buildSafetyMessage(msg);
    }

    final text = msg['text']?.trim() ?? '';
    if (text.isEmpty && msg['rich'] == null) {
      return const SizedBox.shrink();
    }
    final isSia = msg['sender'] == 'sia';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Align(
        alignment: isSia ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSia ? Colors.white : const Color(0xFFF3EFEA),
            borderRadius: BorderRadius.circular(24),
            border: isSia ? Border.all(color: BlushyColors.border) : null,
            boxShadow: [
              BoxShadow(
                color: BlushyColors.text.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isSia ? 'Dr. Docsy Companion' : 'You',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSia ? const Color(0xFF6F42F5) : BlushyColors.text,
                    ),
                  ),
                  const Spacer(),
                  // Only on Dr. Docsy's side of an exchange: the pair is one stored
                  // conversation, so one control shares the whole exchange
                  // rather than offering the same thing twice.
                  if (isSia) _buildShareExchangeButton(msg),
                ],
              ),
              if (msg['fileName'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF6F42F5).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        msg['isPdf'] == 'true' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        size: 18,
                        color: msg['isPdf'] == 'true' ? const Color(0xFFDC2626) : const Color(0xFF6F42F5),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "${msg['fileName']} • ${msg['fileSize'] ?? ''}",
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: BlushyColors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (msg['analyzedFile'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F42F5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF6F42F5)),
                      const SizedBox(width: 6),
                      Text(
                        "Analysis of ${msg['analyzedFile']}",
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF6F42F5)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                msg['text'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: BlushyColors.text,
                  height: 1.45,
                ),
              ),
              if (isSia && msg['rich'] != null) ...[
                const SizedBox(height: 16),
                _buildRichComponent(msg['rich']!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichComponent(String type) {
    if (type == 'checklist') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).sLutealRecoveryActionChecklist,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildCheckItem('Log afternoon hydration intake', true),
            _buildCheckItem('calming breathing cycle (5 minutes)', false),
            _buildCheckItem('Plan light evening stretching routine', false),
          ],
        ),
      );
    }

    if (type == 'breathe') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6F42F5).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Color(0xFF6F42F5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calm Breathing Exercise',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6F42F5)),
                  ),
                  Text(
                    'A slow breathing exercise • 5 min',
                    style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'community') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFADCDC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: BlushyColors.primary, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Community',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // This read "4,281 women reported similar symptoms in their late
              // luteal cycles. 78% found relief by increasing iron-rich
              // nutrition." Both numbers were invented, and the second is an
              // efficacy claim someone could act on. Nothing counted them and
              // no study was behind them, so the card now points at the real
              // community rather than quoting figures that do not exist.
              'Other people are talking about how they feel at this point in their cycle. Tap to read the discussion.',
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCheckItem(String label, bool initialChecked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            initialChecked ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            color: initialChecked ? BlushyColors.success : BlushyColors.secondaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: initialChecked ? BlushyColors.secondaryText : BlushyColors.text,
                decoration: initialChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6F42F5)),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).siaThinking,
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputControlPanel() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: BlushyTheme.getPagePadding(context),
        vertical: 16.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BlushyColors.border),
        boxShadow: const [
          BoxShadow(
            color: BlushyColors.shadow,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isListeningVoice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (index) {
                final randomHeight = 5.0 + math.Random().nextDouble() * 25.0;
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    final heightFactor = math.sin(_waveController.value * 2.0 * math.pi + index) * 8.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 3,
                      height: (randomHeight + heightFactor).clamp(4.0, 32.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Recording voice... 00:${_recordingSeconds.toString().padLeft(2, '0')} (Tap Mic to finish)',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
            ),
            const SizedBox(height: 8),
          ],
          
          if (_attachedFile != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6F42F5).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _attachedFile!.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: _attachedFile!.isPdf ? const Color(0xFFDC2626) : const Color(0xFF6F42F5),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachedFile!.name,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${_attachedFile!.formattedSize} • Ready for Dr. Docsy review",
                          style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: BlushyColors.secondaryText),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _attachedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              GestureDetector(
                onTap: () => _showAttachmentOptionsModal(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _attachedFile != null ? const Color(0xFF6F42F5).withValues(alpha: 0.1) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _attachedFile != null ? Icons.add_circle_rounded : Icons.add_circle_outline_rounded,
                    color: _attachedFile != null ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text),
                    decoration: InputDecoration(
                      hintText: _attachedFile != null
                          ? "Ask Dr. Docsy about ${_attachedFile!.name}..."
                          : _placeholders[_placeholderIndex],
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: _sendUserMessage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_chatController.text.isNotEmpty || _attachedFile != null) {
                    _sendUserMessage(_chatController.text);
                  } else {
                    _toggleVoiceRecording();
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isListeningVoice 
                        ? const Color(0xFFDD0D22) 
                        : const Color(0xFF6F42F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (_chatController.text.isNotEmpty || _attachedFile != null)
                        ? Icons.send_rounded 
                        : (_isListeningVoice ? Icons.stop_rounded : Icons.mic_rounded),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SiaBreathingOrb extends StatefulWidget {
  const _SiaBreathingOrb();

  @override
  State<_SiaBreathingOrb> createState() => _SiaBreathingOrbState();
}

class _SiaBreathingOrbState extends State<_SiaBreathingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.15);
        final opacity = 0.2 + (_controller.value * 0.3);
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: opacity),
                const Color(0xFFC084FC).withValues(alpha: 0.0),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), BlushyColors.secondary],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniWeeklySleepBarChart extends StatefulWidget {
  final String? sleepVal;
  const _MiniWeeklySleepBarChart({this.sleepVal});

  @override
  State<_MiniWeeklySleepBarChart> createState() => _MiniWeeklySleepBarChartState();
}

class _MiniWeeklySleepBarChartState extends State<_MiniWeeklySleepBarChart> {
  /// Real sleep for the last seven days. Only today used to be real; the other
  /// six were hardcoded to zero, so logged nights were shown as blank and the
  /// average was divided by seven regardless.
  Map<String, double> _hoursByDay = const {};

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    final from = DateTime.now().subtract(const Duration(days: 6));
    final result = await EventsApi.timeline(
      eventTypes: const ['sleep_logged'],
      from: DateTime(from.year, from.month, from.day),
      limit: 50,
    );
    if (!mounted) return;

    final byDay = <String, double>{};
    for (final entry in result.data?.entries ?? const []) {
      final hours = (entry.detail['durationHours'] ?? entry.detail['duration']) as num?;
      if (hours == null) continue;
      final key = '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      // Latest entry for a day wins, matching how a re-log replaces the value.
      byDay.putIfAbsent(key, () => hours.toDouble());
    }

    setState(() => _hoursByDay = byDay);
  }

  double _hoursFor(DateTime day) =>
      _hoursByDay['${day.year}-${day.month}-${day.day}'] ?? 0.0;

  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final bool isLogged = widget.sleepVal != null && widget.sleepVal != "Not Logged";
    final double loggedHours = isLogged
        ? (double.tryParse(widget.sleepVal!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0)
        : 0.0;

    // The last seven days ending today, each from what was actually logged.
    const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    final List<Map<String, dynamic>> days = [
      for (var back = 6; back >= 0; back--)
        () {
          final day = today.subtract(Duration(days: back));
          // Today prefers the value already on screen, so the chart agrees with
          // the card above it even before the week finishes loading.
          final hours = back == 0 && isLogged ? loggedHours : _hoursFor(day);
          return {
            'day': initials[day.weekday - 1],
            'hours': hours,
            'quality': hours > 0 ? 'Recorded' : 'Unlogged',
            'isToday': back == 0,
          };
        }(),
    ];

    // Averaged over the nights that were logged, not over seven. Dividing by
    // seven made a single good night look like a poor week.
    final logged = days.where((d) => (d['hours'] as num) > 0).toList();
    final double totalHours =
        logged.fold(0.0, (sum, d) => sum + (d['hours'] as num).toDouble());
    final double avgHours = logged.isEmpty ? 0.0 : totalHours / logged.length;
    const double targetHours = 8.0;
    const double maxScale = 10.0;
    const double chartBarAreaHeight = 28.0;

    return Container(
      // This is rendered inside a FittedBox, which hands its child unbounded
      // width. The Rows below use Flexible and Expanded, which cannot divide an
      // infinite width -- without a definite width here the whole card fails to
      // lay out. The sibling card does the same thing with its CustomPaint.
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3E4DD), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "SLEEP",
                  style: GoogleFonts.poppins(
                    fontSize: 7.0,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.secondaryText,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                "${avgHours.toStringAsFixed(1)}h",
                style: GoogleFonts.poppins(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Main Bar Graph Canvas
          SizedBox(
            height: chartBarAreaHeight + 28,
            child: Stack(
              children: [
                // Dashed 8h Target Line
                Positioned(
                  left: 0,
                  right: 0,
                  top: chartBarAreaHeight * (1.0 - (targetHours / maxScale)),
                  child: Row(
                    children: List.generate(
                      18,
                      (index) => Expanded(
                        child: Container(
                          height: 1,
                          color: (index % 2 == 0)
                              ? const Color(0xFF6F42F5).withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bars Row
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final d = entry.value;
                      final double h = (d['hours'] as num).toDouble();
                      final bool isToday = d['isToday'] as bool;
                      final bool isSelected = _selectedBarIndex == idx;
                      final double barHeight = ((h / maxScale) * chartBarAreaHeight).clamp(10.0, chartBarAreaHeight);

                      final bool isLogged = d['quality'] != 'Unlogged' && h > 0;
                      final bool isActiveToday = isToday && isLogged;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBarIndex = isSelected ? null : idx;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Hours badge on top of bar
                            Text(
                              "${h.toStringAsFixed(1)}h",
                              style: GoogleFonts.poppins(
                                fontSize: 7.5,
                                fontWeight: (isActiveToday || isSelected) ? FontWeight.bold : FontWeight.w500,
                                color: (isActiveToday || isSelected) ? BlushyColors.primary : BlushyColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 1),

                            // Animated Bar Column
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 16 : 12,
                              height: barHeight,
                              decoration: BoxDecoration(
                                gradient: isActiveToday
                                    ? const LinearGradient(
                                        colors: [Color(0xFF6F42F5), Color(0xFFF76B8A)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      )
                                    : LinearGradient(
                                        colors: isSelected
                                            ? [const Color(0xFFF76B8A), const Color(0xFFFFB3C6)]
                                            : [const Color(0xFFEADBCE), const Color(0xFFF3E4DD)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                boxShadow: isActiveToday || isSelected
                                    ? [
                                        BoxShadow(
                                          color: BlushyColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 1),

                            // Day Label below bar
                            Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: isActiveToday
                                  ? const BoxDecoration(
                                      color: BlushyColors.primary,
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Text(
                                d['day'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 7.5,
                                  fontWeight: isActiveToday ? FontWeight.bold : FontWeight.w600,
                                  color: isActiveToday ? Colors.white : BlushyColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedBarIndex != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bedtime_rounded, size: 16, color: Color(0xFF6F42F5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${days[_selectedBarIndex!]['day']} Sleep: ${days[_selectedBarIndex!]['hours']} Hours • ${days[_selectedBarIndex!]['quality']}",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
