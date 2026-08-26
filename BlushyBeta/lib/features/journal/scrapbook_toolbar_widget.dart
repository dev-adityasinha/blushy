import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScrapbookToolbarWidget extends StatelessWidget {
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onColorEdit;
  final VoidCallback onDeselect;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final String? itemType;

  const ScrapbookToolbarWidget({
    super.key,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onDuplicate,
    required this.onDelete,
    required this.onColorEdit,
    required this.onDeselect,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onUndo != null)
            IconButton(
              icon: Icon(Icons.undo_rounded, color: canUndo ? Colors.white : Colors.white30, size: 18),
              onPressed: canUndo ? onUndo : null,
              tooltip: 'Undo',
            ),
          if (onRedo != null)
            IconButton(
              icon: Icon(Icons.redo_rounded, color: canRedo ? Colors.white : Colors.white30, size: 18),
              onPressed: canRedo ? onRedo : null,
              tooltip: 'Redo',
            ),
          if (onUndo != null || onRedo != null)
            const VerticalDivider(color: Colors.white24, width: 12, indent: 6, endIndent: 6),
          _buildToolButton(
            icon: Icons.flip_to_front_rounded,
            label: 'Front',
            onTap: onBringToFront,
          ),
          _buildToolButton(
            icon: Icons.flip_to_back_rounded,
            label: 'Back',
            onTap: onSendToBack,
          ),
          _buildToolButton(
            icon: Icons.palette_outlined,
            label: itemType == 'text' ? 'Style' : 'Color',
            onTap: onColorEdit,
          ),
          _buildToolButton(
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: onDuplicate,
          ),
          _buildToolButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFF43F5E),
            onTap: onDelete,
          ),
          const VerticalDivider(color: Colors.white24, width: 12, indent: 6, endIndent: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            onPressed: onDeselect,
            tooltip: 'Deselect Item',
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
