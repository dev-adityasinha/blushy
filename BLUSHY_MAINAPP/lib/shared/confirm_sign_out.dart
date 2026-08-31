import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/colors.dart';
import '../l10n/app_localizations.dart';

/// Asks before signing out, and returns whether the person meant it.
///
/// The partner profile screen already asked; the main account screen did not,
/// so the same action was guarded on one side of the app and instant on the
/// other. Signing out is not destructive, but it does end the session and drop
/// the user back to the login screen with no way back except their password —
/// an easy tap to make by accident on a screen that also holds "clear symptom
/// logs".
///
/// Shared rather than copied so the two sides cannot drift apart again.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppLocalizations.of(context).csoSignOut,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'You will need your password to sign back in. Anything you have logged '
        'stays on your account.',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            AppLocalizations.of(context).csoCancel,
            style: GoogleFonts.poppins(color: BlushyColors.secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: BlushyColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            AppLocalizations.of(context).csoSignOut,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  // Dismissing by tapping outside means no.
  return confirmed ?? false;
}
