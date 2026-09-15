import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';
import 'metric_trend_chart.dart';

/// What a numeric metric needs to know about itself.
///
/// Weight and basal temperature are the same interaction with different
/// numbers, so they share one sheet rather than two near-identical ones.
class NumericMetric {
  const NumericMetric({
    required this.key,
    required this.title,
    required this.unit,
    required this.eventType,
    required this.payloadKey,
    required this.min,
    required this.max,
    required this.decimals,
    required this.step,
    this.hint,
  });

  /// Storage key under `daily_checkin.json`.
  final String key;
  final String title;
  final String unit;
  final String eventType;

  /// The field the backend validator reads.
  final String payloadKey;

  final double min;
  final double max;
  final int decimals;
  final double step;
  final String? hint;

  /// Basal body temperature.
  ///
  /// The range matches the server's validator exactly. A wider range here
  /// would let her type a number that is then rejected on the wire with
  /// nothing on screen to say why.
  static const bbt = NumericMetric(
    key: 'bbt',
    title: 'Basal temperature',
    unit: '°C',
    eventType: 'bbt_logged',
    payloadKey: 'celsius',
    min: 33,
    max: 43,
    decimals: 2,
    step: 0.05,
    hint: 'Taken before getting up, at the same time each morning.',
  );

  static const weight = NumericMetric(
    key: 'weight',
    title: 'Weight',
    unit: 'kg',
    eventType: 'weight_logged',
    payloadKey: 'kg',
    min: 20,
    max: 400,
    decimals: 1,
    step: 0.1,
  );

  String format(double value) => value.toStringAsFixed(decimals);
}

/// Enter today's reading, and see the recent ones behind it.
class NumericMetricSheet extends StatefulWidget {
  const NumericMetricSheet({
    super.key,
    required this.metric,
    required this.initialValue,
    required this.history,
    required this.onSave,
    this.onClear,
  });

  final NumericMetric metric;

  /// Today's reading, when there is one.
  final double? initialValue;

  /// Recent readings, oldest first, for the chart.
  final List<MetricReading> history;

  final void Function(double value) onSave;
  final VoidCallback? onClear;

  static Future<double?> show(
    BuildContext context, {
    required NumericMetric metric,
    required double? initialValue,
    required List<MetricReading> history,
    required void Function(double) onSave,
    VoidCallback? onClear,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NumericMetricSheet(
        metric: metric,
        initialValue: initialValue,
        history: history,
        onSave: onSave,
        onClear: onClear,
      ),
    );
  }

  @override
  State<NumericMetricSheet> createState() => _NumericMetricSheetState();
}

class _NumericMetricSheetState extends State<NumericMetricSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : widget.metric.format(widget.initialValue!),
  );

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _parsed {
    final raw = _controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _nudge(double by) {
    final m = widget.metric;
    final current = _parsed ?? widget.initialValue ?? _midpointSeed();
    final next = (current + by).clamp(m.min, m.max);
    // Snap to the step, so repeated taps do not accumulate a drift the
    // decimals then hide.
    final snapped = (next / m.step).round() * m.step;
    setState(() {
      _error = null;
      _controller.text = m.format(snapped.clamp(m.min, m.max));
    });
  }

  /// Where the steppers start from when there is nothing logged yet.
  ///
  /// The midpoint of the allowed range would be 36 kg or 38 degrees, neither
  /// of which is a sensible first offer, so each metric seeds from its own
  /// last reading and falls back to a typical value.
  double _midpointSeed() {
    if (widget.history.isNotEmpty) return widget.history.last.value;
    return widget.metric.key == 'bbt' ? 36.5 : 60.0;
  }

  void _save() {
    final m = widget.metric;
    final value = _parsed;
    if (value == null) {
      setState(() => _error = 'Enter a number.');
      return;
    }
    if (value < m.min || value > m.max) {
      // Said here rather than after a rejected request, which would show
      // nothing on screen.
      setState(() => _error =
          'Enter a value between ${m.format(m.min)} and ${m.format(m.max)} ${m.unit}.');
      return;
    }
    widget.onSave(value);
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BlushyColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: BlushyColors.secondaryText),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (m.hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.hint!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.4,
                        color: BlushyColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepButton(
                      icon: Icons.remove,
                      onTap: () => _nudge(-m.step),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _controller,
                        autofocus: widget.initialValue == null,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        style: GoogleFonts.manrope(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: BlushyColors.text,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: m.format(_midpointSeed()),
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: BlushyColors.disabled,
                          ),
                        ),
                      ),
                    ),
                    _StepButton(icon: Icons.add, onTap: () => _nudge(m.step)),
                  ],
                ),
              ),
              Text(
                m.unit,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.secondaryText,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: BlushyColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MetricTrendChart(
                  readings: widget.history,
                  unit: m.unit,
                  decimals: m.decimals,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    if (widget.initialValue != null && widget.onClear != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: IconButton(
                          onPressed: () {
                            widget.onClear!();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          color: BlushyColors.secondaryText,
                          tooltip: 'Remove today\'s reading',
                        ),
                      ),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlushyColors.cardBg,
      shape: const CircleBorder(
        side: BorderSide(color: BlushyColors.border),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: BlushyColors.text),
        ),
      ),
    );
  }
}
