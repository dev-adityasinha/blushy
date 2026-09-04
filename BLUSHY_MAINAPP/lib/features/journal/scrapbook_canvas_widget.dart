import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'journal_screen.dart';
import 'scrapbook_item_renderers.dart';
import 'ambient_effects_overlay.dart';
import 'engine/scrapbook_animation_engine.dart';
import 'engine/micro_interaction_manager.dart';
import '../../theme/colors.dart';

class ScrapbookCanvasWidget extends StatefulWidget {
  final List<ScrapbookItem> items;
  final String activeTheme;
  final String activeFont;
  final String? selectedItemId;
  final ValueChanged<String?> onItemSelect;
  final Function(ScrapbookItem) onItemUpdate;
  final Function(ScrapbookItem) onItemDuplicate;
  final Function(String) onItemDelete;
  final String? playingVoiceItemId;
  final double voicePlaybackProgress;
  final ValueChanged<ScrapbookItem> onVoicePlayToggle;
  final ScrapbookAnimationEngine animationEngine;

  const ScrapbookCanvasWidget({
    super.key,
    required this.items,
    required this.activeTheme,
    required this.activeFont,
    required this.selectedItemId,
    required this.onItemSelect,
    required this.onItemUpdate,
    required this.onItemDuplicate,
    required this.onItemDelete,
    this.playingVoiceItemId,
    this.voicePlaybackProgress = 0.0,
    required this.onVoicePlayToggle,
    required this.animationEngine,
  });

  @override
  State<ScrapbookCanvasWidget> createState() => _ScrapbookCanvasWidgetState();
}

class _ScrapbookCanvasWidgetState extends State<ScrapbookCanvasWidget> {
  final TransformationController _transformationController = TransformationController();
  final Size _canvasSize = const Size(700, 900);
  String? _currentlyDraggingId;

  Color _getThemeBgColor() {
    switch (widget.activeTheme) {
      case 'Vintage Paper':
        return const Color(0xFFF4EAD4);
      case 'Pink Floral':
        return const Color(0xFFFFF0F5);
      case 'Watercolor':
        return const Color(0xFFE0F2FE);
      case 'Minimal White':
        return const Color(0xFFFFFFFF);
      case 'Dark Mode':
        return const Color(0xFF1F2937);
      default: // 'Cream Paper'
        return const Color(0xFFFDFBF7);
    }
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onViewportChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onViewportChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onViewportChanged() {
    // Notify sticker animation manager to update round-robin active batch
    final visibleStickers = widget.items
        .where((item) => item.type == 'sticker' && _isItemInViewport(item))
        .map((item) => item.id)
        .toList();
    widget.animationEngine.stickerManager.updateActiveStickerBatch(visibleStickers);
  }

  /// Off-screen culling check: returns true if item position falls inside visible canvas
  bool _isItemInViewport(ScrapbookItem item) {
    return item.position.dx >= -50 &&
        item.position.dx <= _canvasSize.width + 50 &&
        item.position.dy >= -50 &&
        item.position.dy <= _canvasSize.height + 50;
  }

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<ScrapbookItem>.from(widget.items)..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return GestureDetector(
      onTap: () => widget.onItemSelect(null),
      child: Container(
        color: _getThemeBgColor(),
        child: InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: widget.selectedItemId == null,
          minScale: 0.6,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(300),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Canvas Paper Sheet with Desk Lighting Shadow Physics
              Container(
                width: _canvasSize.width,
                height: _canvasSize.height,
                decoration: BoxDecoration(
                  color: _getThemeBgColor(),
                  boxShadow: [
                    BoxShadow(
                      color: widget.animationEngine.physicsCoordinator.getShadowColor('paper'),
                      blurRadius: widget.animationEngine.physicsCoordinator.getShadowBlurRadius('paper') + 12,
                      offset: widget.animationEngine.physicsCoordinator.getShadowOffset('paper'),
                    ),
                  ],
                ),
              ),

              // Seasonal Ambient Particles Overlay
              Positioned.fill(
                child: AmbientEffectsOverlay(
                  particleManager: widget.animationEngine.particleManager,
                  canvasSize: _canvasSize,
                ),
              ),

              // Rendered Scrapbook Items with Physics & Micro-interactions
              ...sortedItems.map((item) {
                final isSelected = widget.selectedItemId == item.id;
                final isInViewport = _isItemInViewport(item);
                final shouldAnimateSticker = widget.animationEngine.stickerManager.shouldAnimateSticker(item.id, isInViewport);
                final microInteraction = widget.animationEngine.microInteractionManager.getInteraction(item.id);
                final isDraggingThis = _currentlyDraggingId == item.id;

                // Physics Shadow for Object
                final shadowOffset = widget.animationEngine.physicsCoordinator.getShadowOffset(item.id);
                final shadowBlur = widget.animationEngine.physicsCoordinator.getShadowBlurRadius(item.id);
                final shadowColor = widget.animationEngine.physicsCoordinator.getShadowColor(item.id);

                Widget contentWidget = _renderItemContent(item, shouldAnimateSticker);

                // Apply placement bounce micro-interaction
                if (microInteraction?.type == MicroInteractionType.placementBounce) {
                  contentWidget = AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: contentWidget,
                  );
                }

                return Positioned(
                  left: item.position.dx,
                  top: item.position.dy,
                  child: Transform.rotate(
                    angle: item.rotation,
                    child: Transform.scale(
                      scale: isDraggingThis ? item.scale * 1.05 : item.scale,
                      child: GestureDetector(
                        onTap: () => widget.onItemSelect(item.id),
                        onPanStart: (_) {
                          setState(() => _currentlyDraggingId = item.id);
                          widget.animationEngine.physicsCoordinator.setItemLift(item.id, 1.0);
                          widget.animationEngine.setEditingOrInteractingState(
                            isTyping: false,
                            isRecording: false,
                            isDragging: true,
                          );
                        },
                        onPanUpdate: (details) {
                          widget.onItemSelect(item.id);
                          widget.onItemUpdate(
                            item.copyWith(position: item.position + details.delta),
                          );
                        },
                        onPanEnd: (_) {
                          setState(() => _currentlyDraggingId = null);
                          widget.animationEngine.physicsCoordinator.setItemLift(item.id, 0.0);
                          widget.animationEngine.setEditingOrInteractingState(
                            isTyping: false,
                            isRecording: false,
                            isDragging: false,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: shadowBlur,
                                offset: shadowOffset,
                              ),
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                            ],
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 1.5) : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              contentWidget,

                              // Interactive 4 Corner Handles when Selected
                              if (isSelected) ...[
                                // Top-Left: Resize Handle
                                Positioned(
                                  left: -12,
                                  top: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      final newScale = (item.scale - details.delta.dy * 0.01).clamp(0.4, 3.0);
                                      widget.onItemUpdate(item.copyWith(scale: newScale));
                                    },
                                    child: _buildHandleBadge(Icons.open_in_full_rounded, const Color(0xFF3B82F6)),
                                  ),
                                ),

                                // Top-Right: Delete Handle
                                Positioned(
                                  right: -12,
                                  top: -12,
                                  child: GestureDetector(
                                    onTap: () => widget.onItemDelete(item.id),
                                    child: _buildHandleBadge(Icons.close_rounded, const Color(0xFFEF4444)),
                                  ),
                                ),

                                // Bottom-Left: Rotate Handle
                                Positioned(
                                  left: -12,
                                  bottom: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      final newRotation = item.rotation + details.delta.dx * 0.02;
                                      widget.onItemUpdate(item.copyWith(rotation: newRotation));
                                    },
                                    child: _buildHandleBadge(Icons.rotate_right_rounded, BlushyColors.accent),
                                  ),
                                ),

                                // Bottom-Right: Duplicate Handle
                                Positioned(
                                  right: -12,
                                  bottom: -12,
                                  child: GestureDetector(
                                    onTap: () => widget.onItemDuplicate(item),
                                    child: _buildHandleBadge(Icons.copy_rounded, const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandleBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }

  Widget _renderItemContent(ScrapbookItem item, bool shouldAnimateSticker) {
    switch (item.type) {
      case 'sticker':
        return ScrapbookItemRenderers.renderSticker(
          item.content,
          item.customColor,
          isAnimated: shouldAnimateSticker,
        );
      case 'tape':
        return ScrapbookItemRenderers.renderTape(
          item.customColor ?? (item.content is Color ? item.content : const Color(0xFFFBCFE8)),
          style: item.content is Map ? (item.content['style'] ?? 'Classic') : 'Classic',
        );
      case 'photo':
        return ScrapbookItemRenderers.renderPhotoCard(
          item.content,
          frameStyle: item.content is Map ? (item.content['frameStyle'] ?? 'Polaroid') : 'Polaroid',
          enableDevelopingEffect: true,
        );
      case 'voice':
        return ScrapbookItemRenderers.renderVoiceCard(
          content: item.content,
          isPlaying: widget.playingVoiceItemId == item.id,
          playbackProgress: widget.voicePlaybackProgress,
          onPlayToggle: () => widget.onVoicePlayToggle(item),
        );
      default: // 'text'
        return ScrapbookItemRenderers.renderTextCard(
          text: item.content is String ? item.content : 'Reflection Note',
          cardStyle: 'classic',
          textStyle: GoogleFonts.caveat(fontSize: 18, color: Colors.black87),
          customBgColor: item.customColor,
        );
    }
  }
}
