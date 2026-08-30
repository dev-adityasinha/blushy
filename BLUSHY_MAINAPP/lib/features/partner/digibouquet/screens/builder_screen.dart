import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../state/bouquet_state.dart';
import '../models/flower.dart';
import '../widgets/bouquet_canvas.dart';
import '../models/auth_models.dart';
import '../models/partner_models.dart';
import 'garden_screen.dart';

class BuilderScreen extends StatefulWidget {
  final AuthSession? session;
  final PartnerConnection? connection;

  const BuilderScreen({super.key, this.session, this.connection});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  late ConfettiController _confettiController;
  final TextEditingController _msgController = TextEditingController();
  bool _isSendingBouquet = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _triggerConfetti() {
    _confettiController.play();
  }

  Future<void> _shareBouquetImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final bouquetState = Provider.of<BouquetState>(context, listen: false);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/my_boutique.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'I made a beautiful digital bouquet for you! 💐',
      );

      bouquetState.incrementBouquetCounter();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share image: $e')),
      );
    }
  }

  Future<void> _sendBouquetToPartner(BouquetState state) async {
    if (widget.session == null || widget.connection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active partner connection found.')),
      );
      return;
    }

    setState(() {
      _isSendingBouquet = true;
    });

    final bouquetData = {
      'flowers': state.placedFlowers.map((f) => f.toJson()).toList(),
      'greeneryIndex': state.greeneryIndex,
      'wrappingPaper': state.wrappingPaper,
      'ribbonColorIndex': state.ribbonColorIndex,
      'mode': state.currentMode,
      'recipient': 'Dear Partner',
      'message': state.bouquetMessage.isEmpty ? 'Thinking of you! Here is a digital bouquet just for you.' : state.bouquetMessage,
      'sender': UserProfileController.instance.displayName,
    };

    final jsonStr = '[BOUQUET_JSON]:${jsonEncode(bouquetData)}';

    try {
      final partnerService = PartnerService();
      await partnerService.sendMessage(
        token: widget.session!.token,
        connectionId: widget.connection!.connectionId,
        message: jsonStr,
      );

      state.incrementBouquetCounter();
      try {
        await state.saveBouquetToGarden(UserProfileController.instance.displayName);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSendingBouquet = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bouquet sent to your partner and saved to My Garden! 💐')),
        );
        state.resetBuilder();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingBouquet = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send bouquet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BouquetState>(context);

    // Trigger confetti automatically when entering finish step
    if (state.currentStep == 'finish' && _confettiController.state == ConfettiControllerState.stopped) {
      _triggerConfetti();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.currentMode == 'mono' ? 'Boutique (B&W)' : 'Boutique',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.currentStep == 'arrange') {
              state.setStep('pick');
            } else if (state.currentStep == 'finish') {
              state.setStep('arrange');
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Screen Contents
            Column(
              children: [
                // Top Progress Steps Indicator
                _buildStepProgress(state),
                const SizedBox(height: 8),

                // Active Step Content
                Expanded(
                  child: _buildActiveStepView(state),
                ),
              ],
            ),

            // Confetti Overlay (Positioned center-top for finish celebration)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFE8A0B4),
                  Color(0xFFFADDE3),
                  Color(0xFFD4A574),
                  Colors.white,
                  Color(0xFF8FB996)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgress(BouquetState state) {
    final step = state.currentStep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepNode('1', 'Pick', step == 'pick', step == 'arrange' || step == 'finish'),
          _buildStepDivider(step == 'arrange' || step == 'finish'),
          _buildStepNode('2', 'Arrange', step == 'arrange', step == 'finish'),
          _buildStepDivider(step == 'finish'),
          _buildStepNode('3', 'Finish', step == 'finish', false),
        ],
      ),
    );
  }

  Widget _buildStepNode(String num, String label, bool isActive, bool isDone) {
    final activeColor = const Color(0xFFE8A0B4);
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? activeColor
                : (isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent),
            border: Border.all(
              color: isDone || isActive ? activeColor : Colors.grey.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  num,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isActive ? activeColor : Colors.grey,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive || isDone ? const Color(0xFFE8A0B4) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isDone) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 14),
      color: isDone ? const Color(0xFFE8A0B4) : Colors.grey.withValues(alpha: 0.3),
    );
  }

  Widget _buildActiveStepView(BouquetState state) {
    switch (state.currentStep) {
      case 'arrange':
        return _buildArrangeView(state);
      case 'finish':
        return _buildFinishView(state);
      case 'pick':
      default:
        return _buildPickerView(state);
    }
  }

  // --- 1. PICK VIEW ---
  Widget _buildPickerView(BouquetState state) {
    final totalSelected = state.totalFlowersSelected;
    final isSelectionValid = totalSelected >= 6 && totalSelected <= 10;

    return Column(
      children: [
        // Picker Header & Counter Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              Text(
                'Select 6 to 10 flowers',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              // Selection meter
              Container(
                height: 6,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (totalSelected / 10).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A0B4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalSelected of 10 selected',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Selection Actions Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed: state.canUndo ? () => state.undo() : null,
                        tooltip: 'Undo',
                      ),
                      IconButton(
                        icon: const Icon(Icons.redo),
                        onPressed: state.canRedo ? () => state.redo() : null,
                        tooltip: 'Redo',
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: const Text('Surprise Me'),
                    onPressed: () => state.surpriseMe(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Grid of flowers
        Expanded(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: flowers.length,
                itemBuilder: (context, idx) {
              final f = flowers[idx];
              final count = state.selectedFlowers[f.id] ?? 0;
              final imagePath = state.currentMode == 'mono' ? f.monoImage : f.image;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: count > 0 ? const Color(0xFFE8A0B4) : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    width: count > 0 ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Count Badge
                    if (count > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8A0B4),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Card Content Clickable
                    InkWell(
                      onTap: totalSelected < 10
                          ? () => state.toggleFlowerSelection(f.id, 1)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Image.asset(
                                imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              f.meaning,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Remove Button Overlay
                    if (count > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: InkWell(
                          onTap: () => state.toggleFlowerSelection(f.id, -1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 14, color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),

        // Bottom wizard actions
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8A0B4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            onPressed: isSelectionValid
                ? () {
                    // Populate arrangement initially based on seed
                    state.selectCombo(
                      state.getSelectedFlowerList(),
                      state.arrangementSeed,
                      state.greeneryIndex,
                    );
                    state.setStep('arrange');
                  }
                : null,
            child: const Text('Arrange Flowers', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- 2. ARRANGE VIEW ---
  Widget _buildArrangeView(BouquetState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Helper Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              Text(
                'Arrange Bouquet',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '✨ Drag flowers to reposition them',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('New Layout', style: TextStyle(fontSize: 12)),
                    onPressed: () => state.generateNewArrangement(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.grass, size: 16),
                    label: Text('Greenery (${state.greeneryIndex + 1})', style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      state.setGreeneryIndex(state.greeneryIndex + 1);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Wrapping Paper selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            children: BouquetState.wrappingOptions.map((opt) {
              final isSelected = state.wrappingPaper == opt['class'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      state.setWrappingPaper(opt['class']!);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Canvas Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Center(
              child: BouquetCanvas(
                flowers: state.placedFlowers,
                greeneryIndex: state.greeneryIndex,
                wrappingPaper: state.wrappingPaper,
                ribbonColorIndex: state.ribbonColorIndex,
                mode: state.currentMode,
                isEditing: true,
                onFlowerMoved: (idx, x, y) {
                  state.updatePlacedFlowerPosition(idx, x, y);
                },
              ),
            ),
          ),
        ),

        // Ribbon Selector
        if (!state.wrappingPaper.startsWith('vase-')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(BouquetState.ribbonColors.length, (idx) {
                final color = BouquetState.ribbonColors[idx];
                final isSelected = state.ribbonColorIndex == idx;
                return GestureDetector(
                  onTap: () => state.setRibbonColor(idx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],

        // Back / Next Wizard
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFFADDE3) : const Color(0xFF5C3841),
                    side: BorderSide(color: isDark ? const Color(0xFF5C3841) : const Color(0xFFE6C5CC)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => state.setStep('pick'),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A0B4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  onPressed: () => state.setStep('finish'),
                  child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. FINISH / SHARE VIEW ---
  Widget _buildFinishView(BouquetState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Occasion tags preset notes
    final List<Map<String, String>> occasionPresets = [
      {'tag': '🎂 Birthday', 'msg': 'Happy Birthday! 🎂 Wishing you a wonderful day filled with joy!'},
      {'tag': '💕 Valentine\'s', 'msg': 'You are so loved 💕 Sending all my love your way.'},
      {'tag': '🙏 Thank You', 'msg': 'Thank you so much 🙏 Your kindness means the world.'},
      {'tag': '🤒 Get Well', 'msg': 'Get well soon! 💛 Sending warm thoughts your way.'},
      {'tag': '🎓 Graduation', 'msg': 'Congratulations! 🎓 So proud of everything you\'ve achieved.'},
      {'tag': '✨ Just Because', 'msg': 'Just because ✨ You deserve something beautiful today.'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Repaint boundary wrapped canvas for screenshots
          Center(
            child: SizedBox(
              width: 320,
              child: RepaintBoundary(
                key: _canvasKey,
                child: BouquetCanvas(
                  flowers: state.placedFlowers,
                  greeneryIndex: state.greeneryIndex,
                  wrappingPaper: state.wrappingPaper,
                  ribbonColorIndex: state.ribbonColorIndex,
                  mode: state.currentMode,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Message Input Field
          Text(
            'Greeting Message',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'To someone special...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (text) => state.setMessage(text),
            controller: _msgController..text = state.bouquetMessage,
          ),
          const SizedBox(height: 8),

          // Occasion Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: occasionPresets.map((opt) {
              final isPresetActive = state.bouquetMessage == opt['msg'];
              return ChoiceChip(
                label: Text(opt['tag']!, style: const TextStyle(fontSize: 12)),
                selected: isPresetActive,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      state.setMessage(opt['msg']!);
                      _msgController.text = opt['msg']!;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Finish Actions
          if (widget.connection != null) ...[
            ElevatedButton.icon(
              icon: _isSendingBouquet
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSendingBouquet ? 'Sending...' : 'Send to Partner', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8A0B4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              onPressed: _isSendingBouquet ? null : () => _sendBouquetToPartner(state),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share & Export Image', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.connection == null ? const Color(0xFFE8A0B4) : Colors.white,
              foregroundColor: widget.connection == null ? Colors.white : const Color(0xFF5C3841),
              side: widget.connection == null ? null : const BorderSide(color: Color(0xFFE6C5CC)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            onPressed: _shareBouquetImage,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_border),
            label: const Text('Save to My Garden'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFFADDE3) : const Color(0xFF5C3841),
              side: BorderSide(color: isDark ? const Color(0xFF5C3841) : const Color(0xFFE6C5CC)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () {
              state.saveBouquetToGarden(UserProfileController.instance.displayName);
              state.incrementBouquetCounter();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saved to My Garden!'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider.value(
                          value: state,
                          child: GardenScreen(
                            session: widget.session,
                            connection: widget.connection,
                          ),
                        )),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              state.resetBuilder();
            },
            child: const Text('Start Over', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
