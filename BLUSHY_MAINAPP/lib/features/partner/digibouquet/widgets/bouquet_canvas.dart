import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/flower.dart';
import '../models/bouquet.dart';
import '../state/bouquet_state.dart';

class BouquetCanvas extends StatefulWidget {
  final List<PlacedFlower> flowers;
  final bool isEditing;
  final int greeneryIndex;
  final String wrappingPaper;
  final int ribbonColorIndex;
  final String mode; // 'color' or 'mono'
  final Function(int index, double x, double y)? onFlowerMoved;

  const BouquetCanvas({
    super.key,
    required this.flowers,
    required this.greeneryIndex,
    required this.wrappingPaper,
    required this.ribbonColorIndex,
    required this.mode,
    this.isEditing = false,
    this.onFlowerMoved,
  });

  @override
  State<BouquetCanvas> createState() => _BouquetCanvasState();
}

class _BouquetCanvasState extends State<BouquetCanvas> {
  int? _activeDragIndex;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 520 / 580,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double logicalWidth = 520.0;
            final double scaleX = constraints.maxWidth / logicalWidth;
            final double scale = scaleX; // Keep aspect ratio uniform

            // Build layers
            return Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                // 1. Wrapping paper / Vase background
                _buildWrappingPaper(scale),

                // 2. Greenery Base
                _buildGreeneryBase(scale),

                // 3. Flowers Stack
                ..._buildFlowers(scale),

                // 4. Greenery Top
                _buildGreeneryTop(scale),

                // 5. Ribbon Overlay
                _buildRibbon(scale),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWrappingPaper(double scale) {
    final isVase = widget.wrappingPaper.startsWith('vase-');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dimensions in logical pixels
    final double width = 520.0 * 0.55;
    final double height = 580.0 * 0.65;
    final double left = (520.0 - width) / 2;

    if (isVase) {
      final isGlass = widget.wrappingPaper == 'vase-glass';
      final double vaseWidth = 130.0;
      final double vaseHeight = 210.0;
      final double vaseLeft = (520.0 - vaseWidth) / 2;

      if (isGlass) {
        return Positioned(
          bottom: 0,
          left: vaseLeft * scale,
          width: vaseWidth * scale,
          height: vaseHeight * scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // Ceramic Pot
        return Positioned(
          bottom: 0,
          left: vaseLeft * scale,
          width: vaseWidth * scale,
          height: vaseHeight * scale,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE0D5C1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [
                  Color(0x22FFFFFF),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      }
    }

    // Classic Wrap
    Gradient gradient;
    switch (widget.wrappingPaper) {
      case 'wrap-rose':
        gradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5C3841), Color(0xFF3D232A)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFADDE3), Color(0xFFE6C5CC)],
              );
        break;
      case 'wrap-sage':
        gradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A4A3C), Color(0xFF243026)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE2ECE3), Color(0xFFC8D8CA)],
              );
        break;
      case 'wrap-slate':
        gradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A3D42), Color(0xFF222428)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE2E4E8), Color(0xFFC3C7CF)],
              );
        break;
      case 'wrap-classic':
      default:
        gradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A2420), Color(0xFF1E1A16)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0E8D9), Color(0xFFE3D5C1)],
              );
        break;
    }

    return Positioned(
      bottom: 0,
      left: left * scale,
      width: width * scale,
      height: height * scale,
      child: ClipPath(
        clipper: TrapezoidClipper(),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
          ),
        ),
      ),
    );
  }

  Widget _buildGreeneryBase(double scale) {
    // Determine greenery path
    final list = bushImages[widget.mode == 'mono' ? 'mono' : 'color'] ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    final greenery = list[widget.greeneryIndex % list.length];

    // Width: 80%, Height: 70%, Bottom: 5%
    final double width = 520.0 * 0.8;
    final double height = 580.0 * 0.7;
    final double left = (520.0 - width) / 2;

    return Positioned(
      bottom: 580.0 * 0.05 * scale,
      left: left * scale,
      width: width * scale,
      height: height * scale,
      child: Image.asset(
        greenery.base,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildGreeneryTop(double scale) {
    final list = bushImages[widget.mode == 'mono' ? 'mono' : 'color'] ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    final greenery = list[widget.greeneryIndex % list.length];

    final double width = 520.0 * 0.8;
    final double height = 580.0 * 0.7;
    final double left = (520.0 - width) / 2;

    return Positioned(
      bottom: 580.0 * 0.05 * scale,
      left: left * scale,
      width: width * scale,
      height: height * scale,
      child: IgnorePointer(
        child: Image.asset(
          greenery.top,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  List<Widget> _buildFlowers(double scale) {
    final list = <Widget>[];

    for (int i = 0; i < widget.flowers.length; i++) {
      final placedFlower = widget.flowers[i];
      final flower = getFlowerById(placedFlower.flowerId);
      if (flower == null) continue;

      final imagePath = widget.mode == 'mono' ? flower.monoImage : flower.image;

      // Layout coordinates are mapped to 520x580 canvas
      // In JS, flower size is 120x120 pixels
      final double size = 120.0;

      final isDragging = _activeDragIndex == i;

      list.add(
        Positioned(
          left: placedFlower.x * scale,
          top: placedFlower.y * scale,
          width: size * scale,
          height: size * scale,
          child: GestureDetector(
            onPanStart: widget.isEditing
                ? (details) {
                    setState(() {
                      _activeDragIndex = i;
                    });
                  }
                : null,
            onPanUpdate: widget.isEditing
                ? (details) {
                    // Update logical coordinate: details.delta is screen-pixel based.
                    // Convert delta to logical coordinates by dividing by scale.
                    final double newX = placedFlower.x + details.delta.dx / scale;
                    final double newY = placedFlower.y + details.delta.dy / scale;

                    // Bounds checking inside canvas (logical coordinates)
                    final double clampedX = newX.clamp(0.0, 520.0 - size);
                    final double clampedY = newY.clamp(0.0, 580.0 - size);

                    if (widget.onFlowerMoved != null) {
                      widget.onFlowerMoved!(i, clampedX, clampedY);
                    }
                  }
                : null,
            onPanEnd: widget.isEditing
                ? (_) {
                    setState(() {
                      _activeDragIndex = null;
                    });
                  }
                : null,
            child: Transform.scale(
              scale: placedFlower.scale * (isDragging ? 1.15 : 1.0),
              child: Transform.rotate(
                angle: placedFlower.rotation * 3.14159 / 180,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }

  Widget _buildRibbon(double scale) {
    if (widget.wrappingPaper.startsWith('vase-')) {
      return const SizedBox.shrink();
    }

    final color = BouquetState.ribbonColors[widget.ribbonColorIndex % BouquetState.ribbonColors.length];

    final double width = 520.0 * 0.36;
    final double left = (520.0 - width) / 2;
    final double bottom = 580.0 * 0.35;

    return Positioned(
      bottom: bottom * scale,
      left: left * scale,
      width: width * scale,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 4 * scale,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    color.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 14 * scale,
              height: 14 * scale,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10 * scale,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrapezoidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.15, 0);
    path.lineTo(size.width * 0.85, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
