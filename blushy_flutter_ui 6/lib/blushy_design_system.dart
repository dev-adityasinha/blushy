import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BDColors {
  static const cream = Color(0xFFFAF6F0);
  static const white = Colors.white;
  static const ink = Color(0xFF1A0F0A);
  static const inkLight = Color(0xFF6B6562);
  static const red = Color(0xFFE31C25);
  static const orange = Color(0xFFFF4A00);
  static const pinkBg = Color(0xFFFFF0F5);
  static const divider = Color(0x151A0F0A);
}



class BlushyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  const BlushyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = BDColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BDColors.ink.withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class BlushyChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const BlushyChip({
    super.key,
    required this.text,
    this.color = BDColors.pinkBg,
    this.textColor = BDColors.red,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(text, style: GoogleFonts.inter(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class LanguageNotifier {
  static final ValueNotifier<String> activeLanguage = ValueNotifier<String>('English');
}

class BlushyTopBar extends StatelessWidget {
  final VoidCallback? onTapLanguage;
  const BlushyTopBar({super.key, this.onTapLanguage});

  static final List<Map<String, String>> langList = [
    {'code': 'English', 'native': 'English'},
    {'code': '\u0939\u093f\u0928\u094d\u0926\u0940', 'native': '\u0939\u093f\u0928\u094d\u0926\u0940 (Hindi)'},
    {'code': '\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41', 'native': '\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 (Telugu)'},
    {'code': '\u0b24\u0b2e\u0b3f\u0b34\u0b4d', 'native': '\u0b24\u0b2e\u0b3f\u0b34\u0b4d (Tamil)'},
    {'code': '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1', 'native': '\u0c95\u0ca8\u0ccd\u0ca8\u0ca1 (Kannada)'},
    {'code': '\u0d2e\u0d3abs\u0d4d', 'native': '\u0d2e\u0d3abs\u0d4d (Malayalam)'},
    {'code': '\u092e\u0930\u093e\u0920\u0940', 'native': '\u092e\u0930\u093e\u0920\u0940 (Marathi)'},
    {'code': '\u09ac\u09be\u0982\u09b2\u09be', 'native': '\u09ac\u09be\u0982\u09b2\u09be (Bengali)'},
    {'code': '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0', 'native': '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0 (Gujarati)'},
    {'code': '\u0a2a\u0a70\u0a1c\u0a3e\u0a2c\u0a40', 'native': '\u0a2a\u0a70\u0a1c\u0a3e\u0a2c\u0a40 (Punjabi)'},
  ];

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          decoration: const BoxDecoration(
            color: BDColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(color: BDColors.divider, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Language',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: BDColors.ink),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: LanguageNotifier.activeLanguage,
                    builder: (context, currentLang, _) {
                      return ListView(
                        shrinkWrap: true,
                        children: langList.map((langMap) {
                          final langCode = langMap['code']!;
                          final nativeName = langMap['native']!;
                          final isSelected = currentLang == langCode;
                          return ListTile(
                            onTap: () {
                              LanguageNotifier.activeLanguage.value = langCode;
                              Navigator.pop(bc);
                            },
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              nativeName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? BDColors.red : BDColors.ink,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: BDColors.red, size: 20)
                                : null,
                          );
                        }).toList(),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('BLUSHY', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 3, color: BDColors.red)),
              Text('.', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: BDColors.orange)),
            ],
          ),
          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: LanguageNotifier.activeLanguage,
                builder: (context, currentLang, _) {
                  return GestureDetector(
                    onTap: () {
                      if (onTapLanguage != null) {
                        onTapLanguage!();
                      } else {
                        _showLanguageBottomSheet(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BDColors.cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BDColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language_rounded, color: BDColors.ink, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            currentLang,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: BDColors.ink),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: BDColors.inkLight),
                        ],
                      ),
                    ),
                  );
                }
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: BDColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: BDColors.cream, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BlushyBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;
  const BlushyBottomNav({super.key, required this.activeIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: BDColors.white,
        border: Border(top: BorderSide(color: BDColors.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(0),
            child: _NavItem(icon: Icons.home_filled, label: 'Home', isActive: activeIndex == 0),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(1),
            child: _NavItem(icon: Icons.people_rounded, label: 'Community', isActive: activeIndex == 1),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(2),
            child: _NavItem(icon: Icons.auto_awesome, label: 'Sia', isActive: activeIndex == 2),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(3),
            child: _NavItem(icon: Icons.menu_book_rounded, label: 'Journal', isActive: activeIndex == 3),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(4),
            child: _NavItem(icon: Icons.favorite_rounded, label: 'Partner', isActive: activeIndex == 4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavItem({required this.icon, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? BDColors.red : BDColors.inkLight.withOpacity(0.4), size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 8, color: isActive ? BDColors.red : BDColors.inkLight.withOpacity(0.5), fontWeight: FontWeight.bold)),
      ],
    );
  }
}
