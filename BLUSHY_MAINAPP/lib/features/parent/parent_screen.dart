import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';

import '../../services/api_partner_service.dart';
import '../../l10n/app_localizations.dart';

class BlushyParentScreen extends StatefulWidget {
  const BlushyParentScreen({super.key});

  @override
  State<BlushyParentScreen> createState() => _BlushyParentScreenState();
}

class _BlushyParentScreenState extends State<BlushyParentScreen> {
  final ApiPartnerService _partnerService = ApiPartnerService();

  @override
  void initState() {
    super.initState();
    _partnerService.getPartnerStatus();
  }
  // Category tabs for Mother/Guardian Support
  final List<String> _tabs = [
    'Overview',
    'Emergency Kit',
    ' Starters',
    'Parent FAQ'
  ];
  int _selectedTabIndex = 0;

  // FAQ Expandable tiles
  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I know my daughter is about to get her first period?',
      'a': 'Common signs include vaginal discharge (white or yellow marks), breast development, and growth of pubic hair. This typically happens 1-2 years after breast development begins.'
    },
    {
      'q': 'What products should she start with?',
      'a': 'Most young girls prefer simple, thin sanitary pads first. Tampons and cups can be introduced later when they feel comfortable with their bodies.'
    },
    {
      'q': 'Are irregular cycles normal in the beginning?',
      'a': 'Absolutely! It takes up to two years for hormone cycles to mature and regulate. Missing months or unexpected cycles are perfectly normal.'
    }
  ];
  final Set<int> _expandedFaqIndices = {};

  // Conversation Starters list
  final List<String> _starters = [
    "\"Did you know that periods are actually a sign that your body is growing strong and healthy?\"",
    "\"How are you feeling about all the changes your body is going through lately?\"",
    "\"Let's set up a special bag with pads and spare clothes for your locker, just so you feel ready.\"",
    "\"Is there anything you want to ask Docsy or me about periods today?\""
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Editorial Title
                Text(
                  "PARENT MODE",
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  "Supporting Her",
                  style: GoogleFonts.manrope(fontSize: 34, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  "Guides, conversation starters, and period basics for mothers and guardians.",
                  style: GoogleFonts.manrope(fontSize: 13, color: BlushyColors.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 20),

                // Tab choices
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    itemBuilder: (context, idx) {
                      final isActive = _selectedTabIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(_tabs[idx]),
                          selected: isActive,
                          selectedColor: BlushyColors.primary.withValues(alpha: 0.12),
                          backgroundColor: Colors.white,
                          labelStyle: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? BlushyColors.primary : BlushyColors.text,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isActive ? BlushyColors.primary : BlushyColors.border),
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedTabIndex = idx;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Active View Content
                _buildActiveTabContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildEmergencyKitTab();
      case 2:
        return _buildStartersTab();
      case 3:
        return _buildFaqTab();
      default:
        return Container();
    }
  }

  // 1. Overview Tab (Milestones, Articles, General status)
  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daughter Milestone
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDE0D4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MILESTONES",
                style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w900, color: BlushyColors.primary, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              Text(
                "Cycle Setup in Progress",
                style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold, color: BlushyColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                "Your daughter is currently tracking cycle rhythms and logs. Docsy provides supportive insights to keep her prepared.",
                style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Helpful Article links
        Text(
          "HELPFUL ARTICLES",
          style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.1),
        ),
        const SizedBox(height: 12),
        ...[
          {'title': 'Talking to your daughter about periods', 'time': '5 min read'},
          {'title': 'Understanding puberty hormones in teens', 'time': '8 min read'},
        ].map((art) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(art['title']!, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: BlushyColors.text)),
                ),
                Text(art['time']!, style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText)),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 2. Emergency Kit Tab
  Widget _buildEmergencyKitTab() {
    final list = [
      {'title': 'A small pouch or bag', 'desc': 'Keeps items discreet and organized.'},
      {'title': '2-3 Sanitary Pads', 'desc': 'Ultra-thin, regular flow options are best.'},
      {'title': 'A spare pair of underwear', 'desc': 'A crucial backup in case of leaks.'},
      {'title': 'Wet wipes', 'desc': 'For quick, hygienic cleanup in school bathrooms.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).pPreparingHerEmergencySchool,
          style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.1),
        ),
        const SizedBox(height: 16),
        ...list.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: BlushyColors.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title']!, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text)),
                      const SizedBox(height: 2),
                      Text(item['desc']!, style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 3. Conversation Starters Tab
  Widget _buildStartersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).pConversationStarters,
          style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.1),
        ),
        const SizedBox(height: 12),
        ..._starters.map((starter) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Text(
              starter,
              style: GoogleFonts.manrope(fontSize: 18, color: BlushyColors.text, fontStyle: FontStyle.italic, height: 1.3),
            ),
          );
        }),
      ],
    );
  }

  // 4. FAQ Tab
  Widget _buildFaqTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).pParentFrequentQuestions,
          style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: BlushyColors.secondaryText, letterSpacing: 1.1),
        ),
        const SizedBox(height: 12),
        ..._faqs.asMap().entries.map((entry) {
          final idx = entry.key;
          final faq = entry.value;
          final isExpanded = _expandedFaqIndices.contains(idx);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BlushyColors.border),
            ),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (val) {
                setState(() {
                  if (val) {
                    _expandedFaqIndices.add(idx);
                  } else {
                    _expandedFaqIndices.remove(idx);
                  }
                });
              },
              title: Text(faq['q']!, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold, color: BlushyColors.text)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                  child: Text(faq['a']!, style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText, height: 1.45)),
                )
              ],
            ),
          );
        }),
      ],
    );
  }
}
