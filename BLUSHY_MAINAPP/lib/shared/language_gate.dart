import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../core/theme.dart' hide BlushyColors;
import '../services/language_preference.dart';
import '../theme/colors.dart';

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

  /// The English name beside each native one. A user who has the app in a
  /// language they did not intend needs to find their way back out, and the
  /// script they can read may not be the script the row is written in.
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
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // The wordmark stays in Latin script in every language: it is
                // the product's name, not a translatable string.
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Ada Hybrid',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
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
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        t.languageChoiceTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.languageChoiceSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: BlushyColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: LanguagePreference.current,
                    builder: (context, selected, _) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: codes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // English is the default, so a user who wants English
                        // may never tap a row. Confirming is what records the
                        // choice, and it is what stops the screen returning.
                        LanguagePreference.set(LanguagePreference.code);
                        onDone();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BlushyTheme.radius),
                        ),
                      ),
                      child: Text(
                        t.languageChoiceContinue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    return Material(
      color: selected ? BlushyColors.primary.withValues(alpha: 0.06) : BlushyColors.cardBg,
      borderRadius: BorderRadius.circular(BlushyTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BlushyTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BlushyTheme.radius),
            border: Border.all(
              color: selected ? BlushyColors.primary : BlushyColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      englishName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: BlushyColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
