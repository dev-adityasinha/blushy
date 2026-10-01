import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_auth_service.dart';
import '../../../services/sia_dashboard_service.dart';
import 'profile_answers.dart';

/// A focused editor that lets an already-onboarded user set the two lifestyle
/// answers that drive the home cards: physical activities (everyone) and
/// smoking status (18+ only). Saves to the local lifestyle store (instant) and
/// the backend (durable / cross-device), then refreshes the dashboard.
class LifestyleEditorSheet extends StatefulWidget {
  const LifestyleEditorSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LifestyleEditorSheet(),
    );
  }

  @override
  State<LifestyleEditorSheet> createState() => _LifestyleEditorSheetState();
}

class _LifestyleEditorSheetState extends State<LifestyleEditorSheet> {
  static const Color _crimson = Color(0xFFDD0D22);
  static const Color _textMain = Color(0xFF221510);
  static const Color _textMuted = Color(0xFF7A6B72);

  static const List<String> _activityOptions = [
    'Swimming',
    'Gym & strength training',
    'Yoga',
    'Dance',
    'Running',
    'Cycling',
    'Badminton',
    'Throwball',
    'Kho-Kho',
    'Volleyball',
    'Walking',
    'Not very active right now',
  ];

  static const List<String> _smokingOptions = [
    'No, never',
    'Once in a while',
    'Yes, regularly',
    "I'm trying to quit",
  ];

  final Set<String> _activities = {};
  String? _smoking;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activities.addAll(profileListAnswer('physical_activities'));
    _smoking = profileStringAnswer('smoking_status');
  }

  bool get _is18Plus {
    final age = profileAgeYears();
    return age != null && age >= 18;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final activities = _activities.toList();

    writeLifestyleAnswers(
      activities: activities,
      smokingStatus: _smoking,
    );

    try {
      await ApiAuthService().saveOnboardingAnswers({
        'physical_activities': activities,
        if (_smoking != null && _smoking!.isNotEmpty) 'smoking_status': _smoking,
      });
    } catch (_) {
      // Saved locally regardless; the next backend round-trip will retry.
    }

    SiaDashboardService().triggerRefresh();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFECE4DC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your activities & lifestyle', // i18n-ignore: lifestyle editor (English copy)
              style: GoogleFonts.cormorantGaramond(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'These tailor your home — gentle activity tips, and supportive care if you need it.', // i18n-ignore: lifestyle editor (English copy)
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.4,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How do you love to move?', // i18n-ignore: lifestyle editor (English copy)
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _textMain,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activityOptions.map((opt) {
                final selected = _activities.contains(opt);
                return _chip(
                  label: opt,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _activities.remove(opt);
                    } else {
                      _activities.add(opt);
                    }
                  }),
                );
              }).toList(),
            ),
            if (_is18Plus) ...[
              const SizedBox(height: 22),
              Text(
                'Do you smoke or vape?', // i18n-ignore: lifestyle editor (English copy)
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No judgment — it only helps Blushy look after you.', // i18n-ignore: lifestyle editor (English copy)
                style: GoogleFonts.manrope(fontSize: 11.5, color: _textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _smokingOptions.map((opt) {
                  return _chip(
                    label: opt,
                    selected: _smoking == opt,
                    onTap: () => setState(() => _smoking = opt),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimson,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _crimson.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save', // i18n-ignore: lifestyle editor (English copy)
                        style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _crimson.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _crimson : const Color(0xFFE6DCD3),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? _crimson : _textMain,
          ),
        ),
      ),
    );
  }
}
