import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../core/state.dart';
import '../../core/stage_config.dart';
import '../../core/storage.dart';
import '../../services/journal_storage.dart';
import '../../services/api_auth_service.dart';
import '../../services/html_audio_helper.dart';
import '../../services/html_file_helper.dart';
import '../../services/api_sia_service.dart';
import 'journal_cover_widget.dart';
import 'desk_environment_widget.dart';
import 'journal_ambient_audio.dart';
import 'engine/scrapbook_animation_engine.dart';
import 'ai/insight_scheduler.dart';
import 'ai/memory_highlights_service.dart';
import 'ai/mood_timeline_service.dart';
import 'ai/reflection_service.dart';
import 'ai/memory_connections_service.dart';
import 'ai/smart_search_service.dart';
import 'ai/journal_title_service.dart';
import 'ai/prompt_service.dart';
import 'ai/memory_book_service.dart';
import 'vault/memory_vault.dart';
import 'vault/year_in_review.dart';
import 'vault/time_capsule.dart';
import 'calendar/memory_map.dart';
import 'insights/achievement_garden.dart';
import 'insights/journal_dashboard.dart';
import 'themes/theme_marketplace.dart';
import 'backup/backup_service.dart';
import 'export/export_service.dart';
import 'settings/journal_settings_screen.dart';
import 'controller/journal_controller.dart';
import '../../services/api_blushy_service.dart';
import '../../services/api_contract_client.dart';
import '../../services/offline_event_queue.dart';
import 'journal_templates.dart';

/// Wide enough to fill a phone screen, small enough that a page of photos
/// does not make the entry too large to sync.
const int _journalPhotoMaxWidth = 1280;

/// Vertical gap between a template's prompts. Enough to write an answer
/// under each without the next question landing on top of it.
const double _promptSpacing = 96;

class ScrapbookItem {
  final String id;
  final String type; // 'sticker', 'photo', 'text', 'voice', 'tape', 'ai_insight'
  dynamic content;
  Offset position;
  double scale;
  double rotation;
  int zIndex;
  Color? customColor;

  ScrapbookItem({
    required this.id,
    required this.type,
    required this.content,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
    this.customColor,
  });

  ScrapbookItem copyWith({
    String? id,
    String? type,
    dynamic content,
    Offset? position,
    double? scale,
    double? rotation,
    int? zIndex,
    Color? customColor,
  }) {
    return ScrapbookItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      customColor: customColor ?? this.customColor,
    );
  }
}

class JournalEntryItem {
  final String id;
  final String title;
  final DateTime dateTime;
  final List<ScrapbookItem> items;
  final String themeName;
  final String fontName;
  final String templateName;
  final String moodKey;

  JournalEntryItem({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.items,
    this.themeName = 'Cream Paper',
    this.fontName = 'Handwriting',
    this.templateName = 'Daily Reflection',
    this.moodKey = 'satisfied',
  });

  JournalEntryItem copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    List<ScrapbookItem>? items,
    String? themeName,
    String? fontName,
    String? templateName,
    String? moodKey,
  }) {
    return JournalEntryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      items: items ?? List.from(this.items),
      themeName: themeName ?? this.themeName,
      fontName: fontName ?? this.fontName,
      templateName: templateName ?? this.templateName,
      moodKey: moodKey ?? this.moodKey,
    );
  }
}

Map<String, dynamic> scrapbookItemToJson(ScrapbookItem item) {
  dynamic contentJson;
  if (item.type == 'sticker') {
    final stickerMap = item.content as Map<String, dynamic>;
    contentJson = {
      'name': stickerMap['name'],
      'iconCodePoint': (stickerMap['icon'] as IconData).codePoint,
      // Present once a sticker is backed by artwork rather than a Material
      // glyph. Stored per item so an entry keeps the sticker it was made with
      // even if the set is later changed.
      if (stickerMap['asset'] != null) 'asset': stickerMap['asset'],
      'colorValue': (stickerMap['color'] as Color).toARGB32(),
    };
  } else if (item.type == 'tape') {
    contentJson = (item.content as Color).toARGB32();
  } else {
    contentJson = item.content;
  }

  return {
    'id': item.id,
    'type': item.type,
    'content': contentJson,
    'positionDx': item.position.dx,
    'positionDy': item.position.dy,
    'scale': item.scale,
    'rotation': item.rotation,
    'zIndex': item.zIndex,
    'customColor': item.customColor?.toARGB32(),
  };
}

ScrapbookItem scrapbookItemFromJson(Map<String, dynamic> json) {
  final String id = json['id'] as String;
  final String type = json['type'] as String;
  dynamic content;

  if (type == 'sticker') {
    final stickerMap = json['content'] as Map<String, dynamic>;
    final String name = stickerMap['name'] as String;
    final int colorValue = stickerMap['colorValue'] as int? ?? 0xFFE57373;
    IconData resolveIcon(String name) {
      if (name.contains('Flower')) return Icons.local_florist_rounded;
      if (name.contains('Butterfly')) return Icons.flutter_dash_rounded;
      if (name.contains('Moon')) return Icons.dark_mode_rounded;
      if (name.contains('Star')) return Icons.star_rounded;
      if (name.contains('Coffee')) return Icons.coffee_rounded;
      if (name.contains('Books')) return Icons.menu_book_rounded;
      if (name.contains('Leaf')) return Icons.eco_rounded;
      return Icons.favorite_rounded;
    }
    content = {
      'name': name,
      // Resolved by name rather than from the stored code point on purpose:
      // Flutter's icon tree-shaking requires IconData to be constant, and
      // rebuilding one from a saved integer defeats it.
      'icon': resolveIcon(name),
      'asset': stickerMap['asset'],
      'color': Color(colorValue),
    };
  } else if (type == 'tape') {
    content = Color(json['content'] as int);
  } else {
    content = json['content'];
  }

  return ScrapbookItem(
    id: id,
    type: type,
    content: content,
    position: Offset(
      (json['positionDx'] as num).toDouble(),
      (json['positionDy'] as num).toDouble(),
    ),
    scale: (json['scale'] as num).toDouble(),
    rotation: (json['rotation'] as num).toDouble(),
    zIndex: json['zIndex'] as int,
    customColor: json['customColor'] != null ? Color(json['customColor'] as int) : null,
  );
}

class BlushyJournalScreen extends StatefulWidget {
  final bool isEmbedded;
  const BlushyJournalScreen({super.key, this.isEmbedded = false});

  @override
  State<BlushyJournalScreen> createState() => BlushyJournalScreenState();
}

class BlushyJournalScreenState extends State<BlushyJournalScreen> with TickerProviderStateMixin {
  void openNewEntryBottomSheet() {
    _showCreateOptionsBottomSheet();
  }
  final List<JournalEntryItem> _entries = [];

  /// Days the user has chosen to make available to a partner, and the ones
  /// currently being written. Sharing is per day, never a blanket release.
  final Set<String> _sharedJournalDates = <String>{};
  final Set<String> _sharingJournalDates = <String>{};
  String? _currentEntryId;

  String _activeTheme = 'Cream Paper';
  String _activeFont = 'Handwriting';
  String _activeTemplate = 'Daily Reflection';

  final List<ScrapbookItem> _items = [];
  String? _selectedItemId;
  int _itemCounter = 0;
  HtmlAudioRecorder? _audioRecorder;
  HtmlAudioPlayer? _audioPlayer;
  String? _playingVoiceItemId;
  final Map<String, TextEditingController> _textControllers = {};

  String _selectedMoodKey = 'satisfied';
  late TextEditingController _titleController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _journalStorage = JournalStorage();
  final _apiSiaService = ApiSiaService();

  /// Null until the server has a reflection drawn from real entries.
  ///
  /// This used to default to "Estrogen is naturally rising. Your focus and
  /// mental clarity are at peak rhythm today." -- shown as an AI reflection on
  /// the user's own journal, asserting a hormonal state nobody measured, to
  /// someone who might not have written anything at all.
  String? _backendReflection;
  List<String> _reflectionThemes = const [];
  bool _reflectionLoading = false;

  Future<void> _fetchBackendMemorySummary({bool showSpinner = false}) async {
    if (showSpinner && mounted) setState(() => _reflectionLoading = true);
    try {
      final data = await _apiSiaService.getMemorySummary();
      if (!mounted) return;
      setState(() {
        _reflectionLoading = false;
        final reflection = data['reflection'];
        // An absent reflection clears the old one rather than leaving a stale
        // sentence on screen after entries are deleted.
        _backendReflection = (reflection is String && reflection.isNotEmpty) ? reflection : null;
        _reflectionThemes = (data['themes'] as List?)
                ?.map((t) => t.toString())
                .toList() ??
            const [];
      });
    } catch (_) {
      if (mounted) setState(() => _reflectionLoading = false);
    }
  }

  int get _calculatedWordsCount {
    int total = 0;
    for (var item in _items) {
      if (item.type == 'text' && item.content is String) {
        final text = (item.content as String).trim();
        if (text.isNotEmpty) {
          total += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        }
      }
    }
    final now = DateTime.now();
    final todayEntries = _entries.where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day).toList();
    final targetList = todayEntries.isNotEmpty ? todayEntries : (_entries.isNotEmpty ? [_entries.first] : <JournalEntryItem>[]);
    for (var entry in targetList) {
      for (var item in entry.items) {
        if (item.type == 'text' && item.content is String) {
          final text = (item.content as String).trim();
          if (text.isNotEmpty) {
            total += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          }
        }
      }
    }
    return total;
  }

  int get _calculatedPhotosCount {
    int total = _items.where((i) => i.type == 'photo').length;
    final now = DateTime.now();
    final todayEntries = _entries.where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day).toList();
    final targetList = todayEntries.isNotEmpty ? todayEntries : (_entries.isNotEmpty ? [_entries.first] : <JournalEntryItem>[]);
    for (var entry in targetList) {
      total += entry.items.where((i) => i.type == 'photo').length;
    }
    return total;
  }

  int get _calculatedVoiceCount {
    int total = _items.where((i) => i.type == 'voice').length;
    final now = DateTime.now();
    final todayEntries = _entries.where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day).toList();
    final targetList = todayEntries.isNotEmpty ? todayEntries : (_entries.isNotEmpty ? [_entries.first] : <JournalEntryItem>[]);
    for (var entry in targetList) {
      total += entry.items.where((i) => i.type == 'voice').length;
    }
    return total;
  }

  int get _calculatedWritingTimeMins {
    final words = _calculatedWordsCount;
    if (words == 0) return _items.isNotEmpty ? 1 : 0;
    return (words / 35).ceil().clamp(1, 120);
  }

  int get _calculatedStreakDays {
    if (_entries.isEmpty && _items.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDates = _entries.map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day)).toSet();
    entryDates.add(today);

    int streak = 0;
    DateTime checkDate = today;
    while (entryDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String get _currentEmotionLabel {
    switch (_selectedMoodKey) {
      case 'happy':
        return 'Joyful 😄';
      case 'satisfied':
        return 'Peaceful 😊';
      case 'neutral':
        return 'Calm 😐';
      case 'sad':
        return 'Reflective 🙁';
      case 'very_sad':
        return 'Gentle 😫';
      default:
        // No mood chosen for this entry. Previously fell back to a server
        // supplied "Peaceful", which put a feeling on the entry that the
        // person writing it had not.
        return 'Not set';
    }
  }

  // Speech/Voice overlay states
  bool _showRecordOverlay = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Cream Paper', 'bgColor': const Color(0xFFFDFBF7), 'borderColor': const Color(0xFFE6DFD3), 'textColor': const Color(0xFF1A0F0A), 'paperPattern': true},
    {'name': 'Vintage Paper', 'bgColor': const Color(0xFFF4EAD4), 'borderColor': const Color(0xFFD4C5A9), 'textColor': const Color(0xFF2C1E15), 'paperPattern': true},
    {'name': 'Pink Floral', 'bgColor': const Color(0xFFFFF0F5), 'borderColor': const Color(0xFFFBCFE8), 'textColor': const Color(0xFF831843), 'paperPattern': false},
    {'name': 'Watercolor', 'bgColor': const Color(0xFFE0F2FE), 'borderColor': const Color(0xFFBAE6FD), 'textColor': const Color(0xFF0369A1), 'paperPattern': false},
    {'name': 'Minimal White', 'bgColor': const Color(0xFFFFFFFF), 'borderColor': const Color(0xFFE5E7EB), 'textColor': const Color(0xFF111827), 'paperPattern': false},
    {'name': 'Dark Mode', 'bgColor': const Color(0xFF1F2937), 'borderColor': const Color(0xFF374151), 'textColor': const Color(0xFFF9FAFB), 'paperPattern': false},
  ];

  final List<String> _fonts = ['Elegant Serif', 'Handwriting', 'Modern Sans', 'Brush Script', 'Notebook'];

  /// The sticker set.
  ///
  /// Names carry no emoji. Eight of the ten used to open with one and two did
  /// not, which was inconsistent — and since the complaint is that the
  /// stickers read as emoji, putting emoji in their names worked against the
  /// intent.
  ///
  /// Add `'asset': 'assets/stickers/flower.png'` to any entry to back it with
  /// artwork; the renderer prefers the image and falls back to the glyph if
  /// the file is missing. Saved entries keep whichever they were made with.
  /// The name is also how a saved sticker is resolved on load, so renaming one
  /// changes what old entries show — check `resolveIcon` before you do.
  final List<Map<String, dynamic>> _stickersList = [
    {'name': 'Flower', 'icon': Icons.local_florist_rounded, 'color': const Color(0xFFF472B6)},
    {'name': 'Butterfly', 'icon': Icons.flutter_dash_rounded, 'color': const Color(0xFFC084FC)},
    {'name': 'Moon', 'icon': Icons.dark_mode_rounded, 'color': const Color(0xFFFCD34D)},
    {'name': 'Star', 'icon': Icons.star_rounded, 'color': const Color(0xFFFBBF24)},
    {'name': 'Coffee', 'icon': Icons.coffee_rounded, 'color': const Color(0xFFB45309)},
    {'name': 'Books', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF3B82F6)},
    {'name': 'Leaf', 'icon': Icons.eco_rounded, 'color': const Color(0xFF10B981)},
    {'name': 'Heart', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFEF4444)},
    {'name': 'Sparkles', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFFEAB308)},
    {'name': 'Tea', 'icon': Icons.emoji_food_beverage_rounded, 'color': const Color(0xFF059669)},
  ];

  final List<Map<String, String>> _moodEmojis = const [
    {'emoji': '😫', 'key': 'very_sad', 'label': 'Very Sad'},
    {'emoji': '🙁', 'key': 'sad', 'label': 'Sad'},
    {'emoji': '😐', 'key': 'neutral', 'label': 'Neutral'},
    {'emoji': '🙂', 'key': 'satisfied', 'label': 'Satisfied'},
    {'emoji': '😄', 'key': 'happy', 'label': 'Very Satisfied'},
  ];

  String _activeToolbarTab = 'Stickers';

  List<String> _templates = [
    'Daily Reflection',
    'Gratitude',
    'Cycle Reflection',
    'Dream Journal',
    'Weekly Check-in'
  ];

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
      _templates = StageConfig.forStage(stage).journalTemplates;
    });
  }

  final List<({IconData icon, String key})> _moods = const [
    (icon: Icons.sentiment_very_dissatisfied_rounded, key: 'very_sad'),
    (icon: Icons.sentiment_dissatisfied_rounded, key: 'sad'),
    (icon: Icons.sentiment_neutral_rounded, key: 'neutral'),
    (icon: Icons.sentiment_satisfied_rounded, key: 'satisfied'),
    (icon: Icons.sentiment_very_satisfied_rounded, key: 'happy'),
  ];

  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  DeskSurfaceTheme _selectedDeskTheme = DeskSurfaceTheme.wood;
  final CoverMaterial _selectedCoverMaterial = CoverMaterial.leather;
  Color _selectedCoverColor = const Color(0xFF8B4513);
  bool _showDeskCoverView = true;
  bool _isOpeningCover = false;

  String _saveIndicatorStatus = 'idle';
  Timer? _saveStatusTimer;

  bool _enableAnimations = true;
  bool _enableAmbientAudio = true;
  bool _enableDecorativeEffects = true;
  final ScrapbookAnimationEngine _animationEngine = ScrapbookAnimationEngine();
  final InsightScheduler _insightScheduler = InsightScheduler();
  final JournalTitleService _titleService = JournalTitleService();
  final MemoryConnectionsService _connectionsService = MemoryConnectionsService();
  final SmartSearchService _smartSearchService = SmartSearchService();
  final PromptService _promptService = PromptService();
  final MemoryBookService _memoryBookService = MemoryBookService();
  final MemoryHighlightsService _highlightsService = MemoryHighlightsService();
  final MoodTimelineService _moodTimelineService = MoodTimelineService();
  final ReflectionService _reflectionService = ReflectionService();
  final JournalController _journalController = JournalController();
  final BackupService _backupService = BackupService();
  final ExportService _exportService = ExportService();

  void _triggerAutoSaveIndicator() {
    if (!mounted) return;
    _animationEngine.microInteractionManager.triggerSavePulse();
    setState(() => _saveIndicatorStatus = 'saving');
    _saveStatusTimer?.cancel();
    _saveStatusTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _saveIndicatorStatus = 'saved');
      }
      _saveStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _saveIndicatorStatus = 'idle');
        }
      });
    });
  }

  Widget _buildSaveStatusIndicatorWidget() {
    if (_saveIndicatorStatus == 'idle') return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_saveIndicatorStatus),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _saveIndicatorStatus == 'saved'
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _saveIndicatorStatus == 'saved'
                ? const Color(0xFF43A047).withValues(alpha: 0.3)
                : const Color(0xFFFFB300).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_saveIndicatorStatus == 'saving') ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).journalAutoSaving,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFD97706)),
              ),
            ] else ...[
              const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 14),
              const SizedBox(width: 6),
              Text(
                '✓ Saved',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF43A047)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAccessibilityDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Accessibility & Motion Settings', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    activeThumbColor: BlushyColors.primary,
                    title: Text('Ambient Sounds', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Play background environment soundscapes.', style: GoogleFonts.poppins(fontSize: 12)),
                    value: _enableAmbientAudio,
                    onChanged: (val) {
                      setModalState(() => _enableAmbientAudio = val);
                      setState(() {
                        if (!val) JournalAmbientAudio().stop();
                      });
                    },
                  ),
                  SwitchListTile(
                    activeThumbColor: BlushyColors.primary,
                    title: Text('Long Animations & Transitions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Enable 3D cover flipping and opening motion.', style: GoogleFonts.poppins(fontSize: 12)),
                    value: _enableAnimations,
                    onChanged: (val) {
                      setModalState(() => _enableAnimations = val);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    activeThumbColor: BlushyColors.primary,
                    title: Text('Decorative Effects', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Coffee steam curves, plant sway, & reflections.', style: GoogleFonts.poppins(fontSize: 12)),
                    value: _enableDecorativeEffects,
                    onChanged: (val) {
                      setModalState(() => _enableDecorativeEffects = val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_isFabVisible) setState(() => _isFabVisible = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_isFabVisible) setState(() => _isFabVisible = true);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    // Live database entries loaded from storage/API
    _loadSavedJournalEntries();
    _fetchBackendMemorySummary();
    _journalController.loadEntries('default_user');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    for (var c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }


  Future<void> _loadSavedJournalEntries() async {
    var saved = await _journalStorage.loadEntries('default_user');

    // Nothing on this device: the account may still have journals from a
    // reinstall or from the other platform. The server copy is the durable one.
    if (saved.isEmpty) {
      saved = await _restoreJournalsFromServer();
      if (saved.isNotEmpty) {
        await _journalStorage.saveEntries('default_user', saved);
      }
    }

    if (saved.isNotEmpty && mounted) {
      setState(() {
        for (var localEntry in saved) {
          if (localEntry.rawJson != null && localEntry.rawJson!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(localEntry.rawJson!);
              final List<dynamic> itemsJson = data['items'] ?? [];
              final items = itemsJson.map((i) => scrapbookItemFromJson(Map<String, dynamic>.from(i))).toList();
              final entry = JournalEntryItem(
                id: localEntry.id,
                title: localEntry.title,
                dateTime: DateTime.tryParse(localEntry.dateTime ?? '') ?? DateTime.now(),
                items: items,
                themeName: data['themeName'] ?? 'Cream Paper',
                fontName: data['fontName'] ?? 'Handwriting',
                templateName: data['templateName'] ?? 'Daily Reflection',
                moodKey: localEntry.moodKey,
              );
              _entries.removeWhere((e) => e.id == entry.id);
              _entries.insert(0, entry);
              _recordJournalEvent(entry);
            } catch (_) {}
          }
        }
      });
    }
  }

  /// Pulls stored journals back down and flattens them into local entries.
  ///
  /// The server groups by day, so one document can hold several entries.
  Future<List<LocalJournalEntry>> _restoreJournalsFromServer() async {
    try {
      final journals = await ApiAuthService().getJournals();
      final restored = <LocalJournalEntry>[];
      for (final journal in journals) {
        // The server knows which days are shared; without reading it back the
        // control would reset to "Share" on every launch.
        final date = (journal['entryDate'] ?? journal['date'])?.toString();
        if (date != null && journal['sharedWithPartner'] == true) {
          _sharedJournalDates.add(date);
        }
        final entries = journal['entries'];
        if (entries is! List) continue;
        for (final raw in entries) {
          if (raw is! Map) continue;
          try {
            restored.add(LocalJournalEntry.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {
            // One malformed entry must not cost the user the rest of them.
          }
        }
      }
      return restored;
    } catch (_) {
      return const [];
    }
  }

  /// Mirrors the local entries to the account, one document per day.
  ///
  /// Fire-and-forget: saving must not block on the network, and the local copy
  /// has already been written by the time this runs.
  Future<void> _pushJournalsToServer(List<LocalJournalEntry> entries) async {
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      byDate.putIfAbsent(entry.date, () => []).add(entry.toJson());
    }

    final service = ApiAuthService();
    for (final date in byDate.keys) {
      final dayEntries = byDate[date]!;
      await service.saveJournalForDate(
        entryDate: date,
        entries: dayEntries,
        summary: dayEntries.length == 1
            ? (dayEntries.first['title']?.toString() ?? '')
            : '${dayEntries.length} entries',
      );
    }
  }

  Future<void> _persistAllEntries() async {
    _triggerAutoSaveIndicator();
    final List<LocalJournalEntry> listToSave = _entries.map((entry) {
      final String rawJson = jsonEncode({
        'themeName': entry.themeName,
        'fontName': entry.fontName,
        'templateName': entry.templateName,
        'items': entry.items.map((i) => scrapbookItemToJson(i)).toList(),
      });
      return LocalJournalEntry(
        id: entry.id,
        date: '${entry.dateTime.year}-${entry.dateTime.month.toString().padLeft(2, '0')}-${entry.dateTime.day.toString().padLeft(2, '0')}',
        title: entry.title,
        body: _getEntryTextPreview(entry),
        moodKey: entry.moodKey,
        dateTime: entry.dateTime.toIso8601String(),
        rawJson: rawJson,
      );
    }).toList();

    // The key is already namespaced per authenticated user by BlushyStorage,
    // so 'default_user' here is only a legacy suffix; changing it would orphan
    // existing entries.
    await _journalStorage.saveEntries('default_user', listToSave);
    // The account copy is what survives a reinstall or a move to web.
    unawaited(_pushJournalsToServer(listToSave));
  }

  /// Records a journal entry as a health event so it reaches the timeline.
  ///
  /// Only metadata is sent: a word count and whether audio was attached. The
  /// text itself stays local, because journal content is private by default
  /// and never enters AI context or analytics without explicit permission
  /// (spec sections 6, 10 and 26).
  Future<void> _recordJournalEvent(JournalEntryItem entry) async {
    final text = _getEntryTextPreview(entry);
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final hasAudio = entry.items.any((item) => item.type == 'audio');

    if (wordCount == 0 && !hasAudio) return;

    final clientEventId = 'journal:${entry.dateTime.toIso8601String()}';

    final result = await EventsApi.log(
      eventType: 'journal_created',
      payload: {
        // A placeholder stands in for the body: the event records that an
        // entry exists, not what it says.
        'text': '[$wordCount words]',
        if (hasAudio) 'audioRef': 'local',
      },
      timestamp: entry.dateTime,
      clientEventId: clientEventId,
    );

    if (result.state == ApiState.offline || result.state == ApiState.error) {
      await OfflineEventQueue.instance.enqueue(
        eventType: 'journal_created',
        payload: {
          'text': '[$wordCount words]',
          if (hasAudio) 'audioRef': 'local',
        },
        clientEventId: clientEventId,
        timestamp: entry.dateTime,
      );
    }
  }

  String _getEntryTextPreview(JournalEntryItem entry) {
    for (var item in entry.items) {
      if (item.type == 'text' && item.content is String && (item.content as String).isNotEmpty) {
        return item.content as String;
      }
    }
    return 'Journal entry logged on ${entry.dateTime.month}/${entry.dateTime.day}';
  }

  /// Adds a photo from the device gallery to the page.
  ///
  /// The "Photo Frames" tray used to insert a text item reading
  /// "[Polaroid Memory]" -- a placeholder standing in for a picture. The model
  /// has carried a 'photo' item type all along and the journal counts photos
  /// for its statistics, but nothing ever created one.
  ///
  /// The image is embedded as a data URI, the same way voice notes are, so it
  /// travels with the entry through the existing JSON persistence. That is why
  /// it is downscaled first: a phone photo is several megabytes and base64
  /// adds a third again, which would bloat every entry and its sync.
  Future<void> _addPhotoFromGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    final couldNotAdd = AppLocalizations.of(context).jrnCouldNotAddPhoto;

    PickedBlushyFile? picked;
    try {
      picked = await pickFileFromDevice(accept: 'image/*');
    } catch (_) {
      picked = null;
    }
    if (picked == null) return; // cancelled

    Uint8List bytes;
    try {
      bytes = await _downscaleForJournal(Uint8List.fromList(picked.bytes));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(couldNotAdd)));
      return;
    }

    if (!mounted) return;
    final dataUri = 'data:image/png;base64,${base64Encode(bytes)}';
    _addItem(
      'photo_${DateTime.now().millisecondsSinceEpoch}',
      'photo',
      {'url': dataUri, 'name': picked.name},
      const Offset(60, 100),
    );
  }

  /// Shrinks to at most [_journalPhotoMaxWidth] across, leaving smaller images
  /// alone rather than upscaling them into a bigger file.
  static Future<Uint8List> _downscaleForJournal(Uint8List original) async {
    final probe = await ui.instantiateImageCodec(original);
    final frame = await probe.getNextFrame();
    final width = frame.image.width;
    frame.image.dispose();

    if (width <= _journalPhotoMaxWidth) {
      final encoded = await _encodePng(original);
      return encoded ?? original;
    }

    final codec = await ui.instantiateImageCodec(
      original,
      targetWidth: _journalPhotoMaxWidth,
    );
    final resized = await codec.getNextFrame();
    final data = await resized.image.toByteData(format: ui.ImageByteFormat.png);
    resized.image.dispose();
    if (data == null) return original;
    return data.buffer.asUint8List();
  }

  static Future<Uint8List?> _encodePng(Uint8List original) async {
    final codec = await ui.instantiateImageCodec(original);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return data?.buffer.asUint8List();
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
    final newId = '${item.id}_copy_$_itemCounter';
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
        _items.insert(0, item.copyWith(zIndex: 0));
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

  void _loadEntry(JournalEntryItem entry) {
    setState(() {
      _currentEntryId = entry.id;
      _titleController.text = entry.title;
      _activeTheme = entry.themeName;
      _activeFont = entry.fontName;
      _activeTemplate = entry.templateName;
      _selectedMoodKey = entry.moodKey;
      _items.clear();
      _items.addAll(List.from(entry.items));
      _selectedItemId = null;
      _itemCounter = _items.length;
    });
  }

  void _saveAndCloseEntry() {
    if (_currentEntryId != null) {
      final index = _entries.indexWhere((e) => e.id == _currentEntryId);
      if (index != -1) {
        setState(() {
          _entries[index] = _entries[index].copyWith(
            title: _titleController.text.trim().isEmpty ? 'Daily Reflection' : _titleController.text.trim(),
            items: List.from(_items),
            themeName: _activeTheme,
            fontName: _activeFont,
            templateName: _activeTemplate,
            moodKey: _selectedMoodKey,
          );
          _currentEntryId = null;
        });
        _persistAllEntries();
      }
    }
  }

  void _createNewEntry({String title = 'Self Reflection', String? templateName}) {
    final String newId = 'entry_${DateTime.now().millisecondsSinceEpoch}';

    // The template decides what the page opens with. It used to decide nothing:
    // every entry got the same blank "Tap to start writing your reflection...",
    // whichever template had been chosen, so the choice was cosmetic.
    final prompts = JournalTemplates.promptsFor(templateName);

    final List<ScrapbookItem> initialItems = [
      ScrapbookItem(id: 'tape_$newId', type: 'tape', content: const Color(0xFFFBCFE8), position: const Offset(20, 16)),
      // Spaced down the page so they read as separate questions rather than a
      // paragraph, and so there is room to answer under each one.
      for (var i = 0; i < prompts.length; i++)
        ScrapbookItem(
          id: 'text_${newId}_$i',
          type: 'text',
          content: prompts[i],
          position: Offset(20, 70 + (i * _promptSpacing)),
        ),
    ];

    final newEntry = JournalEntryItem(
      id: newId,
      title: title,
      dateTime: DateTime.now(),
      items: initialItems,
      templateName: templateName ?? 'Daily Reflection',
    );

    setState(() {
      _entries.insert(0, newEntry);
      _recordJournalEvent(newEntry);
      _loadEntry(newEntry);
    });
    _persistAllEntries();
  }

  Future<void> _startRecordingFlow() async {
    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
      _showRecordOverlay = true;
    });

    try {
      _audioRecorder = HtmlAudioRecorder();
      await _audioRecorder!.start();
    } catch (e) {
      debugPrint("Error starting microphone audio recorder: $e");
    }

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration++;
        });
      }
    });
  }

  Future<void> _stopRecordingAndTranscribe() async {
    // Resolved up front: this method stops the recorder and then calls the
    // transcription service, and the context may be gone by the time either
    // returns.
    final couldNotTranscribe = AppLocalizations.of(context).jrnCouldNotTranscribe;
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    ({List<int> bytes, int duration})? recordResult;
    try {
      if (_audioRecorder != null && _audioRecorder!.isRecording) {
        recordResult = await _audioRecorder!.stop();
      }
    } catch (e) {
      debugPrint("Error stopping audio recorder: $e");
    }

    final int secondsRecorded = recordResult?.duration ?? _recordingDuration;
    final List<int> audioBytes = recordResult?.bytes ?? [];

    String dataUrl = '';
    if (audioBytes.isNotEmpty) {
      final base64Str = base64Encode(audioBytes);
      dataUrl = 'data:audio/webm;base64,$base64Str';
    }

    final durationStr = "${(secondsRecorded ~/ 60).toString().padLeft(2, '0')}:${(secondsRecorded % 60).toString().padLeft(2, '0')}";

    String transcribedText = '';
    String? transcriptionProblem;
    if (audioBytes.isNotEmpty) {
      try {
        transcribedText = await ApiSiaService().transcribeAudioBytes(audioBytes, 'dictation_${DateTime.now().millisecondsSinceEpoch}.webm');
      } on TranscriptionUnavailable catch (e) {
        // The recording was fine, the service was not. Naming which one keeps
        // the user from thinking they were not heard.
        transcriptionProblem = e.message;
      } catch (e) {
        debugPrint("Transcription API call error: $e");
        transcriptionProblem = couldNotTranscribe;
      }
    }

    final bool isVoiceNote = _activeToolbarTab == 'Voice Note';

    if (mounted) {
      final newId = DateTime.now().millisecondsSinceEpoch;
      if (isVoiceNote) {
        // The audio itself is the entry, so it is kept regardless of whether
        // the words could be recognised.
        _addItem('voice_$newId', 'voice', {
          'url': dataUrl,
          'duration': durationStr,
          'seconds': secondsRecorded,
        }, const Offset(40, 120));
      } else if (transcribedText.trim().isNotEmpty) {
        _addItem('text_$newId', 'text', transcribedText.trim(), const Offset(40, 120));
      }

      setState(() {
        _isTranscribing = false;
        _showRecordOverlay = false;
      });

      // Nothing was captured. Previously this wrote "Voice Reflection: Feeling
      // peaceful and reflective today." into the journal -- inventing a
      // reflection the user never said, in the one place in the app where the
      // words are supposed to be entirely theirs.
      if (!isVoiceNote && transcribedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transcriptionProblem == null
                  ? AppLocalizations.of(context).jrnNothingRecognised
                  : '$transcriptionProblem You can type it instead.',
            ),
          ),
        );
        return;
      }

      _persistAllEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showDeskCoverView && _currentEntryId == null) {
      return _buildDeskCoverOpeningView();
    }

    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: Stack(
        children: [
          _currentEntryId == null ? _buildNotebookListView() : _buildEditorView(),
          if (_showRecordOverlay) _buildRecordingOverlay(),
        ],
      ),
      floatingActionButton: (_currentEntryId == null && _isFabVisible)
          ? GestureDetector(
              onLongPress: () => _showCreateOptionsBottomSheet(),
              onDoubleTap: () {
                if (_entries.isNotEmpty) {
                  _loadEntry(_entries.first);
                } else {
                  _openNewBlankEntry();
                }
              },
              onTap: () => _openNewBlankEntry(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDD0D22), Color(0xFFFF4D6D)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66DD0D22), blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).journalNewMemory,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Color _selectedRibbonColor = const Color(0xFFD97706);
  final String _selectedEmblem = 'sparkles';

  Widget _buildDeskCoverOpeningView() {
    return Scaffold(
      body: DeskEnvironmentWidget(
        surfaceTheme: _selectedDeskTheme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              JournalCoverWidget(
                title: 'My Scrapbook',
                subtitle: 'Dream Big. Write Beautifully.',
                coverColor: _selectedCoverColor,
                ribbonColor: _selectedRibbonColor,
                material: _selectedCoverMaterial,
                emblem: _selectedEmblem,
                isOpening: _isOpeningCover,
                onTapOpen: () {
                  setState(() {
                    _showDeskCoverView = false;
                    _isOpeningCover = false;
                  });
                },
              ),
              const SizedBox(height: 28),

              // Customize Cover & Desk Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('Cover: ', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                    _buildCoverColorDot(const Color(0xFF8B4513)),
                    _buildCoverColorDot(const Color(0xFFFBCFE8)),
                    _buildCoverColorDot(const Color(0xFFC084FC)),
                    _buildCoverColorDot(const Color(0xFF1E3A8A)),
                    _buildCoverColorDot(const Color(0xFF065F46)),
                    const SizedBox(width: 8),
                    Text('Ribbon: ', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                    _buildRibbonDot(const Color(0xFFD97706)),
                    _buildRibbonDot(const Color(0xFFE11D48)),
                    _buildRibbonDot(const Color(0xFF059669)),
                    _buildRibbonDot(const Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text('Desk: ', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white)),
                    _buildDeskChip('Wood', DeskSurfaceTheme.wood),
                    _buildDeskChip('Marble', DeskSurfaceTheme.marble),
                    _buildDeskChip('Pink', DeskSurfaceTheme.pink),
                    _buildDeskChip('Vintage', DeskSurfaceTheme.vintage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverColorDot(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCoverColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: _selectedCoverColor == color ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Widget _buildRibbonDot(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRibbonColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: _selectedRibbonColor == color ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDeskChip(String label, DeskSurfaceTheme theme) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDeskTheme = theme),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _selectedDeskTheme == theme ? BlushyColors.primary : Colors.black26,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
      ),
    );
  }

  String _getTimeBasedGreetingPrefix() {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else if (hour >= 17 && hour < 22) {
      return "Good Evening";
    } else {
      return "Good Night";
    }
  }

  Widget _buildNotebookListView() {
    final filtered = _entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.title.toLowerCase().contains(_searchQuery) ||
             e.templateName.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: BlushyColors.border, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isEmbedded && Navigator.canPop(context)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 18, color: BlushyColors.text),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).journalBackToHome,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final osState = BlushyOSProvider.of(context);
                      final String displayName = (osState.personalContext.userName != null && osState.personalContext.userName!.trim().isNotEmpty)
                          ? osState.personalContext.userName!.trim()
                          : 'User';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getTimeBasedGreetingPrefix()}, $displayName',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: BlushyColors.text,
                            ),
                          ),
                          Text(
                            "Today's mood? Record your thoughts below",
                            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.book_rounded, color: BlushyColors.primary),
                        tooltip: 'Desk & Diary Cover',
                        onPressed: () => setState(() => _showDeskCoverView = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: BlushyColors.primary),
                        tooltip: 'Ambient Sound Environment',
                        onPressed: () => _showAmbientAudioDialog(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.accessibility_new_rounded, color: BlushyColors.primary),
                        tooltip: 'Accessibility Settings',
                        onPressed: () => _showAccessibilityDialog(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search memories, stickers & templates...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: BlushyColors.secondaryText),
                  filled: true,
                  fillColor: BlushyColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Today's Inspiration Quote Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFBCFE8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF472B6).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFDB2777), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TODAY\'S INSPIRATION',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFDB2777), letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '"The smallest memories become the biggest treasures."',
                            style: GoogleFonts.caveat(fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Today's Summary Memory Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: BlushyColors.border),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 18, color: BlushyColors.primary),
                            const SizedBox(width: 8),
                            Text('Today\'s Memory Summary', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                          child: Text('Emotion: $_currentEmotionLabel', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_reflectionLoading)
                      Text(
                        AppLocalizations.of(context).journalReadingYourEntries,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: BlushyColors.secondaryText),
                      )
                    else if (_backendReflection != null) ...[
                      Text(
                        _backendReflection!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.secondaryText),
                      ),
                      if (_reflectionThemes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _reflectionThemes
                              .map((theme) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: BlushyColors.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      theme,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: BlushyColors.primary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).journalNothingToReflect,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: BlushyColors.secondaryText),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _fetchBackendMemorySummary(showSpinner: true),
                            child: Text('Refresh',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: BlushyColors.primary)),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildSummaryMetric(Icons.schedule_rounded, 'Writing Time: $_calculatedWritingTimeMins mins', Colors.blue),
                        _buildSummaryMetric(Icons.notes_rounded, 'Words: $_calculatedWordsCount', Colors.purple),
                        _buildSummaryMetric(Icons.camera_alt_rounded, 'Photos: $_calculatedPhotosCount', Colors.pink),
                        _buildSummaryMetric(Icons.graphic_eq_rounded, 'Voice: $_calculatedVoiceCount', Colors.teal),
                        _buildSummaryMetric(Icons.local_fire_department_rounded, 'Streak: $_calculatedStreakDays Days', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Smart Memory Timeline Header
              Row(
                children: [
                  const Text('📜 ', style: TextStyle(fontSize: 18)),
                  Text('Smart Memory Timeline', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                ],
              ),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.filter_vintage_rounded, size: 48, color: BlushyColors.border),
                        const SizedBox(height: 12),
                        Text(AppLocalizations.of(context).journalNoMemoriesFound, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                        const SizedBox(height: 4),
                        Text('Tap "New Memory" or record a voice reflection.', style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((entry) => _buildEntryCardTile(entry)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: BlushyColors.text)),
      ],
    );
  }

  void _showAmbientAudioDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final audio = JournalAmbientAudio();
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily Ambient Environment Sounds', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildAmbientChip('None 🔇', AmbientTheme.none, audio, setModalState),
                      _buildAmbientChip('Forest 🌲', AmbientTheme.forest, audio, setModalState),
                      _buildAmbientChip('Rain 🌧️', AmbientTheme.rain, audio, setModalState),
                      _buildAmbientChip('Cafe ☕', AmbientTheme.cafe, audio, setModalState),
                      _buildAmbientChip('Library 📚', AmbientTheme.library, audio, setModalState),
                      _buildAmbientChip('Night 🌙', AmbientTheme.night, audio, setModalState),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAmbientChip(String label, AmbientTheme theme, JournalAmbientAudio audio, StateSetter setModalState) {
    final isSelected = audio.currentTheme == theme;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: BlushyColors.primary.withValues(alpha: 0.2),
      onSelected: (val) {
        setModalState(() {
          audio.playTheme(theme);
        });
        setState(() {});
      },
    );
  }

  void _openNewBlankEntry() {
    final newId = 'entry_${DateTime.now().millisecondsSinceEpoch}';
    final newEntry = JournalEntryItem(
      id: newId,
      title: 'Scrapbook Memory',
      dateTime: DateTime.now(),
      items: [
        ScrapbookItem(id: 'tape_$newId', type: 'tape', content: const Color(0xFFFBCFE8), position: const Offset(20, 16)),
        ScrapbookItem(id: 'text_$newId', type: 'text', content: 'Tap to write your thoughts...', position: const Offset(20, 60)),
      ],
      moodKey: 'satisfied',
    );
    setState(() {
      _entries.insert(0, newEntry);
      _recordJournalEvent(newEntry);
      _loadEntry(newEntry);
    });
    _persistAllEntries();
  }

  /// Per-day share control.
  ///
  /// Kept next to the entry rather than in settings: deciding to show someone a
  /// particular day is a decision about that day, and it should be made while
  /// looking at it.
  Widget _buildShareWithPartnerButton(JournalEntryItem entry) {
    final dateKey = '${entry.dateTime.year}-'
        '${entry.dateTime.month.toString().padLeft(2, '0')}-'
        '${entry.dateTime.day.toString().padLeft(2, '0')}';
    final shared = _sharedJournalDates.contains(dateKey);
    final busy = _sharingJournalDates.contains(dateKey);

    return InkWell(
      onTap: busy ? null : () => _toggleJournalShared(dateKey, !shared),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shared ? Icons.people_alt_rounded : Icons.people_outline_rounded,
                    size: 14,
                    color: shared ? BlushyColors.primary : BlushyColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    shared ? 'Shared' : AppLocalizations.of(context).jrnShare,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: shared ? FontWeight.w600 : FontWeight.w400,
                      color: shared ? BlushyColors.primary : BlushyColors.secondaryText,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _toggleJournalShared(String dateKey, bool shared) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharingJournalDates.add(dateKey));

    final ok = await ApiAuthService().setJournalShared(
      entryDate: dateKey,
      shared: shared,
    );

    if (!mounted) return;
    setState(() {
      _sharingJournalDates.remove(dateKey);
      if (ok) {
        if (shared) {
          _sharedJournalDates.add(dateKey);
        } else {
          _sharedJournalDates.remove(dateKey);
        }
      }
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? AppLocalizations.of(context).jrnCouldNotChangeSharing
              : shared
                  ? 'Shared. Your partner sees this day only if you have turned on journal sharing for them.'
                  : AppLocalizations.of(context).jrnNoLongerShared,
        ),
      ),
    );
  }

  Widget _buildEntryCardTile(JournalEntryItem entry) {
    final theme = _themes.firstWhere((t) => t['name'] == entry.themeName, orElse: () => _themes.first);
    final moodIcon = _moods.firstWhere((m) => m.key == entry.moodKey, orElse: () => _moods[3]).icon;

    return GestureDetector(
      onTap: () => _loadEntry(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme['bgColor'] as Color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (theme['borderColor'] as Color).withValues(alpha: 0.8), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(moodIcon, color: BlushyColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: theme['textColor'] as Color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (theme['borderColor'] as Color).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.templateName,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: theme['textColor'] as Color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getEntryTextPreview(entry),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.caveat(fontSize: 16, color: (theme['textColor'] as Color).withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${entry.dateTime.month}/${entry.dateTime.day}/${entry.dateTime.year} • ${entry.dateTime.hour}:${entry.dateTime.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A journal day reaches a partner only if it is marked here
                    // AND they hold the journal permission. Granting the
                    // category never releases anything on its own.
                    _buildShareWithPartnerButton(entry),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    child: Container(width: 38, height: 4, decoration: BoxDecoration(color: BlushyColors.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).journalCreateNew, style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BlushyColors.text)),
                  const SizedBox(height: 12),
                  _buildOptionTile(
                    icon: Icons.edit_note_rounded,
                    title: 'Write Reflection',
                    subtitle: 'Start on a fresh scrapbook canvas',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewEntry(title: 'Self Reflection');
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.mic_none_rounded,
                    title: 'Record & Transcribe',
                    subtitle: 'Speak and let Dr. Docsy transcribe into your journal',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _showRecordOverlay = true;
                      });
                      _startRecordingFlow();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.grid_view_rounded,
                    title: 'Start from Template',
                    subtitle: 'Choose a guided journaling template',
                    onTap: () {
                      Navigator.pop(context);
                      _showTemplateSelectionModal();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.search_rounded,
                    title: 'Smart AI Search',
                    subtitle: 'Contextual semantic search across memories',
                    onTap: () {
                      Navigator.pop(context);
                      _openSmartSearchDialog();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.military_tech_rounded,
                    title: 'Memory Vault',
                    subtitle: 'Starred memories & custom collections',
                    onTap: () {
                      Navigator.pop(context);
                      final localList = _entries.map((e) => LocalJournalEntry(id: e.id, date: e.dateTime.toString(), title: e.title, body: '', moodKey: e.moodKey)).toList();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MemoryVaultWidget(entries: localList, onEntryTap: (e) {})));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Smart Calendar & Map',
                    subtitle: 'Visual mood grid & location pins',
                    onTap: () {
                      Navigator.pop(context);
                      final localList = _entries.map((e) => LocalJournalEntry(id: e.id, date: e.dateTime.toString(), title: e.title, body: '', moodKey: e.moodKey)).toList();
                      _backupService.createBackupPackage(localList.map((l) => l.toJson()).toList());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryMapWidget()));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.eco_rounded,
                    title: 'Reflective Content Garden',
                    subtitle: 'Organic garden growth tied to reflection depth',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementGardenWidget()));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.palette_rounded,
                    title: 'Modular Theme Marketplace',
                    subtitle: 'Mix & match covers, paper, fonts & audio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeMarketplaceWidget(onApplyTheme: (pack) {})));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.settings_rounded,
                    title: 'Settings & Privacy Center',
                    subtitle: 'Subsystem flags, diagnostics & accessibility',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalSettingsScreen()));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.analytics_rounded,
                    title: 'Journal Insights Dashboard',
                    subtitle: 'Writing statistics, word count & active hours',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalDashboardWidget()));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.history_edu_rounded,
                    title: 'Year in Review Scrapbook',
                    subtitle: 'Guided multi-page yearly recap',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => YearInReviewScrapbook(onClose: () => Navigator.pop(context))));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.lock_clock_rounded,
                    title: 'Memory Time Capsule',
                    subtitle: 'Encrypted future memories with ceremonial unlock',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeCapsuleWidget()));
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.file_upload_rounded,
                    title: 'Export Studio (6 Layouts)',
                    subtitle: 'Export PDF, Markdown, JSON, HTML',
                    onTap: () {
                      Navigator.pop(context);
                      if (_entries.isNotEmpty) {
                        final sample = LocalJournalEntry(id: _entries.first.id, date: _entries.first.dateTime.toString(), title: _entries.first.title, body: 'Reflection memory', moodKey: _entries.first.moodKey);
                        final exp = _exportService.exportEntry(entry: sample, format: ExportFormat.markdown, style: ExportLayoutStyle.hardcoverScrapbook);
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(title: const Text('Export Studio Preview'), content: SingleChildScrollView(child: Text(exp))),
                        );
                      }
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

    Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: BlushyColors.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: BlushyColors.primary, size: 20),
          ),
          title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text)),
          subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BlushyColors.secondaryText),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showTemplateSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).journalSelectTemplate, style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BlushyColors.text)),
                const SizedBox(height: 12),
                ..._templates.map((tpl) => ListTile(
                      leading: const Icon(Icons.star_outline_rounded, color: BlushyColors.primary),
                      title: Text(tpl, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        _createNewEntry(title: tpl, templateName: tpl);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorView() {
    final activeThemeObj = _themes.firstWhere((t) => t['name'] == _activeTheme, orElse: () => _themes.first);
    final bgColor = activeThemeObj['bgColor'] as Color;
    final borderColor = activeThemeObj['borderColor'] as Color;

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Top Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text),
                    onPressed: _saveAndCloseEntry,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BlushyColors.text),
                            decoration: const InputDecoration(
                              hintText: 'Entry Title...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        _buildSaveStatusIndicatorWidget(),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 20),
                    tooltip: 'AI Title Suggestions',
                    onPressed: _showAiTitlePickerModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706), size: 20),
                    tooltip: 'Weekly Memory Book',
                    onPressed: _showMemoryBookModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                    tooltip: 'AI & Privacy Settings',
                    onPressed: _showAiPrivacySettingsModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.color_lens_rounded, color: BlushyColors.primary),
                    onPressed: () => _showThemeFontPicker(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_rounded, color: Colors.green),
                    onPressed: _saveAndCloseEntry,
                  ),
                ],
              ),
            ),
          ),

          // Feeling / Mood Selector Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.white.withValues(alpha: 0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Feeling: ',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.secondaryText),
                ),
                const SizedBox(width: 8),
                Row(
                  children: _moodEmojis.map((me) {
                    final isSelected = me['key'] == _selectedMoodKey;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMoodKey = me['key']!),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? BlushyColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: BlushyColors.primary, width: 1.5) : null,
                        ),
                        child: Text(
                          me['emoji']!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Interactive Drag-and-Drop Scrapbooking Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activeThemeObj['bgColor'] as Color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeThemeObj['borderColor'] as Color, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedItemId = null),
                  child: Stack(
                    children: [
                      // Paper lines painter background
                      if (activeThemeObj['paperPattern'] == true)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PaperLinesPainter(lineColor: (activeThemeObj['borderColor'] as Color).withValues(alpha: 0.4)),
                          ),
                        ),

                      ..._items.map((item) => _buildScrapbookItemWidget(item)),

                      // Active Selected Item Toolbar Controls overlay
                      if (_selectedItemId != null) _buildItemEditToolbar(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Scrapbook Toolbar
          _buildBottomScrapbookToolbar(),
        ],
      ),
    );
  }

  Widget _buildScrapbookItemWidget(ScrapbookItem item) {
    final isSelected = item.id == _selectedItemId;
    const double handleOffset = 20.0;

    return Positioned(
      left: item.position.dx - handleOffset,
      top: item.position.dy - handleOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(handleOffset),
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
                child: Transform.scale(
                  scale: item.scale,
                  child: Container(
                    decoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(color: BlushyColors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: _renderItemContent(item),
                  ),
                ),
              ),
            ),
          ),
          if (isSelected) ...[
            // Top Right: Red X (Delete) Button
            Positioned(
              right: handleOffset - 10,
              top: handleOffset - 10,
              child: GestureDetector(
                onTap: () => _deleteItem(item.id),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
            // Bottom Right: Blue Duplicate Button
            Positioned(
              right: handleOffset - 10,
              bottom: handleOffset - 10,
              child: GestureDetector(
                onTap: () => _duplicateItem(item),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
            // Top Left: Scale/Resize Handle
            Positioned(
              left: handleOffset - 10,
              top: handleOffset - 10,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double delta = -details.delta.dx - details.delta.dy;
                    item.scale = (item.scale + delta * 0.01).clamp(0.4, 3.0);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: BlushyColors.text,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 10),
                ),
              ),
            ),
            // Bottom Left: Rotate Handle
            Positioned(
              left: handleOffset - 10,
              bottom: handleOffset - 10,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    item.rotation += details.delta.dx * 0.02;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: BlushyColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderItemContent(ScrapbookItem item) {
    if (item.type == 'tape') {
      final tapeColor = item.customColor ?? (item.content as Color);
      return Container(
        width: 90,
        height: 22,
        decoration: BoxDecoration(
          color: tapeColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: tapeColor.withValues(alpha: 0.4)),
        ),
      );
    } else if (item.type == 'sticker') {
      final stickerMap = item.content as Map<String, dynamic>;
      final stkColor = item.customColor ?? (stickerMap['color'] as Color);

      // Artwork wins where a sticker has it. Material glyphs are flat
      // single-colour shapes by design, which is why the current set reads as
      // emoji -- no amount of styling makes one look painted. This is the seam
      // an illustrated set drops into: add 'asset' to the sticker definition
      // and nothing else changes, here or in already-saved entries.
      final asset = stickerMap['asset'] as String?;
      if (asset != null && asset.isNotEmpty) {
        return Image.asset(
          asset,
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          // A missing file should cost a sticker, not the whole page.
          errorBuilder: (_, _, _) => Icon(
            stickerMap['icon'] as IconData,
            color: stkColor,
            size: 44,
          ),
        );
      }

      return Icon(
        stickerMap['icon'] as IconData,
        color: stkColor,
        size: 44,
      );
    } else if (item.type == 'text') {
      final controller = _textControllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.content as String),
      );
      final txtBgColor = item.customColor ?? Colors.white.withValues(alpha: 0.9);

      return Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: txtBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.customColor != null ? item.customColor! : BlushyColors.border),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_indicator_rounded, size: 13, color: Colors.black38),
                    const SizedBox(width: 2),
                    Text(
                      'Move',
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black38),
                    ),
                  ],
                ),
                const Icon(Icons.edit_note_rounded, size: 13, color: BlushyColors.primary),
              ],
            ),
            const SizedBox(height: 2),
            TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              cursorColor: BlushyColors.primary,
              style: _getTextStyle(14, color: item.customColor != null ? Colors.white : BlushyColors.text),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                item.content = val;
              },
            ),
          ],
        ),
      );
    } else if (item.type == 'photo') {
      final photo = (item.content is Map)
          ? Map<String, dynamic>.from(item.content as Map)
          : <String, dynamic>{};
      final uri = photo['url']?.toString() ?? '';
      final base64Part = uri.contains(',') ? uri.split(',').last : '';
      if (base64Part.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // The polaroid border the tray used to only pretend to add.
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.memory(
            base64Decode(base64Part),
            width: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 160,
              height: 120,
              child: Icon(Icons.broken_image_rounded, color: BlushyColors.secondaryText),
            ),
          ),
        ),
      );
    } else if (item.type == 'voice') {
      final cardColor = item.customColor ?? const Color(0xFFFFF0F5);
      final isThisPlaying = _playingVoiceItemId == item.id;
      final Map<String, dynamic> voiceData = (item.content is Map)
          ? Map<String, dynamic>.from(item.content as Map)
          : {'url': '', 'duration': item.content.toString(), 'seconds': 0};

      final String durationText = voiceData['duration']?.toString() ?? '00:10';
      final String audioUrl = voiceData['url']?.toString() ?? '';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFBCFE8)),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (isThisPlaying) {
                  _audioPlayer?.pause();
                  setState(() => _playingVoiceItemId = null);
                } else {
                  _audioPlayer?.dispose();
                  if (audioUrl.isNotEmpty) {
                    _audioPlayer = HtmlAudioPlayer(audioUrl);
                    _audioPlayer!.onEnded = () {
                      if (mounted) setState(() => _playingVoiceItemId = null);
                    };
                    _audioPlayer!.play();
                    setState(() => _playingVoiceItemId = item.id);
                  }
                }
              },
              child: CircleAvatar(
                radius: 14,
                backgroundColor: BlushyColors.primary,
                child: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Voice Note ($durationText)',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text),
            ),
          ],
        ),
      );
    } else if (item.type == 'ai_insight') {
      final cardColor = item.customColor ?? const Color(0xFFFDF2F2);
      return Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: BlushyColors.primary),
                const SizedBox(width: 4),
                Text('DR. DOCSY INSIGHTS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.content as String, style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.3)),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildItemEditToolbar() {
    final item = _items.firstWhere((it) => it.id == _selectedItemId, orElse: () => _items.first);
    return Positioned(
      bottom: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BlushyColors.text,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.flip_to_front_rounded, color: Colors.white, size: 16),
                tooltip: 'Bring to Front',
                onPressed: () => _bringToFront(item.id),
              ),
              IconButton(
                icon: const Icon(Icons.flip_to_back_rounded, color: Colors.white, size: 16),
                tooltip: 'Send to Back',
                onPressed: () => _sendToBack(item.id),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                tooltip: 'Zoom In',
                onPressed: () => setState(() => item.scale = (item.scale + 0.15).clamp(0.4, 3.0)),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 16),
                tooltip: 'Zoom Out',
                onPressed: () => setState(() => item.scale = (item.scale - 0.15).clamp(0.4, 3.0)),
              ),
              IconButton(
                icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 16),
                tooltip: 'Rotate 15°',
                onPressed: () => setState(() => item.rotation += 0.26),
              ),
              IconButton(
                icon: const Icon(Icons.color_lens_rounded, color: Colors.white, size: 16),
                tooltip: 'Object Color',
                onPressed: () => _showColorPickerDialog(item),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                tooltip: 'Duplicate',
                onPressed: () => _duplicateItem(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                tooltip: AppLocalizations.of(context).jrnDelete,
                onPressed: () => _deleteItem(item.id),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                tooltip: 'Deselect',
                onPressed: () => setState(() => _selectedItemId = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPickerDialog(ScrapbookItem item) {
    final initialColor = item.customColor ?? Colors.white;
    showDialog(
      context: context,
      builder: (context) {
        return _EditColorDialog(
          initialColor: initialColor,
          onApply: (selectedColor) {
            setState(() {
              item.customColor = selectedColor;
            });
          },
        );
      },
    );
  }

  Widget _buildBottomScrapbookToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BlushyColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toolbar Tab Buttons Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _buildToolbarTabButton('Stickers', Icons.face_retouching_natural_rounded),
                  _buildToolbarTabButton('Washi Tape', Icons.linear_scale_rounded),
                  _buildToolbarTabButton('Photo Frames', Icons.camera_alt_rounded),
                  _buildToolbarTabButton('Fonts', Icons.font_download_rounded),
                  _buildToolbarTabButton('Text Box', Icons.text_fields_rounded),
                  _buildToolbarTabButton('Voice Note', Icons.graphic_eq_rounded),
                  _buildToolbarTabButton('Dictate (STT)', Icons.mic_rounded),
                  _buildToolbarTabButton('Dr. Docsy Insights', Icons.auto_awesome_rounded),
                ],
              ),
            ),
            const Divider(height: 1, color: BlushyColors.border),
            // Active Asset Tray Drawer
            SizedBox(
              height: 52,
              child: _buildActiveAssetTray(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarTabButton(String label, IconData icon) {
    final isSelected = _activeToolbarTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeToolbarTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? BlushyColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? BlushyColors.primary : BlushyColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAssetTray() {
    if (_activeToolbarTab == 'Stickers') {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _stickersList.length,
        itemBuilder: (context, i) {
          final stk = _stickersList[i];
          return GestureDetector(
            onTap: () => _addItem('stk_${DateTime.now().millisecondsSinceEpoch}', 'sticker', stk, const Offset(60, 80)),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Center(
                child: Text(
                  stk['name'] as String,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: BlushyColors.text),
                ),
              ),
            ),
          );
        },
      );
    } else if (_activeToolbarTab == 'Washi Tape') {
      final tapes = [
        {'name': 'Pink Tape', 'color': const Color(0xFFFBCFE8)},
        {'name': 'Yellow Tape', 'color': const Color(0xFFFEF08A)},
        {'name': 'Mint Tape', 'color': const Color(0xFFA7F3D0)},
        {'name': 'Lavender Tape', 'color': const Color(0xFFE9D5FF)},
        {'name': 'Coral Tape', 'color': const Color(0xFFFDE68A)},
      ];

      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tapes.length,
        itemBuilder: (context, i) {
          final tp = tapes[i];
          return GestureDetector(
            onTap: () => _addItem('tape_${DateTime.now().millisecondsSinceEpoch}', 'tape', tp['color'], const Offset(40, 50)),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (tp['color'] as Color).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Center(
                child: Text(
                  tp['name'] as String,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: BlushyColors.text),
                ),
              ),
            ),
          );
        },
      );
    } else if (_activeToolbarTab == 'Photo Frames') {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          GestureDetector(
            onTap: _addPhotoFromGallery,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Center(
                child: Text('Add Polaroid Frame', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: BlushyColors.text)),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _addItem('photo_tint_${DateTime.now().millisecondsSinceEpoch}', 'text', '[Pink Rose Frame]', const Offset(70, 120)),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBCFE8)),
              ),
              child: Center(
                child: Text('Pink Rose Frame', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF831843))),
              ),
            ),
          ),
        ],
      );
    } else if (_activeToolbarTab == 'Fonts') {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _fonts.length,
        itemBuilder: (context, i) {
          final f = _fonts[i];
          final isSel = f == _activeFont;
          return GestureDetector(
            onTap: () => setState(() => _activeFont = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSel ? BlushyColors.primary : const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? BlushyColors.primary : BlushyColors.border),
              ),
              child: Center(
                child: Text(
                  f,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : BlushyColors.text),
                ),
              ),
            ),
          );
        },
      );
    } else if (_activeToolbarTab == 'Voice Note') {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() => _showRecordOverlay = true);
            _startRecordingFlow();
          },
          icon: const Icon(Icons.graphic_eq_rounded, size: 16),
          label: Text(AppLocalizations.of(context).journalRecordVoiceNote),
          style: OutlinedButton.styleFrom(
            foregroundColor: BlushyColors.primary,
            side: const BorderSide(color: BlushyColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    } else if (_activeToolbarTab == 'Dictate (STT)') {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() => _showRecordOverlay = true);
            _startRecordingFlow();
          },
          icon: const Icon(Icons.mic_rounded, size: 16),
          label: const Text('Dictate to Text (STT)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: BlushyColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      );
    } else if (_activeToolbarTab == 'Dr. Docsy Insights') {
      final prompt = _promptService.getPrompts().first;
      final localEntries = _entries.map((e) => LocalJournalEntry(id: e.id, date: e.dateTime.toString(), title: e.title, body: '', moodKey: e.moodKey)).toList();
      final reflection = _reflectionService.generateSummary(localEntries, ReflectionPeriod.weekly);
      final highlights = _highlightsService.generateHighlights(localEntries);
      final timeline = _moodTimelineService.buildTimeline(localEntries);

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _addItem('ai_${DateTime.now().millisecondsSinceEpoch}', 'ai_insight', 'Dr. Docsy Reflection: ${reflection.summaryText}', const Offset(30, 180)),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Add Reflection Summary'),
              style: ElevatedButton.styleFrom(backgroundColor: BlushyColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _addItem('text_${DateTime.now().millisecondsSinceEpoch}', 'text', prompt.text, const Offset(40, 100)),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
              label: Text('Prompt: ${prompt.category}'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
            const SizedBox(width: 8),
            if (highlights.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _addItem('ai_h_${DateTime.now().millisecondsSinceEpoch}', 'ai_insight', '${highlights.first.category}: ${highlights.first.title}', const Offset(50, 220)),
                icon: const Icon(Icons.star_rounded, size: 16),
                label: Text('Highlight (${timeline.length} entries)'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
          ],
        ),
      );
    } else {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () => _addItem('text_${DateTime.now().millisecondsSinceEpoch}', 'text', 'New reflection note...', const Offset(40, 100)),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(AppLocalizations.of(context).journalAddTextBox),
          style: OutlinedButton.styleFrom(
            foregroundColor: BlushyColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }
  }

  void _showAiTitlePickerModal() {
    final bodyText = _items.where((it) => it.type == 'text').map((it) => it.content.toString()).join(' ');
    final suggestions = _titleService.generateTitles(bodyText);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text('Dr. Docsy Title Suggestions', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Pick a title that matches your reflection mood:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              ...suggestions.map((title) => ListTile(
                    leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706)),
                    title: Text(title, style: GoogleFonts.caveat(fontSize: 20, fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() {
                        _titleController.text = title;
                      });
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showAiPrivacySettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).journalAiPrivacyControls, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).journalAiPrivacySub, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context).journalTitleGeneration, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Suggest thoughtful entry titles', style: GoogleFonts.poppins(fontSize: 11)),
                    value: _insightScheduler.enableTitles,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setModalState(() => _insightScheduler.updatePrivacySettings(titles: val));
                    },
                  ),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context).journalSmartSearch, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(AppLocalizations.of(context).journalSmartSearchSub, style: GoogleFonts.poppins(fontSize: 11)),
                    value: _insightScheduler.enableSearch,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setModalState(() => _insightScheduler.updatePrivacySettings(search: val));
                    },
                  ),
                  SwitchListTile(
                    title: Text('Memory Links', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Discover explainable links between memories', style: GoogleFonts.poppins(fontSize: 11)),
                    value: _insightScheduler.enableMemoryLinks,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setModalState(() => _insightScheduler.updatePrivacySettings(memoryLinks: val));
                    },
                  ),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context).journalCloudAi, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(AppLocalizations.of(context).journalCloudAiSub, style: GoogleFonts.poppins(fontSize: 11)),
                    value: _insightScheduler.enableCloudAi,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setModalState(() => _insightScheduler.updatePrivacySettings(cloudAi: val));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMemoryBookModal() {
    final localEntries = _entries.map((e) => LocalJournalEntry(
      id: e.id,
      date: e.dateTime.toString(),
      title: e.title,
      body: e.items.where((it) => it.type == 'text').map((it) => it.content.toString()).join(' '),
      moodKey: e.moodKey,
    )).toList();
    final book = _memoryBookService.generateWeeklyBook(localEntries);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFBEB),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title, style: GoogleFonts.caveat(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
              Text(book.datePeriodStr, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFB45309))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBookStatBadge('${book.totalEntries}', 'Entries'),
                  _buildBookStatBadge('${book.totalPhotos}', 'Photos'),
                  _buildBookStatBadge('${book.totalVoiceNotes}', 'Voice Notes'),
                ],
              ),
              const SizedBox(height: 16),
              Text('Favorite Reflection Moment:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
                child: Text('"${book.favoriteMomentSnippet}"', style: GoogleFonts.caveat(fontSize: 18, color: const Color(0xFF78350F))),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(AppLocalizations.of(context).journalCloseMemoryBook, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSmartSearchDialog() {
    final searchController = TextEditingController();
    final localEntries = _entries.map((e) => LocalJournalEntry(
      id: e.id,
      date: e.dateTime.toString(),
      title: e.title,
      body: e.items.where((it) => it.type == 'text').map((it) => it.content.toString()).join(' '),
      moodKey: e.moodKey,
    )).toList();

    showDialog(
      context: context,
      builder: (context) {
        List<SmartSearchResult> results = [];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text('Smart Context Search', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search (e.g. Beach, Happy, Exams)...',
                        prefixIcon: Icon(Icons.psychology_rounded, color: Color(0xFFD97706)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          results = _smartSearchService.search(val, localEntries);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (results.isEmpty)
                      Text(AppLocalizations.of(context).journalNoSearchMatch, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey))
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final res = results[i];
                            final connections = _connectionsService.findConnections(res.entry, localEntries);
                            final explanation = connections.isNotEmpty ? connections.first.explanation : res.matchedConcept;
                            return ListTile(
                              title: Text(res.entry.title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(explanation, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFD97706))),
                              onTap: () {
                                Navigator.pop(context);
                                final target = _entries.firstWhere((e) => e.id == res.entry.id, orElse: () => _entries.first);
                                _loadEntry(target);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookStatBadge(String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        children: [
          Text(count, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF92400E))),
        ],
      ),
    );
  }


  void _showThemeFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).journalPaperTheme, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BlushyColors.text)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _themes.map((t) {
                    final isSel = t['name'] == _activeTheme;
                    return ChoiceChip(
                      label: Text(t['name'] as String),
                      selected: isSel,
                      selectedColor: BlushyColors.primary.withValues(alpha: 0.2),
                      onSelected: (val) {
                        setState(() => _activeTheme = t['name'] as String);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).journalFontStyle, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: BlushyColors.text)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _fonts.map((f) {
                    final isSel = f == _activeFont;
                    return ChoiceChip(
                      label: Text(f),
                      selected: isSel,
                      selectedColor: BlushyColors.primary.withValues(alpha: 0.2),
                      onSelected: (val) {
                        setState(() => _activeFont = f);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isTranscribing ? AppLocalizations.of(context).jrnTranscribing : AppLocalizations.of(context).jrnRecordingVoiceNote,
                  style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: BlushyColors.text),
                ),
                const SizedBox(height: 20),
                if (_isTranscribing)
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(BlushyColors.primary))
                else
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController),
                    child: const CircleAvatar(
                      radius: 36,
                      backgroundColor: BlushyColors.primary,
                      child: Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_isTranscribing)
                  Text(
                    '00:${_recordingDuration.toString().padLeft(2, '0')}',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: BlushyColors.primary),
                  ),
                const SizedBox(height: 20),
                if (!_isTranscribing)
                  ElevatedButton(
                    onPressed: _stopRecordingAndTranscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(AppLocalizations.of(context).journalDoneRecording, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
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

    double y = 40.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 28.0;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLinesPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}

class _EditColorDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onApply;

  const _EditColorDialog({
    required this.initialColor,
    required this.onApply,
  });

  @override
  State<_EditColorDialog> createState() => _EditColorDialogState();
}

class _EditColorDialogState extends State<_EditColorDialog> {
  late int _red;
  late int _green;
  late int _blue;
  late TextEditingController _hexController;

  final List<Color> _basicColors = const [
    Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B),
    Color(0xFFFDBA74), Color(0xFFFB923C), Color(0xFFF59E0B), Color(0xFFD97706),
    Color(0xFFFEF08A), Color(0xFFFDE047), Color(0xFFEAB308), Color(0xFFCA8A04),
    Color(0xFFA7F3D0), Color(0xFF4ADE80), Color(0xFF22C55E), Color(0xFF15803D),
    Color(0xFF99F6E4), Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E),
    Color(0xFFBAE6FD), Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1),
    Color(0xFFC7D2FE), Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF3730A3),
    Color(0xFFE9D5FF), Color(0xFFC084FC), Color(0xFF9333EA), Color(0xFF6B21A8),
    Color(0xFFFBCFE8), Color(0xFFF472B6), Color(0xFFDB2777), Color(0xFF9D174D),
    Color(0xFFFFFFFF), Color(0xFFFDFBF7), Color(0xFFE5E7EB), Color(0xFF9CA3AF),
    Color(0xFF4B5563), Color(0xFF1F2937), Color(0xFF111827), Color(0xFF1A0F0A),
  ];

  @override
  void initState() {
    super.initState();
    _red = (widget.initialColor.r * 255).round();
    _green = (widget.initialColor.g * 255).round();
    _blue = (widget.initialColor.b * 255).round();
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => Color.fromRGBO(_red, _green, _blue, 1.0);

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _updateFromHex(String hex) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) {
        setState(() {
          _red = (val >> 16) & 0xFF;
          _green = (val >> 8) & 0xFF;
          _blue = val & 0xFF;
        });
      }
    }
  }

  void _setColor(Color color) {
    setState(() {
      _red = (color.r * 255).round();
      _green = (color.g * 255).round();
      _blue = (color.b * 255).round();
      _hexController.text = _colorToHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Color',
                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: BlushyColors.text),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                      decoration: InputDecoration(
                        labelText: 'Hex Code',
                        labelStyle: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: BlushyColors.primary),
                        ),
                      ),
                      onChanged: _updateFromHex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Red Slider
              Row(
                children: [
                  SizedBox(width: 45, child: Text('Red', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.redAccent,
                        thumbColor: Colors.redAccent,
                        overlayColor: Colors.redAccent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _red.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (val) {
                          setState(() {
                            _red = val.round();
                            _hexController.text = _colorToHex(_currentColor);
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 32, child: Text('$_red', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),

              // Green Slider
              Row(
                children: [
                  SizedBox(width: 45, child: Text('Green', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.green,
                        thumbColor: Colors.green,
                        overlayColor: Colors.green.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _green.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (val) {
                          setState(() {
                            _green = val.round();
                            _hexController.text = _colorToHex(_currentColor);
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 32, child: Text('$_green', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),

              // Blue Slider
              Row(
                children: [
                  SizedBox(width: 45, child: Text('Blue', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blueAccent,
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _blue.toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (val) {
                          setState(() {
                            _blue = val.round();
                            _hexController.text = _colorToHex(_currentColor);
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 32, child: Text('$_blue', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),

              const SizedBox(height: 16),
              Text('Basic Colors', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.secondaryText)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _basicColors.map((color) {
                  final isSelected = _currentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => _setColor(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? BlushyColors.primary : Colors.black12,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).jrnCancel, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: BlushyColors.secondaryText)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onApply(_currentColor);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(AppLocalizations.of(context).journalApply, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
