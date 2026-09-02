import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';

class VaultCollection {
  final String id;
  final String title;
  final String emoji;
  final String coverColorHex;
  final List<String> entryIds;

  VaultCollection({
    required this.id,
    required this.title,
    required this.emoji,
    required this.coverColorHex,
    required this.entryIds,
  });
}

class MemoryVaultWidget extends StatefulWidget {
  final List<LocalJournalEntry> entries;
  final ValueChanged<LocalJournalEntry> onEntryTap;

  const MemoryVaultWidget({
    super.key,
    required this.entries,
    required this.onEntryTap,
  });

  @override
  State<MemoryVaultWidget> createState() => _MemoryVaultWidgetState();
}

class _MemoryVaultWidgetState extends State<MemoryVaultWidget> {
  final List<VaultCollection> _customCollections = [
    VaultCollection(id: 'fav', title: 'Favorites', emoji: '⭐', coverColorHex: '0xFFFCD34D', entryIds: []),
    VaultCollection(id: 'happy', title: 'Happy Memories', emoji: '😊', coverColorHex: '0xFFF472B6', entryIds: []),
    VaultCollection(id: 'travel', title: 'Road Trips', emoji: '🚗', coverColorHex: '0xFF60A5FA', entryIds: []),
    VaultCollection(id: 'dog', title: 'My Pet', emoji: '🐶', coverColorHex: '0xFFF97316', entryIds: []),
    VaultCollection(id: 'goals', title: '2027 Goals', emoji: '🌸', coverColorHex: '0xFF34D399', entryIds: []),
  ];

  void _createCustomCollection() {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Custom Vault Collection', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Wedding, College, Books...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _customCollections.add(VaultCollection(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      title: titleCtrl.text.trim(),
                      emoji: '📁',
                      coverColorHex: '0xFFC084FC',
                      entryIds: [],
                    ));
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        title: Text('Memory Vault 🏆', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: BlushyColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded, color: Color(0xFFD97706)),
            tooltip: 'New Collection',
            onPressed: _createCustomCollection,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
        ),
        itemCount: _customCollections.length,
        itemBuilder: (context, i) {
          final col = _customCollections[i];
          final Color colColor = Color(int.parse(col.coverColorHex));

          return GestureDetector(
            onTap: () {
              if (widget.entries.isNotEmpty) {
                widget.onEntryTap(widget.entries.first);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colColor.withValues(alpha: 0.6)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(col.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(col.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('${widget.entries.length} Memories', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
