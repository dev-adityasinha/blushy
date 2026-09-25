import 'dart:async';

import 'package:flutter/material.dart';
import 'partner_home_sections.dart';
import '../../../shared/live_refresh.dart';
import '../../../services/partner_websocket_service.dart';
import 'partner_stage_today.dart';
import '../partner_stage.dart';
import 'private_space_partner_state.dart';
import 'cycle_harmony_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../services/auth_storage.dart';
import 'partner_sia.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/api_partner_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../models/blushy_models.dart';
import '../../../shared/api_state_card.dart';
import 'partner_privacy_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../partner_display_name.dart';
import '../../../shared/docsy_wordmark.dart';
import '../../../shared/docsy_avatar.dart';
import '../../../services/user_state_store.dart';

class PartnerHomeScreen extends StatefulWidget {
  const PartnerHomeScreen({super.key});

  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen>
    with WidgetsBindingObserver, LiveRefresh {
  final ApiPartnerService _partnerService = ApiPartnerService();
  bool _isLoading = true;
  Map<String, dynamic>? _activeConnection;
  Map<String, dynamic>? _sharedData;
  Set<String> _completedActionIds = {};

  // ---------------------------------------------------------------------
  // Partner-safe read model (spec sections 19 to 21).
  //
  // The legacy shared-data endpoint predates the 13-key permission matrix, so
  // it can surface categories the woman never granted under the current model.
  // This is the server-filtered view: it returns only what her present
  // permissions allow, and stops returning it the moment she revokes.
  // ---------------------------------------------------------------------

  ApiResult<PartnerHomeModel> _partnerHome = const ApiResult.loading();

  Future<void> _loadPartnerHome(String connectionId) async {
    if (connectionId.isEmpty) return;
    final result = await PartnerApi.home(connectionId);
    if (!mounted) return;
    setState(() => _partnerHome = result);
  }

  /// Acknowledge or complete a care request. Only the partner may do this;
  /// the server enforces it (spec section 11).
  Future<void> _updateSupportRequest(SupportRequest request, String nextState) async {
    final messenger = ScaffoldMessenger.of(context);
    final connectionId = (_activeConnection?['connectionId'] ?? _activeConnection?['_id'] ?? '').toString();

    final result = await PartnerApi.updateSupportRequest(request.requestId, nextState);
    if (!mounted) return;

    if (result.isReady) {
      await _loadPartnerHome(connectionId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(nextState == 'completed' ? 'Marked as done.' : 'Let her know you have seen it.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That could not be saved.')),
      );
    }
  }

  String _getTodayDateKey() => DateTime.now().toIso8601String().substring(0, 10);

  /// The server already announces the things worth reacting to instantly.
  ///
  /// `PartnerScreen` has listened to this since it was written; Home never
  /// did, so when she changed what she shares, the one screen built entirely
  /// out of what she shares was the last to find out -- up to a poll interval
  /// later, or not until it was reopened. The socket is a broadcast singleton,
  /// so listening here costs no second connection.
  StreamSubscription<PartnerWebSocketEvent>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadLocalCompletedActions();
    _fetchLivePartnerData();
    startLiveRefresh();
    _listenForLiveChanges();
  }

  void _listenForLiveChanges() {
    final ws = PartnerWebSocketService();
    ws.connect();
    _wsSubscription = ws.events.listen((event) {
      if (!mounted) return;
      const worthRefetching = {
        'permissions-updated',
        'invitation-accepted',
        'breakup-requested',
        'breakup-completed',
        'shared-data-updated',
      };
      if (worthRefetching.contains(event.reason)) {
        refreshQuietly();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    stopLiveRefresh();
    super.dispose();
  }

  /// A refresh with no spinner and no flicker.
  ///
  /// `_isLoading` is deliberately untouched: the progress bar at the top of
  /// the screen is for the first load, when there is nothing to look at yet.
  /// Showing it every forty-five seconds would make a working screen look
  /// like a struggling one.
  @override
  Future<void> refreshNow() => _fetchLivePartnerData();

  void _loadLocalCompletedActions() {
    try {
      final saved = UserStateStore.read('partner_completed_actions_${_getTodayDateKey()}');
      if (saved['completed'] is List) {
        setState(() {
          _completedActionIds = Set<String>.from((saved['completed'] as List).map((e) => e.toString()));
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleActionCompletion(String actionId) async {
    final bool willComplete = !_completedActionIds.contains(actionId);
    setState(() {
      if (willComplete) {
        _completedActionIds.add(actionId);
      } else {
        _completedActionIds.remove(actionId);
      }
    });

    try {
      UserStateStore.write('partner_completed_actions_${_getTodayDateKey()}', {
        'completed': _completedActionIds.toList(),
      });
    } catch (_) {}

    if (_activeConnection != null && _activeConnection!.isNotEmpty) {
      final connId = (_activeConnection!['connectionId'] ?? _activeConnection!['_id'] ?? '').toString();
      if (connId.isNotEmpty) {
        try {
          final updated = await _partnerService.toggleSupportAction(
            connectionId: connId,
            actionId: actionId,
            completed: willComplete,
          );
          if (mounted && updated.isNotEmpty) {
            setState(() {
              _completedActionIds = Set<String>.from(updated);
            });
            UserStateStore.write('partner_completed_actions_${_getTodayDateKey()}', {
              'completed': _completedActionIds.toList(),
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _fetchLivePartnerData() async {
    try {
      final connections = await _partnerService.getConnections();
      final active = connections.firstWhere(
        (c) => c['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );

      if (active.isNotEmpty) {
        final connId = (active['connectionId'] ?? active['_id'] ?? '').toString();
        Map<String, dynamic> shared = {};
        if (connId.isNotEmpty) {
          shared = await _partnerService.getPartnerSharedData(connId);
          // The permission-filtered view, loaded alongside.
          await _loadPartnerHome(connId);
        }
        if (mounted) {
          setState(() {
            _activeConnection = active;
            _sharedData = shared;
            if (shared['completedActionIds'] is List) {
              // Replaced, not merged. `addAll` could only ever add, so an
              // action he un-ticked on another device stayed ticked here.
              // The server owns the day; this is its view of it.
              _completedActionIds = Set<String>.from(
                (shared['completedActionIds'] as List).map((e) => e.toString()),
              );
              UserStateStore.write(
                'partner_completed_actions_${_getTodayDateKey()}',
                {'completed': _completedActionIds.toList()},
              );
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeConnection = null;
            _sharedData = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const List<Map<String, String>> _defaultManNeeds = [
    {
      "label": "He needs appreciation & validation",
      "tip": "Docsy recommends: Acknowledge his effort, say thank you for something specific, or let him know how much you value him."
    },
    {
      "label": "He needs quiet space to decompress",
      "tip": "Docsy recommends: Give him some uninterrupted downtime to unwind after a stressful day without pressure."
    },
    {
      "label": "He needs words of encouragement",
      "tip": "Docsy recommends: Remind him that you believe in him and that you're right by his side through current pressures."
    },
    {
      "label": "He wants comfort & physical affection",
      "tip": "Docsy recommends: Offer a warm hug, a gentle massage, or a quiet moment relaxing together."
    },
    {
      "label": "He wants fun & quality time",
      "tip": "Docsy recommends: Suggest a casual game, watch a movie, share a favorite snack, or go for an easy walk together."
    },
    {
      "label": "I don't know what he needs",
      "tip": "Docsy recommends: Ask gently: 'Are you looking for encouragement, quiet downtime, or just want to hang out?'"
    },
  ];

  static const List<Map<String, String>> _defaultWomanNeeds = [
    {
      "label": "She needs rest",
      "tip": "Docsy recommends: Cancel non-essential tasks, dim the lights, and handle dinner tonight."
    },
    {
      "label": "She needs comfort",
      "tip": "Docsy recommends: Bring a warm heat pack, brew her favorite tea, or offer a back rub."
    },
    {
      "label": "She needs practical help",
      "tip": "Docsy recommends: Check the laundry, wash dishes, or ask: 'Which chore can I handle for you right now?'"
    },
    {
      "label": "She wants company",
      "tip": "Docsy recommends: Put away phones, suggest a relaxed walk, or watch a movie together."
    },
    {
      "label": "She wants space",
      "tip": "Docsy recommends: Give her quiet time. Say: 'I am here in the other room if you need anything.'"
    },
    {
      "label": "I don't know what she needs",
      "tip": "Docsy recommends: Ask gently: 'Are you looking for comfort, help, or space right now?'"
    },
  ];

  void _showHelpOptionsDialog(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    final currentRole = AuthStorage.getRole() ?? state.selectedRole;
    final bool isUserWoman = (currentRole != 'partner' && currentRole != 'man');

    final dynamic dynamicNeeds = _sharedData?['dynamicNeeds'];
    final bool hasDynamicData = dynamicNeeds != null && dynamicNeeds is Map;
    final bool hasNeeds = hasDynamicData && (dynamicNeeds['hasNeeds'] == true);
    final List<dynamic> customNeedsList = hasDynamicData && (dynamicNeeds['needs'] is List)
        ? (dynamicNeeds['needs'] as List)
        : [];

    final String dialogTitle = hasDynamicData && dynamicNeeds['title'] != null
        ? dynamicNeeds['title'].toString()
        : (isUserWoman ? "What does he need today?" : "What does she need?");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BlushyColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
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
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Case 1: Dynamic Needs exist and hasNeeds is true
                if (hasNeeds && customNeedsList.isNotEmpty) ...[
                  if (dynamicNeeds['message'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        dynamicNeeds['message'].toString(),
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 13,
                          color: BlushyColors.text.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: customNeedsList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: BlushyColors.border),
                      itemBuilder: (context, index) {
                        final item = customNeedsList[index];
                        final String label = (item is Map ? item['label'] : null) ?? item.toString();
                        final String tip = (item is Map ? item['tip'] : null) ?? "Docsy recommends: Show love and patience.";
                        final String? category = (item is Map ? item['category'] : null);
                        final String? source = (item is Map ? item['source'] : null);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          title: Text(
                            label,
                            style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600, color: BlushyColors.text),
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
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            category,
                                            style: GoogleFonts.manrope(height: 1.5, 
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
                                            style: GoogleFonts.manrope(height: 1.5, 
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
                ]
                // Case 2: hasNeeds is false (She doesn't need anything right now)
                else if (hasDynamicData && !hasNeeds) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),

                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: BlushyColors.successSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.spa, size: 24, color: BlushyColors.success),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isUserWoman ? "He's feeling peaceful" : "She's feeling peaceful",
                                    style: GoogleFonts.manrope(height: 1.5, 
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: BlushyColors.success,
                                    ),
                                  ),
                                  Text(
                                    "No distress or special needs logged",
                                    style: GoogleFonts.manrope(height: 1.5, 
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
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.4,
                            color: BlushyColors.text.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BlushyColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: BlushyColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: BlushyColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dynamicNeeds['tip']?.toString() ??
                                      "Docsy recommends: A warm check-in or simple 'Thinking of you' goes a long way.",
                                  style: GoogleFonts.manrope(
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      AppLocalizations.of(context).phGotIt,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]
                // Case 3: Fallback (unconnected or loading)
                else ...[
                  Text(
                    AppLocalizations.of(context).phHereAreGeneralWays,
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: (isUserWoman ? _defaultManNeeds : _defaultWomanNeeds).map((need) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(need["label"]!, style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600)),
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
  }

  void _showTipDialog(BuildContext context, String title, String tip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(tip, style: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: BlushyColors.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).phGotIt, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
          ),
        ],
      ),
    );
  }


  /// Cycle phase from the filtered context, or null when she has not shared it.
  ///
  /// Shaped to match what the existing cards already read, so the cards
  /// themselves did not have to change.
  static Map<String, dynamic>? _permittedCycleInfo(Map<String, dynamic> permitted) {
    final phase = permitted['cyclePhase'];
    if (phase is! Map) return null;
    return {
      'phase': phase['phase'],
      'currentCycleDay': phase['cycleDay'],
    };
  }

  static Map<String, dynamic>? _permittedMood(Map<String, dynamic> permitted) {
    final mood = permitted['mood'];
    if (mood is! Map) return null;
    return {'mood': mood['value']};
  }

  /// Only used until a connection has been through the new sharing screen.
  static Map<String, dynamic>? _legacyMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Opens the Docsy tab, optionally with a question already asked.
  ///
  /// Home never answers anything itself. Her permitted context and the safety
  /// ruleset are assembled on the Docsy screen; a second answering surface
  /// would be a second place for either to be missed.
  void _openDocsy([String? question]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerSiaScreen(initialPrompt: question),
      ),
    );
  }

  /// Opens the sharing settings, where the per-signal request buttons live.
  ///
  /// He cannot grant himself anything there; every request goes to her to
  /// approve or refuse. That is the point — the alternative to an empty screen
  /// is asking, not taking.
  void _openSharingSettings() {
    final connectionId =
        (_activeConnection?['connectionId'] ?? _activeConnection?['_id'] ?? '').toString();
    if (connectionId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerPrivacyScreen(connectionId: connectionId),
      ),
    );
  }

  /// The "Us" surface (spec section 21): only what she has explicitly chosen
  /// to share, plus care requests.
  ///
  /// Nothing here queries her health records. The server assembles a
  /// permission-filtered view and this renders whatever survived that filter.
  Widget _buildUsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "US",
            style: GoogleFonts.manrope(height: 1.5, 
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BlushyColors.secondaryText,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          ApiStateCard<PartnerHomeModel>(
            result: _partnerHome,
            emptyMessage: "Nothing shared yet.",
            // "Nothing shared yet" was a dead end: he cannot share anything
            // himself, and nothing told him he could ask. Sending him to the
            // privacy screen puts him in front of the per-signal request
            // buttons, which is the only move available to him — and keeps her
            // in control, since each request is hers to approve or refuse.
            emptyActionLabel: "Ask what she'd like to share",
            onEmptyAction: _openSharingSettings,
            restrictedMessage: "This connection is no longer active.",
            builder: (context, home) {
              if (!home.relationshipActive) {
                return _usCard(
                  icon: Icons.link_off,
                  title: AppLocalizations.of(context).phConnectionEnded,
                  body: "You no longer have access to anything that was shared.",
                );
              }

              final populated = home.sharedSections.where((s) => s.enabled && s.items.isNotEmpty).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (home.supportRequests.isNotEmpty) ...[
                    ...home.supportRequests.map(_buildSupportRequestCard),
                    const SizedBox(height: 4),
                  ],
                  if (populated.isEmpty)
                    // A designed state, not an error: she has not shared
                    // anything, and the app says so plainly rather than
                    // implying something is missing.
                    _usCard(
                      icon: Icons.lock_outline,
                      title: AppLocalizations.of(context).phNothingSharedRightNow,
                      body: "She decides what to share, and can change it at any time. "
                          "You can still use Learn and Docsy for general support.",
                    )
                  else
                    ...populated.map(_buildSharedSectionCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _sharedSectionTitles = {
    'shared_insights': 'What Docsy noticed',
    'cycle_context': 'Cycle context',
    'fertility_context': 'Fertility context',
    'pregnancy_milestones': 'Pregnancy milestones',
    'postpartum_milestones': 'Recovery milestones',
    'appointments': 'Appointments',
    'care_requests': 'Care requests',
  };

  Widget _buildSharedSectionCard(SharedSection section) {
    final title = _sharedSectionTitles[section.key] ?? section.key.replaceAll('_', ' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BlushyColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: BlushyColors.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            ...section.items.map((item) {
              final text = _describeSharedItem(section.key, item);
              if (text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text,
                  style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.text, height: 1.45),
                ),
              );
            }),

            // A phase on its own is a label. What makes it useful is knowing
            // what to do with it, so the questions worth asking in this phase
            // sit directly under it -- the same three the Docsy tab offers,
            // from one list, so the two cannot drift.
            if (section.key == 'cycle_context' && section.items.isNotEmpty)
              _phasePrompts(section.items.first['phase']?.toString()),
          ],
        ),
      ),
    );
  }

  /// Questions worth asking in the phase she is actually in.
  ///
  /// Tapping one opens Docsy with it already asked, because the answer needs
  /// her permitted context and the safety ruleset, and both live there. This
  /// card only knows which question to put in front of him.
  Widget _phasePrompts(String? phase) {
    final questions = partnerPhaseQuestions(phase);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: BlushyColors.border),
          const SizedBox(height: 12),
          Text(
            'WORTH ASKING',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: BlushyColors.secondaryText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final question in questions)
                InkWell(
                  onTap: () => _openDocsy(question),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Text(
                      question,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders one shared item. Deliberately conservative: only fields the
  /// server chose to include are read, so an unexpected shape shows nothing
  /// rather than leaking a raw payload.
  String _describeSharedItem(String sectionKey, Map<String, dynamic> item) {
    switch (sectionKey) {
      case 'shared_insights':
        return item['description']?.toString() ?? item['title']?.toString() ?? '';
      case 'cycle_context':
        final phase = item['phase']?.toString();
        final day = item['cycleDay'];
        if (phase == null) return '';
        return day == null ? phase : '$phase (day $day)';
      case 'fertility_context':
        final start = item['start']?.toString();
        final end = item['end']?.toString();
        return (start == null || end == null) ? '' : 'Estimated fertile window: $start to $end';
      case 'pregnancy_milestones':
      case 'postpartum_milestones':
        return item['title']?.toString() ?? '';
      case 'appointments':
        final title = item['title']?.toString() ?? 'Appointment';
        final date = item['date']?.toString();
        return date == null ? title : '$title on $date';
      default:
        return item['text']?.toString() ?? item['title']?.toString() ?? '';
    }
  }

  /// A care request carries only the request itself - no cycle data, no
  /// symptoms, no life stage detail (spec section 11).
  Widget _buildSupportRequestCard(SupportRequest request) {
    final bool acknowledged = request.state == 'acknowledged';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.primary.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_outline, size: 16, color: BlushyColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.label ?? 'She asked for something',
                    style: GoogleFonts.manrope(height: 1.5, 
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.message,
              style: GoogleFonts.manrope(fontSize: 14, color: BlushyColors.text, height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!acknowledged)
                  TextButton(
                    onPressed: () => _updateSupportRequest(request, 'acknowledged'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    child: Text(
                      "I have seen this",
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.primary),
                    ),
                  ),
                if (!acknowledged) const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _updateSupportRequest(request, 'completed'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: Text(
                    "Done",
                    style: GoogleFonts.manrope(height: 1.5, 
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _usCard({required IconData icon, required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BlushyColors.secondaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(height: 1.5, 
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How long the two have been connected, or null when the payload does not
  /// say. Never guessed: a made-up "together for 184 days" is a claim about
  /// their relationship that the app has no basis for.
  int? _connectedSince(Object? raw) {
    final at = DateTime.tryParse(raw?.toString() ?? '');
    if (at == null) return null;
    final days = DateTime.now().difference(at).inDays;
    return days < 0 ? null : days;
  }

  /// Whether anything personal is actually reaching this screen.
  ///
  /// Read off what arrived rather than off the permission flags alone: a
  /// permission that is on but has nothing behind it is not sharing.
  bool _isSharingAnything(
    Map<String, dynamic> permitted,
    Map<String, dynamic>? cycleInfo,
    Map<String, dynamic>? moodData,
  ) {
    if (cycleInfo != null || moodData != null) return true;

    // Not `permitted.isNotEmpty`.
    //
    // `buildPartnerSafeContext` always returns `relationshipActive`,
    // `partnerPreferredName`, `lifeStage` and `relationshipType` -- the
    // non-private context that keeps the partner app useful when nothing is
    // shared. So the map was never empty, this was always true, and the
    // "nothing is being shared" state could not appear at all. Instead he got
    // a stage card, an empty tracker and a set of default actions, which
    // reads as though she is sharing when she is not.
    //
    // Only the keys that carry something of hers count.
    const personal = [
      'cyclePhase',
      'nextPeriodWindow',
      'fertileWindow',
      'pregnancyWeek',
      'pregnancyMilestone',
      'postpartumMilestone',
      'mood',
      'energyLevel',
      'sleep',
      'symptoms',
      'appointments',
      'generalInsights',
    ];
    return personal.any((key) {
      final value = permitted[key];
      if (value == null) return false;
      if (value is Iterable) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _activeConnection != null && _activeConnection!.isNotEmpty;
    final partnerUser = _sharedData?['partnerUser'];

    // Cycle and mood come from the permission-filtered context, which honours
    // the current 13-key matrix and migrates the older flags onto it. The
    // legacy shared-data endpoint reads the old flags directly, so once she
    // uses the new Partner Mode screen those keys no longer exist and its
    // cards silently blank out even though she is still sharing.
    final permitted = _partnerHome.data?.permittedContext ?? const <String, dynamic>{};

    // A successful filtered response with no cycle data means she has not
    // shared it, so the legacy value must not fill the gap. The old endpoint
    // is only consulted while the filtered view is unavailable.
    final bool filteredContextAvailable = _partnerHome.data != null &&
        (_partnerHome.isReady || _partnerHome.state == ApiState.empty);

    final Map<String, dynamic>? cycleInfo = filteredContextAvailable
        ? _permittedCycleInfo(permitted)
        : _legacyMap(_sharedData?['cycleInfo']);
    final Map<String, dynamic>? moodData = filteredContextAvailable
        ? _permittedMood(permitted)
        : _legacyMap(_sharedData?['mood']);

    final List<dynamic> suggestions = (_sharedData?['suggestions'] is List) ? _sharedData!['suggestions'] : [];

    // Partner display name
    String partnerName = "Her";
    if (isConnected) {
      // `partnerName` is what the server now sends; the rest stay as
      // fallbacks for a connection payload that predates it.
      partnerName = partnerDisplayName(
        Map<String, dynamic>.from(_activeConnection!),
        fallback: partnerUser?['display_name'] as String? ?? "Her",
      );
    }

    // Her stage, from the payloads that actually carry it.
    //
    // This read `partnerUser['lifeStage']`, which is not a field -- the stage
    // sits at the top level of the shared-data payload, behind her
    // `shareOnboarding` switch, and on `permittedContext` behind the same
    // permission filter as everything else. So it was null on every account
    // and fell back to "everydayWellness": a partner of someone in her third
    // trimester was shown an ordinary week.
    //
    // `PartnerStage.resolve` also settles the two spellings. The server
    // normalises stages to snake_case; `StageConfig` switches on camelCase.
    // Nothing translated, so even a stage that did arrive matched no case.
    final stage = PartnerStage.resolve(
      permittedContext: permitted,
      lifeStageContext: _partnerHome.data?.lifeStageContext,
      sharedData: _sharedData,
    );
    final stageToday = PartnerStageToday(
      stage: stage,
      permitted: permitted,
      partnerName: partnerName,
    );
    final connectedDateRaw = _activeConnection?['senderAcceptedAt'] ??
        _activeConnection?['receiverAcceptedAt'] ??
        _activeConnection?['createdAt'] ??
        _sharedData?['connectedAt'];


    // Dynamic list of support actions
    final List<Map<String, dynamic>> actionItems = [];
    if (suggestions.isNotEmpty) {
      for (int i = 0; i < suggestions.length && actionItems.length < 4; i++) {
        final s = suggestions[i];
        if (s is Map) {
          final String title = s['title']?.toString() ?? "Support Action";
          final String desc = s['description']?.toString() ?? s['text']?.toString() ?? "A thoughtful gesture for today.";
          final String id = s['id']?.toString() ?? "action_$i";
          final String? cat = s['category']?.toString();
          actionItems.add({'id': id, 'title': title, 'description': desc, 'category': cat});
        } else if (s is String && s.isNotEmpty) {
          actionItems.add({'id': 'action_$i', 'title': s, 'description': 'Thoughtful gesture for her today.', 'category': null});
        }
      }
    }

    if (actionItems.isEmpty) {
      actionItems.addAll([
        {'id': 'default_checkin', 'title': 'Check in with her', 'description': 'Send a gentle message or ask how her day is going.', 'category': 'Emotional Support'},
        {'id': 'default_take_plate', 'title': 'Take something off her plate', 'description': 'Handle chores like cleaning or meal prep.', 'category': 'Practical Help'},
        {'id': 'default_space', 'title': 'Give her some space', 'description': 'Support her by creating a peaceful, quiet environment.', 'category': 'Space'},
      ]);
    }


    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: BlushyColors.primary,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: RefreshIndicator(
                color: BlushyColors.primary,
                onRefresh: refreshQuietly,
                child: SingleChildScrollView(
                // Always scrollable, so the pull works on a short screen too.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: BlushyTheme.getPagePadding(context),
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // 01 -- who you are connected to, and the state of it.
              PartnerEditorialHeader(
                partnerName: isConnected ? partnerName : null,
                cycleInfo: cycleInfo,
                connectedSince: _connectedSince(connectedDateRaw),
                live: _partnerHome.isReady,
                eyebrow: stageToday.greetingEyebrow,
                verb: stageToday.greetingVerb,
                stageFacts: stageToday.greetingFacts,
              ),
              const SizedBox(height: 22),

              // 02 -- four signals, each one real or honestly empty.
              PartnerSignalRow(
                cycleInfo: cycleInfo,
                moodData: moodData,
                permitted: permitted,
                sharingActive: isConnected && _isSharingAnything(permitted, cycleInfo, moodData),
                // Stage-specific signals where her stage is known: a due date
                // and the next appointment say more in pregnancy than a cycle
                // day does. Null keeps the stage-agnostic four.
                badges: stage.isKnown ? stageToday.signalBadges : null,
              ),
              const SizedBox(height: 22),

              if (isConnected) ...[
                ConnectionSanctuary(
                  sharing: _isSharingAnything(permitted, cycleInfo, moodData),
                  onManage: _openSharingSettings,
                ),
                const SizedBox(height: 22),

                // Nothing personal is reaching him. Say so once, calmly, and
                // offer the things that still work -- rather than leaving him
                // to read a screen of empty cards and go looking for why.
                //
                // Deliberately the same whether she paused her sharing or
                // never turned it on: which of the two it is belongs to her.
                if (!_isSharingAnything(permitted, cycleInfo, moodData)) ...[
                  PrivateSpacePartnerState(
                    partnerName: partnerName,
                    onBloom: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PartnerSiaScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // What today may be like for her, hedged because a phase is
                  // a tendency across many people rather than a fact about
                  // one -- and a way to ask rather than assume.
                  if (stageToday.stageLeads)
                    PartnerStageCard(today: stageToday)
                  else
                    CycleHarmonyCard(
                      partnerName: partnerName,
                      cycleInfo: cycleInfo,
                      onAskDocsy: () => _openDocsy(),
                    ),
                  const SizedBox(height: 18),

                  // 03b -- her tracker, read-only. Draws nothing unless she
                  // shares a day, a pregnancy week or a recovery week.
                  PartnerCycleTracker(today: stageToday),
                  const SizedBox(height: 18),

                  // 04 -- what would actually help, from what she logged.
                  SupportActionsCard(
                    actions: actionItems,
                    completedIds: _completedActionIds.toSet(),
                    onToggle: _toggleActionCompletion,
                  ),
                  const SizedBox(height: 18),
                ],

                // 05 -- a way into Docsy with the stage already in mind.
                // Shown whether or not she is sharing: when she is not, the
                // general questions are the ones he needs most.
                PartnerDocsyPrompt(
                  today: stageToday,
                  onAsk: _openDocsy,
                ),
                const SizedBox(height: 24),
              ],

              // The greeting is the editorial header above. What was here
              // was a second one, in a different typeface, saying the same
              // thing; only the refresh it carried was worth keeping.
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: BlushyColors.primary),
                  tooltip: 'Refresh live data',
                  onPressed: _fetchLivePartnerData,
                ),
              ),
              _buildUsSection(),
              const SizedBox(height: 24),

                    // Help CTA
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showHelpOptionsDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: BlushyColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          "I want to help",
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'partner_sia_fab',
        backgroundColor: BlushyColors.dark,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PartnerSiaScreen(),
            ),
          );
        },
        label: DocsyWordmark(
          text: AppLocalizations.of(context).phDrDocsy,
          style: GoogleFonts.manrope(height: 1.5, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: const DocsyIcon(color: Colors.white, size: 18),
      ),
    );
  }

  // `_buildActionCard`, `_buildNoCycleSharedCard` and
  // `_buildHerLiveCycleCard` lived here. The first drew a second copy of
  // the support checklist that `SupportActionsCard` already draws; the
  // other two drew a phase card below the one `PartnerStageCard` and
  // `CycleHarmonyCard` draw above. Two of each, disagreeing in wording.
}
