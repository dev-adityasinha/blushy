import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../state/bouquet_state.dart';
import '../models/flower.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BouquetState>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bouquet',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. General About Card
              _buildCard(
                child: Column(
                  children: [
                    const Text('💐', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'About Bouquet',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A digital flower bouquet builder — pick your blooms, arrange them with love, and send them to someone special. No water needed. 🌿',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Bouquet Tips Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Bouquet Tips',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFE8A0B4)),
                    ),
                    const SizedBox(height: 12),
                    _buildTip('Odd numbers', 'Bouquets with 7 or 9 flowers look more natural'),
                    _buildTip('Mix textures', 'Pair big roses with small daisies for depth'),
                    _buildTip('Color harmony', 'Stick to 2-3 colors for an elegant look'),
                    _buildTip('Add variety', 'Use at least 3 different flower types'),
                    _buildTip('Drag to arrange', 'Reposition flowers after placing them'),
                    _buildTip('Try templates', 'Start with "Birthday" or "Anniversary"'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Gesture/Control Shortcuts Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Interactive Gestures',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildShortcut('Drag & Move', 'Touch and drag flowers on the canvas to compose'),
                    _buildShortcut('Step back', 'Use the Undo button to revert flower selections'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Flower Meanings Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌼 Flower Meanings',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: flowers.length,
                      itemBuilder: (context, idx) {
                        final f = flowers[idx];
                        // Extract icon emoji for flower
                        String emoji = _getFlowerEmoji(f.id);
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$emoji ${f.name}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f.meaning,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Support Project Card
              _buildCard(
                color: isDark ? const Color(0xFF1E1A16) : const Color(0xFFFAF6EE),
                borderColor: isDark ? const Color(0xFF3D232A) : const Color(0xFFFADDE3),
                child: Column(
                  children: [
                    const Text('☕', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Support this Project',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFE8A0B4)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you enjoyed building a digital bouquet, consider supporting the creator. Your donations help keep the server running and the flowers blooming!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A0B4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => showUpiPaymentDialog(context),
                      child: const Text('Pay via UPI', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A0B4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        state.resetBuilder();
                        state.setMode('color');
                        Navigator.pushNamed(context, '/builder');
                      },
                      child: const Text('Build a Bouquet', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFFADDE3) : const Color(0xFF5C3841),
                        side: BorderSide(color: isDark ? const Color(0xFF5C3841) : const Color(0xFFE6C5CC)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/garden'),
                      child: const Text('View Garden', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    Color? color,
    Color? borderColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildTip(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcut(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  String _getFlowerEmoji(String id) {
    switch (id) {
      case 'rose':
        return '🌹';
      case 'sunflower':
        return '🌻';
      case 'tulip':
        return '🌷';
      case 'peony':
        return '🌸';
      case 'daisy':
        return '🌼';
      case 'lily':
        return '🌺';
      case 'orchid':
        return '💮';
      case 'dahlia':
        return '🏵️';
      case 'carnation':
        return '🌼';
      case 'anemone':
        return '🌸';
      case 'ranunculus':
        return '💐';
      case 'zinnia':
        return '🌺';
      default:
        return '🌸';
    }
  }
}

// Global Dialog helper
void showUpiPaymentDialog(BuildContext context) {
  const upiId = 'aditya262701@okicici';
  const payeeName = 'Bouquet';
  const note = 'Support Bouquet';
  final upiLink = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&tn=${Uri.encodeComponent(note)}';
  final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=8&data=${Uri.encodeComponent(upiLink)}';

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('💳 Pay via UPI', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan this QR in any UPI app or copy the UPI ID.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Image.network(
              qrUrl,
              width: 180,
              height: 180,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
            const SizedBox(height: 12),
            SelectableText(
              upiId,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: upiId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI ID copied to clipboard!')),
                    );
                  },
                  child: const Text('Copy ID'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A0B4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uri = Uri.parse(upiLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not open UPI app. Please copy ID instead.')),
                      );
                    }
                  },
                  child: const Text('Open UPI App'),
                ),
              ],
            )
          ],
        ),
      );
    },
  );
}
