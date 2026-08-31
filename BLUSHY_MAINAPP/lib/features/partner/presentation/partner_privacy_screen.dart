import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../theme/colors.dart';

/// What this partner currently receives, and what they do not.
///
/// This replaced a dialog that asserted "Your partner retains complete control
/// over what cycle, mood, and health updates are shared with your device" and
/// then showed nothing. A claim about a permission system is only worth making
/// next to the permissions themselves.
///
/// The sharing panel itself is deliberately not readable here: the server
/// returns 403 to anyone who is not the person sharing, so this screen is built
/// from the grants the partner is actually allowed to see, which is exactly
/// what they receive.
class PartnerPrivacyScreen extends StatefulWidget {
  const PartnerPrivacyScreen({super.key, required this.connectionId});

  final String? connectionId;

  @override
  State<PartnerPrivacyScreen> createState() => _PartnerPrivacyScreenState();
}

class _PartnerPrivacyScreenState extends State<PartnerPrivacyScreen> {
  bool _loading = true;
  String? _error;
  List<PartnerPermission> _matrix = const [];
  Set<String> _allowedGrants = const {};

  /// Permission keys with a request already waiting, and the ones being sent.
  /// Asking twice would only queue the same thing again for the other person.
  Set<String> _pendingRequests = <String>{};
  final Set<String> _sendingRequests = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final matrixResult = await PartnerApi.permissionMatrix();
    if (!mounted) return;

    if (matrixResult.data == null) {
      setState(() {
        _loading = false;
        _error = matrixResult.errorMessage ?? 'Could not load the sharing categories.';
      });
      return;
    }

    final connectionId = widget.connectionId;
    if (connectionId == null || connectionId.isEmpty) {
      setState(() {
        _matrix = matrixResult.data!;
        _allowedGrants = const {};
        _loading = false;
      });
      return;
    }

    // The grants come back in the response envelope rather than the body: the
    // context itself is the filtered data, and `permissions` says why.
    final contextResult = await PartnerApi.context(connectionId);
    if (!mounted) return;

    final granted = <String>{};
    final permissions = contextResult.permissions;
    if (permissions != null && permissions['allowedGrants'] is List) {
      for (final grant in permissions['allowedGrants'] as List) {
        granted.add(grant.toString());
      }
    }

    final requests = await PartnerApi.permissionRequests(connectionId, states: 'pending');
    if (!mounted) return;

    setState(() {
      _matrix = matrixResult.data!;
      _allowedGrants = granted;
      _pendingRequests = {
        for (final request in requests.data ?? const <Map<String, dynamic>>[])
          request['permissionKey']?.toString() ?? '',
      }..removeWhere((key) => key.isEmpty);
      _loading = false;
      if (contextResult.state == ApiState.offline || contextResult.state == ApiState.error) {
        _error = 'Showing categories only. Could not reach the server for what is currently shared.';
      }
    });
  }

  /// A category counts as shared when the partner holds any of its grants.
  ///
  /// The grants come from the matrix endpoint rather than a table kept here.
  /// A local copy drifts silently: when a category's grants change server-side,
  /// it would simply start reporting itself as not shared.
  bool _isShared(PartnerPermission permission) {
    if (permission.grants.isEmpty) return permission.enabled;
    return permission.grants.any(_allowedGrants.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: BlushyColors.dark),
        title: Text(
          'Privacy & Sharing',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: BlushyColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your partner decides what reaches this device, one category at a '
                            'time. They can change it whenever they like, and a change takes '
                            'effect on your very next request.',
                            style: GoogleFonts.poppins(fontSize: 12, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'WHAT YOU RECEIVE',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_matrix.isEmpty)
                    Text(
                      'No sharing categories available.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: BlushyColors.secondaryText),
                    )
                  else
                    ..._matrix.map(_buildRow),
                  const SizedBox(height: 24),
                  Text(
                    'Nothing here is a live feed of their records. Blushy only ever sends the '
                    'categories above, and never their journal, their messages with Dr. Docsy, or '
                    'anything they have not turned on.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      height: 1.5,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Asks the person sharing to turn one category on.
  ///
  /// This never changes what is shared: it records the ask and notifies them.
  Future<void> _requestPermission(PartnerPermission permission) async {
    final connectionId = widget.connectionId;
    if (connectionId == null || connectionId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingRequests.add(permission.key));

    final result = await PartnerApi.requestPermission(connectionId, permission.key);
    if (!mounted) return;

    setState(() {
      _sendingRequests.remove(permission.key);
      if (result.data != null) _pendingRequests.add(permission.key);
    });

    if (result.data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Could not send that request.')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.data!['alreadyPending'] == true
              // Saying so is kinder than a second silent no-op.
              ? 'You have already asked for this. They have not answered yet.'
              : 'Asked. It is their choice, and they can say no.',
        ),
      ),
    );
  }

  Widget _buildRow(PartnerPermission permission) {
    final shared = _isShared(permission);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            shared ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 18,
            color: shared ? const Color(0xFF10B981) : BlushyColors.secondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BlushyColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // The example is what this category would look like when on,
                  // which explains the setting better than the label alone.
                  shared
                      ? (permission.example ?? 'Shared with you.')
                      : 'Not shared with you.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (shared)
            Text(
              'On',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            )
          else if (permission.alwaysOn)
            Text(
              'Off',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BlushyColors.secondaryText,
              ),
            )
          else if (_sendingRequests.contains(permission.key))
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_pendingRequests.contains(permission.key))
            Text(
              'Asked',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BlushyColors.secondaryText,
              ),
            )
          else
            TextButton(
              onPressed: () => _requestPermission(permission),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Ask',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
