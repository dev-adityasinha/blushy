import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/bouquet_state.dart';
import '../widgets/falling_petals.dart';
import 'builder_screen.dart';
import 'garden_screen.dart';
import '../models/auth_models.dart';
import '../models/partner_models.dart';
import '../../../../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  final AuthSession session;
  final List<PartnerConnection> activeConnections;

  const HomeScreen({
    super.key,
    required this.session,
    required this.activeConnections,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BouquetState>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Falling Petals Background
          const FallingPetals(),

          // 2. Main Content Scrollable
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    const SizedBox(height: 30),

                    // Peony Hero Image
                    Hero(
                      tag: 'hero-peony',
                      child: Image.asset(
                        'assets/color/flowers/peony.png',
                        width: 140,
                        height: 140,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logo / Title
                    Text(
                      'Bouquet',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.0,
                        color: isDark ? const Color(0xFFF2C6D0) : const Color(0xFF5C3841),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'beautiful flowers\ndelivered digitally',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Main Action Buttons
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8A0B4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              state.resetBuilder();
                              state.setMode('color');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ChangeNotifierProvider.value(
                                          value: state,
                                          child: BuilderScreen(
                                            session: session,
                                            connection: activeConnections.isNotEmpty
                                                ? activeConnections.first
                                                : null,
                                          ),
                                        )),
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).hBuildABouquet,
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? const Color(0xFFFADDE3)
                                  : const Color(0xFF5C3841),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF5C3841)
                                    : const Color(0xFFE6C5CC),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () {
                              state.resetBuilder();
                              state.setMode('mono');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ChangeNotifierProvider.value(
                                          value: state,
                                          child: BuilderScreen(
                                            session: session,
                                            connection: activeConnections.isNotEmpty
                                                ? activeConnections.first
                                                : null,
                                          ),
                                        )),
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).hBuildItInBlack,
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.yard_outlined, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8FB996),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ChangeNotifierProvider.value(
                                          value: state,
                                          child: GardenScreen(
                                            session: session,
                                            connection: activeConnections.isNotEmpty
                                                ? activeConnections.first
                                                : null,
                                          ),
                                        )),
                              );
                            },
                            label: Text(
                              'View Garden (${state.savedBouquets.length} saved)',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats badge
                    if (state.createdBouquetsCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💐 ', style: TextStyle(fontSize: 16)),
                            Text(
                              '${state.createdBouquetsCount} bouquet${state.createdBouquetsCount != 1 ? 's' : ''} created',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}



}
