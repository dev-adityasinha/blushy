import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';

class ModularThemePack {
  final String id;
  final String name;
  final Color paperColor;
  final Color coverColor;
  final String fontName;
  final String washiStyle;
  final String ambientAudioName;

  ModularThemePack({
    required this.id,
    required this.name,
    required this.paperColor,
    required this.coverColor,
    required this.fontName,
    required this.washiStyle,
    required this.ambientAudioName,
  });
}

class ThemeMarketplaceWidget extends StatefulWidget {
  final ValueChanged<ModularThemePack> onApplyTheme;

  const ThemeMarketplaceWidget({
    super.key,
    required this.onApplyTheme,
  });

  @override
  State<ThemeMarketplaceWidget> createState() => _ThemeMarketplaceWidgetState();
}

class _ThemeMarketplaceWidgetState extends State<ThemeMarketplaceWidget> {
  final List<ModularThemePack> _themePacks = [
    ModularThemePack(id: 'sakura', name: 'Sakura Floral 🌸', paperColor: const Color(0xFFFFF0F5), coverColor: const Color(0xFFF472B6), fontName: 'Handwriting', washiStyle: 'Floral', ambientAudioName: 'Soft Rain'),
    ModularThemePack(id: 'cottage', name: 'Cottagecore 🌿', paperColor: const Color(0xFFFDFBF7), coverColor: const Color(0xFF10B981), fontName: 'Elegant Serif', washiStyle: 'Kraft', ambientAudioName: 'Forest Birds'),
    ModularThemePack(id: 'vintage', name: 'Vintage Antique 📜', paperColor: const Color(0xFFF4EAD4), coverColor: const Color(0xFF8B4513), fontName: 'Brush Script', washiStyle: 'Vintage', ambientAudioName: 'Vinyl Crackle'),
    ModularThemePack(id: 'ocean', name: 'Ocean Waves 🌊', paperColor: const Color(0xFFE0F2FE), coverColor: const Color(0xFF0284C7), fontName: 'Modern Sans', washiStyle: 'Holographic', ambientAudioName: 'Ocean Waves'),
    ModularThemePack(id: 'dark', name: 'Dark Academia 🦉', paperColor: const Color(0xFF1F2937), coverColor: const Color(0xFF374151), fontName: 'Notebook', washiStyle: 'Gold Foil', ambientAudioName: 'Fireplace'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        title: Text('Modular Theme Engine 🎨', style: GoogleFonts.instrumentSerif(fontWeight: FontWeight.bold)),
        backgroundColor: BlushyColors.background,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _themePacks.length,
        itemBuilder: (context, i) {
          final pack = _themePacks[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: pack.coverColor, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(pack.name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Mix & Match Components:', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('Paper: ${pack.paperColor.toARGB32().toRadixString(16)}'), backgroundColor: pack.paperColor),
                      Chip(label: Text('Font: ${pack.fontName}')),
                      Chip(label: Text('Washi: ${pack.washiStyle}')),
                      Chip(label: Text('Audio: ${pack.ambientAudioName}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApplyTheme(pack);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                      child: const Text('Apply Custom Combination'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
