import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../theme/colors.dart';
import '../view_models/partner_privacy_view_model.dart';

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
  /// This screen is the View; the branching load lives in the tested
  /// PartnerPrivacyViewModel and is mirrored back by _onDataChanged.
  late final PartnerPrivacyViewModel _vm =
      PartnerPrivacyViewModel(connectionId: widget.connectionId);

  bool _loading = true;
  String? _error;
  List<PartnerPermission> _matrix = const [];

  /// Permission keys with a request already waiting, and the ones being sent.
  /// Asking twice would only queue the same thing again for the other person.
  Set<String> _pendingRequests = <String>{};
  final Set<String> _sendingRequests = <String>{};

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _vm.removeListener(_onDataChanged);
    _vm.dispose();
    super.dispose();
  }

  /// Delegated to the view model; _onDataChanged mirrors the result.
  Future<void> _load() => _vm.load();

  /// The View reacting to its ViewModel.
  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _loading = _vm.loading;
      _error = _vm.error;
      _matrix = _vm.matrix;
      _pendingRequests = _vm.pendingRequests;
    });
  }

  /// A category counts as shared when the partner holds any of its grants.
  bool _isShared(PartnerPermission permission) => _vm.isShared(permission);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: BlushyColors.dark),
        title: Text(
          'Privacy & Sharing',
          style: GoogleFonts.manrope(height: 1.5, 
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
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),
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
                            style: GoogleFonts.manrope(fontSize: 12, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.primary),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'WHAT YOU RECEIVE',
                    style: GoogleFonts.manrope(height: 1.5, 
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
                      style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 12, color: BlushyColors.secondaryText),
                    )
                  else
                    ..._matrix.map(_buildRow),
                  const SizedBox(height: 24),
                  Text(
                    'Nothing here is a live feed of their records. Blushy only ever sends the '
                    'categories above, and never their journal, their messages with Docsy, or '
                    'anything they have not turned on.',
                    style: GoogleFonts.manrope(
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
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            shared ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 18,
            color: shared ? BlushyColors.success : BlushyColors.secondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.label,
                  style: GoogleFonts.manrope(height: 1.5, 
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
                  style: GoogleFonts.manrope(height: 1.5, 
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
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BlushyColors.success,
              ),
            )
          else if (permission.alwaysOn)
            Text(
              'Off',
              style: GoogleFonts.manrope(height: 1.5, 
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
              style: GoogleFonts.manrope(height: 1.5, 
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
                style: GoogleFonts.manrope(height: 1.5, 
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
