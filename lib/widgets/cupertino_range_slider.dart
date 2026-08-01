import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';

/// Quale maniglia è attiva durante un trascinamento — `null` a riposo.
enum _Handle { start, end }

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

class _CupertinoRangeSliderState extends State<CupertinoRangeSlider>
    with SingleTickerProviderStateMixin {
  // Area di tocco piena 44x44pt anche se il thumb visivo è più piccolo.
  static const _thumbTouchSize = 44.0;
  static const _thumbVisualSize = 14.0;
  static const _thumbActiveScale = 1.3;
  static const _trackHeight = 4.0;
  static const _minGapMonths = 1;

  // Stessa fisica "a molla" di `SpringButton` (ingrandimento rapido
  // all'afferrare, overshoot elastico al rilascio) — qui applicata in
  // crescita invece che in pressione, per dare un feedback tattile chiaro
  // di "sto trascinando questa maniglia".
  static const Curve _grabCurve = Curves.easeOut;
  static const Curve _releaseCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  late double _startFraction;
  late double _endFraction;

  late final AnimationController _scaleController;
  _Handle? _activeHandle;
  int? _lastHapticMonthOffset;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, value: 0.0);
    _startFraction = _fractionFor(widget.startValue);
    _endFraction = _fractionFor(widget.endValue);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
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

  // Unità del range in mesi interi (non millisecondi): i periodi delle
  // buste paga sono sempre il 1° del mese (`DateTime(anno, mese)`) — un
  // fraction→data continuo su millisecondi poteva restituire un giorno a
  // metà mese (es. 15 marzo) che, pur mostrando l'etichetta "mar '26",
  // escludeva dal filtro la busta paga di marzo (1° marzo, "prima" del
  // valore di inizio range). Agganciando ogni posizione del thumb a un
  // passo mensile, la data risultante coincide sempre con un periodo reale.
  int get _totalMonths =>
      (widget.maxDate.year - widget.minDate.year) * 12 +
      (widget.maxDate.month - widget.minDate.month);

  double get _minGapFraction {
    if (_totalMonths <= 0) return 0;
    return (_minGapMonths / _totalMonths).clamp(0.0, 0.9);
  }

  double _fractionFor(DateTime date) {
    if (_totalMonths <= 0) return 0;
    final monthsFromMin = (date.year - widget.minDate.year) * 12 +
        (date.month - widget.minDate.month);
    return (monthsFromMin / _totalMonths).clamp(0.0, 1.0);
  }

  DateTime _dateFor(double fraction) {
    final monthsOffset =
        (_totalMonths * fraction.clamp(0.0, 1.0)).round().clamp(0, _totalMonths);
    return DateTime(widget.minDate.year, widget.minDate.month + monthsOffset);
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

  /// Converte una posizione orizzontale locale (relativa all'intera area
  /// dello slider, non al singolo thumb) in una fraction 0..1 — stessa
  /// mappatura usata per disegnare i thumb (`_thumbTouchSize/2` di margine
  /// su ciascun lato), così la maniglia risulta sempre esattamente sotto il
  /// punto toccato invece di conservare lo scarto rispetto a dove è stata
  /// afferrata inizialmente.
  double _fractionForLocalDx(double dx, double usableWidth) {
    if (usableWidth <= 0) return 0;
    return ((dx - _thumbTouchSize / 2) / usableWidth).clamp(0.0, 1.0);
  }

  void _handleDragStart(double dx, double usableWidth) {
    final fraction = _fractionForLocalDx(dx, usableWidth);
    // La maniglia attiva è quella più vicina al punto toccato — permette di
    // afferrare l'una o l'altra toccando in un punto qualunque della barra,
    // non solo esattamente sul pallino.
    final handle = (fraction - _startFraction).abs() <=
            (fraction - _endFraction).abs()
        ? _Handle.start
        : _Handle.end;
    _activeHandle = handle;
    _lastHapticMonthOffset = (_totalMonths * fraction).round();
    _scaleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 110),
      curve: _grabCurve,
    );
    _applyFraction(fraction);
  }

  void _handleDragUpdate(double dx, double usableWidth) {
    if (_activeHandle == null) return;
    _applyFraction(_fractionForLocalDx(dx, usableWidth));
  }

  void _applyFraction(double fraction) {
    setState(() {
      if (_activeHandle == _Handle.start) {
        _startFraction = fraction.clamp(0.0, _endFraction - _minGapFraction);
      } else if (_activeHandle == _Handle.end) {
        _endFraction = fraction.clamp(_startFraction + _minGapFraction, 1.0);
      }
    });
    _maybeHapticFeedback();
    _notify();
  }

  /// Una leggera vibrazione ogni volta che il trascinamento fa "scattare"
  /// il valore su un mese diverso — stesso rinforzo tattile dei picker
  /// nativi iOS (es. il selettore data), utile perché il valore reale è
  /// sempre agganciato a passi mensili anche se il dito si muove in modo
  /// continuo.
  void _maybeHapticFeedback() {
    final current =
        _activeHandle == _Handle.start ? _startFraction : _endFraction;
    final monthOffset = (_totalMonths * current).round();
    if (_lastHapticMonthOffset != null &&
        _lastHapticMonthOffset != monthOffset) {
      HapticFeedback.selectionClick();
    }
    _lastHapticMonthOffset = monthOffset;
  }

  void _handleDragEnd() {
    _scaleController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: _releaseCurve,
    );
    _activeHandle = null;
    _notifyEnd();
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

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) => _handleDragStart(
                    details.localPosition.dx, usableWidth),
                onHorizontalDragUpdate: (details) => _handleDragUpdate(
                    details.localPosition.dx, usableWidth),
                onHorizontalDragEnd: (_) => _handleDragEnd(),
                onHorizontalDragCancel: _handleDragEnd,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: _thumbTouchSize / 2,
                      right: _thumbTouchSize / 2,
                      child: Container(
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius:
                              BorderRadius.circular(_trackHeight / 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: startCenter,
                      child: Container(
                        width:
                            (endCenter - startCenter).clamp(0.0, usableWidth),
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius:
                              BorderRadius.circular(_trackHeight / 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: startCenter - _thumbTouchSize / 2,
                      child: _AnimatedThumb(
                        scaleController: _scaleController,
                        active: _activeHandle == _Handle.start,
                      ),
                    ),
                    Positioned(
                      left: endCenter - _thumbTouchSize / 2,
                      child: _AnimatedThumb(
                        scaleController: _scaleController,
                        active: _activeHandle == _Handle.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Thumb con scala animata: cresce quando [active] (maniglia sotto
/// trascinamento), resta a riposo altrimenti — entrambi i thumb osservano
/// lo stesso [scaleController] (un solo trascinamento alla volta è
/// possibile), ma solo quello marcato [active] applica la trasformazione.
class _AnimatedThumb extends StatelessWidget {
  final AnimationController scaleController;
  final bool active;

  const _AnimatedThumb({required this.scaleController, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _CupertinoRangeSliderState._thumbTouchSize,
      height: _CupertinoRangeSliderState._thumbTouchSize,
      child: Center(
        child: AnimatedBuilder(
          animation: scaleController,
          builder: (context, child) {
            final scale = active
                ? 1.0 +
                    scaleController.value *
                        (_CupertinoRangeSliderState._thumbActiveScale - 1.0)
                : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: _RangeThumb(active: active),
        ),
      ),
    );
  }
}

class _RangeThumb extends StatelessWidget {
  final bool active;

  const _RangeThumb({this.active = false});

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
            color: CupertinoColors.black.withValues(alpha: active ? 0.28 : 0.15),
            blurRadius: active ? 10 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
