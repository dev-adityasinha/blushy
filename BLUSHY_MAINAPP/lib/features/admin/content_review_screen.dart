import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_blushy_service.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';

/// Where a clinical reviewer reads and approves health content.
///
/// The backend has carried the whole review API from the start -- queue,
/// status transitions, audit trail -- but nothing called it. A reviewer had no
/// route and no button, so the only way to approve anything was curl or a
/// script, which is why 74 education articles sat unreviewed.
///
/// Approving writes the reviewer's name and the date into the content audit
/// trail. That record is the point of the whole gate: it is what separates
/// "someone read this" from "nobody did".
class ContentReviewScreen extends StatefulWidget {
  const ContentReviewScreen({super.key});

  @override
  State<ContentReviewScreen> createState() => _ContentReviewScreenState();
}

class _ContentReviewScreenState extends State<ContentReviewScreen> {
  final TextEditingController _reviewerController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _awaiting = const [];
  List<Map<String, dynamic>> _overdue = const [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ContentReviewApi.queue();
    if (!mounted) return;

    setState(() {
      _loading = false;
      final data = result.data;
      if (data == null) {
        // Most likely cause is not being an admin, which the server enforces.
        _error = result.errorMessage ?? 'Could not load the review queue.';
        return;
      }
      _awaiting = ((data['awaitingReview'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _overdue = ((data['reviewOverdue'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  bool get _hasReviewerName => _reviewerController.text.trim().length >= 3;

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final contentId = item['contentId']?.toString() ?? '';
    if (contentId.isEmpty) return;

    final reviewer = _reviewerController.text.trim();
    if (status == 'approved' && !_hasReviewerName) {
      _notify('Enter your name before approving. It goes on the record.');
      return;
    }

    setState(() => _busy.add(contentId));
    final result = await ContentReviewApi.setStatus(
      contentId,
      status: status,
      reviewer: status == 'approved' ? reviewer : null,
    );
    if (!mounted) return;
    setState(() => _busy.remove(contentId));

    if (result.data == null) {
      _notify(result.errorMessage ?? 'That change could not be saved.');
      return;
    }

    await _load();
    if (!mounted) return;
    _notify(status == 'approved'
        ? 'Approved, recorded against $reviewer.'
        : 'Sent back as a draft.');
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Full text plus the actions, so nothing is approved from a title alone.
  void _openItem(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              item['title']?.toString() ?? '',
              style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              [
                (item['lifeStages'] as List?)?.join(', ') ?? '',
                (item['topics'] as List?)?.join(', ') ?? '',
              ].where((s) => s.isNotEmpty).join(' • '),
              style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText),
            ),
            const SizedBox(height: 16),
            Text(
              item['body']?.toString() ?? '',
              style: GoogleFonts.manrope(fontSize: 13, height: 1.55),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BlushyColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOURCE',
                      style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: BlushyColors.secondaryText)),
                  const SizedBox(height: 4),
                  Text(
                    item['source']?.toString() ?? 'No source recorded.',
                    style: GoogleFonts.manrope(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _setStatus(item, 'draft');
                    },
                    child: const Text('Send back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _setStatus(item, 'approved');
                    },
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.dark),
        title: Text(
          'Content review',
          style: GoogleFonts.manrope(
              fontSize: 16, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.primary),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _reviewerController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Your name and credentials',
                      helperText: AppLocalizations.of(context).crRecordedAgainstEverythingYou,
                      helperMaxLines: 2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader('AWAITING REVIEW', _awaiting.length),
                  if (_awaiting.isEmpty)
                    _emptyNote('Nothing is waiting for review.')
                  else
                    ..._awaiting.map(_buildRow),
                  const SizedBox(height: 24),
                  _sectionHeader('REVIEW OVERDUE', _overdue.length),
                  if (_overdue.isEmpty)
                    _emptyNote('Nothing approved has passed its review date.')
                  else
                    ..._overdue.map(_buildRow),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String label, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: BlushyColors.secondaryText,
          ),
        ),
      );

  Widget _emptyNote(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: GoogleFonts.manrope(fontSize: 12, color: BlushyColors.secondaryText)),
      );

  Widget _buildRow(Map<String, dynamic> item) {
    final contentId = item['contentId']?.toString() ?? '';
    final busy = _busy.contains(contentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border),
      ),
      child: ListTile(
        title: Text(
          item['title']?.toString() ?? '',
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          (item['lifeStages'] as List?)?.join(', ') ?? '',
          style: GoogleFonts.manrope(fontSize: 11, color: BlushyColors.secondaryText),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right_rounded, color: BlushyColors.secondaryText),
        // Opens the full text: approving from a list of titles would defeat
        // the purpose of the review.
        onTap: busy ? null : () => _openItem(item),
      ),
    );
  }
}
