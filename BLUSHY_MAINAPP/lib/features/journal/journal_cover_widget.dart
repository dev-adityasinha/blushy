import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum CoverMaterial { leather, linen, velvet, fabric, matte }

class JournalCoverWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color coverColor;
  final Color ribbonColor;
  final CoverMaterial material;
  final String emblem; // 'sparkles', 'flower', 'butterfly', 'none'
  final VoidCallback onTapOpen;
  final bool isOpening;

  const JournalCoverWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.coverColor,
    this.ribbonColor = const Color(0xFFD97706),
    this.material = CoverMaterial.leather,
    this.emblem = 'sparkles',
    required this.onTapOpen,
    this.isOpening = false,
  });

  @override
  State<JournalCoverWidget> createState() => _JournalCoverWidgetState();
}

class _JournalCoverWidgetState extends State<JournalCoverWidget> with TickerProviderStateMixin {
  late AnimationController _openController;
  late Animation<double> _liftAnim;
  late Animation<double> _shadowAnim;
  late Animation<double> _ribbonSwingAnim;
  late Animation<double> _coverRotateAnim;
  late Animation<double> _pagesFlipAnim;

  Offset _pointerPos = Offset.zero;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 1. Notebook lifts & shadow expands (0.0 - 0.25)
    _liftAnim = Tween<double>(begin: 0.0, end: -28.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic)),
    );
    _shadowAnim = Tween<double>(begin: 12.0, end: 40.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    // 2. Ribbon swings (0.2 - 0.5)
    _ribbonSwingAnim = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.2, 0.5, curve: Curves.elasticOut)),
    );

    // 3. Cover rotates (0.3 - 0.75)
    _coverRotateAnim = Tween<double>(begin: 0.0, end: -1.57).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.3, 0.75, curve: Curves.easeInOutCubic)),
    );

    // 4. Pages flip (0.6 - 0.9)
    _pagesFlipAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.6, 0.9, curve: Curves.easeOutQuad)),
    );

    // 5. Paper settles (0.85 - 1.0)
  }

  @override
  void didUpdateWidget(covariant JournalCoverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpening && !_openController.isAnimating && _openController.value == 0) {
      _triggerOpeningSequence();
    }
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  void _triggerOpeningSequence() {
    setState(() => _isUnlocked = true);
    _openController.forward().then((_) {
      widget.onTapOpen();
    });
  }

  BoxDecoration _getMaterialTexture() {
    switch (widget.material) {
      case CoverMaterial.leather:
        return BoxDecoration(
          color: widget.coverColor,
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.coverColor,
              widget.coverColor.withValues(alpha: 0.82),
            ],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: _shadowAnim.value, offset: const Offset(0, 12)),
          ],
        );
      case CoverMaterial.linen:
        return BoxDecoration(
          color: widget.coverColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: _shadowAnim.value, offset: const Offset(0, 10)),
          ],
        );
      case CoverMaterial.velvet:
        return BoxDecoration(
          color: widget.coverColor,
          borderRadius: BorderRadius.circular(20),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              widget.coverColor,
              widget.coverColor.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: _shadowAnim.value, offset: const Offset(0, 14)),
          ],
        );
      default:
        return BoxDecoration(
          color: widget.coverColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: _shadowAnim.value, offset: const Offset(0, 10)),
          ],
        );
    }
  }

  Widget _getEmblemIcon() {
    switch (widget.emblem) {
      case 'flower':
        return const Icon(Icons.local_florist_rounded, color: Color(0xFFD4AF37), size: 28);
      case 'butterfly':
        return const Icon(Icons.flutter_dash_rounded, color: Color(0xFFD4AF37), size: 28);
      case 'none':
        return const SizedBox.shrink();
      default:
        return const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 28);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _openController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _liftAnim.value),
          child: GestureDetector(
            onTap: _triggerOpeningSequence,
            onPanUpdate: (details) {
              setState(() {
                _pointerPos = details.localPosition;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Journal Pages Thickness (Right Side Preview with Page Flip Animation)
                Positioned(
                  top: 8,
                  bottom: 8,
                  right: -14,
                  child: Transform.rotate(
                    angle: _pagesFlipAnim.value * 0.05,
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F3E9),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(3, 0))],
                        border: Border.all(color: const Color(0xFFE6DFD3)),
                      ),
                    ),
                  ),
                ),

                // Ribbon Bookmark sticking out from bottom with Ribbon Swing animation
                Positioned(
                  bottom: -24,
                  left: 60 + _ribbonSwingAnim.value,
                  child: Container(
                    width: 18,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.ribbonColor,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                  ),
                ),

                // Hardcover Journal Container with 3D Cover Rotation Transformation
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_coverRotateAnim.value),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 310,
                    height: 430,
                    decoration: _getMaterialTexture(),
                    padding: const EdgeInsets.all(24),
                    child: Stack(
                      children: [
                        // Gold Foil Embossed Border Line
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                          ),
                        ),

                        // Light Reflection Sheen when moving finger
                        if (_pointerPos != Offset.zero)
                          Positioned(
                            left: _pointerPos.dx - 60,
                            top: _pointerPos.dy - 60,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Cover Titles & Decor
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _getEmblemIcon(),
                              const SizedBox(height: 14),
                              Text(
                                widget.title.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD4AF37),
                                  letterSpacing: 2.0,
                                  shadows: const [Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.caveat(
                                    fontSize: 18,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),

                              // Decorative Fingerprint Unlock Icon (Visual Delight)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6)),
                                ),
                                child: Icon(
                                  _isUnlocked ? Icons.lock_open_rounded : Icons.fingerprint_rounded,
                                  color: const Color(0xFFD4AF37),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to open diary (Decorative Unlock)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
