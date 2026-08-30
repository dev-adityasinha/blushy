import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../shared/api_state_card.dart';
import '../doctor_summary_composer.dart';

/// Doctor / appointment companion (spec section 18).
///
/// Builds a summary from the user's own logs over a chosen date range. Every
/// section is labelled as user-reported or app-generated, the user can remove
/// anything they do not want to share before saving, and nothing here is
/// presented as a diagnosis.
class DoctorSummaryScreen extends StatefulWidget {
  const DoctorSummaryScreen({super.key});

  @override
  State<DoctorSummaryScreen> createState() => _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends State<DoctorSummaryScreen> {
  ApiResult<Map<String, dynamic>> _preview = const ApiResult.loading();

  DateTime _from = DateTime.now().subtract(const Duration(days: 90));
  DateTime _to = DateTime.now();
  bool _includeScreenings = false;
  bool _saving = false;

  /// Entries the user has removed, keyed as "sectionKey::index". Removal is
  /// local until they save, so nothing is lost by exploring.
  final Set<String> _removed = {};
  final List<String> _questions = [];
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() => _preview = const ApiResult.loading());
    final result = await DoctorCompanionApi.preview(
      from: _from,
      to: _to,
      includeScreenings: _includeScreenings,
    );
    if (!mounted) return;
    setState(() {
      _preview = result;
      // A new range means the old removals no longer refer to the same entries.
      _removed.clear();
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'SELECT DATE RANGE',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    await _loadPreview();
  }

  void _addQuestion() {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _questions.add(text);
      _questionController.clear();
    });
  }

  /// Builds the composer for the current removals and questions. It owns the
  /// decision about what actually leaves the app.
  DoctorSummaryComposer _composer(List<dynamic> rawSections, [String? disclaimer]) {
    return DoctorSummaryComposer(
      sections: rawSections.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      removed: _removed,
      questions: _questions,
      fromLabel: _dateLabel(_from),
      toLabel: _dateLabel(_to),
      disclaimer: disclaimer,
    );
  }

  Future<void> _save(List<dynamic> rawSections) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sections = _composer(rawSections).keptSections;

    if (sections.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing left to save. Keep at least one entry.')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await DoctorCompanionApi.save(
      from: _from.toIso8601String(),
      to: _to.toIso8601String(),
      sections: sections,
      questions: _questions,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isReady) {
      messenger.showSnackBar(const SnackBar(content: Text('Summary saved.')));
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Could not save the summary.')),
      );
    }
  }

  Future<void> _share(List<dynamic> rawSections, String? disclaimer) async {
    final messenger = ScaffoldMessenger.of(context);
    final composer = _composer(rawSections, disclaimer);
    if (composer.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing left to share. Keep at least one entry.')),
      );
      return;
    }

    // The share sheet is where the user chooses the destination, so nothing
    // leaves the device until they pick one.
    await Share.share(
      composer.toPlainText(),
      subject: 'Blushy summary ${_dateLabel(_from)} to ${_dateLabel(_to)}',
    );
  }

  Future<void> _copy(List<dynamic> rawSections, String? disclaimer) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _composer(rawSections, disclaimer).toPlainText()));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Summary copied.')));
  }

  static String _dateLabel(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('For your appointment')),
      body: ApiStateCard<Map<String, dynamic>>(
        result: _preview,
        onRetry: _loadPreview,
        emptyMessage: 'Nothing logged in this date range. Try a wider range.',
        builder: (context, data) {
          final sections = (data['sections'] as List?) ?? const [];
          if (sections.isEmpty) {
            return _wrap(
              theme,
              [
                Text(
                  'Nothing logged between ${_dateLabel(_from)} and ${_dateLabel(_to)}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          }

          return _wrap(theme, [
            ...sections.map((raw) => _buildSection(theme, Map<String, dynamic>.from(raw as Map))),
            const SizedBox(height: 8),
            _buildQuestions(theme),
            const SizedBox(height: 20),
            _buildDisclaimer(theme, data['disclaimer']?.toString()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(sections),
                child: Text(_saving ? 'Saving…' : 'Save this summary'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _share(sections, data['disclaimer']?.toString()),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(sections, data['disclaimer']?.toString()),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sharing sends this text out of Blushy to whichever app you choose. '
              'Only what is shown above is included.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
          ]);
        },
      ),
    );
  }

  Widget _wrap(ThemeData theme, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRangeControls(theme),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildRangeControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_dateLabel(_from)} — ${_dateLabel(_to)}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Change'),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          value: _includeScreenings,
          onChanged: (value) {
            setState(() => _includeScreenings = value);
            _loadPreview();
          },
          title: const Text('Include questionnaire scores'),
          subtitle: Text(
            'Off by default. These are screening results, not diagnoses.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, Map<String, dynamic> section) {
    final key = section['key']?.toString() ?? '';
    final items = (section['items'] as List?) ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section['title']?.toString() ?? key,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              // Says plainly whether a line is the user's own words or the
              // app's observation (spec section 18).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DoctorSummaryComposer.provenanceLabel(section['provenance']?.toString()),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final text = item is Map ? item['text']?.toString() ?? '' : item.toString();
            final removed = _removed.contains(DoctorSummaryComposer.entryKey(key, index));

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: removed ? TextDecoration.lineThrough : null,
                  color: removed ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
              // Anything can be taken out before the summary is shared.
              trailing: IconButton(
                icon: Icon(removed ? Icons.undo : Icons.close, size: 18),
                tooltip: removed ? 'Put back' : 'Remove from summary',
                onPressed: () {
                  setState(() {
                    if (removed) {
                      _removed.remove(DoctorSummaryComposer.entryKey(key, index));
                    } else {
                      _removed.add(DoctorSummaryComposer.entryKey(key, index));
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Questions to ask', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        ..._questions.asMap().entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value, style: theme.textTheme.bodyMedium),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove question',
                  onPressed: () => setState(() => _questions.removeAt(entry.key)),
                ),
              ),
            ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  hintText: 'Something you want to raise',
                  isDense: true,
                ),
                onSubmitted: (_) => _addQuestion(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add question',
              onPressed: _addQuestion,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisclaimer(ThemeData theme, String? disclaimer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        disclaimer ??
            'Prepared from what you logged in Blushy. This is a record of self-reported '
                'information and app-generated observations, not a diagnosis.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
      ),
    );
  }
}
