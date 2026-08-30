import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
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
    'Boutique',
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
  bool _gardenLoading = false;

  Future<void> _loadGarden() async {
    final connectionId = _activeConnectionId;
    if (connectionId == null) return;

    if (mounted) setState(() => _gardenLoading = true);
    final result = await PartnerApi.garden(connectionId);
    if (!mounted) return;

    setState(() {
      _gardenLoading = false;
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
      const SnackBar(content: Text('Your garden grew. Your partner sees it too.')),
    );
  }

  // Messenger states
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _msgController = TextEditingController();
  int _selectedMessageIndexForActions = -1;
  bool _showComposerActionsMenu = false;

  // Partner connections state
  List<Map<String, dynamic>> _connections = [];

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
    final active = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    final id = active['connectionId'];
    return id?.toString();
  }

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
      _sharedActivities = activities;
      _activitiesLoading = false;
    });
  }

  Future<void> _advanceActivity(SharedActivity activity) async {
    final connId = _activeConnectionId;
    if (connId == null) return;

    // Tapping moves it one step: not started -> in progress -> completed, and
    // a completed repeatable activity starts again.
    final next = activity.isInProgress ? 'completed' : 'in_progress';

    setState(() => _activityBusyKey = activity.key);
    final updated = await _partnerService.setSharedActivityStatus(connId, activity.key, next);
    if (!mounted) return;

    setState(() {
      _activityBusyKey = null;
      if (updated != null) _sharedActivities = updated;
    });

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the activity. Please try again.')),
      );
    }
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
      final saved = BlushyStorage.read('partner_decoder_enabled');
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
      BlushyStorage.write('partner_decoder_enabled', {
        'enabled': _isMessageDecoderActive,
      });
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMessageDecoderActive
              ? '✨ Message Decoder enabled. Sia will analyze her messages in Messenger.'
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
        _showComposerNotice('Sia could not read that message just now.');
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

    _loadMessageDecoderState();
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

  void _checkUrlFragmentClaim() {
    if (_isClaimingFragmentCode) return;
    try {
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty && fragment.contains('code=')) {
        final params = Uri.splitQueryString(fragment);
        final code = params['code']?.trim();
        if (code != null && code.length >= 32) {
          _isClaimingFragmentCode = true;
          _claimInviteCodeSafely(code);
        }
      }
    } catch (_) {}
  }

  Future<void> _claimInviteCodeSafely(String code) async {
    try {
      final res = await _partnerService.acceptInviteLink(code);
      if (!mounted) return;

      if (res['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'].toString()),
            backgroundColor: BlushyColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Connected with your partner successfully!'),
            backgroundColor: Color(0xFF10B981),
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
              backgroundColor: const Color(0xFFDD0D22),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'ACCEPT',
                textColor: Colors.white,
                onPressed: () async {
                  final ok = await _partnerService.respondToInvitation(invId, 'accept');
                  if (ok) {
                    await _fetchPartnerData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connected! Your shared partner portal is now live 🎉'),
                          backgroundColor: Color(0xFF10B981),
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
        final partnerEmail = activeConn['partnerEmail'] as String? ?? activeConn['partnerUserId'] as String? ?? 'Partner';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 $partnerEmail accepted your request! Live connection active.'),
            backgroundColor: const Color(0xFF10B981),
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
        final currentUserId = AuthStorage.getUserId();
        final mapped = apiMsgs.map((m) {
          final senderId = m['senderUserId'] ?? m['sender_user_id'];
          final isMe = (currentUserId != null && currentUserId.isNotEmpty && senderId == currentUserId);
          return {
            'messageId': m['messageId'] ?? m['message_id'],
            'senderUserId': senderId,
            'senderRole': m['sender_role'] ?? m['senderRole'],
            'sender': isMe ? 'You' : (m['sender']?['displayName'] ?? m['sender']?['display_name'] ?? 'Partner'),
            'text': m['message'] ?? m['text'] ?? '',
            'isAudio': m['audioUrl'] != null || m['audio_url'] != null,
            'audioUrl': m['audioUrl'] ?? m['audio_url'],
            'duration': m['audioDuration'] != null ? '${m['audioDuration']}s' : null,
            'createdAt': m['createdAt'] ?? m['created_at'],
            'isCard': false,
            'isMe': isMe,
          };
        }).toList();

        bool hasDifferences = mapped.length != _chatMessages.length;
        if (!hasDifferences) {
          for (int i = 0; i < mapped.length; i++) {
            if (mapped[i]['text'] != _chatMessages[i]['text'] ||
                mapped[i]['isMe'] != _chatMessages[i]['isMe']) {
              hasDifferences = true;
              break;
            }
          }
        }

        if (hasDifferences) {
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
        });
        // The connection id is only known now, and the activities hang off it.
        unawaited(_loadSharedActivities());
        unawaited(_loadGarden());
        _syncLiveMessages();
      }
    } catch (e) {
      debugPrint('Error fetching partner data: $e');
    } finally {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _liveChatTimer?.cancel();
    _msgController.dispose();
    _partnerInviteEmailController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  String _getFloatingActionText() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Overview':
        return 'Grow Garden';
      case 'Boutique':
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
        return 'Ask Sia';
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
      case 'Boutique':
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

  void _sendTextMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
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
    _syncWithStorage();
    final state = BlushyOSProvider.of(context);
    final isHome = _selectedTabIndex == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isHome) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: BlushyColors.dark, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedTabIndex = 0;
                            });
                          },
                        ),
                        Text(
                          _tabs[_selectedTabIndex],
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: BlushyColors.border),
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


  void _showHelpOptionsDialog(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final bool isUserWoman = (currentRole != 'partner' && currentRole != 'man');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF6F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: () async {
            try {
              final service = ApiPartnerService();
              final conns = await service.getConnections();
              final active = conns.firstWhere((c) => c['status'] == 'active', orElse: () => <String, dynamic>{});
              if (active.isNotEmpty) {
                final connId = (active['connectionId'] ?? active['_id'] ?? '').toString();
                if (connId.isNotEmpty) {
                  return await service.getPartnerSharedData(connId);
                }
              }
            } catch (_) {}
            return <String, dynamic>{};
          }(),
          builder: (context, snapshot) {
            final sharedData = snapshot.data;
            final dynamic dynamicNeeds = sharedData?['dynamicNeeds'];
            final bool hasDynamicData = dynamicNeeds != null && dynamicNeeds is Map;
            final bool hasNeeds = hasDynamicData && (dynamicNeeds['hasNeeds'] == true);
            final List<dynamic> customNeedsList = hasDynamicData && (dynamicNeeds['needs'] is List)
                ? (dynamicNeeds['needs'] as List)
                : [];

            final String dialogTitle = hasDynamicData && dynamicNeeds['title'] != null
                ? dynamicNeeds['title'].toString()
                : (isUserWoman ? "What does he need today?" : "What does she need today?");

            final defaultNeeds = isUserWoman
                ? [
                    {
                      "label": "He needs appreciation & validation",
                      "tip": "Sia recommends: Acknowledge his effort, say thank you for something specific, or let him know how much you value him."
                    },
                    {
                      "label": "He needs quiet space to decompress",
                      "tip": "Sia recommends: Give him some uninterrupted downtime to unwind after a stressful day without pressure."
                    },
                    {
                      "label": "He needs words of encouragement",
                      "tip": "Sia recommends: Remind him that you believe in him and that you're right by his side through current pressures."
                    },
                    {
                      "label": "He wants comfort & physical affection",
                      "tip": "Sia recommends: Offer a warm hug, a gentle massage, or a quiet moment relaxing together."
                    },
                    {
                      "label": "He wants fun & quality time",
                      "tip": "Sia recommends: Suggest a casual game, watch a movie, share a favorite snack, or go for an easy walk together."
                    },
                    {
                      "label": "I don't know what he needs",
                      "tip": "Sia recommends: Ask gently: 'Are you looking for encouragement, quiet downtime, or just want to hang out?'"
                    },
                  ]
                : [
                    {
                      "label": "She needs rest",
                      "tip": "Sia recommends: Cancel non-essential tasks, dim the lights, and handle dinner tonight."
                    },
                    {
                      "label": "She needs comfort",
                      "tip": "Sia recommends: Bring a warm heat pack, brew her favorite herbal tea, or offer a back rub."
                    },
                    {
                      "label": "She needs practical help",
                      "tip": "Sia recommends: Check the laundry, wash dishes, or ask: 'Which chore can I take off your plate right now?'"
                    },
                    {
                      "label": "She wants company",
                      "tip": "Sia recommends: Put away phones, suggest a relaxed walk, or watch a movie together."
                    },
                    {
                      "label": "She wants space",
                      "tip": "Sia recommends: Give her quiet time. Say: 'I am right here in the other room if you need anything.'"
                    },
                    {
                      "label": "I don't know what she needs",
                      "tip": "Sia recommends: Ask gently: 'Are you looking for comfort, help, or quiet space right now?'"
                    },
                  ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BlushyColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite, size: 20, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dialogTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: BlushyColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: BlushyColors.primary),
                        ),
                      )
                    else if (hasNeeds && customNeedsList.isNotEmpty) ...[
                      if (dynamicNeeds['message'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            dynamicNeeds['message'].toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: BlushyColors.text.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: customNeedsList.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE8DFD8)),
                          itemBuilder: (context, index) {
                            final item = customNeedsList[index];
                            final String label = (item is Map ? item['label'] : null) ?? item.toString();
                            final String tip = (item is Map ? item['tip'] : null) ?? "Sia recommends: Show love and patience.";
                            final String? category = (item is Map ? item['category'] : null);
                            final String? source = (item is Map ? item['source'] : null);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              title: Text(
                                label,
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
                              ),
                              subtitle: (source != null || category != null)
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          if (category != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: BlushyColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                category,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: BlushyColors.primary,
                                                ),
                                              ),
                                            ),
                                          if (category != null && source != null) const SizedBox(width: 8),
                                          if (source != null)
                                            Expanded(
                                              child: Text(
                                                source,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : null,
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: BlushyColors.primary),
                              onTap: () {
                                Navigator.pop(context);
                                _showTipDialog(context, label, tip);
                              },
                            );
                          },
                        ),
                      ),
                    ] else if (hasDynamicData && !hasNeeds) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.spa, size: 24, color: Color(0xFF2E7D32)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUserWoman ? "He's feeling peaceful" : "She's feeling peaceful",
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                      ),
                                      Text(
                                        "No distress or special needs logged",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              dynamicNeeds['message']?.toString() ??
                                  (isUserWoman
                                      ? "He hasn't logged any discomfort or asked for specific help recently."
                                      : "She hasn't logged any discomfort or asked for specific help recently."),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.4,
                                color: BlushyColors.text.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF6F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE8DFD8)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 18, color: BlushyColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dynamicNeeds['tip']?.toString() ??
                                          "Sia recommends: A warm check-in or simple 'Thinking of you' goes a long way.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: BlushyColors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Got it",
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "Here are general ways to support your partner today:",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: defaultNeeds.map((need) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(need["label"]!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: BlushyColors.primary),
                              onTap: () {
                                Navigator.pop(context);
                                _showTipDialog(context, need["label"]!, need["tip"]!);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTipDialog(BuildContext context, String title, String tip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(tip, style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: BlushyColors.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Got it", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showArgumentModeConfirmationDialog(BlushyOSState state) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Turn on Argument Mode?"),
          content: const Text(
            "While Argument Mode is enabled, your personal insights, mood, cycle and wellbeing updates won't be shared with your partner.\n\nShared relationship activities and milestones will continue to work."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                state.setArgumentModeActive(true);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Argument Mode enabled. Personal insights paused.')),
                );
              },
              child: const Text("Turn On"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BlushyOSState state) {
    final bool canPop = Navigator.canPop(context);
    final double pagePadding = BlushyTheme.getPagePadding(context);

    if (!canPop) {
      return const SizedBox(height: 16);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pagePadding, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Back to Home',
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
      ),
    );
  }


  Widget _buildWorkspaceTabContent(BlushyOSState state) {
    switch (_tabs[_selectedTabIndex]) {
      case 'Overview':
        return _buildOverviewTab(state);
      case 'Boutique':
        return _buildBoutiqueTab();
      case 'Messenger':
        return _buildMessengerTab(state);
      case 'Activities':
        return _buildActivitiesTab();
      case 'Letters':
        return _buildLettersTab();
      case 'Memory Book':
        return _buildMemoryBookTab();
      case 'Relationship AI':
        // Guarded by tab as well as by entry point, so it cannot be reached by
        // index from a stale selection.
        if (!_isSupportingPartner) return _buildOverviewTab(state);
        return _buildRelationshipAITab(state);
      case 'Gifts':
        return _buildGiftsTab();
      default:
        return _buildOverviewTab(state);
    }
  }

  // --- TAB 1: OVERVIEW & RELATIONSHIP GARDEN ---
  Widget _buildOverviewTab(BlushyOSState state) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _buildHeader(state),
        if (_incomingInvitations.isNotEmpty) _buildPendingRequestsBanner(),
        _buildRelationshipStatusCard(state),
        _buildQuickActionsRow(),
        _buildRelationshipTimeline(state),
        const SizedBox(height: 24),
        _buildRecentMomentsCarousel(state),
      ],
    );
  }

  Widget _buildPendingRequestsBanner() {
    return Column(
      children: _incomingInvitations.map((inv) {
        final invId = (inv['invitationId'] ?? inv['_id'] ?? '').toString();
        final senderEmail = inv['senderEmail'] as String? ?? inv['senderUserId'] as String? ?? 'Your Partner';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: BlushyColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Partner Request',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          senderEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Text(
                      'Live Pending',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Accept to connect your spaces and begin sharing cycles, insights, and live couple chat.',
                style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final ok = await _partnerService.respondToInvitation(invId, 'reject');
                      if (ok) {
                        await _fetchPartnerData();
                      }
                    },
                    child: Text(AppLocalizations.of(context).partnerDecline, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD0D22),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                    ),
                    onPressed: () async {
                      final ok = await _partnerService.respondToInvitation(invId, 'accept');
                      if (ok) {
                        await _fetchPartnerData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connected! Your Partner Space is now live 🎉'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: Text('Accept Request', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRelationshipStatusCard(BlushyOSState state) {
    final active = state.argumentModeActive;

    // ============================================================================
    // 🔒 [PRODUCTION MODE: STRICT SEPARATE ACCOUNTS - ACTIVE]
    // Strictly enforces 1-to-1 account invite, token handshake, and connection verification.
    // ============================================================================
    final pc = state.personalContext;
    final wb = state.wellbeingState;

    final checkinData = BlushyStorage.read('daily_checkin.json');
    final String currentEnergy = checkinData['energy'] ?? (wb.energy != null ? (wb.energy! >= 7 ? 'High' : (wb.energy! >= 4 ? 'Medium' : 'Low')) : 'Medium');

    final DateTime? pStart = pc.lastPeriodStart;
    final int cycleDay = (pStart != null)
        ? (DateTime.now().difference(pStart).inDays + 1)
        : (pc.cycleDay ?? 1);

    final hasConnection = _connections.isNotEmpty;
    final primaryPartner = hasConnection ? _connections.first : null;
    final partnerNameOrEmail = primaryPartner != null
        ? (primaryPartner['partnerName'] as String? ?? primaryPartner['partnerEmail'] as String? ?? primaryPartner['partnerUserId'] as String? ?? 'Partner')
        : 'No Partner Connected';

    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final bool isUserWoman = (currentRole != 'partner' && currentRole != 'man');

    final String statusSubtitle = hasConnection
        ? (isUserWoman
            ? 'Live Sync • Shared Connection • $currentEnergy Energy'
            : 'Live Sync • Day $cycleDay of Cycle • $currentEnergy Energy')
        : 'No partner paired yet • Send an invite to begin sharing';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: BlushyColors.dark.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: BlushyColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasConnection ? "$partnerNameOrEmail's Portal" : "Partner Portal",
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      statusSubtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: hasConnection ? BlushyColors.primary : BlushyColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasConnection) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedTabIndex = 2; // Messenger tab
                        });
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, size: 13, color: Colors.white),
                      label: Text(
                        'Open Chat',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlushyColors.success,
                        side: const BorderSide(color: Color(0xFFD6F1DF)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _showHelpOptionsDialog(context),
                      child: Text(
                        'Tips',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _showPartnerConnectionsModal,
                  icon: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                  label: Text(
                    'Connect',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: BlushyColors.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    active ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: active ? BlushyColors.success : BlushyColors.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Argument Mode",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: active ? BlushyColors.danger : BlushyColors.text,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (hasConnection) ...[
                    TextButton(
                      onPressed: _showPartnerConnectionsModal,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Manage',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () {
                      if (!active) {
                        _showArgumentModeConfirmationDialog(state);
                      } else {
                        state.setArgumentModeActive(false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Argument Mode disabled. Resuming normal sharing.')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFFDF2F2) : const Color(0xFFFAF6F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: active ? BlushyColors.secondary : BlushyColors.border),
                      ),
                      child: Text(
                        active ? "ON" : "OFF",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: active ? BlushyColors.success : BlushyColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.secondary),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_person_rounded, size: 14, color: BlushyColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Argument Mode is ON. Your partner won't receive any new personal insights until you turn it off.",
                      style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.danger, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isUserWoman) ...[
            const SizedBox(height: 10),
            const Divider(color: BlushyColors.border),
            const SizedBox(height: 10),
            // Her Message Decoder Option (Only for Male Partner - Default OFF)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isMessageDecoderActive ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: _isMessageDecoderActive ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Her Message Decoder",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isMessageDecoderActive ? const Color(0xFF6F42F5) : BlushyColors.text,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleMessageDecoder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isMessageDecoderActive ? const Color(0xFFF3EFFF) : const Color(0xFFFAF6F0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isMessageDecoderActive ? const Color(0xFF9D7BFF) : BlushyColors.border,
                          ),
                        ),
                        child: Text(
                          _isMessageDecoderActive ? "ON" : "OFF",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _isMessageDecoderActive ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_isMessageDecoderActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6C8FF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6F42F5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Decoder is ON. Sia will translate what she is coming to tell based on her live cycle phase, mood, and sleep levels in Messenger.",
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF5A31D8), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Opens the server-enforced sharing panel for the active connection.
  ///
  /// Only the person whose data is shared can open it; the server returns 403
  /// to the other side, so the partner is told that rather than shown an empty
  /// screen they cannot act on.
  /// True for the partner supporting someone, false for the person whose data
  /// is shared.
  ///
  /// Relationship advice is built for the supporting side: it explains what she
  /// is telling him, grounded in what she chose to share. Asked from her side
  /// there is nothing to ground it in -- the partner shell has no Sia and no
  /// M Studio, so he logs nothing -- and the server refuses it outright.
  bool get _isSupportingPartner {
    final active = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    if (active.isEmpty) return false;
    return active['canManagePermissions'] != true;
  }

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
                partnerName: active['partnerEmail']?.toString(),
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
                color: Color(0xFFFAF6F0),
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
                            style: GoogleFonts.poppins(
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
                      labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      tabs: [
                        Tab(text: 'Connections (${_connections.length})'),
                        Tab(
                          text: _incomingInvitations.isNotEmpty
                              ? 'Pending (${_incomingInvitations.length})'
                              : 'Pending',
                        ),
                        const Tab(text: 'Invite'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildConnectionsListTab(setModalState),
                          _buildPendingRequestsTab(setModalState),
                          _buildInvitePartnerTab(setModalState),
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
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).partnerSendInviteExplainer,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
        final partnerEmail = conn['partnerEmail'] as String? ?? conn['partnerUserId'] as String? ?? 'Partner';
        final role = conn['partnerRole'] as String? ?? 'Partner';
        final status = conn['status'] as String? ?? 'active';
        final connectionId = conn['connectionId'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                      partnerEmail,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    Text(
                      'Role: $role • Status: $status',
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: BlushyColors.primary, size: 20),
                tooltip: 'Privacy Settings',
                onPressed: () => _showGranularPermissionsModal(context, conn),
              ),
              // Full server-enforced permission matrix (spec section 10).
              // Shows every shareable category with its current state, so the
              // person sharing can always see exactly what is shared.
              IconButton(
                icon: const Icon(Icons.visibility_outlined, color: BlushyColors.primary, size: 20),
                tooltip: 'What you share',
                onPressed: connectionId.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PartnerSharingScreen(
                              connectionId: connectionId,
                              partnerName: partnerEmail.isEmpty ? null : partnerEmail,
                            ),
                          ),
                        ),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Disconnect Partner?'),
                      content: Text('Are you sure you want to disconnect $partnerEmail?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).partnerDisconnect, style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true && connectionId.isNotEmpty) {
                    final success = await _partnerService.breakupConnection(connectionId);
                    if (success) {
                      await _fetchPartnerData();
                      setModalState(() {});
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Partner disconnected.')),
                      );
                    }
                  }
                },
                child: Text(
                  AppLocalizations.of(context).partnerDisconnect,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
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

    Map<String, dynamic> perms = {
      'shareCycle': true,
      'shareMood': true,
      'shareSleep': true,
      'shareInsights': true,
      'shareOnboarding': true,
      'allowAiSuggestionsWoman': true,
      'allowAiSuggestionsMan': true,
      'allowDecoderMan': true,
    };
    if (conn['permissions'] is Map) {
      perms.addAll(Map<String, dynamic>.from(conn['permissions'] as Map));
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
                      const Icon(Icons.shield_outlined, color: BlushyColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Partner Privacy Settings',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOwner
                        ? 'Control what health & wellness updates are shared with your partner in real time.'
                        : 'These privacy settings are managed by your partner.',
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          final ok = await _partnerService.updatePermissions(connectionId, perms);
                          nav.pop();
                          if (ok && mounted) {
                            await _fetchPartnerData();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Privacy settings updated.')),
                            );
                          }
                        },
                        child: Text('Save Permissions', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
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
      title: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText)),
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
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: BlushyColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Incoming and outgoing partner invitations will appear here.',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          ..._incomingInvitations.map((inv) {
            final invId = inv['invitationId'] as String? ?? '';
            final senderEmail = inv['senderEmail'] as String? ?? inv['senderUserId'] as String? ?? 'A user';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$senderEmail wants to connect with you.',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          final ok = await _partnerService.respondToInvitation(invId, 'reject');
                          if (ok) {
                            await _fetchPartnerData();
                            setModalState(() {});
                          }
                        },
                        child: Text('Reject', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          final ok = await _partnerService.respondToInvitation(invId, 'accept');
                          if (ok) {
                            await _fetchPartnerData();
                            setModalState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Partner request accepted! 🎉')),
                              );
                            }
                          }
                        },
                        child: Text(AppLocalizations.of(context).partnerAccept, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
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
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          ..._outgoingInvitations.map((inv) {
            final receiverEmail = inv['receiverEmail'] as String? ?? 'Partner';
            final status = inv['status'] as String? ?? 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text),
                        ),
                        Text(
                          'Status: $status',
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pending',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[800]),
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
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your partner\'s registered email address to send a connection request.',
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _partnerInviteEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'partner@example.com',
              labelText: 'Partner Email Address',
              prefixIcon: const Icon(Icons.email_outlined, color: BlushyColors.primary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: BlushyColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: BlushyColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                              SnackBar(content: Text(res['error'] as String)),
                            );
                          }
                        } else {
                          _partnerInviteEmailController.clear();
                          await _fetchPartnerData();
                          setModalState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Partner invitation sent successfully! 💌')),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to send invitation: $e')),
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
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
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
                Row(
                  children: [
                    const Icon(Icons.link_rounded, color: BlushyColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).partnerInviteLinkTitle,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Generate a private, single-use link to share directly via WhatsApp, SMS, or messaging apps.',
                  style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BlushyColors.primary,
                      side: const BorderSide(color: BlushyColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        const SnackBar(
                          content: Text('Invite link copied to clipboard! 📋'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      'Generate & Copy Link',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
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
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Shows a generated invite link and its code.
  ///
  /// The code matters on mobile: the link points at the web app, and Android
  /// registers no https App Link for blushy.life, so tapping it on a phone
  /// cannot hand the code back to this app. Entering the code by hand is the
  /// only route that works on a device.
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
              'Share this invitation',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Send them the link, or read out the code for them to enter in their app. It expires in 48 hours.',
              style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 20),
            SelectableText(
              url,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary),
            ),
            if (code != null) ...[
              const SizedBox(height: 20),
              Text(
                'INVITE CODE',
                style: GoogleFonts.poppins(
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text('Copy link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
              const SnackBar(
                content: Text('🎉 Connected with your partner successfully!'),
                backgroundColor: Color(0xFF10B981),
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
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste the code your partner shared with you.',
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: GoogleFonts.robotoMono(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Invite code',
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: submit,
                    child: Text('Connect', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    final actions = [
      {'label': 'Boutique', 'icon': Icons.local_florist_rounded, 'tab': 1},
      {'label': 'Message', 'icon': Icons.chat_bubble_outline_rounded, 'tab': 2},
      {'label': 'Shared Activity', 'icon': Icons.task_alt_rounded, 'tab': 3},
      {'label': 'Send Letter', 'icon': Icons.mail_outline_rounded, 'tab': 4},
      {'label': 'Memory Book', 'icon': Icons.photo_library_outlined, 'tab': 5},
      if (_isSupportingPartner)
        {'label': 'Ask Relationship AI', 'icon': Icons.psychology_alt_rounded, 'tab': 6},
      {'label': 'Surprise', 'icon': Icons.card_giftcard_rounded, 'tab': 7},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Row(
        children: actions.map((act) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTabIndex = act['tab'] as int;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border),
                boxShadow: [
                  BoxShadow(
                    color: BlushyColors.dark.withValues(alpha: 0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(act['icon'] as IconData, size: 14, color: BlushyColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    act['label'] as String,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRelationshipTimeline(BlushyOSState state) {

    final activeConn = _connections.firstWhere(
      (c) => c['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    final hasActivePartner = activeConn.isNotEmpty;
    final partnerIdentifier = (activeConn['partnerEmail'] ?? activeConn['partnerUserId'] ?? 'Partner').toString();
    final connectionDuration = formatConnectionDuration(activeConn['created_at'] ?? activeConn['createdAt']);

    final dynamicTimelineEvents = <Map<String, dynamic>>[
      if (hasActivePartner)
        {
          'title': 'Partner Connected',
          'time': 'Connected with $partnerIdentifier • $connectionDuration',
          'icon': Icons.favorite_rounded,
          'color': const Color(0xFFFDF2F2),
          'onTap': () => setState(() => _selectedTabIndex = 2), // Messenger
        }
      else
        {
          'title': 'Invite Your Partner',
          'time': 'Link accounts to unlock live cycle sharing and messaging',
          'icon': Icons.person_add_rounded,
          'color': const Color(0xFFFDF2F2),
          'onTap': () => _showPartnerConnectionsModal(),
        },
      // Reachable only while connected, which is when it matters. The sharing
      // panel used to sit behind the "Invite Your Partner" tile, and that tile
      // is replaced by "Partner Connected" the moment a connection exists -- so
      // once you had someone to share with, there was no way to open it.
      if (_activeConnectionId != null)
        {
          'title': 'Privacy & Sharing',
          'time': 'Choose what your partner can see. Nothing is shared until you say so.',
          'icon': Icons.shield_outlined,
          'color': const Color(0xFFF3EEFA),
          'onTap': () => _openSharingPanel(),
        },
      {
        'title': 'Shared Activity',
        'time': 'Gratitude Checklist & Couple Challenges',
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFFF3FAF6),
        'onTap': () => setState(() => _selectedTabIndex = 3), // Activities
      },
      {
        'title': 'Garden Blossoming',
        'time': _gardenLoading
            ? 'Loading your garden...'
            : (_flowersCount == 0 && _treesCount == 0
                // An empty garden says so rather than implying a Season 1 that
                // is already in bloom.
                ? 'Nothing planted yet (Tap to tend)'
                : '$_flowersCount flowers, $_treesCount trees together (Tap to tend)'),
        'icon': Icons.local_florist_rounded,
        'color': const Color(0xFFF3FAF6),
        'onTap': () {
          // Grown on the server, so the flower shows up for both of you.
          unawaited(_growGarden(flowers: 1));
        },
      },
      {
        'title': 'Time Capsule Letters',
        'time': 'Sealed milestones and personal messages',
        'icon': Icons.mail_outline_rounded,
        'color': const Color(0xFFFFF9F2),
        'onTap': () => setState(() => _selectedTabIndex = 4), // Letters
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Timeline',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...dynamicTimelineEvents.map((evt) {
            final onTap = evt['onTap'] as VoidCallback?;
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: BlushyColors.dark.withValues(alpha: 0.01),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: evt['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(evt['icon'] as IconData, size: 16, color: BlushyColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evt['title'] as String,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            evt['time'] as String,
                            style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: BlushyColors.secondaryText),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentMomentsCarousel(BlushyOSState state) {
    final moments = [
      if (_isSupportingPartner)
        {
          'title': "Partner's Check-in",
          'desc': 'Review latest mood & cycle rhythm',
          'icon': Icons.sentiment_very_satisfied_rounded,
          'tab': 6, // Relationship AI
        },
      {
        'title': 'Letter From Partner',
        'desc': 'Unseals on milestones • View letters',
        'icon': Icons.mail_outline_rounded,
        'tab': 4, // Letters
      },
      {
        'title': 'Memory Added',
        'desc': 'Couple Scrapbook & Memories',
        'icon': Icons.photo_library_outlined,
        'tab': 5, // Memory book
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Text(
            'Recent Moments',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: moments.map((mom) {
              final tabIndex = mom['tab'] as int;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTabIndex = tabIndex;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: BlushyColors.dark.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(mom['icon'] as IconData, size: 20, color: BlushyColors.primary),
                      const SizedBox(height: 14),
                      Text(
                        mom['title'] as String,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mom['desc'] as String,
                        style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: MESSENGER (INSTAGRAM-QUALITY REDESIGN) ---
  Widget _buildMessengerTab(BlushyOSState state) {
    final messages = state.argumentModeActive
        ? _chatMessages.where((msg) => msg['sender'] != 'Sia' || msg['isCard'] == false).toList()
        : _chatMessages;

    final currentUserId = AuthStorage.getUserId();
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;

    return Column(
      key: const ValueKey('messenger_tab'),
      children: [
        // 1. Messenger Instagram-inspired Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: BlushyColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: BlushyColors.dark, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 0; // Back to Overview
                  });
                },
              ),
              CircleAvatar(
                backgroundColor: BlushyColors.primary.withValues(alpha: 0.1),
                radius: 18,
                child: Text('💌', style: GoogleFonts.poppins(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentRole == 'partner' ? 'Her Space' : 'Partner',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Live synchronized',
                      style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _toggleMessageDecoder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMessageDecoderActive ? const Color(0xFFF3EFFF) : const Color(0xFFFAF6F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isMessageDecoderActive ? const Color(0xFF9D7BFF) : BlushyColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: _isMessageDecoderActive ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMessageDecoderActive ? 'Decoder ON' : 'Decoder OFF',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _isMessageDecoderActive ? const Color(0xFF6F42F5) : BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: BlushyColors.secondaryText, size: 20),
                onPressed: _syncLiveMessages,
              ),
            ],
          ),
        ),

        // 2. Chat history body
        Expanded(
          child: Container(
            color: const Color(0xFFFAF6F0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: BlushyColors.secondaryText),
                        const SizedBox(height: 10),
                        Text(
                          AppLocalizations.of(context).partnerNoMessages,
                          style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).partnerSayHello,
                          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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

        // 3. Instagram-inspired Message Composer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: BlushyColors.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showComposerActionsMenu = !_showComposerActionsMenu;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EFEA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: BlushyColors.dark, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Talk to Partner...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendTextMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendTextMessage,
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFDD0D22),
                  radius: 18,
                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: BlushyColors.warning, size: 14),
              const SizedBox(width: 8),
              Text(
                msg['title'] ?? '',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: BlushyColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg['subtitle'] ?? '',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            msg['text'] ?? '',
            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
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
              child: Text('Complete Check-in', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
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
            color: isMe ? const Color(0xFFFFF0F3) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF2C6D0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8A0B4).withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFADDE3),
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
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        Text(
                          'Digital Flower Gift',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFE8A0B4), fontWeight: FontWeight.w600),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFAF0F2)),
                ),
                child: Text(
                  '“$message”',
                  style: GoogleFonts.caveat(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5C3841),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 1; // Open Boutique / Garden
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A0B4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_florist_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Open Boutique & Garden',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
                    style: GoogleFonts.poppins(fontSize: 9, color: BlushyColors.secondaryText),
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
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDD0D22), Color(0xFFFF4B5C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDD0D22).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: const Color(0xFFE8E2D9), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
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
                          Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : const Color(0xFF6F42F5)),
                          const SizedBox(width: 6),
                          ...List.generate(12, (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 2,
                            height: 6.0 + math.Random().nextDouble() * 12.0,
                            color: isMe ? Colors.white70 : const Color(0xFF6F42F5),
                          )),
                          const SizedBox(width: 8),
                          Text(
                            msg['duration'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : BlushyColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        msg['text'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : const Color(0xFF2D2529),
                        ),
                      ),
                    ],
                    if (timeDisplay != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        timeDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: isMe ? Colors.white.withValues(alpha: 0.75) : BlushyColors.secondaryText.withValues(alpha: 0.7),
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
                        color: const Color(0xFFF3EFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD6C8FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDecoding) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6F42F5)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context).partnerSiaDecoding,
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6F42F5)),
                            ),
                          ] else ...[
                            const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF6F42F5)),
                            const SizedBox(width: 4),
                            Text(
                              "✨ Decode with Sia",
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF6F42F5)),
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
                    color: const Color(0xFFFAF7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD6C8FF), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6F42F5).withValues(alpha: 0.06),
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
                          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6F42F5), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Sia Decoded Meaning",
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6F42F5)),
                          ),
                          const Spacer(),
                          if (decodedData['emotionalTone'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6F42F5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                decodedData['emotionalTone'],
                                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6F42F5)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        decodedData['decodedMeaning'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2C2240), height: 1.35),
                      ),
                      if (decodedData['cycleMoodContext'] != null && decodedData['cycleMoodContext'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 11, color: Color(0xFFE8A0B4)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                decodedData['cycleMoodContext'],
                                style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEFE8FC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).partnerSuggestedReply,
                                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "“${decodedData['recommendedReply']}”",
                                style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: BlushyColors.text),
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
                                      color: const Color(0xFF6F42F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context).partnerUseReply,
                                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
                            const Icon(Icons.lightbulb_outline_rounded, size: 12, color: Color(0xFFFFA000)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Tip: ${decodedData['actionTip']}",
                                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF6A5A38), height: 1.3),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI Communication Hub',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildOverlayActionItem('Rewrite Kindly', Icons.auto_awesome_rounded, () {
                setState(() {
                  _chatMessages[_selectedMessageIndexForActions]['text'] = "“I value our walks. Let's connect tonight.”";
                  _selectedMessageIndexForActions = -1;
                });
              }),
              _buildOverlayActionItem('Save to Memory Book', Icons.bookmark_outline_rounded, () {
                setState(() {
                  _selectedMessageIndexForActions = -1;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to shared scrapbook memory!')),
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

  Widget _buildOverlayActionItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: BlushyColors.primary, size: 18),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
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
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Based on what your partner has shared. Tap one to send it.',
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _sendComposerMessage(title);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
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
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.text)),
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
                style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.poppins(
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
    'daily_gratitude': Icons.volunteer_activism_rounded,
    'weekend_planner': Icons.calendar_month_rounded,
    'date_planner': Icons.calendar_today_rounded,
    'shared_canvas': Icons.palette_rounded,
    'virtual_bouquet': Icons.local_florist_rounded,
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
        onTap: busy ? null : () => _advanceActivity(activity),
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
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      style: GoogleFonts.poppins(
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                sub,
                style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
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
      final saved = BlushyStorage.read('partner_letters');
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
                color: Color(0xFFFAF6F0),
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
                      const Icon(Icons.edit_note_rounded, color: Color(0xFF6F42F5), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "Write a Love Letter",
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
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
                              color: isSel ? const Color(0xFF6F42F5) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSel ? const Color(0xFF6F42F5) : BlushyColors.border),
                            ),
                            child: Text(
                              style,
                              style: GoogleFonts.poppins(
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: TextField(
                      controller: titleController,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "Letter Title (e.g. For our special day)",
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: TextField(
                        controller: bodyController,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: "Pour your heart out here... Your thoughts, gratitude, or memories for your partner.",
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
                        activeColor: const Color(0xFF6F42F5),
                        onChanged: (val) => setModalState(() => sealForAnniversary = val ?? false),
                      ),
                      Expanded(
                        child: Text(
                          // This said "Deliver & open on milestone". Sealing
                          // sets a flag on the letter; nothing delivers it on
                          // a date, so it no longer promises that.
                          "Seal it, and open it together later",
                          style: GoogleFonts.poppins(fontSize: 11.5, color: BlushyColors.secondaryText),
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
                        backgroundColor: const Color(0xFF6F42F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final body = bodyController.text.trim();
                        if (title.isEmpty || body.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter both a title and letter message.')),
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
                          BlushyStorage.write('partner_letters', {'letters': currentLetters});
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
                                ? const Color(0xFF10B981)
                                : BlushyColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.mark_email_read_rounded, size: 18),
                      label: Text(
                        "Seal & Send to Partner 💌",
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
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
            color: const Color(0xFFFAF6F0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFE8DCCF)),
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
                      color: const Color(0xFF6F42F5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_rounded, color: Color(0xFF6F42F5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          letter['title'] ?? 'Love Letter',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                        ),
                        Text(
                          letter['stationery'] ?? 'Stationery',
                          style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: BlushyColors.dark.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      letter['body'] ?? '',
                      style: GoogleFonts.poppins(fontSize: 13.5, height: 1.7, color: const Color(0xFF2D2529)),
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
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: BlushyColors.secondaryText),
            ),
            ElevatedButton.icon(
              onPressed: () => _showWriteLetterModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F42F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.create_rounded, size: 14),
              label: Text(AppLocalizations.of(context).partnerWriteLetter, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (letters.isEmpty)
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              AppLocalizations.of(context).partnerNoLetters,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
            ),
          ),
        ...letters.map((letter) {
          final isSealed = letter['sealed'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showReadLetterModal(context, letter),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: BlushyColors.dark.withValues(alpha: 0.01),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSealed
                            ? const Color(0xFFFFF9F2)
                            : const Color(0xFF6F42F5).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSealed ? Icons.lock_clock_rounded : Icons.mail_rounded,
                        color: isSealed ? const Color(0xFFF59E0B) : const Color(0xFF6F42F5),
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
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isSealed
                                ? 'Sealed Time Capsule • Tap to read'
                                : (letter['isFromMe'] == true ? 'Sent to Partner • Tap to view' : 'Received from Partner • Tap to read'),
                            style: GoogleFonts.poppins(fontSize: 10.5, color: BlushyColors.secondaryText),
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
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: BlushyColors.secondaryText,
              ),
            ),
            if (completed.isNotEmpty)
              Text(
                completed.length == 1 ? '1 memory' : '${completed.length} memories',
                style: GoogleFonts.poppins(fontSize: 10, color: BlushyColors.secondaryText),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_activitiesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (completed.isEmpty)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BlushyColors.border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              AppLocalizations.of(context).partnerNoMemories,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3EEFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Color(0xFF6F42F5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BlushyColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _describeMemory(activity, finishedByMe),
                          style: GoogleFonts.poppins(
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
                        color: const Color(0xFF6F42F5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${activity.completionCount}x',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6F42F5),
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
  // behind it, so there was nothing here that could work. It now asks Sia,
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
            color: const Color(0xFFF3EEFA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4D6F1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).partnerSiaAdviceTitle,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6F42F5),
                ),
              ),
              const SizedBox(height: 10),
              if (connectionId == null)
                Text(
                  'Connect with your partner first, and Sia can help you think things through together.',
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.45),
                )
              else if (state.argumentModeActive)
                Text(
                  'Your partner has chosen not to share personal insights right now.',
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.45),
                )
              else
                Text(
                  AppLocalizations.of(context).partnerSiaAdviceExplainer,
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.45),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4D6F1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _relationshipAnswer!,
                    style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                  ),
                  if (_relationshipUsedPartnerData != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _relationshipUsedPartnerData!
                          // Saying which is the difference between advice that
                          // knows something and advice that is guessing.
                          ? 'Based on what your partner shares with you.'
                          : 'Your partner has not shared data Sia could use here.',
                      style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _relationshipController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'What would you like help with?',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE4D6F1)),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F42F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                _relationshipLoading ? 'Thinking…' : 'Ask Sia',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
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
              _selectedTabIndex = 1; // Open Boutique tab
            });
          },
          child: _buildOverviewItem('Send Digital Flowers', 'Send a sweet postcard and customizable flower bloom', Icons.local_florist_rounded),
        ),
      ],
    );
  }

  // --- TAB BOUTIQUE ---
  Widget _buildBoutiqueTab() {
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
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: Icon(_getFloatingActionIcon(), color: Colors.white, size: 16),
      ),
    );
  }

  void _showActivityTriggerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Start Shared Activity'),
          content: const Text('Would you like to notify Partner to start the Gratitude Checklist together?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final connectionId = _activeConnectionId;
                navigator.pop();

                if (connectionId == null) {
                  _showComposerNotice('Connect with your partner first.');
                  return;
                }

                // Started on the connection, so it genuinely appears for both
                // of you rather than only on this device.
                final updated = await _partnerService.setSharedActivityStatus(
                  connectionId,
                  'daily_gratitude',
                  'in_progress',
                );
                if (!mounted) return;

                if (updated == null) {
                  _showComposerNotice('Could not start that activity. Please try again.');
                  return;
                }

                setState(() => _sharedActivities = updated);
                await _growGarden(flowers: 1);
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }
}
