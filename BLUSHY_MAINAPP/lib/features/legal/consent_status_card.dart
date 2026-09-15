import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_consent_service.dart';
import '../../theme/colors.dart';
import 'consent_gate.dart';
import 'legal_documents_screen.dart';

/// Shows what the user agreed to, when, and lets them take it back.
///
/// The privacy policy promises both halves of this: section 19 that a user can
/// see what we hold about them, and section 11 that consent given can be
/// withdrawn from within the app. Neither was true before -- the agreement was
/// never recorded, so there was nothing to show and nothing to withdraw.
///
/// Withdrawal is deliberately not deletion. Section 11 says so, and conflating
/// the two would mean a user who wanted us to stop relying on their consent
/// lost every entry they had ever made as a side effect.
class ConsentStatusCard extends StatefulWidget {
  const ConsentStatusCard({super.key});

  @override
  State<ConsentStatusCard> createState() => _ConsentStatusCardState();
}

class _ConsentStatusCardState extends State<ConsentStatusCard> {
  final ApiConsentService _service = ApiConsentService();

  ConsentStatus? _status;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _service.fetchStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw your consent?'),
        content: const Text(
          'Blushy cannot track your cycle, log your symptoms or answer your questions without '
          'processing your health data, so those features will stop working until you agree again.\n\n'
          'Withdrawing does not delete anything. Your entries stay on your account, and you can agree '
          'again at any time. If you want your data removed as well, use Delete Account Permanently '
          'instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: BlushyColors.danger),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    final ok = await _service.withdraw(reason: 'withdrawn_from_settings');
    if (!mounted) return;
    setState(() => _working = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not withdraw just now. Please check your connection and try again.')),
      );
      return;
    }

    // Straight to the consent screen rather than leaving them inside an app
    // whose consent they have just withdrawn. Agreeing again returns them
    // here; signing out takes them out. The route cannot be dismissed, because
    // dismissing it would put them back where they should no longer be.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => PopScope(
          canPop: false,
          child: ConsentScreen(
            reason: ConsentReason.withdrawn,
            onAccepted: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    final String body;
    if (_loading) {
      body = 'Checking…';
    } else if (status == null) {
      // Unknown, not "none". Saying "you have not consented" because a request
      // failed would be a false statement about a legal record.
      body = 'We could not reach your account to check this just now.';
    } else if (status.hasConsent && status.grantedAt != null) {
      body = 'You agreed to our Privacy Policy, Terms of Service and Medical Disclaimer '
          'on ${_formatDate(status.grantedAt!)}. This is the record we keep of that.';
    } else if (status.reason == ConsentReason.withdrawn) {
      body = 'You withdrew your consent. Blushy is not relying on it, and the health features '
          'stay switched off until you agree again. Nothing has been deleted.';
    } else if (status.reason == ConsentReason.documentsUpdated) {
      body = 'Our policies have changed since you last agreed. Blushy will ask you to read '
          'and agree to the current version.';
    } else {
      body = 'We do not yet have a record of your agreement. Blushy will ask you for it.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            'Your consent',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: BlushyColors.text,
            ),
          ),
        ),
        Text(
          body,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            height: 1.45,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 4,
          children: [
            _link(
              'Read the documents',
              () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
            ),
            if (status != null && status.hasConsent)
              _link(
                _working ? 'Withdrawing…' : 'Withdraw consent',
                _working ? null : _withdraw,
                danger: true,
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _link(String label, VoidCallback? onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: onTap == null
              ? BlushyColors.disabled
              : (danger ? BlushyColors.danger : BlushyColors.primary),
        ),
      ),
    );
  }
}
