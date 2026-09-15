import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/bouquet_state.dart';
import '../models/bouquet.dart';
import '../widgets/bouquet_canvas.dart';
import 'builder_screen.dart';
import '../models/auth_models.dart';
import '../models/partner_models.dart';
import '../../../../l10n/app_localizations.dart';

class GardenScreen extends StatefulWidget {
  final AuthSession? session;
  final PartnerConnection? connection;

  const GardenScreen({super.key, this.session, this.connection});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  String _currentTab = 'community'; // 'community' | 'my'
  String _currentSort = 'default'; // 'default' | 'liked'

  // Pre-made community bouquets matching flowers.js
  static final List<Bouquet> _communityBouquets = [
    Bouquet(
      id: 'comm_1',
      flowers: ['rose', 'rose', 'carnation', 'daisy', 'lily', 'zinnia', 'orchid', 'peony'],
      greeneryIndex: 0,
      seed: 12345,
      creator: 'Flora',
      mode: 'color',
      message: 'A beautiful blend of roses and daisies!',
      wrappingPaper: 'wrap-classic',
      ribbonColorIndex: 0,
      date: DateTime(2026, 4, 12),
    ),
    Bouquet(
      id: 'comm_2',
      flowers: ['sunflower', 'rose', 'dahlia', 'orchid', 'daisy', 'ranunculus', 'anemone', 'carnation'],
      greeneryIndex: 1,
      seed: 67890,
      creator: 'Ivy',
      mode: 'color',
      message: 'Sunny sunflower vibes for a bright day!',
      wrappingPaper: 'wrap-sage',
      ribbonColorIndex: 2,
      date: DateTime(2026, 4, 12),
    ),
    Bouquet(
      id: 'comm_3',
      flowers: ['tulip', 'tulip', 'peony', 'rose', 'lily', 'orchid', 'daisy', 'carnation'],
      greeneryIndex: 2,
      seed: 11223,
      creator: 'Rosemary',
      mode: 'color',
      message: 'With love and warm wishes.',
      wrappingPaper: 'wrap-rose',
      ribbonColorIndex: 1,
      date: DateTime(2026, 4, 11),
    ),
    Bouquet(
      id: 'comm_4',
      flowers: ['zinnia', 'sunflower', 'dahlia', 'ranunculus', 'anemone', 'carnation', 'rose', 'lily'],
      greeneryIndex: 0,
      seed: 44556,
      creator: 'Dahlia',
      mode: 'color',
      message: 'Elegance and inner strength blooms.',
      wrappingPaper: 'wrap-slate',
      ribbonColorIndex: 3,
      date: DateTime(2026, 4, 10),
    ),
    Bouquet(
      id: 'comm_5',
      flowers: ['rose', 'peony', 'ranunculus', 'dahlia', 'carnation', 'orchid', 'tulip', 'daisy'],
      greeneryIndex: 1,
      seed: 77889,
      creator: 'Sage',
      mode: 'color',
      message: 'Just because you are special.',
      wrappingPaper: 'wrap-classic',
      ribbonColorIndex: 0,
      date: DateTime(2026, 4, 9),
    ),
    Bouquet(
      id: 'comm_6',
      flowers: ['lily', 'anemone', 'sunflower', 'zinnia', 'rose', 'daisy', 'dahlia', 'carnation'],
      greeneryIndex: 2,
      seed: 99001,
      creator: 'Violet',
      mode: 'color',
      message: 'Thinking of you!',
      wrappingPaper: 'wrap-sage',
      ribbonColorIndex: 2,
      date: DateTime(2026, 4, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BouquetState>(context);

    final hasSaved = state.savedBouquets.isNotEmpty;
    // Without this the tab row stayed hidden for someone who had never made
    // a bouquet but had been sent one.
    final hasReceived = state.receivedBouquets.isNotEmpty;

    // Resolve list based on current tab
    List<Bouquet> displayedList = [];
    if (_currentTab == 'my') {
      displayedList = state.savedBouquets;
    } else if (_currentTab == 'received') {
      // These have been fetched into state and exposed as `receivedBouquets`
      // since the account sync was added, and nothing ever rendered them -- so
      // a bouquet sent to a partner arrived, was stored, and was never seen.
      displayedList = state.receivedBouquets;
    } else {
      displayedList = List.from(_communityBouquets);
      if (_currentSort == 'liked') {
        // Sorted by what she actually liked. The previous ordering derived a
        // like count from the id -- 'comm_1' became 21 likes, 'comm_2' 35 --
        // so the ranking was invented, and nothing anywhere counts likes.
        displayedList.sort((a, b) {
          final aLiked = state.isLiked(a.id) ? 1 : 0;
          final bLiked = state.isLiked(b.id) ? 1 : 0;
          return bLiked.compareTo(aLiked);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).gBouquet,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
        child: Column(
          children: [
            // Header titles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  Text(
                    'Our Garden',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).gIdeasSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs (Community / My)
            if (hasSaved || hasReceived)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentTab = 'community';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _currentTab == 'community'
                                    ? const Color(0xFFE8A0B4)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).gCommunity,
                            style: TextStyle(
                              fontWeight: _currentTab == 'community' ? FontWeight.bold : FontWeight.normal,
                              color: _currentTab == 'community' ? const Color(0xFFE8A0B4) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentTab = 'my';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _currentTab == 'my'
                                    ? const Color(0xFFE8A0B4)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            '📌 My Bouquets (${state.savedBouquets.length})',
                            style: TextStyle(
                              fontWeight: _currentTab == 'my' ? FontWeight.bold : FontWeight.normal,
                              color: _currentTab == 'my' ? const Color(0xFFE8A0B4) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentTab = 'received';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _currentTab == 'received'
                                    ? const Color(0xFFE8A0B4)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            '💌 For Me (${state.receivedBouquets.length})',
                            style: TextStyle(
                              fontWeight: _currentTab == 'received' ? FontWeight.bold : FontWeight.normal,
                              color: _currentTab == 'received' ? const Color(0xFFE8A0B4) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Sort Controls (Community only)
            if (_currentTab == 'community')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Newest'),
                      selected: _currentSort == 'default',
                      onSelected: (val) {
                        setState(() {
                          _currentSort = 'default';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Most Liked'),
                      selected: _currentSort == 'liked',
                      onSelected: (val) {
                        setState(() {
                          _currentSort = 'liked';
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Grid of Bouquets
            Expanded(
              child: displayedList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🌿', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Your garden is empty. Build a bouquet and save it!',
                            style: GoogleFonts.inter(fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: displayedList.length,
                      itemBuilder: (context, idx) {
                        final bouquet = displayedList[idx];
                        return _buildBouquetCard(context, bouquet, state);
                      },
                    ),
            ),

            // Bottom CTA Build Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A0B4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          session: widget.session,
                          connection: widget.connection,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Build Your Own', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBouquetCard(BuildContext context, Bouquet bouquet, BouquetState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Generate arrangement for preview
    final List<PlacedFlower> positions = state.generateArrangement(
      bouquet.flowers,
      (bouquet.seed / 100000),
    );

    // Only whether she liked it. There was a count here derived from the id --
    // 'comm_1' rendered as 21 likes, 'comm_2' as 35 -- presented on the card as
    // though other people had liked it. Nothing anywhere counts likes.
    final isLiked = state.isLiked(bouquet.id);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bouquet Canvas Preview
          Expanded(
            child: BouquetCanvas(
              flowers: positions,
              greeneryIndex: bouquet.greeneryIndex,
              wrappingPaper: bouquet.wrappingPaper,
              ribbonColorIndex: bouquet.ribbonColorIndex,
              mode: bouquet.mode,
            ),
          ),

          // Details & Actions bottom panel
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'by ${bouquet.creator}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${bouquet.date.month}/${bouquet.date.day}',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Like button (Community only)
                    if (bouquet.id.startsWith('comm_')) ...[
                      InkWell(
                        onTap: () {
                          if (!state.isLoggedIn) {
                            _showLoginDialog(context);
                            return;
                          }
                          state.toggleLike(bouquet.id);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],

                    // Use Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2A2420) : const Color(0xFFE3D5C1),
                        foregroundColor: isDark ? const Color(0xFFFADDE3) : const Color(0xFF5C3841),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Load this template into the builder
                        state.selectCombo(
                          bouquet.flowers,
                          (bouquet.seed / 100000),
                          bouquet.greeneryIndex,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider.value(
                              value: state,
                              child: BuilderScreen(
                                session: widget.session,
                                connection: widget.connection,
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Use', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),

                    // Delete Button (My saved bouquets only)
                    if (!bouquet.id.startsWith('comm_')) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          state.deleteSavedBouquet(bouquet.id);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌸', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              const Text(
                'Sign in to like bouquets!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A0B4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
                child: const Text('Sign In'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }
}
