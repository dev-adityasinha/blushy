import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../../theme/colors.dart';
import '../../../services/auth_storage.dart';
import '../../../services/api_partner_service.dart';

class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final ApiPartnerService _partnerService = ApiPartnerService();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _activeConnection;
  String _userEmail = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final session = AuthStorage.getSession();
      _userEmail = session['email']?.toString() ?? 'partner@blushy.life';
      _userName = _userEmail.contains('@') ? _userEmail.split('@').first : 'Partner';
      _nameController.text = _userName;

      final connections = await _partnerService.getConnections();
      final active = connections.firstWhere(
        (c) => c['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );

      if (mounted) {
        setState(() {
          _activeConnection = active.isNotEmpty ? active : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out of your partner account?', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: BlushyColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final state = BlushyOSProvider.of(context);
              await state.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BlushyColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String connectedPartnerName = "Not connected";
    if (_activeConnection != null) {
      connectedPartnerName = _activeConnection!['partner']?['displayName'] ??
          _activeConnection!['partnerEmail'] ??
          "Connected Partner";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Partner Profile",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Text(
                                _userEmail,
                                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Partner Mode • Supporting Her 💙",
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
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
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3FAF6),
                            borderRadius: BorderRadius.circular(14),
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
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: BlushyColors.text),
                              ),
                              Text(
                                _activeConnection != null ? "Active connection • Live data enabled" : "No partner paired yet",
                                style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: BlushyColors.primary),
                          title: Text('Push Notifications', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('Get Sia daily support alerts', style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
                          trailing: Switch(
                            value: true,
                            activeColor: BlushyColors.primary,
                            onChanged: (val) {},
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded, color: BlushyColors.primary),
                          title: Text('Privacy & Sharing', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('Learn how your shared data is protected', style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: BlushyColors.secondaryText),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Privacy & Protection', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                content: Text(
                                  'Your partner retains complete control over what cycle, mood, and health updates are shared with your device. Insights update only when permitted.',
                                  style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Understood', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
                                  ),
                                ],
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
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
