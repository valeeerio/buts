import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pulse_surface.dart';

/// Selettore di periodo "anni a schede + griglia mesi", tutto a tocchi
/// precisi — sostituisce `CupertinoRangeSlider` (drag a doppia maniglia,
/// percepito impreciso/scomodo con molti mesi di storico, vedi CLAUDE.md).
///
/// Stesso "contratto" verso il resto della schermata Statistiche del vecchio
/// slider: [minDate]/[maxDate] delimitano il range disponibile,
/// [startValue]/[endValue] il range corrente, [onChanged] notifica un nuovo
/// range completo `(start, end)` con `start <= end` sempre garantito.
class PeriodYearMonthPicker extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  /// Notificato subito dopo [onChanged] quando il tocco appena ricevuto
  /// conclude la selezione a due tocchi (secondo tocco, o ri-tocco dello
  /// stesso mese già impostato come unico estremo) — a differenza di
  /// [onChanged], non scatta sul primo tocco che avvia una nuova selezione
  /// (che resta "in sospeso" in attesa del secondo tocco). Solo un segnale
  /// aggiuntivo, non duplica la logica di selezione: opzionale, usato da un
  /// widget contenitore (es. il chip riassuntivo collassabile) per sapere
  /// quando è il momento giusto per richiudersi.
  final VoidCallback? onSelectionComplete;

  const PeriodYearMonthPicker({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
    this.onSelectionComplete,
  });

  /// Etichetta leggibile del range `start → end`, es. "Gennaio 2026 →
  /// Febbraio 2026" o solo "Gennaio 2026" se il range è un singolo mese.
  /// Esposta come funzione statica per essere riusata da un widget
  /// contenitore (es. il chip riassuntivo collassato) senza duplicare la
  /// logica di formattazione.
  static String formatRangeLabel(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return _formatMeseAnno(start);
    }
    return '${_formatMeseAnno(start)} → ${_formatMeseAnno(end)}';
  }

  static String _formatMeseAnno(DateTime date) {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  State<PeriodYearMonthPicker> createState() => _PeriodYearMonthPickerState();
}

class _PeriodYearMonthPickerState extends State<PeriodYearMonthPicker> {
  static const _monthsPerRow = 4;

  // Larghezza fissa delle schede anno (+ separatore), usata per calcolare
  // l'offset di scroll esatto verso la scheda dell'anno attivo — evita di
  // dover misurare i `RenderBox` a runtime. Deve restare abbastanza larga da
  // contenere un anno a 4 cifre (es. "2026") con il padding orizzontale di
  // `_YearChip` sottratto, usando il font di sistema (vedi
  // `AppTextStyles.pulseBodyEmphasis`, w500 16px) — con un padding più
  // generoso il testo andava a capo su due righe e la seconda riga veniva
  // ritagliata dall'altezza fissa di 40, mostrando solo "202" invece di
  // "2026" (bug corretto 2026-09-09).
  static const double _yearChipWidth = 72;
  static const double _yearChipSpacing = AppSpacing.sm;

  final ScrollController _yearScrollController = ScrollController();

  late int _activeYear;

  // Estremo "in sospeso" di una selezione a un solo tocco — quando è
  // impostato, il range corrente è collassato a un solo mese
  // (`start == end`) in attesa del secondo tocco che lo estende/scambia.
  late DateTime _pendingStart;
  bool _rangeComplete = true;

  // Ultimo range notificato da questo widget stesso via [widget.onChanged]:
  // distingue un aggiornamento di `startValue`/`endValue` che è solo l'eco
  // del nostro ultimo tocco (in quel caso lo stato di selezione interno,
  // es. `_rangeComplete == false` dopo un primo tocco, va preservato) da un
  // aggiornamento realmente esterno (es. reset del filtro dal chiamante),
  // che invece deve risincronizzare lo stato interno da zero.
  ({DateTime start, DateTime end})? _lastEmitted;

  @override
  void initState() {
    super.initState();
    _activeYear = widget.endValue.year;
    _pendingStart = widget.startValue;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveYear(animate: false);
    });
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveYear({bool animate = true}) {
    if (!_yearScrollController.hasClients) return;
    final index = _availableYears.indexOf(_activeYear);
    if (index < 0) return;
    final position = _yearScrollController.position;
    final itemStart = index * (_yearChipWidth + _yearChipSpacing);
    final itemEnd = itemStart + _yearChipWidth;
    final viewport = position.viewportDimension;
    final maxScroll = position.maxScrollExtent;
    double target = position.pixels;
    if (itemStart < position.pixels) {
      target = itemStart;
    } else if (itemEnd > position.pixels + viewport) {
      target = itemEnd - viewport;
    }
    target = target.clamp(0.0, maxScroll < 0 ? 0.0 : maxScroll);
    if (animate) {
      _yearScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _yearScrollController.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant PeriodYearMonthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.startValue != widget.startValue ||
        oldWidget.endValue != widget.endValue;
    if (!changed) return;
    final isOwnEcho = _lastEmitted != null &&
        _lastEmitted!.start == widget.startValue &&
        _lastEmitted!.end == widget.endValue;
    if (isOwnEcho) return;
    _pendingStart = widget.startValue;
    _rangeComplete = true;
  }

  void _emit(DateTime start, DateTime end) {
    _lastEmitted = (start: start, end: end);
    widget.onChanged((start: start, end: end));
  }

  List<int> get _availableYears {
    final years = <int>[];
    for (var y = widget.minDate.year; y <= widget.maxDate.year; y++) {
      years.add(y);
    }
    return years;
  }

  bool _isWithinAvailableRange(DateTime month) {
    final min = DateTime(widget.minDate.year, widget.minDate.month);
    final max = DateTime(widget.maxDate.year, widget.maxDate.month);
    return !month.isBefore(min) && !month.isAfter(max);
  }

  bool _isInSelectedRange(DateTime month) {
    final start = DateTime(widget.startValue.year, widget.startValue.month);
    final end = DateTime(widget.endValue.year, widget.endValue.month);
    return !month.isBefore(start) && !month.isAfter(end);
  }

  bool _isRangeEndpoint(DateTime month) {
    final start = DateTime(widget.startValue.year, widget.startValue.month);
    final end = DateTime(widget.endValue.year, widget.endValue.month);
    return month == start || month == end;
  }

  void _handleMonthTap(DateTime month) {
    if (!_isWithinAvailableRange(month)) return;
    HapticFeedback.selectionClick();

    if (_rangeComplete) {
      // Ricomincia una nuova selezione: primo tocco -> nuovo inizio,
      // collassato a un range di un solo mese finché non arriva il
      // secondo tocco.
      setState(() {
        _pendingStart = month;
        _rangeComplete = false;
      });
      _emit(month, month);
      return;
    }

    // Secondo tocco: completa il range con [_pendingStart].
    if (month == _pendingStart) {
      // Tocco sullo stesso mese già impostato come unico estremo: collassa
      // (resta) un range di un solo mese e considera il ciclo concluso.
      setState(() => _rangeComplete = true);
      _emit(month, month);
      widget.onSelectionComplete?.call();
      return;
    }

    final start = month.isBefore(_pendingStart) ? month : _pendingStart;
    final end = month.isBefore(_pendingStart) ? _pendingStart : month;
    setState(() => _rangeComplete = true);
    _emit(start, end);
    widget.onSelectionComplete?.call();
  }

  String get _periodoSelezionatoLabel => PeriodYearMonthPicker.formatRangeLabel(
        widget.startValue,
        widget.endValue,
      );

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final onAccent =
        CupertinoDynamicColor.resolve(AppColors.pulseOnAccent, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodoSelezionatoLabel,
          style: AppTextStyles.pulseDisplaySmall.copyWith(color: textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            controller: _yearScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _availableYears.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: _yearChipSpacing),
            itemBuilder: (context, index) {
              final year = _availableYears[index];
              final isActive = year == _activeYear;
              return SizedBox(
                width: _yearChipWidth,
                child: _YearChip(
                  year: year,
                  active: isActive,
                  accent: accent,
                  onAccent: onAccent,
                  textSecondary: textSecondary,
                  onTap: () {
                    setState(() => _activeYear = year);
                    _scrollToActiveYear();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _monthsPerRow,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final month = DateTime(_activeYear, index + 1);
            final enabled = _isWithinAvailableRange(month);
            final isEndpoint = _isRangeEndpoint(month);
            final isInRange = _isInSelectedRange(month);
            return _MonthCell(
              label: _monthShortLabel(index),
              enabled: enabled,
              endpoint: isEndpoint,
              inRange: isInRange,
              accent: accent,
              onAccent: onAccent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: enabled ? () => _handleMonthTap(month) : null,
            );
          },
        ),
      ],
    );
  }

  String _monthShortLabel(int monthIndex0) {
    final formatted =
        DateFormat('MMM', 'it_IT').format(DateTime(2024, monthIndex0 + 1));
    return formatted[0].toUpperCase() + formatted.substring(1);
  }
}

class _YearChip extends StatelessWidget {
  final int year;
  final bool active;
  final Color accent;
  final Color onAccent;
  final Color textSecondary;
  final VoidCallback onTap;

  const _YearChip({
    required this.year,
    required this.active,
    required this.accent,
    required this.onAccent,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PulseSurface(
      borderRadius: AppRadius.pulseSmall,
      filled: active,
      filledGradientColors: active ? [accent, accent] : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Text(
          '$year',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: AppTextStyles.pulseBodyEmphasis.copyWith(
            color: active ? onAccent : textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool endpoint;
  final bool inRange;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback? onTap;

  const _MonthCell({
    required this.label,
    required this.enabled,
    required this.endpoint,
    required this.inRange,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill;
    Color labelColor;
    if (endpoint) {
      fill = accent;
      labelColor = onAccent;
    } else if (inRange) {
      fill = accent.withValues(alpha: 0.18);
      labelColor = textPrimary;
    } else {
      fill = CupertinoDynamicColor.resolve(AppColors.pulseSurface, context);
      labelColor = textSecondary;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pulseSmall),
      ),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.pulseBodyEmphasis.copyWith(
                color: labelColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
