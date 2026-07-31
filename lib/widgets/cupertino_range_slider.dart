import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';

/// Selettore di periodo a due maniglie indipendenti (stile "base slider" a
/// doppio thumb) — nessun `CupertinoSlider` nativo perché quello è a un solo
/// pollice. Usato dalla sotto-navigazione Statistiche per filtrare i grafici
/// a un intervallo di mesi tra [minDate] e [maxDate].
///
/// [onChanged] è invocato ad ogni frame di drag (per un feedback live sui
/// grafici); [onChangeEnd] solo al rilascio, se serve distinguere gli eventi
/// intermedi da quello definitivo.
class CupertinoRangeSlider extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;
  final ValueChanged<({DateTime start, DateTime end})>? onChangeEnd;

  const CupertinoRangeSlider({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<CupertinoRangeSlider> createState() => _CupertinoRangeSliderState();
}

class _CupertinoRangeSliderState extends State<CupertinoRangeSlider> {
  // Area di tocco piena 44x44pt anche se il thumb visivo è più piccolo.
  static const _thumbTouchSize = 44.0;
  static const _thumbVisualSize = 22.0;
  static const _trackHeight = 4.0;
  static const _minGapMs = 30 * 24 * 60 * 60 * 1000; // ~1 mese

  late double _startFraction;
  late double _endFraction;

  @override
  void initState() {
    super.initState();
    _startFraction = _fractionFor(widget.startValue);
    _endFraction = _fractionFor(widget.endValue);
  }

  @override
  void didUpdateWidget(covariant CupertinoRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startValue != widget.startValue ||
        oldWidget.minDate != widget.minDate ||
        oldWidget.maxDate != widget.maxDate) {
      _startFraction = _fractionFor(widget.startValue);
    }
    if (oldWidget.endValue != widget.endValue ||
        oldWidget.minDate != widget.minDate ||
        oldWidget.maxDate != widget.maxDate) {
      _endFraction = _fractionFor(widget.endValue);
    }
  }

  double get _totalMs =>
      widget.maxDate.difference(widget.minDate).inMilliseconds.toDouble();

  double get _minGapFraction {
    if (_totalMs <= 0) return 0;
    return (_minGapMs / _totalMs).clamp(0.0, 0.9);
  }

  double _fractionFor(DateTime date) {
    if (_totalMs <= 0) return 0;
    return (date.difference(widget.minDate).inMilliseconds / _totalMs)
        .clamp(0.0, 1.0);
  }

  DateTime _dateFor(double fraction) {
    final ms = (_totalMs * fraction.clamp(0.0, 1.0)).round();
    return widget.minDate.add(Duration(milliseconds: ms));
  }

  void _notify() {
    widget.onChanged(
      (start: _dateFor(_startFraction), end: _dateFor(_endFraction)),
    );
  }

  void _notifyEnd() {
    widget.onChangeEnd?.call(
      (start: _dateFor(_startFraction), end: _dateFor(_endFraction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackColor =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              periodoAxisLabel(_dateFor(_startFraction)),
              style: AppTextStyles.cardLabel.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              periodoAxisLabel(_dateFor(_endFraction)),
              style: AppTextStyles.cardLabel.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _thumbTouchSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth - _thumbTouchSize;
              final startCenter =
                  _thumbTouchSize / 2 + _startFraction * usableWidth;
              final endCenter =
                  _thumbTouchSize / 2 + _endFraction * usableWidth;

              void onStartDrag(double dx) {
                setState(() {
                  final delta = dx / usableWidth;
                  _startFraction = (_startFraction + delta)
                      .clamp(0.0, _endFraction - _minGapFraction);
                });
                _notify();
              }

              void onEndDrag(double dx) {
                setState(() {
                  final delta = dx / usableWidth;
                  _endFraction = (_endFraction + delta)
                      .clamp(_startFraction + _minGapFraction, 1.0);
                });
                _notify();
              }

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: _thumbTouchSize / 2,
                    right: _thumbTouchSize / 2,
                    child: Container(
                      height: _trackHeight,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: startCenter,
                    child: Container(
                      width: (endCenter - startCenter).clamp(0.0, usableWidth),
                      height: _trackHeight,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: startCenter - _thumbTouchSize / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) =>
                          onStartDrag(details.delta.dx),
                      onHorizontalDragEnd: (_) => _notifyEnd(),
                      child: const SizedBox(
                        width: _thumbTouchSize,
                        height: _thumbTouchSize,
                        child: Center(child: _RangeThumb()),
                      ),
                    ),
                  ),
                  Positioned(
                    left: endCenter - _thumbTouchSize / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) =>
                          onEndDrag(details.delta.dx),
                      onHorizontalDragEnd: (_) => _notifyEnd(),
                      child: const SizedBox(
                        width: _thumbTouchSize,
                        height: _thumbTouchSize,
                        child: Center(child: _RangeThumb()),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RangeThumb extends StatelessWidget {
  const _RangeThumb();

  @override
  Widget build(BuildContext context) {
    final accent =
        CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    return Container(
      width: _CupertinoRangeSliderState._thumbVisualSize,
      height: _CupertinoRangeSliderState._thumbVisualSize,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
