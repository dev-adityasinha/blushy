import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../core/theme.dart' hide BlushyColors;
import '../services/language_preference.dart';
import '../theme/colors.dart';
import '../theme/scale.dart';

/// Asks for a language once, before anything else the app shows.
///
/// The picker used to be a chip in the header, which meant a user who does not
/// read English had to find an English-labelled control on an English screen to
/// get out of English. Asking up front is the only ordering that works.
///
/// Shown only when [LanguagePreference.hasChosen] is false, so it appears on a
/// fresh install and never again -- Settings keeps the same control for later.
class LanguageGate extends StatefulWidget {
  const LanguageGate({super.key, required this.child});

  final Widget child;

  @override
  State<LanguageGate> createState() => _LanguageGateState();
}

class _LanguageGateState extends State<LanguageGate> {
  late bool _needsChoice = !LanguagePreference.hasChosen;

  @override
  Widget build(BuildContext context) {
    if (!_needsChoice) return widget.child;
    return LanguageChoiceScreen(
      onDone: () => setState(() => _needsChoice = false),
    );
  }
}

/// The picker itself.
///
/// Selecting applies immediately rather than on confirm: the title, subtitle
/// and button below are localised, so the screen redraws in the tapped
/// language and the choice proves itself before it is committed.
class LanguageChoiceScreen extends StatelessWidget {
  const LanguageChoiceScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const Map<String, String> _englishNames = {
    'en': 'English',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'kn': 'Kannada',
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final codes = LanguagePreference.supported.keys.toList();

    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const SizedBox(height: 28),
                // BLUSHY. Logo Wordmark
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: BlushyColors.primary,
                    ),
                    children: [
                      TextSpan(text: 'BLUSHY'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: BlushyColors.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        t.languageChoiceTitle,
                        textAlign: TextAlign.center,
                        style: BlushyType.headline().copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.languageChoiceSubtitle,
                        textAlign: TextAlign.center,
                        style: BlushyType.body().copyWith(
                          fontSize: 14,
                          height: 1.45,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: LanguagePreference.current,
                    builder: (context, selected, _) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: codes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final code = codes[index];
                        return _LanguageTile(
                          nativeName: LanguagePreference.labelFor(code),
                          englishName: _englishNames[code] ?? code,
                          selected: code == selected,
                          onTap: () => LanguagePreference.set(code),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        LanguagePreference.set(LanguagePreference.code);
                        onDone();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        t.languageChoiceContinue,
                        style: BlushyType.heading().copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.nativeName,
    required this.englishName,
    required this.selected,
    required this.onTap,
  });

  final String nativeName;
  final String englishName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFBEBEA)
            : BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? BlushyColors.primary : BlushyColors.border,
          width: selected ? 1.8 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: BlushyColors.primary.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nativeName,
                        style: BlushyType.heading().copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        englishName,
                        style: BlushyType.caption().copyWith(
                          fontSize: 13,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: BlushyColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
