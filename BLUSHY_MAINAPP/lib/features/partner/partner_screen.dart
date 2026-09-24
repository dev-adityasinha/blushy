import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../shared/skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../../core/state.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/stage_config.dart';
import '../../core/storage.dart';
import '../../services/api_partner_service.dart';
import '../../services/auth_storage.dart';
import '../../services/partner_websocket_service.dart';
import 'digibouquet/state/bouquet_state.dart';
import 'digibouquet/screens/home_screen.dart';
import 'digibouquet/models/auth_models.dart';
import 'digibouquet/models/partner_models.dart';
import 'presentation/partner_sharing_screen.dart';
import 'widgets/breathing_sync_sheet.dart';
import 'date_idea.dart';
import '../../services/api_blushy_service.dart';
import 'presentation/partner_privacy_screen.dart';
import 'partner_display_name.dart';
import 'partner_chat.dart';
import 'pending_invite_code.dart';
import 'private_space.dart';
import 'presentation/private_space_sheet.dart';
import 'presentation/shared_sanctuary_sections.dart';
import '../../shared/docsy_avatar.dart';
import 'package:intl/intl.dart';
import '../../services/user_state_store.dart';
import '../sia/open_docsy.dart';
import 'presentation/couple_experiences_sheet.dart';

const Color kSanctuaryDark = kSanctuaryCharcoal;
const Color kSanctuarySubtext = kSanctuaryMuted;


class BlushyPartnerScreen extends StatefulWidget {
  const BlushyPartnerScreen({super.key});

  @override
  State<BlushyPartnerScreen> createState() => _BlushyPartnerScreenState();
}

class _BlushyPartnerScreenState extends State<BlushyPartnerScreen> {
  final ApiPartnerService _partnerService = ApiPartnerService();

  // Category navigation tabs
  final List<String> _tabs = [
    'Overview',
    'Bouquet',
    'Messenger',
    'Activities',
    'Letters',
    'Memory Book',
    'Relationship AI',
    'Gifts'
  ];
  int _selectedTabIndex = 0;

  // Garden state metrics (Simulated shared interactions)
  // The garden belongs to the connection and is loaded from the server, so
  // both partners see the same one. It used to live in this device's storage
  // under the name `shared_garden_state`, starting at 3 flowers and 1 tree --
  // a garden nobody had grown, that the partner never saw.
  int _flowersCount = 0;
  int _treesCount = 0;
  bool _hasPond = false;

  Future<void> _loadGarden() async {
    final connectionId = _activeConnectionId;
    if (connectionId == null) return;

    final result = await PartnerApi.garden(connectionId);
    if (!mounted) return;

    setState(() {
      final data = result.data;
      if (data != null) {
        _flowersCount = (data['flowers'] as num?)?.toInt() ?? 0;
        _treesCount = (data['trees'] as num?)?.toInt() ?? 0;
        _hasPond = data['hasPond'] == true;
      }
    });
  }

  Future<void> _growGarden({int flowers = 0, int trees = 0, bool addPond = false}) async {
    final connectionId = _activeConnectionId;
    if (connectionId == null) {
      _showComposerNotice('Connect with your partner first.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final result = await PartnerApi.growGarden(
      connectionId,
      flowers: flowers,
      trees: trees,
      addPond: addPond,
    );
    if (!mounted) return;

    if (result.data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Could not tend the garden.')),
      );
      return;
    }

    setState(() {
      _flowersCount = (result.data!['flowers'] as num?)?.toInt() ?? _flowersCount;
      _treesCount = (result.data!['trees'] as num?)?.toInt() ?? _treesCount;
      _hasPond = result.data!['hasPond'] == true;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).ptGardenGrew)),
    );
  }

  // Messenger states
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _messengerScrollController = ScrollController();
  int _selectedMessageIndexForActions = -1;
  bool _showComposerActionsMenu = false;

  void _scrollToBottomMessenger() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messengerScrollController.hasClients) {
        _messengerScrollController.animateTo(
          _messengerScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Partner connections state
  List<Map<String, dynamic>> _connections = [];

  // Whether the first connection load (cache + server) has resolved. Until it
  // has, an empty _connections means "still loading", not "no partner" -- so the
  // screen shows a spinner rather than flashing the unpaired "Invite Partner"
  // view over an account that is in fact connected.
  bool _connectionsLoaded = false;

  // Whether the connected partner currently has a live socket. Seeded from the
  // connection's `partnerOnline` on each load and kept live by the
  // 'partner.presence' events the server sends on connect/disconnect.
  bool _partnerOnline = false;

  /// The partner's online flag as it stands in the latest connection payload.
  bool _connectionPartnerOnline() =>
      _connections.isNotEmpty && _connections.first['partnerOnline'] == true;

  // Whether the partner is currently typing, driven by 'partner.typing' events.
  bool _partnerTyping = false;
  // Clears the indicator if the partner's "stopped" ping never arrives (socket
  // drop, backgrounded app), so it can never stick "typing…" for ever.
  Timer? _partnerTypingClearTimer;
  // Throttles our own outgoing typing pings and remembers the last state sent,
  // so we send at most one ping per burst and one "stopped" when idle.
  Timer? _typingIdleTimer;
  bool _typingSent = false;

  // Shared activities belong to the connection: whatever one partner does, the
  // other sees. They are loaded from the server rather than assumed.
  List<SharedActivity> _sharedActivities = const [];
  bool _activitiesLoading = false;
  String? _activityBusyKey;

  // Relationship AI (tab 6)
  final TextEditingController _relationshipController = TextEditingController();
  String? _relationshipAnswer;
  String? _relationshipError;
  bool? _relationshipUsedPartnerData;
  bool _relationshipLoading = false;
  bool _dateIdeasLoading = false;

  String? get _activeConnectionId {
    if (_connections.isEmpty) return null;
    final active = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => _connections.first,
    );
    final id = active['connectionId'] ?? active['id'] ?? active['_id'];
    return id?.toString();
  }

  static const List<SharedActivity> _defaultActivities = [
    SharedActivity(
      key: 'date_planner',
      title: 'Date Planner & AI Concierge',
      description: 'Plan your next date with Docsy venue & seat booking ideas.',
      status: 'not_started',
    ),
    SharedActivity(
      key: 'shared_canvas',
      title: 'Shared Drawing Canvas',
      description: 'Doodle, sketch cute notes, and draw together in real time.',
      status: 'not_started',
    ),
    SharedActivity(
      key: 'couple_games',
      title: 'Couple Games & Questions',
      description: 'Play Would You Rather, Pillow Talk, and text challenges.',
      status: 'not_started',
    ),
    SharedActivity(
      key: 'virtual_bouquet',
      title: 'Virtual Bouquet & Blooms',
      description: 'Arrange and send digital wildflowers for each other.',
      status: 'not_started',
    ),
    SharedActivity(
      key: 'daily_gratitude',
      title: 'Daily Gratitude Challenge',
      description: 'Each of you names one thing you appreciated today.',
      status: 'not_started',
    ),
  ];

  Future<void> _loadSharedActivities() async {
    final connId = _activeConnectionId;
    if (connId == null) {
      if (mounted) setState(() => _sharedActivities = const []);
      return;
    }
    if (mounted) setState(() => _activitiesLoading = true);
    final activities = await _partnerService.getSharedActivities(connId);
    if (!mounted) return;
    setState(() {
      _sharedActivities = activities.isNotEmpty ? activities : _defaultActivities;
      _activitiesLoading = false;
    });
  }

  Future<void> _advanceActivity(SharedActivity activity) async {
    final next = activity.isInProgress ? 'completed' : 'in_progress';
    final nextCount = next == 'completed' ? activity.completionCount + 1 : activity.completionCount;
    final nextCompletedAt = next == 'completed' ? DateTime.now() : null;

    // Optimistically update local state so user sees instant feedback
    setState(() {
      _activityBusyKey = activity.key;
      final currentList = List<SharedActivity>.from(_sharedActivities.isNotEmpty ? _sharedActivities : _defaultActivities);
      final idx = currentList.indexWhere((a) => a.key == activity.key);
      final updatedItem = SharedActivity(
        key: activity.key,
        title: activity.title,
        description: activity.description,
        status: next,
        completionCount: nextCount,
        completedAt: nextCompletedAt,
      );
      if (idx >= 0) {
        currentList[idx] = updatedItem;
      } else {
        currentList.add(updatedItem);
      }
      _sharedActivities = currentList;
    });

    if (next == 'completed') {
      await _growGarden(flowers: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kSanctuaryCharcoal,
            content: Text(
              '“${activity.title}” completed together! 🌸',
              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kSanctuaryCharcoal,
            content: Text(
              'Activity started! “${activity.title}”',
              style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    }

    final connId = _activeConnectionId;
    if (connId != null) {
      final updated = await _partnerService.setSharedActivityStatus(connId, activity.key, next);
      if (mounted) {
        setState(() {
          _activityBusyKey = null;
          if (updated != null && updated.isNotEmpty) _sharedActivities = updated;
        });
      }
    } else {
      if (mounted) {
        setState(() => _activityBusyKey = null);
      }
    }
  }

  Future<void> _sendDirectWhisper(String text) async {
    if (text.trim().isEmpty) return;
    final state = BlushyOSProvider.of(context);
    final currentUserId = AuthStorage.getUserId();
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final String myName = (state.personalContext.userName != null && state.personalContext.userName!.isNotEmpty)
        ? state.personalContext.userName!
        : "You";

    final newLocalMsg = {
      'sender': myName,
      'senderUserId': currentUserId,
      'senderRole': currentRole,
      'text': text,
      'isAudio': false,
      'isCard': false,
      'isMe': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _chatMessages.add(newLocalMsg);
      _saveSharedGardenState();
    });
    _scrollToBottomMessenger();

    final activeConn = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    if (activeConn.isNotEmpty && activeConn['connectionId'] != null) {
      final connId = activeConn['connectionId'].toString();
      final res = await _partnerService.sendMessage(connId, text);
      if (res != null) {
        _syncLiveMessages();
      }
    }
  }

  void _launchActivityExperience(SharedActivity activity, String partnerName) {
    switch (activity.key) {
      case 'date_planner':
        showDatePlannerSheet(
          context,
          partnerName: partnerName,
          onSendInvite: (inviteMsg) {
            _sendDirectWhisper(inviteMsg);
            _advanceActivity(activity);
          },
          onAskDocsy: (prompt) {
            openDocsyWith(context, prompt);
          },
        );
        break;
      case 'shared_canvas':
        showSharedCanvasSheet(
          context,
          partnerName: partnerName,
          onSendDrawing: (drawingMsg) {
            _sendDirectWhisper(drawingMsg);
            _advanceActivity(activity);
          },
        );
        break;
      case 'couple_games':
        showCoupleGamesSheet(
          context,
          partnerName: partnerName,
          onSendGameQuestion: (gameMsg) {
            _sendDirectWhisper(gameMsg);
            _advanceActivity(activity);
            _openPartnerTab(2);
          },
        );
        break;
      case 'virtual_bouquet':
        _openPartnerTab(1);
        break;
      default:
        _advanceActivity(activity);
        break;
    }
  }

  bool _showActiveStatus = true;
  bool _showReadReceipts = true;

  void _loadPresenceSettings() {
    try {
      final activeSaved = BlushyStorage.read('partner_show_active_status');
      if (activeSaved['enabled'] is bool) {
        _showActiveStatus = activeSaved['enabled'] as bool;
      }
      final receiptsSaved = BlushyStorage.read('partner_read_receipts');
      if (receiptsSaved['enabled'] is bool) {
        _showReadReceipts = receiptsSaved['enabled'] as bool;
      }
    } catch (_) {}
  }
  List<Map<String, dynamic>> _incomingInvitations = [];
  List<Map<String, dynamic>> _outgoingInvitations = [];
  final TextEditingController _partnerInviteEmailController = TextEditingController();
  bool _isSendingInvite = false;
  Timer? _liveChatTimer;
  Set<String> _knownIncomingInvitationIds = {};
  bool _hadActiveConnection = false;
  bool _isLiveSyncing = false;

  // Her Message Decoder state
  bool _isMessageDecoderActive = false;
  final Map<String, Map<String, dynamic>> _decodedMessages = {};
  final Set<String> _decodingMessageIds = {};

  void _loadMessageDecoderState() {
    try {
      final saved = UserStateStore.read('partner_decoder_enabled');
      if (saved['enabled'] is bool) {
        setState(() {
          _isMessageDecoderActive = saved['enabled'] as bool;
        });
      }
    } catch (_) {}
  }

  void _toggleMessageDecoder() {
    setState(() {
      _isMessageDecoderActive = !_isMessageDecoderActive;
    });
    try {
      UserStateStore.write('partner_decoder_enabled', {
        'enabled': _isMessageDecoderActive,
      });
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMessageDecoderActive
              ? '✨ Message Decoder enabled. Docsy will analyze her messages in Messenger.'
              : 'Message Decoder disabled.',
        ),
      ),
    );
  }

  Future<void> _decodeMessageForPartner(String msgId, String messageText) async {
    if (_decodingMessageIds.contains(msgId)) return;
    setState(() {
      _decodingMessageIds.add(msgId);
    });

    try {
      final connId = _activeConnectionId ?? '';
      if (connId.isEmpty) {
        // Previously this sent the literal string 'local_active', which the
        // server could only reject -- and the rejection was swallowed, so the
        // button appeared to do nothing.
        setState(() => _decodingMessageIds.remove(msgId));
        _showComposerNotice('Connect with your partner first.');
        return;
      }

      final result = await _partnerService.decodeMessage(
        connectionId: connId,
        messageText: messageText,
      );

      if (mounted && result != null) {
        setState(() {
          _decodedMessages[msgId] = result;
          _decodingMessageIds.remove(msgId);
        });
      } else if (mounted) {
        // A failed decode used to just stop the spinner, which is
        // indistinguishable from a button that is not wired up.
        setState(() => _decodingMessageIds.remove(msgId));
        _showComposerNotice('Docsy could not read that message just now.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _decodingMessageIds.remove(msgId);
        });
      }
    }
  }

  void _saveSharedGardenState() {
    try {
      BlushyStorage.write('shared_garden_state', {
        'flowersCount': _flowersCount,
        'treesCount': _treesCount,
        'hasPond': _hasPond,
        'messages': _chatMessages,
      });
    } catch (_) {}
  }

  void _syncWithStorage() {
    try {
      final shared = BlushyStorage.read('shared_garden_state');
      if (shared.isNotEmpty) {
        final newFlowers = shared['flowersCount'] as int? ?? 3;
        final newTrees = shared['treesCount'] as int? ?? 1;
        final newPond = shared['hasPond'] as bool? ?? false;
        
        bool changed = false;
        if (newFlowers != _flowersCount) {
          _flowersCount = newFlowers;
          changed = true;
        }
        if (newTrees != _treesCount) {
          _treesCount = newTrees;
          changed = true;
        }
        if (newPond != _hasPond) {
          _hasPond = newPond;
          changed = true;
        }
        if (shared['messages'] != null) {
          final List<dynamic> newMsgs = shared['messages'];
          final filtered = newMsgs
              .where((m) =>
                  m is Map &&
                  m['text'] != 'Hey, looking forward to our walk after dinner tonight!' &&
                  m['text'] != 'Listen to this reflection voice memo from my day')
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
          if (filtered.length != _chatMessages.length) {
            _chatMessages.clear();
            _chatMessages.addAll(filtered);
            changed = true;
          }
        }
        
        if (changed && mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    try {
      final shared = BlushyStorage.read('shared_garden_state');
      if (shared.isNotEmpty) {
        if (shared['flowersCount'] != null) _flowersCount = shared['flowersCount'] as int;
        if (shared['treesCount'] != null) _treesCount = shared['treesCount'] as int;
        if (shared['hasPond'] != null) _hasPond = shared['hasPond'] as bool;
        if (shared['messages'] != null) {
          _chatMessages.clear();
          final loaded = List<Map<String, dynamic>>.from(shared['messages']);
          final filtered = loaded.where((m) =>
              m['text'] != 'Hey, looking forward to our walk after dinner tonight!' &&
              m['text'] != 'Listen to this reflection voice memo from my day').toList();
          _chatMessages.addAll(filtered);
          _saveSharedGardenState();
        }
      } else {
        _saveSharedGardenState();
      }
    } catch (_) {}
    try {
      // Read through UserStateStore -- the same store the cache is WRITTEN
      // through below (_fetchPartnerData). It previously read via BlushyStorage
      // with the raw key while the write went through UserStateStore's mirrored
      // key, so this synchronous read always missed and the screen flashed the
      // unpaired "Invite Partner" view before the server answered. Reading it
      // consistently means a returning, connected user sees the paired state on
      // the very first frame.
      final cachedConnections = UserStateStore.read('partner_connections_cache');
      if (cachedConnections.isNotEmpty) {
        if (cachedConnections['connections'] is List) {
          _connections = List<Map<String, dynamic>>.from(
            (cachedConnections['connections'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
        if (cachedConnections['incoming'] is List) {
          _incomingInvitations = List<Map<String, dynamic>>.from(
            (cachedConnections['incoming'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
        if (cachedConnections['outgoing'] is List) {
          _outgoingInvitations = List<Map<String, dynamic>>.from(
            (cachedConnections['outgoing'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
        _hadActiveConnection = _connections.any((c) => c['status'] == 'active');
        _partnerOnline = _connectionPartnerOnline();
        if (_connections.isNotEmpty) {
          unawaited(_loadSharedActivities());
        }
      }
    } catch (_) {}

    _loadMessageDecoderState();
    _loadPresenceSettings();
    _fetchPartnerData();
    _startLiveSync();
    _initWebSocket();
    _checkUrlFragmentClaim();
  }

  StreamSubscription<PartnerWebSocketEvent>? _wsSubscription;
  bool _isClaimingFragmentCode = false;

  void _initWebSocket() {
    final ws = PartnerWebSocketService();
    ws.connect();
    _wsSubscription = ws.events.listen((event) {
      if (!mounted) return;
      if (event.event == 'partner.presence') {
        // The server sends this to a user when their partner's socket connects
        // or fully disconnects. Only sent about this user's partner, so applies
        // straight to the online dot.
        final online = event.rawPayload['online'] == true;
        if (online != _partnerOnline) {
          setState(() => _partnerOnline = online);
        }
        return;
      }
      if (event.event == 'partner.typing') {
        final typing = event.rawPayload['typing'] == true;
        _partnerTypingClearTimer?.cancel();
        if (typing) {
          if (!_partnerTyping) setState(() => _partnerTyping = true);
          // Safety net: if the "stopped" ping is lost, clear it anyway.
          _partnerTypingClearTimer = Timer(const Duration(seconds: 6), () {
            if (mounted && _partnerTyping) setState(() => _partnerTyping = false);
          });
        } else {
          if (_partnerTyping) setState(() => _partnerTyping = false);
        }
        return;
      }
      if (event.reason == 'message-sent') {
        _syncLiveMessages();
      } else if (event.reason == 'invitation-accepted' ||
          event.reason == 'invitation-sent' ||
          event.reason == 'permissions-updated' ||
          event.reason == 'breakup-requested' ||
          event.reason == 'breakup-completed') {
        _fetchPartnerData();
      }
    });
  }

  /// Redeems the invite the app was opened with, if there was one.
  ///
  /// The code comes from `PendingInviteCode` rather than from `Uri.base` here.
  /// By the time this screen mounts the recipient has been through sign-in and
  /// possibly the whole onboarding wizard, and every `pushReplacementNamed`
  /// along the way rewrote the browser URL through the hash strategy -- so the
  /// fragment this used to read said `/home` by then, and the invite was
  /// silently dropped on exactly the accounts it was written for.
  void _checkUrlFragmentClaim() {
    if (_isClaimingFragmentCode) return;
    final code = PendingInviteCode.code;
    if (code == null) return;
    _isClaimingFragmentCode = true;
    _claimInviteCodeSafely(code);
  }

  Future<void> _claimInviteCodeSafely(String code) async {
    try {
      final res = await _partnerService.acceptInviteLink(code);
      if (!mounted) return;

      if (res['error'] != null) {
        // A verdict spends the code; a failure to reach the server does not.
        // Render's free instance pays a cold start of up to ~27s, and burning
        // the invite on that timeout would leave the recipient with a link
        // that can never be redeemed again.
        const spent = {400, 403, 409};
        if (spent.contains(res['statusCode'] as int?)) {
          PendingInviteCode.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'].toString()),
            backgroundColor: BlushyColors.primary,
          ),
        );
      } else {
        PendingInviteCode.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).ptConnectedSuccess),
            backgroundColor: BlushyColors.success,
          ),
        );
        _fetchPartnerData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim invite link: $e'),
            backgroundColor: BlushyColors.primary,
          ),
        );
      }
    } finally {
      _isClaimingFragmentCode = false;
    }
  }

  void _startLiveSync() {
    _liveChatTimer?.cancel();
    _liveChatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _syncLiveCycle();
      }
    });
  }

  Future<void> _syncLiveCycle() async {
    if (_isLiveSyncing) return;
    _isLiveSyncing = true;
    try {
      await Future.wait([
        _syncLiveMessages(),
        _syncLiveInvitationsAndConnections(),
      ]);
    } finally {
      _isLiveSyncing = false;
    }
  }

  Future<void> _syncLiveInvitationsAndConnections() async {
    try {
      final incoming = await _partnerService.getIncomingInvitations();
      final outgoing = await _partnerService.getOutgoingInvitations();
      final connections = await _partnerService.getConnections();

      if (!mounted) return;

      // 1. Check for brand new incoming invitations
      final currentIncomingIds = incoming
          .map((i) => (i['invitationId'] ?? i['_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final inv in incoming) {
        final invId = (inv['invitationId'] ?? inv['_id'] ?? '').toString();
        if (invId.isNotEmpty && !_knownIncomingInvitationIds.contains(invId)) {
          final senderEmail = inv['senderEmail'] as String? ?? inv['senderUserId'] as String? ?? 'A partner';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💌 Partner Request from $senderEmail!'),
              backgroundColor: BlushyColors.primary,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: AppLocalizations.of(context).ptAccept,
                textColor: Colors.white,
                onPressed: () async {
                  final ok = await _partnerService.respondToInvitation(invId, 'accept');
                  if (ok) {
                    await _fetchPartnerData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context).ptPortalLive),
                          backgroundColor: BlushyColors.success,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      }
      _knownIncomingInvitationIds = currentIncomingIds;

      // 2. Check if a previously pending request was accepted by the opposite person
      final hasActiveNow = connections.any((c) => c['status'] == 'active');
      if (!_hadActiveConnection && hasActiveNow) {
        _hadActiveConnection = true;
        final activeConn = connections.firstWhere((c) => c['status'] == 'active', orElse: () => <String, dynamic>{});
        // The moment they connect is the moment to start using their name.
        // Invitations stay addressed by email -- that is how you reach someone
        // you have not connected with -- but this fires after the handshake.
        final partnerLabel = partnerDisplayName(activeConn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 $partnerLabel accepted your request! Live connection active.'),
            backgroundColor: BlushyColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (!hasActiveNow) {
        _hadActiveConnection = false;
      }

      // 3. Compare state and update lively
      bool changed = false;
      if (incoming.length != _incomingInvitations.length ||
          outgoing.length != _outgoingInvitations.length ||
          connections.length != _connections.length) {
        changed = true;
      }

      if (changed && mounted) {
        setState(() {
          _incomingInvitations = incoming;
          _outgoingInvitations = outgoing;
          _connections = connections;
        });
      }
    } catch (_) {}
  }

  Future<void> _syncLiveMessages() async {
    final activeConn = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    if (activeConn.isNotEmpty && activeConn['connectionId'] != null) {
      final connId = activeConn['connectionId'].toString();
      final apiMsgs = await _partnerService.getMessages(connId);
      if (apiMsgs.isNotEmpty && mounted) {
        // Mapping (mixed camel/snake fields) and the diff live in PartnerChat,
        // where they are unit-tested.
        final mapped = PartnerChat.mapMessages(apiMsgs, AuthStorage.getUserId());

        if (PartnerChat.messagesDiffer(mapped, _chatMessages)) {
          setState(() {
            _chatMessages.clear();
            _chatMessages.addAll(mapped);
          });
          _saveSharedGardenState();
        }
        return;
      }
    }

    _syncWithStorage();
  }

  Future<void> _fetchPartnerData() async {
    if (!mounted) return;
    try {
      final connections = await _partnerService.getConnections();
      final incoming = await _partnerService.getIncomingInvitations();
      final outgoing = await _partnerService.getOutgoingInvitations();

      if (mounted) {
        final currentIncomingIds = incoming
            .map((i) => (i['invitationId'] ?? i['_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        _knownIncomingInvitationIds = currentIncomingIds;
        _hadActiveConnection = connections.any((c) => c['status'] == 'active');

        setState(() {
          _connections = connections;
          _incomingInvitations = incoming;
          _outgoingInvitations = outgoing;
          _partnerOnline = _connectionPartnerOnline();
        });
        try {
          UserStateStore.write('partner_connections_cache', {
            'connections': connections,
            'incoming': incoming,
            'outgoing': outgoing,
          });
        } catch (_) {}
        // The connection id is only known now, and the activities hang off it.
        unawaited(_loadSharedActivities());
        unawaited(_loadGarden());
        _syncLiveMessages();
        // If the other partner ended things, this is where we find out.
        unawaited(_showEndedByPartnerNotice());
      }
    } catch (e) {
      debugPrint('Error fetching partner data: $e');
    } finally {
      if (mounted) {
        setState(() {
          // The first load has resolved (succeeded or failed): from here an
          // empty _connections genuinely means "no partner", so the unpaired
          // view is correct rather than a premature flash.
          _connectionsLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _messengerScrollController.dispose();
    _wsSubscription?.cancel();
    _liveChatTimer?.cancel();
    _partnerTypingClearTimer?.cancel();
    _typingIdleTimer?.cancel();
    _msgController.dispose();
    _partnerInviteEmailController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  String _getFloatingActionText() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Overview':
        return 'Grow Garden';
      case 'Bouquet':
        return 'Create Bouquet';
      case 'Messenger':
        return 'Send Msg';
      case 'Activities':
        return 'Start Activity';
      case 'Letters':
        return 'Send Letter';
      case 'Memory Book':
        return 'Add Scrapbook';
      case 'Relationship AI':
        return 'Ask Docsy';
      case 'Gifts':
        return 'Send Surprise';
      default:
        return 'Interact';
    }
  }

  IconData _getFloatingActionIcon() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Overview':
        return Icons.local_florist_rounded;
      case 'Bouquet':
        return Icons.card_giftcard_rounded;
      case 'Messenger':
        return Icons.send_rounded;
      case 'Activities':
        return Icons.rocket_launch_rounded;
      case 'Letters':
        return Icons.email_outlined;
      case 'Memory Book':
        return Icons.add_a_photo_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  void _onFloatingActionTap() {
    final activeTab = _tabs[_selectedTabIndex];
    if (activeTab == 'Overview') {
      // Grown on the connection, so the check-in shows up for both of you.
      // This used to bump a counter in this device's storage only.
      unawaited(_growGarden(flowers: 2, addPond: _flowersCount + 2 > 6));
    } else if (activeTab == 'Messenger') {
      _sendTextMessage();
    } else if (activeTab == 'Activities') {
      _showActivityTriggerDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting $activeTab action...')),
      );
    }
  }

  /// Sends throttled typing pings as she types: one "typing" at the start of a
  /// burst, and one "stopped" after ~3s idle or when the field is cleared.
  void _handleTypingInput(String text) {
    final ws = PartnerWebSocketService();
    if (text.trim().isNotEmpty) {
      if (!_typingSent) {
        _typingSent = true;
        ws.sendTyping(true);
      }
      _typingIdleTimer?.cancel();
      _typingIdleTimer = Timer(const Duration(seconds: 3), () {
        if (_typingSent) {
          _typingSent = false;
          ws.sendTyping(false);
        }
      });
    } else {
      _stopTyping();
    }
  }

  /// Immediately tells the partner we've stopped typing (on send or on clear).
  void _stopTyping() {
    _typingIdleTimer?.cancel();
    if (_typingSent) {
      _typingSent = false;
      PartnerWebSocketService().sendTyping(false);
    }
  }

  void _sendTextMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    _stopTyping();
    final state = BlushyOSProvider.of(context);
    final currentUserId = AuthStorage.getUserId();
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final String myName = (state.personalContext.userName != null && state.personalContext.userName!.isNotEmpty)
        ? state.personalContext.userName!
        : "You";

    final newLocalMsg = {
      'sender': myName,
      'senderUserId': currentUserId,
      'senderRole': currentRole,
      'text': text,
      'isAudio': false,
      'isCard': false,
      'isMe': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _chatMessages.add(newLocalMsg);
      _saveSharedGardenState();
    });
    _scrollToBottomMessenger();

    final activeConn = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    if (activeConn.isNotEmpty && activeConn['connectionId'] != null) {
      final connId = activeConn['connectionId'].toString();
      final res = await _partnerService.sendMessage(connId, text);
      if (res != null) {
        _syncLiveMessages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final isHome = _selectedTabIndex == 0;
    return Scaffold(
      backgroundColor: kSanctuaryCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isHome && _tabs[_selectedTabIndex] != 'Messenger') ...[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: BlushyTheme.getPagePadding(context),
                      vertical: 10.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: kSanctuaryCharcoal, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedTabIndex = 0;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PARTNER',
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: kSanctuaryCrimson,
                              ),
                            ),
                            Text(
                              _tabs[_selectedTabIndex],
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: kSanctuaryCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: kSanctuaryDivider, height: 1),
                ],

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _tabs[_selectedTabIndex] == 'Messenger'
                            ? 0.0
                            : BlushyTheme.getPagePadding(context),
                      ),
                      child: _buildWorkspaceTabContent(state),
                    ),
                  ),
                ),
              ],
            ),

            // Message long press action menu overlay
            if (_selectedMessageIndexForActions != -1) _buildMessageActionsOverlay(),

            // Adaptive Floating Action Button (Not visible in Messenger for clean layout)
            if (_tabs[_selectedTabIndex] != 'Messenger' && _tabs[_selectedTabIndex] != 'Overview') _buildAdaptiveFloatingActionButton(),
          ],
        ),
      ),
    );
  }


  /// How long is left, for the label under "Private space active".
  String _privateSpaceRemaining() {
    final id = _activeConnectionId;
    if (id == null) return 'Until you resume';
    return PrivateSpace.stateFor(id)?.remainingLabel ?? 'Until you resume';
  }

  /// Pauses what her partner receives, for real.
  ///
  /// The old Argument Mode was a local boolean that never left her device: her
  /// partner kept receiving her cycle, mood and sleep the entire time. This
  /// switches the personal permission keys off through the endpoint that
  /// already governs them, so the pause is enforced by the server.
  ///
  /// The local flag is still set, because the rest of the app reads it -- but
  /// it is no longer the thing doing the work.
  Future<void> _takeSomeSpace(BlushyOSState state) async {
    final connectionId = _activeConnectionId;
    if (connectionId == null) {
      _showConnectFirstDialog();
      return;
    }

    final choice = await PrivateSpaceSheet.show(context);
    if (choice == null || !mounted) return;

    final conn = _connections.firstWhere(
      (c) => c['connectionId'] == connectionId,
      orElse: () => <String, dynamic>{},
    );
    final permissions = conn['permissions'] is Map
        ? Map<String, dynamic>.from(conn['permissions'] as Map)
        : <String, dynamic>{};

    final messenger = ScaffoldMessenger.of(context);
    final ok = await PrivateSpace.take(
      connectionId: connectionId,
      currentPermissions: permissions,
      forDuration: choice.forDuration,
      note: choice.note,
    );
    if (!mounted) return;

    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          // Not "could not reach the server": the server may well have been
          // reached and have refused. Saying which it was would need the
          // error itself; what matters to her is that nothing changed.
          content: Text(
            'Private space could not be turned on, so nothing has changed. '
            'Your sharing is still on.',
          ),
        ),
      );
      return;
    }

    state.setArgumentModeActive(true);
    await _fetchPartnerData();
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).ptPrivateSpaceOn),
      ),
    );
  }

  /// Puts back exactly the sharing she had before.
  Future<void> _resumeSharing(BlushyOSState state) async {
    final connectionId = _activeConnectionId;
    final messenger = ScaffoldMessenger.of(context);

    if (connectionId != null) {
      final ok = await PrivateSpace.resume(connectionId);
      if (!mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not reach the server. Your sharing is still paused.',
            ),
          ),
        );
        return;
      }
    }

    state.setArgumentModeActive(false);
    await _fetchPartnerData();
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).ptSharingResumed)),
    );
  }




  Widget _buildWorkspaceTabContent(BlushyOSState state) {
    switch (_tabs[_selectedTabIndex]) {
      case 'Overview':
        return _buildOverviewTab(state);
      case 'Bouquet':
        return _buildBouquetTab();
      case 'Messenger':
        return _buildMessengerTab(state);
      case 'Activities':
        return _buildActivitiesTab();
      case 'Letters':
        return _buildLettersTab();
      case 'Memory Book':
        return _buildMemoryBookTab();
      case 'Relationship AI':
        return _buildRelationshipAITab(state);
      case 'Gifts':
        return _buildGiftsTab();
      default:
        return _buildOverviewTab(state);
    }
  }

  // --- TAB 1: PARTNER SPACE (WOMAN'S HOME) ---
  Widget _buildOverviewTab(BlushyOSState state) {
    final hasConnection = _connections.isNotEmpty;

    // Until the first load resolves, an empty list means "still loading", not
    // "no partner": show a spinner rather than flashing the unpaired "Invite
    // Partner" view over an account that is actually connected.
    if (!hasConnection && !_connectionsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 96),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kSanctuaryCrimson,
          ),
        ),
      );
    }

    final primaryPartner = hasConnection ? _connections.first : null;
    final partnerName = primaryPartner != null
        ? partnerDisplayName(Map<String, dynamic>.from(primaryPartner))
        : 'Your Partner';
    final durationText = primaryPartner != null
        ? formatConnectionDuration(primaryPartner['created_at'] ?? primaryPartner['createdAt'])
        : '';
    final signals = _buildSanctuarySignals(state, primaryPartner);
    final rightNow = _getRightNowEvent(partnerName);

    final letters = _getLettersList();
    final lettersCount = letters.length;
    final sealedLettersCount = letters.where((l) => l['sealed'] == true).length;
    final bloomsCount = _flowersCount;

    final completedMemories = _sharedActivities.where((a) => a.isCompleted).toList();
    final memoryCount = completedMemories.length;
    final latestMemory = completedMemories.isNotEmpty ? completedMemories.first : null;
    final latestMemoryTitle = latestMemory?.title;
    final latestMemoryDate = latestMemory?.completedAt != null
        ? DateFormat('MMMM d').format(latestMemory!.completedAt!)
        : null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 14, bottom: 48),
      children: [
        // 01 — PARTNER SPACE (Unboxed Editorial Header)
        SharedSanctuaryHeader(
          hasConnection: hasConnection,
          partnerName: partnerName,
          durationText: durationText,
          isPrivateSpaceActive: state.argumentModeActive,
          onInvite: _showPartnerConnectionsModal,
          onManageConnection: () => _showManageConnectionSheet(state),
          onOpenMessenger: hasConnection ? () => _openPartnerTab(2) : null,
          partnerOnline: _partnerOnline,
        ),
        const SizedBox(height: 20),

        if (_incomingInvitations.isNotEmpty) ...[
          _buildPendingRequestsBanner(),
          const SizedBox(height: 20),
        ],

        if (hasConnection) ...[
          // 02 — TODAY, TOGETHER (Dynamic Signal Rail)
          if (signals.isNotEmpty) ...[
            TodayTogetherSignalRail(signals: signals),
            const SizedBox(height: 24),
          ],

          // 03 — RIGHT NOW (Primary Real-Time Relationship Experience)
          // Suppressed when rightNow is a message event to avoid duplicate messaging cards
          if (rightNow.type != RightNowEventType.message) ...[
            RightNowCard(
              type: rightNow.type,
              partnerName: partnerName,
              headline: rightNow.headline,
              bodyText: rightNow.bodyText,
              timeDisplay: rightNow.timeDisplay,
              primaryCtaText: rightNow.primaryCtaText,
              secondaryCtaText: rightNow.secondaryCtaText,
              onPrimaryTap: rightNow.onPrimaryTap,
              onSecondaryTap: rightNow.onSecondaryTap,
            ),
            const SizedBox(height: 24),
          ],

          // 03.5 — DIRECT MESSENGER (Spotlight Stealer — Instagram Direct & Notes style)
          MessengerSpotlightCard(
            partnerName: partnerName,
            onOpenMessenger: () => _openPartnerTab(2),
            unreadCount: rightNow.type == RightNowEventType.message ? 1 : 0,
            latestSnippet: rightNow.type == RightNowEventType.message ? rightNow.bodyText : null,
          ),
          const SizedBox(height: 24),

          // 04 — MAKE A LITTLE MOMENT (Tactile Surprises & Micro-Gestures)
          MakeALittleMomentRail(
            onSendBloom: () => _openPartnerTab(1),
            onWriteLetter: () => _showWriteLetterModal(context),
            onSendWarmGesture: () => showWarmGestureSheet(
              context,
              partnerName: partnerName,
              onSendGesture: (msg) {
                _sendDirectWhisper(msg);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Sent a warm gesture to $partnerName ☕❤️',
                      style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: kSanctuaryCharcoal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
              },
            ),
            onVoiceWhisper: () {
              _openPartnerTab(2);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Tap the voice whisper icon to record audio for $partnerName 🎙️',
                    style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: kSanctuaryCharcoal,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
            onShareVibe: () => showVibePulseSheet(
              context,
              partnerName: partnerName,
              onSendVibe: (msg) {
                _sendDirectWhisper(msg);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Shared your vibe with $partnerName ✨❤️',
                      style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: kSanctuaryCharcoal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
              },
            ),
            onLeaveMessage: () => _openPartnerTab(2),
            bloomsCount: bloomsCount,
            lettersCount: lettersCount,
            sealedLettersCount: sealedLettersCount,
          ),
          const SizedBox(height: 28),

          // 05 — PLAY & PLAN TOGETHER (Couple Experiences Hub: Games, Date Planner, Drawing Canvas)
          CoupleExperiencesHubCard(
            partnerName: partnerName,
            onOpenGames: () => showCoupleGamesSheet(
              context,
              partnerName: partnerName,
              onSendGameQuestion: (msg) => _sendDirectWhisper(msg),
            ),
            onOpenDatePlanner: () => showDatePlannerSheet(
              context,
              partnerName: partnerName,
              onSendInvite: (msg) => _sendDirectWhisper(msg),
              onAskDocsy: (prompt) => openDocsyWith(
                context,
                prompt.isNotEmpty ? prompt : _getDocsyPrompt(state, partnerName),
              ),
            ),
            onOpenSharedCanvas: () => showSharedCanvasSheet(
              context,
              partnerName: partnerName,
              onSendDrawing: (msg) => _sendDirectWhisper(msg),
            ),
            onViewAllActivities: () => _openPartnerTab(3),
          ),
          const SizedBox(height: 28),

          // 06 — YOUR STORY (Living Memory Archive)
          YourStoryCard(
            memoryCount: memoryCount,
            latestMemoryTitle: latestMemoryTitle,
            latestMemoryDate: latestMemoryDate,
            onOpenMemoryBook: () => _openPartnerTab(5),
            onStartMemory: () => _openPartnerTab(3),
          ),
          const SizedBox(height: 28),

          // 07 — MANAGE CONNECTION (Subtle Sanctuary Settings)
          ManageConnectionFooter(
            onTap: () => _showManageConnectionSheet(state),
          ),
        ] else ...[
          // UNPAIRED ASPIRATIONAL PREVIEW
          UnpairedAspirationalExperience(
            onInvite: _showPartnerConnectionsModal,
          ),
        ],
      ],
    );
  }

  List<SignalBadgeSpec> _buildSanctuarySignals(BlushyOSState state, Map<String, dynamic>? primaryPartner) {
    if (primaryPartner == null) return [];
    final perms = primaryPartner['permissions'] is Map
        ? Map<String, dynamic>.from(primaryPartner['permissions'] as Map)
        : <String, dynamic>{};
    final pc = state.personalContext;
    final wb = state.wellbeingState;
    final checkinData = BlushyStorage.read('daily_checkin.json');

    final List<SignalBadgeSpec> signals = [];

    // 1. Cycle signal (only if shareCycle is permitted and valid cycle data exists)
    if (perms['shareCycle'] == true) {
      final DateTime? pStart = pc.lastPeriodStart;
      final int? cDay = (pStart != null)
          ? (DateTime.now().difference(pStart).inDays + 1)
          : pc.cycleDay;
      if (cDay != null && cDay > 0 && cDay < 120) {
        signals.add(SignalBadgeSpec(
          icon: Icons.water_drop_rounded,
          colour: kCobalt,
          tint: kCobaltTint,
          label: AppLocalizations.of(context).ptCycle,
          value: 'Day $cDay',
          onTap: _openSharingPanel,
        ));
      }
    }

    // 2. Energy signal (only if logged and shareSleep/energy is permitted)
    final String? energyVal = checkinData['energy'] ?? (wb.energy != null ? (wb.energy! >= 7 ? 'High' : (wb.energy! >= 4 ? 'Medium' : 'Low')) : null);
    if (perms['shareSleep'] == true && energyVal != null && energyVal.isNotEmpty) {
      signals.add(SignalBadgeSpec(
        icon: Icons.bolt_rounded,
        colour: kAmber,
        tint: kAmberTint,
        label: AppLocalizations.of(context).ptEnergy,
        value: energyVal,
        onTap: _openSharingPanel,
      ));
    }

    // 3. Mood signal (only if permitted and actually logged)
    final String? moodVal = checkinData['mood'] ?? wb.mood;
    if (perms['shareMood'] == true && moodVal != null && moodVal.isNotEmpty) {
      signals.add(SignalBadgeSpec(
        icon: Icons.favorite_rounded,
        colour: kMagenta,
        tint: kMagentaTint,
        label: AppLocalizations.of(context).ptMood,
        value: moodVal.substring(0, 1).toUpperCase() + moodVal.substring(1).toLowerCase(),
        onTap: _openSharingPanel,
      ));
    }

    return signals;
  }

  ({
    RightNowEventType type,
    String? headline,
    String? bodyText,
    String? timeDisplay,
    String? primaryCtaText,
    String? secondaryCtaText,
    VoidCallback? onPrimaryTap,
    VoidCallback? onSecondaryTap,
  }) _getRightNowEvent(String partnerName) {
    // 1. Check for real incoming message from partner that has NOT been replied to
    final regularMsgs = _chatMessages.where((m) =>
        m['sender'] != 'Docsy' &&
        m['isCard'] != true &&
        m['text'] != null &&
        !m['text'].toString().startsWith('[LETTER_JSON]:') &&
        !m['text'].toString().startsWith('[BOUQUET_JSON]:') &&
        m['text'].toString().trim().isNotEmpty).toList();

    final hasUnrepliedPartnerMsg = regularMsgs.isNotEmpty &&
        regularMsgs.last['isMe'] != true &&
        regularMsgs.last['sender'] != 'You';

    if (hasUnrepliedPartnerMsg) {
      final latest = regularMsgs.last;
      final text = latest['text'].toString().trim();
      final rawTime = (latest['timestamp'] ?? latest['created_at'])?.toString();
      return (
        type: RightNowEventType.message,
        headline: 'A LITTLE MESSAGE FROM ${partnerName.toUpperCase()}',
        bodyText: '“$text”',
        timeDisplay: rawTime != null ? _formatElapsedTime(rawTime) : '',
        primaryCtaText: 'Reply',
        secondaryCtaText: null,
        onPrimaryTap: () => _openPartnerTab(2),
        onSecondaryTap: null,
      );
    }

    // 1.5 If regular messages exist and user has replied (user sent the last message)
    if (regularMsgs.isNotEmpty) {
      final latest = regularMsgs.last;
      final text = latest['text'].toString().trim();
      final rawTime = (latest['timestamp'] ?? latest['created_at'])?.toString();
      return (
        type: RightNowEventType.followUp,
        headline: 'WAITING FOR ${partnerName.toUpperCase()}\'S REPLY',
        bodyText: 'You asked: “$text”',
        timeDisplay: rawTime != null ? _formatElapsedTime(rawTime) : '',
        primaryCtaText: 'Remind $partnerName',
        secondaryCtaText: 'Open Messenger',
        onPrimaryTap: () => showQuickFollowUpSheet(
          context,
          partnerName: partnerName,
          lastMsg: text,
          onSendNudge: (nudge) => _sendDirectWhisper(nudge),
        ),
        onSecondaryTap: () => _openPartnerTab(2),
      );
    }

    // 2. Check for recent bloom from partner
    final bloomMsgs = _chatMessages.where((m) =>
        m['isMe'] != true &&
        m['text'] != null &&
        m['text'].toString().startsWith('[BOUQUET_JSON]:')).toList();
    if (bloomMsgs.isNotEmpty) {
      final latest = bloomMsgs.last;
      final rawTime = (latest['timestamp'] ?? latest['created_at'])?.toString();
      return (
        type: RightNowEventType.bloom,
        headline: 'A LITTLE SOMETHING',
        bodyText: '$partnerName sent you a Bloom',
        timeDisplay: rawTime != null ? _formatElapsedTime(rawTime) : '',
        primaryCtaText: 'Open Bloom',
        secondaryCtaText: 'Save to Memories',
        onPrimaryTap: () => _openPartnerTab(1),
        onSecondaryTap: () => _openPartnerTab(5),
      );
    }

    // 3. Check for waiting sealed letter
    final letters = _getLettersList();
    final sealed = letters.where((l) => l['isFromMe'] != true && l['sealed'] == true).toList();
    if (sealed.isNotEmpty) {
      return (
        type: RightNowEventType.letter,
        headline: 'SOMETHING WAITING FOR YOU',
        bodyText: 'A sealed letter from $partnerName',
        timeDisplay: null,
        primaryCtaText: 'Open when you\'re ready',
        secondaryCtaText: null,
        onPrimaryTap: () => _showReadLetterModal(context, sealed.first),
        onSecondaryTap: null,
      );
    }

    // 4. Intentional low-data state (Memory card fallback removed per user request)
    return (
      type: RightNowEventType.lowData,
      headline: 'RIGHT NOW',
      bodyText: null,
      timeDisplay: null,
      primaryCtaText: 'Send something',
      secondaryCtaText: null,
      onPrimaryTap: () => _openPartnerTab(2),
      onSecondaryTap: null,
    );
  }

  String _formatElapsedTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return DateFormat('MMM d').format(dt);
  }

  String _getDocsyPrompt(BlushyOSState state, String partnerName) {
    if (state.argumentModeActive) {
      return '“Need help reconnecting with $partnerName delicately?”';
    }

    final regularMsgs = _chatMessages.where((m) =>
        m['sender'] != 'Docsy' &&
        m['isCard'] != true &&
        m['text'] != null &&
        !m['text'].toString().startsWith('[LETTER_JSON]:') &&
        !m['text'].toString().startsWith('[BOUQUET_JSON]:') &&
        m['text'].toString().trim().isNotEmpty).toList();

    if (regularMsgs.isNotEmpty) {
      final latest = regularMsgs.last;
      final text = latest['text'].toString().trim();
      final isFromMe = latest['isMe'] == true || latest['sender'] == 'You';

      if (isFromMe) {
        if (RegExp(r'\b(ss|screenshot|photo|pic|snap|bhej)\b', caseSensitive: false).hasMatch(text)) {
          return '“Docsy: How should I remind $partnerName to send that screenshot?”';
        }
        return '“Docsy: What\'s a fun, sweet follow-up for $partnerName while I wait?”';
      } else {
        return '“Docsy: Help me craft a thoughtful, witty reply to $partnerName.”';
      }
    }

    final hour = DateTime.now().hour;
    if (hour >= 18) {
      return '“Docsy: Plan a cozy romantic dinner or evening outing for us tonight.”';
    }
    if (hour < 12) {
      return '“Docsy: Suggest a sweet morning thought or coffee idea for $partnerName.”';
    }
    return '“Docsy: What\'s an exciting date idea or surprise I can plan for $partnerName?”';
  }

  Widget _buildPendingRequestsBanner() {
    return Column(
      children: _incomingInvitations.map((inv) {
        final invId = (inv['invitationId'] ?? inv['_id'] ?? '').toString();
        final senderEmail = inv['senderEmail'] as String? ?? inv['senderUserId'] as String? ?? 'Your Partner';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kSanctuaryCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kSanctuaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: kCrimsonTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: kSanctuaryCrimson, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INCOMING PARTNER REQUEST',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: kSanctuaryCrimson,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          senderEmail,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kSanctuaryCharcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Accept to connect your spaces and begin sharing cycles, insights, and live couple chat.',
                style: GoogleFonts.manrope(fontSize: 12, color: kSanctuaryMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSanctuaryMuted,
                      side: const BorderSide(color: kSanctuaryBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final ok = await _partnerService.respondToInvitation(invId, 'reject');
                      if (ok) {
                        await _fetchPartnerData();
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).partnerDecline,
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSanctuaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final ok = await _partnerService.respondToInvitation(invId, 'accept');
                      if (ok) {
                        await _fetchPartnerData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context).ptPartnerSpaceLive),
                              backgroundColor: Color(0xFF0D9488),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Accept Request',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// True once there is somebody on the other side.
  ///
  /// An ended connection stays in the list until its notice is acknowledged,
  /// so this counts live ones only -- otherwise someone whose partner had
  /// already left would still be shown the connected portal.
  bool get _hasPartner =>
      _connections.any((c) => c['status'] == 'active' || c['status'] == null);

  /// Guards the ended-connection notice against showing twice.
  bool _showingBreakupNotice = false;

  /// Opens one of the shared tabs, or says why it will not open yet.
  ///
  /// The tabs used to open regardless, onto a space with nobody in it, which
  /// reads as broken rather than as not-set-up-yet.
  void _openPartnerTab(int index) {
    if (!_hasPartner) {
      _showConnectFirstDialog();
      return;
    }
    setState(() => _selectedTabIndex = index);
    if (index == 2) {
      _scrollToBottomMessenger();
    }
  }

  /// Explains a closed shared space, and offers the one thing that opens it.
  Future<void> _showConnectFirstDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'This one needs two',
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
        content: Text(
          'Everything in the portal is something you and your partner do '
          'together, so it stays closed until there is someone on the other '
          'side. Send an invite and it opens the moment they accept.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            height: 1.5,
            color: BlushyColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BlushyColors.secondaryText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BlushyColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showPartnerConnectionsModal();
            },
            child: Text(
              'Connect',
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A connection the other partner ended, which this person has not been
  /// told about yet.
  ///
  /// There is no longer anything to agree to -- the row is already over. This
  /// is only the notice, and reading `breakupRequestedByUserId` is how the
  /// screen knows whose decision it was.
  Map<String, dynamic>? get _endedByPartner {
    final me = AuthStorage.getUserId();
    for (final conn in _connections) {
      final requester = conn['breakupRequestedByUserId'];
      if (conn['status'] == 'breakup' && requester != null && requester != me) {
        return Map<String, dynamic>.from(conn);
      }
    }
    return null;
  }

  /// Tells this person their partner has gone, once.
  ///
  /// Acknowledging retires the row on the server, so the notice does not
  /// reappear on the next load.
  Future<void> _showEndedByPartnerNotice() async {
    if (_showingBreakupNotice) return;
    final conn = _endedByPartner;
    if (conn == null) return;

    final connectionId = conn['connectionId'] as String? ?? '';
    if (connectionId.isEmpty) return;

    _showingBreakupNotice = true;
    final partnerLabel = partnerDisplayName(conn, fallback: 'Your partner');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$partnerLabel disconnected'),
        content: Text(
          '$partnerLabel ended the connection. All sharing between you has '
          'stopped. You can invite them again whenever you both want to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).commonOk),
          ),
        ],
      ),
    );

    await _partnerService.breakupConnection(connectionId);
    if (!mounted) {
      _showingBreakupNotice = false;
      return;
    }
    await _fetchPartnerData();
    // Held until the refreshed list is in, so a failed acknowledgement cannot
    // put the same dialog straight back up.
    _showingBreakupNotice = false;
    if (!mounted) return;
    setState(() {});
  }

  /// Confirms, then ends it.
  ///
  /// Leaving used to be a request the other partner had to grant, which left
  /// whoever wanted out still connected -- and still sharing -- until they
  /// agreed. One confirmation, and it is over.
  ///
  /// Both partners reach this: from the card on the portal and from the
  /// Manage modal, so there is one behaviour rather than two that can drift.
  /// [onDone] lets the modal rebuild its own list.
  Future<void> _disconnectPartner(
    Map<String, dynamic> conn, {
    VoidCallback? onDone,
  }) async {
    final connectionId = conn['connectionId'] as String? ?? '';
    if (connectionId.isEmpty) return;

    final partnerLabel = partnerDisplayName(conn, fallback: 'your partner');
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).ptDisconnectPartner),
        content: Text(
          'Are you sure you want to disconnect from $partnerLabel? This ends '
          'the connection for both of you and stops all sharing immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(context).partnerDisconnect,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      UserStateStore.write('partner_connections_cache', {
        'connections': <Map<String, dynamic>>[],
        'incoming': <Map<String, dynamic>>[],
        'outgoing': <Map<String, dynamic>>[],
      });
    } catch (_) {}
    setState(() {
      _connections = [];
    });

    final status = await _partnerService.breakupConnection(connectionId);
    if (!mounted) return;

    await _fetchPartnerData();
    if (!mounted) return;
    setState(() {});
    onDone?.call();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == null
              ? 'Could not reach the server. Nothing has changed.'
              : 'Disconnected from $partnerLabel. Sharing has stopped.',
        ),
      ),
    );
  }

  void _showManageConnectionSheet(BlushyOSState state) {
    final hasConnection = _connections.isNotEmpty;
    final primaryPartner = hasConnection ? _connections.first : null;
    final partnerName = primaryPartner != null
        ? partnerDisplayName(Map<String, dynamic>.from(primaryPartner), fallback: 'Your Partner')
        : 'Your Partner';
    final durationText = primaryPartner != null
        ? formatConnectionDuration(primaryPartner['created_at'] ?? primaryPartner['createdAt'])
        : '';
    final isPrivateSpaceActive = state.argumentModeActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: kSanctuaryCanvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Drag Pill
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: kSanctuaryBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Eyebrow
                      Text(
                        'MANAGE YOUR CONNECTION',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: kSanctuaryCrimson,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Heading
                      Text(
                        'Partner Settings',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: kSanctuaryCharcoal,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Connection Section Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSanctuaryCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: kSanctuaryBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: kCrimsonTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.favorite_rounded, color: kSanctuaryCrimson, size: 20),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partnerName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: kSanctuaryCharcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasConnection
                                        ? (durationText.isNotEmpty ? '$durationText · Synced' : 'Connected · Synced')
                                        : 'Not connected',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: kSanctuaryMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                _showPartnerConnectionsModal();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Manage',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kSanctuaryCrimson,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1.5. Active Status & Read Receipts Settings Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSanctuaryCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: kSanctuaryBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: kEmeraldTint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.mark_chat_read_outlined, color: kEmerald, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Active Status & Read Receipts',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kSanctuaryCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Control presence indicators and message read confirmations.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: kSanctuaryMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: kSanctuaryDivider, height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Show Active Status',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kSanctuaryCharcoal,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _showActiveStatus,
                                  activeTrackColor: kEmerald,
                                  onChanged: (val) {
                                    setState(() => _showActiveStatus = val);
                                    setSheetState(() {});
                                    try {
                                      BlushyStorage.write('partner_show_active_status', {'enabled': val});
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Read Receipts',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kSanctuaryCharcoal,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _showReadReceipts,
                                  activeTrackColor: kEmerald,
                                  onChanged: (val) {
                                    setState(() => _showReadReceipts = val);
                                    setSheetState(() {});
                                    try {
                                      BlushyStorage.write('partner_read_receipts', {'enabled': val});
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Privacy & Sharing Card
                      InkWell(
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _openSharingPanel();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kSanctuaryCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kSanctuaryBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: kPurpleTint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.shield_outlined, color: kPurple, size: 20),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Privacy & Sharing',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kSanctuaryCharcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Choose what your partner can see. Nothing is shared without your consent.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: kSanctuaryMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kSanctuaryMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Private Space Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSanctuaryCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: kSanctuaryBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: kPurpleTint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.nightlight_round, color: kPurple, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isPrivateSpaceActive
                                            ? '◐ Private Space Active'
                                            : 'Private Space',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isPrivateSpaceActive ? kPurple : kSanctuaryCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isPrivateSpaceActive
                                            ? 'Your personal updates aren\'t being shared right now (${_privateSpaceRemaining()}).'
                                            : 'Pause personal insights anytime. Shared memories remain.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: kSanctuaryMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: isPrivateSpaceActive
                                  ? ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(sheetCtx);
                                        _resumeSharing(state);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kSanctuaryCrimson,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                      ),
                                      child: Text(
                                        'Resume Sharing',
                                        style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
                                      ),
                                    )
                                  : OutlinedButton(
                                      onPressed: hasConnection
                                          ? () {
                                              Navigator.pop(sheetCtx);
                                              _takeSomeSpace(state);
                                            }
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kSanctuaryCharcoal,
                                        side: const BorderSide(color: kSanctuaryBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                      ),
                                      child: Text(
                                        'Take Some Space',
                                        style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. Separated Destructive Disconnect Section
                      if (hasConnection && primaryPartner != null) ...[
                        const Divider(color: kSanctuaryDivider),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              _disconnectPartner(Map<String, dynamic>.from(primaryPartner));
                            },
                            icon: const Icon(Icons.link_off_rounded, size: 16, color: kSanctuaryCrimson),
                            label: Text(
                              'Disconnect Partner',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kSanctuaryCrimson,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'Requires confirmation. Stops all sharing and unpairs this space.',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: kSanctuaryMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Opens the server-enforced sharing panel for the active connection.
  ///
  void _openSharingPanel() {
    final connectionId = _activeConnectionId;
    if (connectionId == null) {
      _showComposerNotice('Connect with your partner first.');
      return;
    }

    final active = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    // The server decides who owns the permissions and returns 403 to the other
    // side. Reading that flag here sends each person to the screen built for
    // them, rather than showing the partner a control panel that will only
    // reject them.
    final canManage = active['canManagePermissions'] == true;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => canManage
            ? PartnerSharingScreen(
                connectionId: connectionId,
                partnerName: partnerDisplayName(Map<String, dynamic>.from(active)),
              )
            : PartnerPrivacyScreen(connectionId: connectionId),
      ),
    );
  }

  void _showPartnerConnectionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: BlushyColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: BlushyColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Partner Connections',
                            style: GoogleFonts.manrope(height: 1.5, 
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.text,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      labelColor: BlushyColors.primary,
                      unselectedLabelColor: BlushyColors.secondaryText,
                      indicatorColor: BlushyColors.primary,
                      labelStyle: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w600),
                      // Invite first: the modal is opened by someone with no
                      // partner far more often than by someone managing one,
                      // and it used to open on an empty Connections list.
                      tabs: [
                        Tab(text: AppLocalizations.of(context).ptInvite),
                        Tab(
                          text: _incomingInvitations.isNotEmpty
                              ? 'Pending (${_incomingInvitations.length})'
                              : AppLocalizations.of(context).pPending,
                        ),
                        Tab(text: 'Connections (${_connections.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildInvitePartnerTab(setModalState),
                          _buildPendingRequestsTab(setModalState),
                          _buildConnectionsListTab(setModalState),
                        ],
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

  Widget _buildConnectionsListTab(StateSetter setModalState) {
    if (_connections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border_rounded, size: 48, color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).partnerNoConnection,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).partnerSendInviteExplainer,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final conn = _connections[index];
        final partnerLabel = partnerDisplayName(Map<String, dynamic>.from(conn));
        final role = conn['partnerRole'] as String? ?? 'Partner';
        final status = conn['status'] as String? ?? 'active';
        final connectionId = conn['connectionId'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BlushyColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: BlushyColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.favorite_rounded, color: BlushyColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerLabel,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    Text(
                      'Role: $role • Status: $status',
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: BlushyColors.primary, size: 20),
                tooltip: AppLocalizations.of(context).ptPrivacySettings,
                onPressed: () => _showGranularPermissionsModal(context, conn),
              ),
              // Full server-enforced permission matrix (spec section 10).
              // Shows every shareable category with its current state, so the
              // person sharing can always see exactly what is shared.
              IconButton(
                icon: const Icon(Icons.visibility_outlined, color: BlushyColors.primary, size: 20),
                tooltip: AppLocalizations.of(context).ptWhatYouShare,
                onPressed: connectionId.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PartnerSharingScreen(
                              connectionId: connectionId,
                              partnerName: partnerLabel.isEmpty ? null : partnerLabel,
                            ),
                          ),
                        ),
              ),
              // Same flow as the card on the portal, so the two cannot drift
              // apart in what they do or what they claim happened.
              TextButton(
                onPressed: () => _disconnectPartner(
                  Map<String, dynamic>.from(conn),
                  onDone: () => setModalState(() {}),
                ),
                child: Text(
                  AppLocalizations.of(context).partnerDisconnect,
                  style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGranularPermissionsModal(BuildContext context, Map<String, dynamic> conn) {
    final connectionId = (conn['connectionId'] ?? conn['_id'] ?? '').toString();
    final currentUserId = AuthStorage.getUserId() ?? '';
    final permissionOwnerId = (conn['permissionOwnerUserId'] ?? '').toString();
    final isOwner = permissionOwnerId.isEmpty || currentUserId == permissionOwnerId;

    // Off, matching the server's own defaults.
    //
    // These were seeded `true`, so a connection whose permissions had not
    // loaded presented every switch as already sharing. An unknown privacy
    // setting has to read as closed; showing it open is a claim about her
    // that nobody made.
    Map<String, dynamic> perms = {
      'shareCycle': false,
      'shareMood': false,
      'shareSleep': false,
      'shareInsights': false,
      'shareOnboarding': false,
      'allowAiSuggestionsWoman': false,
      'allowAiSuggestionsMan': false,
      'allowDecoderMan': false,
    };
    if (conn['permissions'] is Map) {
      perms.addAll(Map<String, dynamic>.from(conn['permissions'] as Map));
    }

    /// The keys this person is allowed to change.
    ///
    /// Save used to send the whole map. Three of these belong to a particular
    /// side of the connection -- `allowAiSuggestionsWoman` is hers,
    /// `allowAiSuggestionsMan` and `allowDecoderMan` are his -- and the server
    /// refuses the *whole* PATCH if any changed key is not the caller's to
    /// set. So her stored values for his two switches differing from the
    /// seeded ones was enough to have every cycle, mood and sleep change she
    /// had just made thrown out with a 403 she never saw. Seen twice in
    /// production within two minutes.
    final actorRole = AuthStorage.getRole();
    Map<String, dynamic> changeableBy(Map<String, dynamic> all) {
      const his = {'allowAiSuggestionsMan', 'allowDecoderMan'};
      const hers = {'allowAiSuggestionsWoman'};
      final mine = <String, dynamic>{};
      for (final entry in all.entries) {
        final allowed = his.contains(entry.key)
            ? actorRole == 'man'
            : hers.contains(entry.key)
                ? actorRole == 'woman'
                // Everything else is a data-sharing flag, which only the
                // person sharing may change.
                : isOwner;
        if (allowed) mine[entry.key] = entry.value;
      }
      return mine;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: BlushyColors.background,
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
                      const Icon(Icons.shield_outlined, color: BlushyColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Partner Privacy Settings',
                        style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOwner
                        ? 'Control what health & wellness updates are shared with your partner in real time.'
                        : 'These privacy settings are managed by your partner.',
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                  const SizedBox(height: 16),
                  _buildPrivacySwitch('Menstrual Cycle Rhythm', 'Share current cycle day and phase', perms['shareCycle'] == true, isOwner, (val) {
                    setModalState(() => perms['shareCycle'] = val);
                  }),
                  _buildPrivacySwitch('Daily Mood Log', 'Share your daily mood check-ins', perms['shareMood'] == true, isOwner, (val) {
                    setModalState(() => perms['shareMood'] = val);
                  }),
                  _buildPrivacySwitch('Sleep & Recovery', 'Share sleep hours and rest quality', perms['shareSleep'] == true, isOwner, (val) {
                    setModalState(() => perms['shareSleep'] = val);
                  }),
                  _buildPrivacySwitch('Daily AI Insights', 'Share wellness insights and suggestions', perms['shareInsights'] == true, isOwner, (val) {
                    setModalState(() => perms['shareInsights'] = val);
                  }),
                  const SizedBox(height: 20),
                  if (isOwner)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final loc = AppLocalizations.of(context);
                          final nav = Navigator.of(ctx);
                          final ok = await _partnerService
                              .updatePermissions(connectionId, changeableBy(perms));
                          nav.pop();
                          if (ok && mounted) {
                            await _fetchPartnerData();
                            messenger.showSnackBar(
                              SnackBar(content: Text(loc.ptPrivacyUpdated)),
                            );
                          }
                        },
                        child: Text(AppLocalizations.of(context).pSavePermissions, style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.bold)),
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

  Widget _buildPrivacySwitch(String title, String subtitle, bool value, bool enabled, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: BlushyColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText)),
    );
  }

  Widget _buildPendingRequestsTab(StateSetter setModalState) {
    final hasIncoming = _incomingInvitations.isNotEmpty;
    final hasOutgoing = _outgoingInvitations.isNotEmpty;

    if (!hasIncoming && !hasOutgoing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline_rounded, size: 48, color: BlushyColors.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).partnerNoPendingRequests,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Incoming and outgoing partner invitations will appear here.',
                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasIncoming) ...[
          Text(
            'INCOMING REQUESTS',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          ..._incomingInvitations.map((inv) {
            final invId = inv['invitationId'] as String? ?? '';
            final senderEmail = inv['senderEmail'] as String? ?? inv['senderUserId'] as String? ?? 'A user';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BlushyColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$senderEmail wants to connect with you.',
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final ok = await _partnerService.respondToInvitation(invId, 'reject');
                          if (ok) {
                            await _fetchPartnerData();
                            setModalState(() {});
                          }
                        },
                        child: Text(AppLocalizations.of(context).pReject, style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: Colors.grey[700])),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final ok = await _partnerService.respondToInvitation(invId, 'accept');
                          if (ok) {
                            await _fetchPartnerData();
                            setModalState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context).ptRequestAccepted)),
                              );
                            }
                          }
                        },
                        child: Text(AppLocalizations.of(context).partnerAccept, style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
        if (hasOutgoing) ...[
          const SizedBox(height: 16),
          Text(
            'OUTGOING REQUESTS',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          ..._outgoingInvitations.map((inv) {
            final receiverEmail = inv['receiverEmail'] as String? ?? 'Partner';
            final status = inv['status'] as String? ?? 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BlushyColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: BlushyColors.secondaryText, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiverEmail,
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                        ),
                        Text(
                          'Status: $status',
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppLocalizations.of(context).pPending,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildInvitePartnerTab(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect With Your Partner',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your partner\'s registered email address to send a connection request.',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _partnerInviteEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'partner@example.com',
              labelText: AppLocalizations.of(context).ptPartnerEmail,
              prefixIcon: const Icon(Icons.email_outlined, color: BlushyColors.primary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BlushyColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BlushyColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BlushyColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSendingInvite
                  ? null
                  : () async {
                      final email = _partnerInviteEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context).partnerInvalidEmail)),
                        );
                        return;
                      }

                      setModalState(() => _isSendingInvite = true);
                      try {
                        final res = await _partnerService.invitePartnerByEmail(email);

                        if (res.containsKey('error')) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['error'] as String),
                                backgroundColor: BlushyColors.primary,
                              ),
                            );
                          }
                        } else {
                          _partnerInviteEmailController.clear();
                          await _fetchPartnerData();
                          setModalState(() {});
                          if (mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            final inviteUrl = res['inviteUrl'] as String?;
                            if (inviteUrl != null && inviteUrl.isNotEmpty) {
                              await Clipboard.setData(ClipboardData(text: inviteUrl));
                            }
                            final msg = res['message']?.toString() ?? 'Partner invitation sent successfully! 💌';
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(inviteUrl != null ? '$msg (Invite link copied!)' : msg),
                                backgroundColor: BlushyColors.success,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            if (mounted && inviteUrl != null && inviteUrl.isNotEmpty) {
                              _showInviteLinkSheet(inviteUrl, res['inviteCode']?.toString());
                            }
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send invitation: $e'),
                              backgroundColor: BlushyColors.primary,
                            ),
                          );
                        }
                      } finally {
                        setModalState(() => _isSendingInvite = false);
                      }
                    },
              icon: _isSendingInvite
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSendingInvite ? 'Sending...' : 'Send Invitation',
                style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(AppLocalizations.of(context).commonOr, style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link_rounded, color: BlushyColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).partnerInviteLinkTitle,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Generate a private, single-use link to share directly via WhatsApp, SMS, or messaging apps.',
                  style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BlushyColors.primary,
                      side: const BorderSide(color: BlushyColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final linkData = await _partnerService.createInviteLink();
                      final url = linkData['inviteUrl'] as String?;

                      if (url == null) {
                        // Previously this branch did nothing at all, so a
                        // failed request looked identical to a button that
                        // was not wired up.
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              linkData['error']?.toString() ?? 'Could not create an invite link.',
                            ),
                            backgroundColor: BlushyColors.primary,
                          ),
                        );
                        return;
                      }

                      await Clipboard.setData(ClipboardData(text: url));
                      if (!mounted) return;
                      // Shown as well as copied: on a phone the clipboard is
                      // invisible, and the code is what the other person needs
                      // if they cannot open the link.
                      _showInviteLinkSheet(url, linkData['inviteCode']?.toString());
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context).ptInviteLinkCopied),
                          backgroundColor: BlushyColors.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      'Generate & Copy Link',
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The other half of the flow. Without it a code could be generated
          // and shared but never redeemed on a phone, because the link opens
          // the web app rather than coming back into this one.
          Center(
            child: TextButton.icon(
              onPressed: _showEnterInviteCodeSheet,
              icon: const Icon(Icons.link_rounded, size: 16),
              style: TextButton.styleFrom(foregroundColor: BlushyColors.primary),
              label: Text(
                AppLocalizations.of(context).partnerHaveInviteCode,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Shows a generated invite link and its code.
  ///
  /// The code matters on mobile: the link opens the web app, and the manifest
  /// registers no https App Link for it -- only the `blushy://` scheme -- so
  /// tapping it on a phone cannot hand the code back to this app. Entering the
  /// code by hand is the only route that works on a device.
  void _showInviteLinkSheet(String url, String? code) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).pShareThisInvitation,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Send them the link, or read out the code for them to enter in their app. It expires in 48 hours.',
              style: GoogleFonts.manrope(height: 1.5, fontSize: 13, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 20),
            SelectableText(
              url,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.primary),
            ),
            if (code != null) ...[
              const SizedBox(height: 20),
              Text(
                'INVITE CODE',
                style: GoogleFonts.manrope(height: 1.5, 
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                code,
                style: GoogleFonts.robotoMono(fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(AppLocalizations.of(context).ptCopyLink, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lets someone redeem an invite code they were given.
  void _showEnterInviteCodeSheet() {
    final controller = TextEditingController();
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) {
          Future<void> submit() async {
            final code = controller.text.trim();
            if (code.length < 32) {
              setSheetState(() => error = 'That does not look like a full invite code.');
              return;
            }
            setSheetState(() => error = null);
            final res = await _partnerService.acceptInviteLink(code);
            if (!sheetContext.mounted) return;
            if (res['error'] != null) {
              setSheetState(() => error = res['error'].toString());
              return;
            }
            Navigator.of(sheetContext).pop();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).ptConnectedSuccess),
                backgroundColor: BlushyColors.success,
              ),
            );
            _fetchPartnerData();
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(innerContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).partnerEnterInviteCode,
                  style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste the code your partner shared with you.',
                  style: GoogleFonts.manrope(height: 1.5, fontSize: 13, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: GoogleFonts.robotoMono(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).ptInviteCode,
                    errorText: error,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: submit,
                    child: Text(AppLocalizations.of(context).pConnect, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: MESSENGER (INSTAGRAM-QUALITY REDESIGN) ---
  Widget _buildMessengerTab(BlushyOSState state) {
    final messages = state.argumentModeActive
        ? _chatMessages.where((msg) => msg['sender'] != 'Docsy' || msg['isCard'] == false).toList()
        : _chatMessages;

    final currentUserId = AuthStorage.getUserId();
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final hasConnection = _connections.isNotEmpty;
    final primaryPartner = hasConnection ? _connections.first : null;
    final String partnerName = primaryPartner != null
        ? partnerDisplayName(Map<String, dynamic>.from(primaryPartner))
        : (currentRole == 'partner' ? 'Her' : 'Partner');
    final String partnerInitial = partnerName.trim().isNotEmpty
        ? partnerName.trim()[0].toUpperCase()
        : 'P';

    return Column(
      key: const ValueKey('messenger_tab'),
      children: [
        // 1. Instagram-inspired Messenger Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: kSanctuaryCanvas,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: kSanctuaryDark, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 0; // Back to Overview
                  });
                },
              ),
              Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kCobaltTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: kSanctuaryBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      partnerInitial,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kCobalt,
                      ),
                    ),
                  ),
                  if (_showActiveStatus && _partnerOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerName,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kSanctuaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_partnerTyping)
                      Text(
                        'typing…',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else if (_showActiveStatus && _partnerOnline)
                      Text(
                        'Active now',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        'Direct & Private',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: kSanctuarySubtext,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _toggleMessageDecoder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isMessageDecoderActive ? kCrimsonTint : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isMessageDecoderActive ? kSanctuaryCrimson : kSanctuaryBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DocsyIcon(
                        size: 13,
                        color: kSanctuaryCrimson,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMessageDecoderActive ? 'Decoder ON' : 'Decoder OFF',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isMessageDecoderActive ? kSanctuaryCrimson : kSanctuarySubtext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Chat history body
        Expanded(
          child: Container(
            color: kSanctuaryCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kCobaltTint,
                            shape: BoxShape.circle,
                            border: Border.all(color: kSanctuaryBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 26, color: kCobalt),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).partnerNoMessages,
                          style: GoogleFonts.manrope(fontSize: 14, color: kSanctuaryDark, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).partnerSayHello,
                          style: GoogleFonts.manrope(fontSize: 12, color: kSanctuarySubtext),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _messengerScrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, idx) {
                      final msg = messages[idx];
                      bool isMe = false;
                      if (msg['senderUserId'] != null && currentUserId != null && currentUserId.isNotEmpty) {
                        isMe = msg['senderUserId'] == currentUserId;
                      } else if (msg['sender_user_id'] != null && currentUserId != null && currentUserId.isNotEmpty) {
                        isMe = msg['sender_user_id'] == currentUserId;
                      } else if (msg['senderRole'] != null) {
                        isMe = msg['senderRole'] == currentRole;
                      } else if (msg['sender_role'] != null) {
                        isMe = msg['sender_role'] == currentRole;
                      } else if (msg['isMe'] != null) {
                        isMe = msg['isMe'] == true;
                      } else {
                        final sender = (msg['sender'] ?? '').toString().toLowerCase();
                        if (sender == 'you' || sender == 'me') {
                          isMe = true;
                        } else if (sender == 'partner' || sender == 'her' || sender == 'him') {
                          isMe = false;
                        } else {
                          final myName = (state.personalContext.userName ?? '').trim().toLowerCase();
                          isMe = myName.isNotEmpty && sender == myName;
                        }
                      }
                      return _buildMessageRow(msg, idx, isMe);
                    },
                  ),
          ),
        ),

        // Composer dynamic helper triggers drawer
        if (_showComposerActionsMenu) _buildComposerActionsDrawer(),

        // 3. Instagram DM / Docsy AI Uniform Pill Message Composer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: kSanctuaryCanvas,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: kSanctuaryBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showComposerActionsMenu = !_showComposerActionsMenu;
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _showComposerActionsMenu ? kCrimsonTint : kSanctuaryCanvas,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _showComposerActionsMenu ? kSanctuaryCrimson : kSanctuaryBorder,
                      ),
                    ),
                    child: Icon(
                      _showComposerActionsMenu ? Icons.close_rounded : Icons.add_rounded,
                      color: _showComposerActionsMenu ? kSanctuaryCrimson : kSanctuaryDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.manrope(fontSize: 13.5, color: kSanctuaryDark),
                    decoration: InputDecoration(
                      hintText: 'Message $partnerName...',
                      hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: kSanctuarySubtext),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: _handleTypingInput,
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendTextMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: kSanctuaryCrimson,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedCardMessage(Map<String, dynamic> msg, int index, bool isMe) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DocsyIcon(color: BlushyColors.primary, size: 14),
              const SizedBox(width: 8),
              Text(
                msg['title'] ?? '',
                style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg['subtitle'] ?? '',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            msg['text'] ?? '',
            style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => unawaited(_growGarden(flowers: 1)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: BlushyColors.dark,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(AppLocalizations.of(context).pCompleteCheckIn, style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouquetCardMessage(Map<String, dynamic> msg, int index, bool isMe, String? timeDisplay) {
    Map<String, dynamic> bouquetData = {};
    try {
      final raw = msg['text'].toString().substring('[BOUQUET_JSON]:'.length);
      bouquetData = jsonDecode(raw);
    } catch (_) {}

    final senderName = bouquetData['sender']?.toString().isNotEmpty == true
        ? bouquetData['sender']
        : (isMe ? 'You' : 'Your partner');
    final message = (bouquetData['message'] != null && bouquetData['message'].toString().isNotEmpty)
        ? bouquetData['message']
        : 'Thinking of you! Here is a digital bouquet just for you. 💐';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? BlushyColors.lutealSoft : BlushyColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.secondary, width: 1.5),

          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: BlushyColors.lutealSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💐', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? 'You sent a Bouquet' : '$senderName sent a Bouquet',
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        Text(
                          AppLocalizations.of(context).pDigitalFlowerGift,
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.secondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BlushyColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.lutealSoft),
                ),
                child: Text(
                  '“$message”',
                  style: GoogleFonts.caveat(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.text,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 1; // Open Bouquet / Garden
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: BlushyColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_florist_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Open Bouquet & Garden',
                        style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              if (timeDisplay != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    timeDisplay,
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 9, color: BlushyColors.secondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(Map<String, dynamic> msg, int index, bool isMe) {
    if (msg['isCard'] == true) {
      return _buildSharedCardMessage(msg, index, isMe);
    }

    final createdAtStr = msg['createdAt']?.toString();
    String? timeDisplay;
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr);
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        timeDisplay = '$hour:$minute $ampm';
      } catch (_) {}
    }

    if (msg['text'] != null && msg['text'].toString().startsWith('[BOUQUET_JSON]:')) {
      return _buildBouquetCardMessage(msg, index, isMe, timeDisplay);
    }

    final String msgText = (msg['text'] ?? '').toString();
    final String msgId = (msg['_id'] ?? msg['id'] ?? 'msg_$index').toString();
    final bool isDecoded = _decodedMessages.containsKey(msgId);
    final bool isDecoding = _decodingMessageIds.contains(msgId);
    final decodedData = _decodedMessages[msgId];
    final currentRole = AuthStorage.getRole() ?? BlushyOSProvider.of(context).selectedRole;
    final bool isUserWoman = (currentRole != 'partner' && currentRole != 'man');
    final bool canDecode = !isMe && !isUserWoman && _isMessageDecoderActive && msg['isCard'] != true && msgText.isNotEmpty && !msgText.startsWith('[BOUQUET_JSON]:') && msg['isAudio'] != true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () {
                setState(() {
                  _selectedMessageIndexForActions = index;
                });
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: isMe
                    ? const BoxDecoration(
                        color: kSanctuaryCrimson,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      )
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: kSanctuaryBorder, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg['isAudio'] == true) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : kSanctuaryCrimson),
                          const SizedBox(width: 6),
                          ...List.generate(12, (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 2,
                            height: 6.0 + math.Random().nextDouble() * 12.0,
                            color: isMe ? Colors.white70 : kSanctuaryCrimson,
                          )),
                          const SizedBox(width: 8),
                          Text(
                            msg['duration'] ?? '',
                            style: GoogleFonts.manrope(height: 1.5, 
                              fontSize: 10,
                              color: isMe ? Colors.white70 : kSanctuarySubtext,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        msg['text'] ?? '',
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : kSanctuaryDark,
                        ),
                      ),
                    ],
                    if (timeDisplay != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        timeDisplay,
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 9,
                          color: isMe ? Colors.white.withValues(alpha: 0.75) : kSanctuarySubtext,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canDecode) ...[
              if (!isDecoded)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 2.0),
                  child: GestureDetector(
                    onTap: () => _decodeMessageForPartner(msgId, msgText),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: kCrimsonTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kSanctuaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDecoding) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: kSanctuaryCrimson),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context).partnerSiaDecoding,
                              style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w600, color: kSanctuaryCrimson),
                            ),
                          ] else ...[
                            const DocsyIcon(size: 13, color: kSanctuaryCrimson),
                            const SizedBox(width: 4),
                            Text(
                              "Decode with Docsy",
                              style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w700, color: kSanctuaryCrimson),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else if (decodedData != null)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: 2),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kSanctuaryBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const DocsyIcon(color: BlushyColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Docsy Decoded Meaning",
                            style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                          ),
                          const Spacer(),
                          if (decodedData['emotionalTone'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BlushyColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                decodedData['emotionalTone'],
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        decodedData['decodedMeaning'] ?? '',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: BlushyColors.text, height: 1.35),
                      ),
                      if (decodedData['cycleMoodContext'] != null && decodedData['cycleMoodContext'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 11, color: BlushyColors.secondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                decodedData['cycleMoodContext'],
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (decodedData['recommendedReply'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BlushyColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BlushyColors.lutealSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).partnerSuggestedReply,
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "“${decodedData['recommendedReply']}”",
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontStyle: FontStyle.italic, color: BlushyColors.text),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _msgController.text = decodedData['recommendedReply'];
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: BlushyColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context).partnerUseReply,
                                      style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (decodedData['actionTip'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 12, color: BlushyColors.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Tip: ${decodedData['actionTip']}",
                                style: GoogleFonts.manrope(fontSize: 10, color: BlushyColors.secondaryText, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageActionsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        alignment: Alignment.center,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BlushyColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).pAiCommunicationHub,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildOverlayActionItem(
                'Rewrite Kindly',
                null,
                () {
                  setState(() {
                    _chatMessages[_selectedMessageIndexForActions]['text'] = "“I value our walks. Let's connect tonight.”";
                    _selectedMessageIndexForActions = -1;
                  });
                },
                leadingWidget: const DocsyIcon(color: BlushyColors.primary, size: 18),
              ),
              _buildOverlayActionItem('Save to Memory Book', Icons.bookmark_outline_rounded, () {
                setState(() {
                  _selectedMessageIndexForActions = -1;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).ptSavedScrapbook)),
                );
              }),
              _buildOverlayActionItem('Close', Icons.close_rounded, () {
                setState(() {
                  _selectedMessageIndexForActions = -1;
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayActionItem(String label, IconData? icon, VoidCallback onTap, {Widget? leadingWidget}) {
    return ListTile(
      leading: leadingWidget ?? Icon(icon, color: BlushyColors.primary, size: 18),
      title: Text(label, style: GoogleFonts.manrope(height: 1.5, fontSize: 12)),
      onTap: onTap,
    );
  }

  // --- Composer activities drawer ---
  //
  // These three were placeholders: Couple Quiz appended a card to the local
  // list only -- and one that `_syncLiveMessages` then filtered straight back
  // out, so it deleted itself -- while Date Ideas and Breathing Sync closed the
  // menu and did nothing at all. Each now does something real and reaches the
  // partner through the same send path as a typed message.
  Widget _buildComposerActionsDrawer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BlushyColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActivityComposerItem('Couple Quiz', Icons.quiz_outlined, _sendCoupleQuiz),
          _buildActivityComposerItem(
            'Date Ideas',
            Icons.restaurant_rounded,
            _showDateIdeas,
            loading: _dateIdeasLoading,
          ),
          _buildActivityComposerItem('Breathing Sync', Icons.air_rounded, _startBreathingSync),
        ],
      ),
    );
  }

  /// Prompts for the couple quiz.
  ///
  /// A rotating set rather than one fixed line, so sending it twice does not
  /// ask the same question again.
  static const List<String> _couplePrompts = [
    'What is one thing you appreciated about me this week?',
    'What is something small I could do that would help you most right now?',
    'What is a moment together you keep coming back to?',
    'What would a genuinely restful evening look like for you?',
    'What is something you are looking forward to that I could be part of?',
    'When do you feel most supported by me?',
    'What is one thing you would like more of between us?',
  ];

  int _quizPromptIndex = 0;

  Future<void> _sendCoupleQuiz() async {
    setState(() => _showComposerActionsMenu = false);

    final prompt = _couplePrompts[_quizPromptIndex % _couplePrompts.length];
    _quizPromptIndex++;

    await _sendComposerMessage('Couple Quiz: $prompt');
  }

  /// Offers real, cycle-aware suggestions the server derives from what the
  /// partner has chosen to share -- not a fixed list of generic date ideas.
  Future<void> _showDateIdeas() async {
    setState(() => _showComposerActionsMenu = false);

    final connectionId = _activeConnectionId;
    if (connectionId == null) {
      _showComposerNotice('Connect with your partner first.');
      return;
    }

    setState(() => _dateIdeasLoading = true);
    final result = await _partnerService.getPartnerDecoder(connectionId);
    if (!mounted) return;
    setState(() => _dateIdeasLoading = false);

    // The endpoint mixes string-shaped and object-shaped suggestions in one
    // array. Reading `suggestion` as a Map threw on the first string, and the
    // throw was uncaught, so the sheet never opened.
    final ideas = DateIdea.listFrom(result['suggestions']);

    if (ideas.isEmpty) {
      // Saying why is the difference between "no ideas" and "nothing shared".
      _showComposerNotice(
        'No suggestions yet. They arrive once your partner has shared some of their day.',
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).partnerDateIdeas,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Based on what your partner has shared. Tap one to send it.',
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: ideas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final idea = ideas[i];
                  final title = idea.title;
                  final description = idea.description ?? '';
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _sendComposerMessage(title);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.manrope(height: 1.5, 
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: GoogleFonts.manrope(height: 1.5, 
                                fontSize: 11,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a paced breathing exercise and tells the partner it has started, so
  /// the two can do it at the same time.
  Future<void> _startBreathingSync() async {
    setState(() => _showComposerActionsMenu = false);

    await _sendComposerMessage('Shall we do a two minute breathing sync together?');
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BreathingSyncSheet(),
    );
  }

  /// One path for everything the composer sends, so a shortcut message is a
  /// real message: persisted, delivered, and visible to both people.
  Future<void> _sendComposerMessage(String text) async {
    final connectionId = _activeConnectionId;
    if (connectionId == null) {
      _showComposerNotice('Connect with your partner first.');
      return;
    }

    final state = BlushyOSProvider.of(context);
    final myName = (state.personalContext.userName != null &&
            state.personalContext.userName!.isNotEmpty)
        ? state.personalContext.userName!
        : 'You';

    setState(() {
      _chatMessages.add({
        'sender': myName,
        'senderUserId': AuthStorage.getUserId(),
        'senderRole': AuthStorage.getRole() ?? state.selectedRole,
        'text': text,
        'isAudio': false,
        'isCard': false,
        'isMe': true,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _saveSharedGardenState();
    });

    final sent = await _partnerService.sendMessage(connectionId, text);
    if (!mounted) return;
    if (sent == null) {
      _showComposerNotice('Could not send that. It will not have reached your partner.');
      return;
    }
    _syncLiveMessages();
  }

  void _showComposerNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildActivityComposerItem(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool loading = false,
  }) {
    return GestureDetector(
      // Ignored while loading so a second tap cannot fire a second request.
      onTap: loading ? null : onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: BlushyColors.primary.withValues(alpha: 0.1),
            radius: 20,
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BlushyColors.primary,
                    ),
                  )
                : Icon(icon, color: BlushyColors.primary, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.text)),
        ],
      ),
    );
  }

  // --- TAB 3: SHARED ACTIVITIES ---
  Widget _buildActivitiesTab() {
    final connected = _activeConnectionId != null;

    return Column(
      key: const ValueKey('activities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).partnerSharedActivities,
                style: GoogleFonts.manrope(height: 1.5, 
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ),
            if (_activitiesLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 14),
        if (!connected)
          _activityNotice(
            'Connect with your partner first',
            'Shared activities live in the connection, so they appear once you are linked.',
          )
        else if (_sharedActivities.isEmpty && !_activitiesLoading)
          _activityNotice(
            'Could not load your activities',
            'They will appear once the connection is back.',
            onRetry: _loadSharedActivities,
          )
        else
          ..._sharedActivities.map(_buildSharedActivityCard),
      ],
    );
  }

  Widget _activityNotice(String headline, String body, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BlushyTheme.premiumCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: GoogleFonts.manrope(height: 1.5, 
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.5,
              color: BlushyColors.secondaryText,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(AppLocalizations.of(context).partnerTryAgain),
              style: OutlinedButton.styleFrom(foregroundColor: BlushyColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  static const Map<String, IconData> _activityIcons = {
    'date_planner': Icons.calendar_today_rounded,
    'shared_canvas': Icons.palette_rounded,
    'couple_games': Icons.casino_rounded,
    'virtual_bouquet': Icons.local_florist_rounded,
    'daily_gratitude': Icons.volunteer_activism_rounded,
    'weekend_planner': Icons.calendar_month_rounded,
    'dinner_date': Icons.restaurant_rounded,
  };

  Widget _buildSharedActivityCard(SharedActivity activity) {
    final busy = _activityBusyKey == activity.key;
    final currentUserId = AuthStorage.getUserId();

    String statusLine;
    if (activity.isCompleted) {
      final byYou = activity.completedByUserId == currentUserId;
      statusLine = byYou ? 'Completed by you' : 'Completed by your partner';
      if (activity.completionCount > 1) {
        statusLine += ' · done ${activity.completionCount} times';
      }
    } else if (activity.isInProgress) {
      final byYou = activity.startedByUserId == currentUserId;
      statusLine = byYou ? 'You started this' : 'Your partner started this';
    } else {
      statusLine = 'Not started yet';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: busy
            ? null
            : () {
                final pName = _connections.isNotEmpty && _connections.first['partnerName'] != null
                    ? _connections.first['partnerName'].toString()
                    : 'Your Partner';
                _launchActivityExperience(activity, pName);
              },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BlushyTheme.premiumCardDecoration,
          child: Row(
            children: [
              Icon(
                _activityIcons[activity.key] ?? Icons.task_alt_rounded,
                color: activity.isCompleted ? BlushyColors.success : BlushyColors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.description,
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: activity.isCompleted
                            ? BlushyColors.success
                            : (activity.isInProgress ? BlushyColors.primary : BlushyColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(
                  activity.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: activity.isCompleted ? 20 : 14,
                  color: activity.isCompleted ? BlushyColors.success : BlushyColors.secondaryText,
                ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildOverviewItem(String title, String sub, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: BlushyColors.primary, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                sub,
                style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 4: LETTERS ---
  List<Map<String, dynamic>> _getLettersList() {
    final List<Map<String, dynamic>> list = [];
    try {
      final saved = UserStateStore.read('partner_letters');
      if (saved['letters'] is List) {
        final rawList = saved['letters'] as List;
        list.addAll(rawList.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}

    // Also extract any letters sent over chat
    for (final msg in _chatMessages) {
      final text = (msg['text'] ?? '').toString();
      if (text.startsWith('[LETTER_JSON]:')) {
        try {
          final json = jsonDecode(text.replaceFirst('[LETTER_JSON]:', ''));
          if (json is Map) {
            final letter = Map<String, dynamic>.from(json);
            letter['timestamp'] = msg['timestamp'] ?? msg['created_at'] ?? DateTime.now().toIso8601String();
            letter['isFromMe'] = msg['isMe'] == true || msg['sender'] == 'You';
            if (!list.any((l) => l['title'] == letter['title'] && l['body'] == letter['body'])) {
              list.add(letter);
            }
          }
        } catch (_) {}
      }
    }

    // No placeholder letter here. This list used to fall back to an invented
    // note carrying isFromMe: false -- presenting it as something the partner
    // had written and sent, which they never did.
    return list;
  }

  void _showWriteLetterModal(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedStationery = 'Rose Petal 🌸';
    bool sealForAnniversary = false;

    final stationeryStyles = ['Rose Petal 🌸', 'Warm Parchment 📜', 'Lavender Dream 💜', 'Golden Moonlight 🌙'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: BlushyColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
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
                      const Icon(Icons.edit_note_rounded, color: BlushyColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "Write a Love Letter",
                        style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stationery selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: stationeryStyles.map((style) {
                        final isSel = style == selectedStationery;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedStationery = style),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? BlushyColors.primary : BlushyColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSel ? BlushyColors.primary : BlushyColors.border),
                            ),
                            child: Text(
                              style,
                              style: GoogleFonts.manrope(height: 1.5, 
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : BlushyColors.text,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: TextField(
                      controller: titleController,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).ptLetterTitle,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Body Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BlushyColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: TextField(
                        controller: bodyController,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.manrope(fontSize: 13, height: 1.6),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).ptLetterHint,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Seal Toggle
                  Row(
                    children: [
                      Checkbox(
                        value: sealForAnniversary,
                        activeColor: BlushyColors.primary,
                        onChanged: (val) => setModalState(() => sealForAnniversary = val ?? false),
                      ),
                      Expanded(
                        child: Text(
                          // This said "Deliver & open on milestone". Sealing
                          // sets a flag on the letter; nothing delivers it on
                          // a date, so it no longer promises that.
                          "Seal it, and open it together later",
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 11.5, color: BlushyColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final body = bodyController.text.trim();
                        if (title.isEmpty || body.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context).ptLetterValidation)),
                          );
                          return;
                        }

                        final letterData = {
                          'title': title,
                          'body': body,
                          'stationery': selectedStationery,
                          'sealed': sealForAnniversary,
                          'timestamp': DateTime.now().toIso8601String(),
                          'isFromMe': true,
                        };

                        // 1. Save locally
                        final currentLetters = _getLettersList();
                        currentLetters.insert(0, letterData);
                        try {
                          UserStateStore.write('partner_letters', {'letters': currentLetters});
                        } catch (_) {}

                        // 2. Transmit through partner live chat
                        final payload = '[LETTER_JSON]:${jsonEncode(letterData)}';
                        final activeConn = _connections.firstWhere(
                          (c) => c['status'] == 'active',
                          orElse: () => <String, dynamic>{},
                        );
                        final connectionId = (activeConn['connectionId'] ?? activeConn['_id'] ?? '').toString();

                        // Resolved before the await: `ctx` belongs to the
                        // dialog, which is popped below.
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);

                        var delivered = false;
                        if (connectionId.isNotEmpty) {
                          delivered =
                              await _partnerService.sendMessage(connectionId, payload) != null;
                        }

                        if (!mounted) return;
                        setState(() {
                          _chatMessages.add({
                            'sender': 'You',
                            'text': payload,
                            'isMe': true,
                            'timestamp': DateTime.now().toIso8601String(),
                          });
                        });

                        if (delivered) {
                          unawaited(_growGarden(flowers: 2));
                        }

                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            // Said "delivered to your partner" even with no
                            // connection and nothing sent.
                            content: Text(delivered
                                ? 'Letter sealed and sent to your partner.'
                                : 'Letter saved. It will not have reached your partner.'),
                            backgroundColor: delivered
                                ? BlushyColors.success
                                : BlushyColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.mark_email_read_rounded, size: 18),
                      label: Text(
                        "Seal & Send to Partner 💌",
                        style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
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

  void _showReadLetterModal(BuildContext context, Map<String, dynamic> letter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: BlushyColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: BlushyColors.border),
          ),
          child: Column(
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_rounded, color: BlushyColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          letter['title'] ?? 'Love Letter',
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        Text(
                          letter['stationery'] ?? 'Stationery',
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BlushyColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),

                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      letter['body'] ?? '',
                      style: GoogleFonts.manrope(fontSize: 13.5, height: 1.7, color: BlushyColors.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLettersTab() {
    final letters = _getLettersList();

    return Column(
      key: const ValueKey('letters'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).partnerLettersTitle,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 9, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText),
            ),
            ElevatedButton.icon(
              onPressed: () => _showWriteLetterModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.create_rounded, size: 14),
              label: Text(AppLocalizations.of(context).partnerWriteLetter, style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (letters.isEmpty)
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              AppLocalizations.of(context).partnerNoLetters,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
            ),
          ),
        ...letters.map((letter) {
          final isSealed = letter['sealed'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showReadLetterModal(context, letter),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: BlushyColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border),

                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSealed
                            ? BlushyColors.background
                            : BlushyColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSealed ? Icons.lock_clock_rounded : Icons.mail_rounded,
                        color: isSealed ? BlushyColors.accent : BlushyColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            letter['title'] ?? 'Letter',
                            style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isSealed
                                ? 'Sealed Time Capsule • Tap to read'
                                : (letter['isFromMe'] == true ? 'Sent to Partner • Tap to view' : 'Received from Partner • Tap to read'),
                            style: GoogleFonts.manrope(height: 1.5, fontSize: 10.5, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: BlushyColors.secondaryText),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- TAB 5: MEMORY BOOK Scrapbook ---
  //
  // This was a fixed card reading "Scrapbook is building over time as you
  // complete activities" -- with nothing behind it that could ever build.
  // The shared activities it describes are already tracked on the server,
  // completion date included, so the book is now made of what the pair have
  // actually done.
  Widget _buildMemoryBookTab() {
    final completed = _sharedActivities.where((a) => a.isCompleted).toList()
      ..sort((a, b) {
        final left = a.completedAt;
        final right = b.completedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

    return Column(
      key: const ValueKey('memory_book'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).partnerMemoryBook,
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: BlushyColors.secondaryText,
              ),
            ),
            if (completed.isNotEmpty)
              Text(
                completed.length == 1 ? '1 memory' : '${completed.length} memories',
                style: GoogleFonts.manrope(height: 1.5, fontSize: 10, color: BlushyColors.secondaryText),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_activitiesLoading)
          // Each finished activity is a circle and two lines, so that is what
          // stands in for one while they load.
          SkeletonList(
            count: 3,
            itemBuilder: (context, index) => const SkeletonListRow(),
          )
        else if (completed.isEmpty)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              AppLocalizations.of(context).partnerNoMemories,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
            ),
          )
        else
          ...completed.map((activity) {
            final finishedByMe = activity.completedByUserId != null &&
                activity.completedByUserId == AuthStorage.getUserId();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BlushyColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: BlushyColors.lutealSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: BlushyColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: GoogleFonts.manrope(height: 1.5, 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _describeMemory(activity, finishedByMe),
                          style: GoogleFonts.manrope(height: 1.5, 
                            fontSize: 10.5,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activity.completionCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BlushyColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${activity.completionCount}x',
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  /// Says who finished it and roughly when, using only what the server sent.
  String _describeMemory(SharedActivity activity, bool finishedByMe) {
    final who = finishedByMe ? 'You marked this done' : 'Marked done together';
    final at = activity.completedAt;
    if (at == null) return who;

    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return '$who • today';
    if (days == 1) return '$who • yesterday';
    if (days < 30) return '$who • $days days ago';
    return '$who • ${at.day}/${at.month}/${at.year}';
  }

  // --- TAB 6: RELATIONSHIP AI ---
  //
  // This tab used to be one hardcoded sentence with no input and no request
  // behind it, so there was nothing here that could work. It now asks Docsy,
  // grounded server-side in whatever the partner has agreed to share.
  Widget _buildRelationshipAITab(BlushyOSState state) {
    final connectionId = _activeConnectionId;

    return Column(
      key: const ValueKey('relationship_ai'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BlushyColors.lutealSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BlushyColors.lutealSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).partnerSiaAdviceTitle,
                style: GoogleFonts.manrope(height: 1.5, 
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              if (connectionId == null)
                Text(
                  'Connect with your partner first, and Docsy can help you think things through together.',
                  style: GoogleFonts.manrope(fontSize: 12, height: 1.45),
                )
              else if (state.argumentModeActive)
                Text(
                  AppLocalizations.of(context).pYourPartnerHasChosen,
                  style: GoogleFonts.manrope(fontSize: 12, height: 1.45),
                )
              else
                Text(
                  AppLocalizations.of(context).partnerSiaAdviceExplainer,
                  style: GoogleFonts.manrope(fontSize: 12, height: 1.45),
                ),
            ],
          ),
        ),
        if (connectionId != null && !state.argumentModeActive) ...[
          const SizedBox(height: 16),
          if (_relationshipAnswer != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BlushyColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.lutealSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _relationshipAnswer!,
                    style: GoogleFonts.manrope(fontSize: 13, height: 1.5),
                  ),
                  if (_relationshipUsedPartnerData != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _relationshipUsedPartnerData!
                          // Saying which is the difference between advice that
                          // knows something and advice that is guessing.
                          ? 'Based on what your partner shares with you.'
                          : 'Your partner has not shared data Docsy could use here.',
                      style: GoogleFonts.manrope(height: 1.5, 
                        fontSize: 10,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_relationshipError != null) ...[
            Text(
              _relationshipError!,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.primary),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _relationshipController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            style: GoogleFonts.manrope(height: 1.5, fontSize: 13),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).pWhatWouldYouLike,
              hintStyle: GoogleFonts.manrope(height: 1.5, fontSize: 13, color: BlushyColors.secondaryText),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BlushyColors.lutealSoft),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BlushyColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _relationshipLoading ? null : () => _askRelationshipAi(connectionId),
              icon: _relationshipLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology_alt_rounded, size: 16),
              label: Text(
                _relationshipLoading ? 'Thinking…' : 'Ask Docsy',
                style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _askRelationshipAi(String connectionId) async {
    final question = _relationshipController.text.trim();
    if (question.isEmpty) {
      setState(() => _relationshipError = 'Write a question first.');
      return;
    }

    setState(() {
      _relationshipLoading = true;
      _relationshipError = null;
    });

    final result = await _partnerService.askRelationshipAi(
      connectionId: connectionId,
      question: question,
    );

    if (!mounted) return;

    setState(() {
      _relationshipLoading = false;
      if (result['error'] != null) {
        _relationshipError = result['error'].toString();
        return;
      }
      _relationshipAnswer = result['answer']?.toString();
      _relationshipUsedPartnerData = result['usedPartnerData'] as bool?;
      _relationshipError = null;
      _relationshipController.clear();
    });
  }

  // --- TAB GIFTS ---
  Widget _buildGiftsTab() {
    return Column(
      key: const ValueKey('gifts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedTabIndex = 1; // Open Bouquet tab
            });
          },
          child: _buildOverviewItem('Send Digital Flowers', 'Send a sweet postcard and customizable flower bloom', Icons.local_florist_rounded),
        ),
      ],
    );
  }

  // --- TAB BOUQUET ---
  Widget _buildBouquetTab() {
    final state = BlushyOSProvider.of(context);
    final userId = AuthStorage.getUserId() ?? 'user';
    final token = AuthStorage.getToken() ?? '';
    final role = state.selectedRole == 'partner' ? UserRole.man : UserRole.woman;

    final activeConnectionsList = _connections
        .where((c) => c['status'] == 'active' || c['status'] == null)
        .map((c) {
      final connId = (c['connectionId'] ?? c['_id'] ?? c['id'] ?? '').toString();
      final partnerId = (c['partnerUserId'] ?? c['partner_user_id'] ?? c['partnerEmail'] ?? 'partner').toString();
      return PartnerConnection(
        connectionId: connId.isNotEmpty ? connId : 'conn',
        partnerUserId: partnerId,
        permissionOwnerUserId: c['permissionOwnerUserId']?.toString() ?? userId,
        canManagePermissions: true,
        permissions: const PartnerPermissions(
          shareMood: true,
          shareCycle: true,
          shareSleep: true,
          shareInsights: true,
          shareOnboarding: true,
          allowAiSuggestionsWoman: true,
          allowAiSuggestionsMan: true,
          allowDecoderMan: true,
        ),
        status: c['status']?.toString() ?? 'active',
        viewerIsSender: true,
        createdAt: null,
      );
    }).toList();

    return ChangeNotifierProvider<BouquetState>(
      create: (_) => BouquetState(),
      child: Builder(
        builder: (context) {
          return HomeScreen(
            session: AuthSession(
              message: 'Verified',
              token: token,
              userId: userId,
              tokenType: 'Bearer',
              expiresIn: 3600,
              role: role,
            ),
            activeConnections: activeConnectionsList,
          );
        },
      ),
    );
  }

  Widget _buildAdaptiveFloatingActionButton() {
    if (_selectedTabIndex == 0 || _tabs[_selectedTabIndex] == 'Overview') {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton.extended(
        heroTag: 'partner_fab',
        backgroundColor: BlushyColors.dark,
        onPressed: _onFloatingActionTap,
        label: Text(
          _getFloatingActionText(),
          style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: Icon(_getFloatingActionIcon(), color: Colors.white, size: 16),
      ),
    );
  }

  void _showActivityTriggerDialog() {
    _openPartnerTab(3);
  }
}
