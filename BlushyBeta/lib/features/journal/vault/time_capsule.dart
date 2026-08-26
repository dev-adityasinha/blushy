import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimeCapsuleItem {
  final String id;
  final String title;
  final String contentPayload;
  final DateTime unlockDate;
  final bool isUnlocked;

  TimeCapsuleItem({
    required this.id,
    required this.title,
    required this.contentPayload,
    required this.unlockDate,
    required this.isUnlocked,
  });
}

class TimeCapsuleWidget extends StatefulWidget {
  const TimeCapsuleWidget({super.key});

  @override
  State<TimeCapsuleWidget> createState() => _TimeCapsuleWidgetState();
}

class _TimeCapsuleWidgetState extends State<TimeCapsuleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _unlockAnimController;
  final List<TimeCapsuleItem> _capsules = [
    TimeCapsuleItem(
      id: 'capsule_1',
      title: 'Letter to Future Self (1 Year)',
      contentPayload: 'Remember to stay gentle with yourself. You are doing wonderfully.',
      unlockDate: DateTime.now().add(const Duration(days: 365)),
      isUnlocked: false,
    ),
    TimeCapsuleItem(
      id: 'capsule_2',
      title: 'Open Today Memory 🎁',
      contentPayload: 'A special quiet morning reflection from 3 months ago.',
      unlockDate: DateTime.now().subtract(const Duration(hours: 1)),
      isUnlocked: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _unlockAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _unlockAnimController.dispose();
    super.dispose();
  }

  void _ceremonialUnlock(TimeCapsuleItem item) {
    _unlockAnimController.forward(from: 0.0);
    showDialog(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: _unlockAnimController,
          builder: (context, child) {
            final val = _unlockAnimController.value;
            return AlertDialog(
              backgroundColor: Color.lerp(const Color(0xFF1E293B), const Color(0xFFFFFBEB), val),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Icon(val < 0.6 ? Icons.lock_clock_rounded : Icons.lock_open_rounded, color: const Color(0xFFD97706), size: 36),
                  const SizedBox(height: 8),
                  Text(val < 0.6 ? 'Untying Ceremonial Ribbon...' : item.title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: val > 0.6
                  ? Text(item.contentPayload, style: GoogleFonts.caveat(fontSize: 20, color: const Color(0xFF78350F)))
                  : const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Color(0xFFD97706)))),
              actions: [
                if (val >= 1.0)
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text('Memory Time Capsule ⌛', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _capsules.length,
        itemBuilder: (context, i) {
          final item = _capsules[i];
          final canUnlock = DateTime.now().isAfter(item.unlockDate);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(canUnlock ? Icons.mark_email_read_rounded : Icons.lock_rounded, color: canUnlock ? const Color(0xFF10B981) : const Color(0xFFD97706)),
              title: Text(item.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(canUnlock ? 'Ready for Ceremonial Unlock!' : 'Locked until ${item.unlockDate.toString().substring(0, 10)}', style: GoogleFonts.poppins(fontSize: 11)),
              trailing: ElevatedButton(
                onPressed: canUnlock ? () => _ceremonialUnlock(item) : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                child: Text(canUnlock ? 'Unlock' : 'Locked', style: const TextStyle(color: Colors.white)),
              ),
            ),
          );
        },
      ),
    );
  }
}
