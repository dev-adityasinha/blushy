import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../theme/colors.dart';
import '../../../services/api_blushy_service.dart';
import '../../../models/blushy_models.dart';
import 'partner_privacy_screen.dart';
import '../view_models/partner_profile_view_model.dart';
import '../../../shared/confirm_sign_out.dart';
import '../partner_display_name.dart';

class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  /// This screen is the View; the profile load lives in the tested
  /// PartnerProfileViewModel and is mirrored back by _onDataChanged.
  final PartnerProfileViewModel _vm = PartnerProfileViewModel();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _activeConnection;
  String _userEmail = '';
  String _userName = '';

  /// Real notification preferences. The switch used to be `value: true` with an
  /// empty `onChanged`, so it always read ON and could not be changed.
  NotificationPreferences? _notificationPrefs;
  bool _notificationsSaving = false;

  /// The categories this screen's switch governs. Partner-facing only: the
  /// safety category is `alwaysOn` server-side and is deliberately absent, so
  /// this control cannot silence a safety notice.
  static const List<String> _partnerNotificationCategories = [
    'partner_support_request',
    'partner_shared_update',
    'sia_proactive',
  ];

  bool get _notificationsEnabled {
    final prefs = _notificationPrefs;
    if (prefs == null) return false;
    return _partnerNotificationCategories.any((c) => prefs.categories[c] == true);
  }

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _loadProfileData();
  }

  /// Delegated to the view model; _onDataChanged mirrors the result.
  Future<void> _loadProfileData() => _vm.load();

  /// The View reacting to its ViewModel.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _userEmail = _vm.userEmail;
      _userName = _vm.userName;
      _nameController.text = _vm.userName;
      _notificationPrefs = _vm.notificationPrefs;
      _activeConnection = _vm.activeConnection;
      _isLoading = _vm.isLoading;
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Turns the partner-facing notification categories on or off together.
  ///
  /// Written through the real preferences endpoint, and the switch only moves
  /// once the server has confirmed -- an optimistic flip that silently failed
  /// would leave someone believing they had turned notifications off.
  Future<void> _setNotificationsEnabled(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _notificationsSaving = true);

    final patch = <String, bool>{
      for (final category in _partnerNotificationCategories) category: enabled,
    };

    final result = await NotificationsApi.updatePreferences({'categories': patch});
    if (!mounted) return;

    setState(() {
      _notificationsSaving = false;
      if (result.data != null) _notificationPrefs = result.data;
    });

    if (result.data == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not save that. Please try again.'),
        ),
      );
    }
  }

  /// Uses the shared confirmation so both sides of the app ask the same
  /// question. This screen had its own dialog and the main account screen had
  /// none, which is the kind of drift that produced the difference in the
  /// first place.
  Future<void> _handleLogout() async {
    if (!await confirmSignOut(context)) return;
    if (!mounted) return;

    final state = BlushyOSProvider.of(context);
    await state.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    String connectedPartnerName = "Not connected";
    if (_activeConnection != null) {
      connectedPartnerName = partnerDisplayName(
        Map<String, dynamic>.from(_activeConnection!),
        fallback: "Connected Partner",
      );
    }

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Partner Profile",
          style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BlushyColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: BlushyTheme.getPagePadding(context),
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar & Name Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: BlushyColors.primary.withValues(alpha: 0.12),
                          child: const Icon(Icons.person_rounded, size: 36, color: BlushyColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Text(
                                _userEmail,
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: BlushyColors.successSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Partner Mode • Supporting Her 💙",
                                  style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.w600, color: BlushyColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connection Status Card
                  Text(
                    "Connected Partner",
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                            color: BlushyColors.successSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.favorite_rounded, color: BlushyColors.success, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connectedPartnerName,
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Text(
                                _activeConnection != null ? "Active connection • Live data enabled" : "No partner paired yet",
                                style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferences & Support Settings
                  Text(
                    "App Preferences",
                    style: GoogleFonts.manrope(height: 1.5, fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: BlushyColors.primary),
                          title: Text('Push Notifications', style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('Get Docsy daily support alerts', style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText)),
                          trailing: _notificationsSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Switch(
                                  value: _notificationsEnabled,
                                  activeThumbColor: BlushyColors.primary,
                                  onChanged: _notificationPrefs == null
                                      ? null
                                      : _setNotificationsEnabled,
                                ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded, color: BlushyColors.primary),
                          title: Text('Privacy & Sharing', style: GoogleFonts.manrope(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('Learn how your shared data is protected', style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: BlushyColors.secondaryText),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PartnerPrivacyScreen(
                                  connectionId:
                                      _activeConnection?['connectionId']?.toString(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      label: Text(
                        "Sign Out",
                        style: GoogleFonts.manrope(height: 1.5, fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: BlushyColors.lutealSoft),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
