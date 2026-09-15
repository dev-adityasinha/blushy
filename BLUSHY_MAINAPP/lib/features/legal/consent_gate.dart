import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/state.dart';
import '../../services/api_consent_service.dart';
import '../../theme/colors.dart';
import 'legal_documents_screen.dart';

/// Stands between a signed-in user and the app, and asks for consent again
/// when the recorded consent no longer covers what the app is doing.
///
/// Three cases reach here: an account created before consent was ever
/// recorded, an account whose owner withdrew consent, and an account whose
/// recorded consent names an older version of a document than the one now in
/// force. Section 26 of the privacy policy promises the last of those -- that
/// a material change is put to the user rather than assumed to be covered by
/// an agreement they gave to different words.
///
/// **This gate fails open, deliberately.** It blocks only on a definite answer
/// from the server saying consent is needed. A timeout, an error, an expired
/// session or an unparseable response all mean "unknown", and unknown lets the
/// user through. Locking someone out of their own health data because their
/// connection dropped would be a far worse failure than asking for consent one
/// launch later than ideal.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.child, this.checkStatus});

  final Widget child;

  /// How the gate finds out where it stands. Injectable so that the fail-open
  /// rule -- by far the riskiest behaviour here, since getting it wrong locks
  /// every user out of their own health data -- can be tested without a server.
  final Future<ConsentStatus?> Function()? checkStatus;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  /// Null until the server has answered, and null again whenever it could not.
  ConsentStatus? _status;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    ConsentStatus? status;
    try {
      final check = widget.checkStatus ?? ApiConsentService().fetchStatus;
      status = await check();
    } catch (e) {
      // Belt and braces. The service already swallows its own failures, but a
      // throw escaping here would leave the gate stuck on its initial state
      // forever, which for a widget that can hide the entire app is not a risk
      // worth carrying for the sake of one try block.
      debugPrint('BlushyConsent: gate check failed, letting the user through: $e');
      status = null;
    }
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    // Unknown, or known to be fine: carry on. The child renders immediately on
    // the first frame rather than waiting behind a spinner, because the common
    // case by far is that consent is in order.
    if (status == null || !status.needsConsent) {
      return widget.child;
    }

    return ConsentScreen(
      reason: status.reason ?? ConsentReason.unknown,
      onAccepted: () => setState(() => _status = null),
    );
  }
}

/// Asks for consent to the documents this build ships.
///
/// Used by the gate. The onboarding wizard asks the same question in its own
/// styling as part of its first step, so this exists for everyone who is
/// already past onboarding.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.reason,
    required this.onAccepted,
  });

  final ConsentReason reason;

  /// Called once the acceptance has been recorded by the server.
  final VoidCallback onAccepted;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _privacy = false;
  bool _terms = false;
  bool _disclaimer = false;
  bool _submitting = false;
  String? _error;

  bool get _all => _privacy && _terms && _disclaimer;

  String get _headline {
    switch (widget.reason) {
      case ConsentReason.documentsUpdated:
        return 'We have updated our policies';
      case ConsentReason.withdrawn:
        return 'You withdrew your consent';
      case ConsentReason.neverGiven:
      case ConsentReason.unknown:
        return 'One thing before you continue';
    }
  }

  String get _explanation {
    switch (widget.reason) {
      case ConsentReason.documentsUpdated:
        return 'Our privacy policy, terms or medical disclaimer have changed since you last agreed to '
            'them. Rather than assume your earlier agreement covers the new wording, we would like you '
            'to read and agree again.';
      case ConsentReason.withdrawn:
        return 'Blushy cannot track your cycle, log your symptoms or answer your questions without '
            'processing your health data, and you asked us to stop relying on your consent to do that. '
            'To use Blushy again, please agree below. Nothing you logged has been deleted.';
      case ConsentReason.neverGiven:
      case ConsentReason.unknown:
        return 'Blushy holds health information about you, which the law treats as especially '
            'sensitive. We now keep a record of what you agreed to and when, so please read these and '
            'confirm.';
    }
  }

  Future<void> _submit() async {
    if (!_all || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ApiConsentService().accept(method: 're_consent');
    if (!mounted) return;

    if (result.succeeded) {
      widget.onAccepted();
      return;
    }

    setState(() {
      _submitting = false;
      _error = result.failure == ConsentFailure.appOutOfDate
          ? (result.message ??
              'These documents have changed again since this version of the app was released. '
                  'Please update Blushy so you can read the current version.')
          : 'We could not record your agreement just now. Please check your connection and try again.';
    });
  }

  /// Goes through the app's own logout rather than clearing the token
  /// directly: that is what disconnects the partner socket, clears the cached
  /// dashboard and per-user storage, and -- the part that matters here --
  /// notifies the router, so the app actually returns to the sign-in screen.
  Future<void> _signOut() async {
    await BlushyOSProvider.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 30, color: BlushyColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _headline,
                    style: GoogleFonts.manrope(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _explanation,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      height: 1.5,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _ConsentCheck(
                    label: 'Privacy Policy',
                    checked: _privacy,
                    onChanged: (v) => setState(() => _privacy = v),
                    onOpen: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                  ),
                  _ConsentCheck(
                    label: 'Terms of Service',
                    checked: _terms,
                    onChanged: (v) => setState(() => _terms = v),
                    onOpen: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                  ),
                  _ConsentCheck(
                    label: 'Medical Disclaimer',
                    checked: _disclaimer,
                    onChanged: (v) => setState(() => _disclaimer = v),
                    onOpen: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.medicalDisclaimer),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        height: 1.45,
                        color: const Color(0xFFC0392B),
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_all && !_submitting) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        disabledBackgroundColor: const Color(0xFFEFE9E4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Agree & Continue',
                              style: GoogleFonts.manrope(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: _all ? Colors.white : const Color(0xFFAFA59E),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _submitting ? null : _signOut,
                      child: Text(
                        'Sign out instead',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tick box with the document name as the thing you tap to read it.
class _ConsentCheck extends StatelessWidget {
  const _ConsentCheck({
    required this.label,
    required this.checked,
    required this.onChanged,
    required this.onOpen,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            key: ValueKey('consent-tick-$label'),
            onTap: () => onChanged(!checked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? BlushyColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? BlushyColors.primary : BlushyColors.border,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'I agree to the ',
                  style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.secondaryText),
                ),
                GestureDetector(
                  onTap: onOpen,
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: BlushyColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: BlushyColors.primary,
                    ),
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
