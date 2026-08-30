import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../services/auth_storage.dart';
import '../../../core/stage_config.dart';
import 'partner_sia.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/api_partner_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../models/blushy_models.dart';
import '../../../shared/api_state_card.dart';

class PartnerHomeScreen extends StatefulWidget {
  const PartnerHomeScreen({super.key});

  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadLocalCompletedActions();
    _fetchLivePartnerData();
  }

  void _loadLocalCompletedActions() {
    try {
      final saved = BlushyStorage.read('partner_completed_actions_${_getTodayDateKey()}');
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
      BlushyStorage.write('partner_completed_actions_${_getTodayDateKey()}', {
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
            BlushyStorage.write('partner_completed_actions_${_getTodayDateKey()}', {
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
              final backendIds = List<String>.from(shared['completedActionIds'].map((e) => e.toString()));
              _completedActionIds.addAll(backendIds);
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
  ];

  static const List<Map<String, String>> _defaultWomanNeeds = [
    {
      "label": "She needs rest",
      "tip": "Sia recommends: Cancel non-essential tasks, dim the lights, and handle dinner tonight."
    },
    {
      "label": "She needs comfort",
      "tip": "Sia recommends: Bring a warm heat pack, brew her favorite tea, or offer a back rub."
    },
    {
      "label": "She needs practical help",
      "tip": "Sia recommends: Check the laundry, wash dishes, or ask: 'Which chore can I handle for you right now?'"
    },
    {
      "label": "She wants company",
      "tip": "Sia recommends: Put away phones, suggest a relaxed walk, or watch a movie together."
    },
    {
      "label": "She wants space",
      "tip": "Sia recommends: Give her quiet time. Say: 'I am here in the other room if you need anything.'"
    },
    {
      "label": "I don't know what she needs",
      "tip": "Sia recommends: Ask gently: 'Are you looking for comfort, help, or space right now?'"
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
      backgroundColor: const Color(0xFFFAF6F0),
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

                // Case 1: Dynamic Needs exist and hasNeeds is true
                if (hasNeeds && customNeedsList.isNotEmpty) ...[
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
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE8DFD8)),
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
                ]
                // Case 2: hasNeeds is false (She doesn't need anything right now)
                else if (hasDynamicData && !hasNeeds) ...[
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
                ]
                // Case 3: Fallback (unconnected or loading)
                else ...[
                  Text(
                    "Here are general ways to support your partner today:",
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: (isUserWoman ? _defaultManNeeds : _defaultWomanNeeds).map((need) {
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
            style: GoogleFonts.poppins(
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
            restrictedMessage: "This connection is no longer active.",
            builder: (context, home) {
              if (!home.relationshipActive) {
                return _usCard(
                  icon: Icons.link_off,
                  title: "Connection ended",
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
                      title: "Nothing shared right now",
                      body: "She decides what to share, and can change it at any time. "
                          "You can still use Learn and Sia for general support.",
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
    'shared_insights': 'What Sia noticed',
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.text, height: 1.45),
                ),
              );
            }),
          ],
        ),
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
          color: const Color(0xFFFDF6F0),
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
                    style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontSize: 14, color: BlushyColors.text, height: 1.45),
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
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary),
                    ),
                  ),
                if (!acknowledged) const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _updateSupportRequest(request, 'completed'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: Text(
                    "Done",
                    style: GoogleFonts.poppins(
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 0.8),
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
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: BlushyColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      partnerName = _activeConnection!['partner']?['displayName'] ??
          _activeConnection!['partnerEmail'] ??
          (partnerUser?['display_name'] ?? partnerUser?['email'] ?? "Her");
      if (partnerName.contains('@')) {
        partnerName = partnerName.split('@').first;
      }
    }

    String activeStage = partnerUser?['lifeStage'] ?? "everydayWellness";
    final stageDetails = StageConfig.forStage(activeStage);
    final connectedDateRaw = _activeConnection?['senderAcceptedAt'] ??
        _activeConnection?['receiverAcceptedAt'] ??
        _activeConnection?['createdAt'] ??
        _sharedData?['connectedAt'];

    // Dynamic headline for "Sia noticed something"
    String siaHeadline = isConnected
        ? "Tending to your relationship garden builds healthy, quiet mutual support."
        : "Connect with your partner to see her live cycle and wellness insights.";
    String siaSubtext = isConnected
        ? "Insights will update live as she logs her day."
        : "Send an invite or ask her for her partner code.";

    if (cycleInfo != null && cycleInfo['phase'] != null) {
      final phase = cycleInfo['phase'];
      final day = cycleInfo['currentCycleDay'];
      if (day != null) {
        siaHeadline = "$partnerName is on Day $day ($phase Phase).";
      } else {
        siaHeadline = "$partnerName is in her $phase Phase.";
      }
      if (moodData != null && moodData['mood'] != null) {
        siaSubtext = "She recently logged feeling ${moodData['mood']}.";
      } else {
        siaSubtext = "Live cycle tracking shared with you.";
      }
    } else if (suggestions.isNotEmpty && suggestions.first is Map) {
      siaHeadline = suggestions.first['title']?.toString() ?? siaHeadline;
      siaSubtext = suggestions.first['description']?.toString() ?? siaSubtext;
    }

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

    final int completedCount = actionItems.where((a) => _completedActionIds.contains(a['id'])).length;
    final bool isAllCompleted = actionItems.isNotEmpty && completedCount == actionItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
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
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: BlushyTheme.getPagePadding(context),
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Greeting Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? "Good morning, partner" : "Partner Dashboard",
                        style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? "Connected with $partnerName • Live insights enabled"
                            : "Here's how you can show up and support today.",
                        style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: BlushyColors.primary),
                    tooltip: 'Refresh live data',
                    onPressed: _fetchLivePartnerData,
                  ),
                ],
              ),
              _buildUsSection(),
              const SizedBox(height: 24),

              // Sia Noticed (Live Permissions-dependent UI)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FAF6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD6F1DF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: BlushyColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Sia noticed something",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: BlushyColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      siaHeadline,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      siaSubtext,
                      style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showHelpOptionsDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "See how I can help",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Her Live Health & Cycle Status Card
              _buildHerLiveCycleCard(partnerName, cycleInfo, moodData),
              const SizedBox(height: 24),

              // Today's Support Checklists Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Support Actions",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  if (actionItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAllCompleted
                            ? const Color(0xFFE8F5E9)
                            : BlushyColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAllCompleted
                            ? "All Done 🎉"
                            : "$completedCount/${actionItems.length} Done",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAllCompleted
                              ? const Color(0xFF2E7D32)
                              : BlushyColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

                    // Celebration banner when all completed
                    if (isAllCompleted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "All Today's Actions Completed! 🌸",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  Text(
                                    "You showed up for her today. Tending to your relationship garden keeps love strong.",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Action checklist cards
                    for (var action in actionItems)
                      _buildActionCard(
                        actionId: action['id'].toString(),
                        title: action['title'].toString(),
                        description: action['description'].toString(),
                        category: action['category']?.toString(),
                      ),

                    const SizedBox(height: 24),

                    // Help CTA
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showHelpOptionsDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: BlushyColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          "I want to help",
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // A Little Context
                    Text(
                      "Understanding Her Stage",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACTIVE STAGE: ${stageDetails.formatPartnerSubLabel(connectedDateRaw).toUpperCase()}",
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: BlushyColors.primary, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Supporting her through ${stageDetails.displayName}",
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stageDetails.gardenQuote.isNotEmpty
                                ? stageDetails.gardenQuote
                                : "Understanding her cycle rhythms helps foster deeper mutual empathy and harmony.",
                            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
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
        label: Text(
          'Sia',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildActionCard({
    required String actionId,
    required String title,
    required String description,
    String? category,
  }) {
    final bool isCompleted = _completedActionIds.contains(actionId);

    return InkWell(
      onTap: () => _toggleActionCompletion(actionId),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFF1F8F4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? const Color(0xFFC8E6C9) : BlushyColors.border,
            width: isCompleted ? 1.5 : 1.0,
          ),
          boxShadow: isCompleted
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(
                isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: isCompleted ? const Color(0xFF2E7D32) : BlushyColors.secondaryText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? const Color(0xFF2E7D32) : BlushyColors.text,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            decorationColor: const Color(0xFF2E7D32),
                            decorationThickness: 2.0,
                          ),
                        ),
                      ),
                      if (category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFE8F5E9)
                                : BlushyColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? const Color(0xFF2E7D32) : BlushyColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isCompleted ? Colors.grey.shade500 : BlushyColors.secondaryText,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey.shade400,
                      decorationThickness: 1.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when the partner has not shared cycle data, or has logged none.
  ///
  /// Any mood they did share is still shown -- permissions are per signal, so
  /// having no cycle access does not mean having no access at all.
  Widget _buildNoCycleSharedCard(String partnerName, Map<String, dynamic>? moodData) {
    final String? mood = moodData?['mood']?.toString() ?? moodData?['notes']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BlushyColors.secondaryText.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: BlushyColors.secondaryText, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$partnerName's Cycle & Mood",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text,
                      ),
                    ),
                    Text(
                      'Not shared with you',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mood != null && mood.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Mood shared today: $mood',
                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'They choose what to share, and can change it at any time.',
            style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildHerLiveCycleCard(String partnerName, Map<String, dynamic>? cycleInfo, Map<String, dynamic>? moodData) {
    // With nothing shared this used to default to "Follicular" and tell the
    // partner "Estrogen is rising. Her focus and mood are high." -- stated as
    // fact about a real person who had shared nothing. Say so instead.
    final String? knownPhase = cycleInfo?['phase']?.toString();
    if (knownPhase == null || knownPhase.trim().isEmpty) {
      return _buildNoCycleSharedCard(partnerName, moodData);
    }
    final String phase = knownPhase;
    final dynamic rawDay = cycleInfo?['currentCycleDay'];
    final int? cycleDay = (rawDay is int) ? rawDay : int.tryParse(rawDay?.toString() ?? '');
    final String? mood = moodData?['mood']?.toString() ?? moodData?['notes']?.toString();

    Color phaseColor = const Color(0xFFE8A0B4);
    IconData phaseIcon = Icons.spa_rounded;
    String phaseDescription = "Her natural energy and creativity are building up. Great time for shared plans and active dates together.";
    String phaseEmoji = "🌿";

    switch (phase.toLowerCase()) {
      case 'menstrual':
        phaseColor = const Color(0xFFDD0D22);
        phaseIcon = Icons.water_drop_rounded;
        phaseEmoji = "🩸";
        phaseDescription = "Energy is lower. She may experience fatigue or cramps. Offer warmth, rest, and handle dinner tonight.";
        break;
      case 'follicular':
        phaseColor = const Color(0xFF10B981);
        phaseIcon = Icons.nature_rounded;
        phaseEmoji = "🌱";
        phaseDescription = "Estrogen is rising. Her focus and mood are high. Great time to try new activities together.";
        break;
      case 'ovulation':
      case 'fertile':
        phaseColor = const Color(0xFFF59E0B);
        phaseIcon = Icons.wb_sunny_rounded;
        phaseEmoji = "✨";
        phaseDescription = "Peak energy and social confidence. Perfect for meaningful dates, deep conversations, and quality time.";
        break;
      case 'luteal':
      case 'pms':
        phaseColor = const Color(0xFF8B5CF6);
        phaseIcon = Icons.nightlight_round;
        phaseEmoji = "🌙";
        phaseDescription = "Progesterone is high. She might feel sensitive, tired, or crave quiet. Extra patience and reassurance are key.";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BlushyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(phaseIcon, color: phaseColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$partnerName's Cycle & Mood",
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                      ),
                      Text(
                        cycleDay != null ? "Day $cycleDay • $phase Phase $phaseEmoji" : "$phase Phase $phaseEmoji",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: phaseColor),
                      ),
                    ],
                  ),
                ],
              ),
              if (mood != null && mood.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text("Mood: ", style: TextStyle(fontSize: 10, color: BlushyColors.secondaryText)),
                      Text(mood, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: phaseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    phaseDescription,
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
