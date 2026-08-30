import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_preference.dart';
import '../features/home/widgets/my_health_screen.dart';
import '../core/theme.dart' hide BlushyColors;

import '../services/auth_storage.dart';
import '../features/partner/presentation/partner_profile_screen.dart';

class BlushyHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlushyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlushyColors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo section with back button if pop is possible
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ],
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Ada Hybrid',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'BLUSHY',
                          style: TextStyle(color: BlushyColors.primary),
                        ),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: BlushyColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Language selector & Profile button
              Row(
                children: [
                  // Language Selector
                  // Sets the language Sia replies in. This chip used to be a
                  // no-op showing a fixed "EN".
                  ValueListenableBuilder<String>(
                    valueListenable: LanguagePreference.current,
                    builder: (context, code, _) => GestureDetector(
                      onTap: () => _showLanguagePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: BlushyColors.border),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded, size: 14, color: BlushyColors.secondaryText),
                            const SizedBox(width: 4),
                            Text(
                              LanguagePreference.shortLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BlushyColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Profile Button
                  GestureDetector(
                    onTap: () {
                      final role = AuthStorage.getRole();
                      if (role == 'partner' || role == 'man') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PartnerProfileScreen()),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyHealthScreen()),
                        );
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: BlushyColors.border),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: BlushyColors.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}

/// Lets someone choose the language Sia replies in.
///
/// Only the languages the server actually has strings for are offered; adding
/// more would silently fall back to English and look broken.
void _showLanguagePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Sia speaks',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              // Says exactly what changes, so nobody expects the whole app to
              // switch language.
              'Changes the language Sia replies in. The rest of the app stays in English for now.',
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
            ),
          ),
          ...LanguagePreference.supported.entries.map(
            (entry) => ListTile(
              title: Text(entry.value, style: GoogleFonts.poppins(fontSize: 14)),
              trailing: LanguagePreference.code == entry.key
                  ? const Icon(Icons.check_rounded, color: BlushyColors.primary)
                  : null,
              onTap: () async {
                await LanguagePreference.set(entry.key);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
