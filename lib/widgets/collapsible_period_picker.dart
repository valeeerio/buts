import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'period_year_month_picker.dart';
import 'pulse_icon.dart';
import 'pulse_surface.dart';

/// Contenitore collassabile per [PeriodYearMonthPicker]: in stato
/// collassato (default) mostra un chip compatto con il periodo
/// selezionato; al tocco si espande mostrando il picker per intero (schede
/// anno + griglia mesi, logica di selezione invariata). Si richiude da solo
/// poco dopo che l'utente completa una selezione valida a due tocchi — vedi
/// nota su [onChanged] sotto per il perché di questa scelta rispetto a un
/// secondo tocco esplicito per chiudere.
///
/// Stesso "contratto" dati di [PeriodYearMonthPicker] verso il chiamante:
/// nessuna modifica alla logica di stato del filtro nel genitore.
class CollapsiblePeriodPicker extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  const CollapsiblePeriodPicker({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
  });

  @override
  State<CollapsiblePeriodPicker> createState() =>
      _CollapsiblePeriodPickerState();
}

class _CollapsiblePeriodPickerState extends State<CollapsiblePeriodPicker> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  // Si autochiude sempre dopo che l'utente completa una selezione a due
  // tocchi (opzione (a) nel task): più comodo nell'uso reale di "seleziona e
  // via" rispetto a dover ritoccare il chip per richiudere. Distinguiamo il
  // primo tocco (che avvia una nuova selezione e non deve richiudere,
  // altrimenti l'utente non potrebbe mai dare il secondo tocco) dal tocco
  // che la conclude tramite `onSelectionComplete`, un hook additivo minimo
  // esposto da `PeriodYearMonthPicker` — non duplichiamo qui la sua logica
  // di selezione a 2 tocchi/swap, che resta interamente nel widget interno.
  void _handleSelectionComplete() {
    if (!mounted || !_expanded) return;
    // Richiude con un piccolo ritardo: dà il tempo alla griglia mesi di
    // mostrare l'evidenziazione del range appena selezionato prima che il
    // picker scompaia, invece di un collasso istantaneo che "salta" lo
    // stato finale.
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted || !_expanded) return;
      setState(() => _expanded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    final label = PeriodYearMonthPicker.formatRangeLabel(
      widget.startValue,
      widget.endValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulseSurface(
          borderRadius: AppRadius.pulseSmall,
          onTap: _toggle,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              PulseIcon(
                glyph: PulseIconGlyph.calendar,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.pulseBodyEmphasis
                      .copyWith(color: textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedRotation(
                duration: const Duration(milliseconds: 220),
                turns: _expanded ? 0.5 : 0,
                child: PulseIcon(
                  glyph: PulseIconGlyph.chevronDown,
                  size: 14,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: PeriodYearMonthPicker(
                    minDate: widget.minDate,
                    maxDate: widget.maxDate,
                    startValue: widget.startValue,
                    endValue: widget.endValue,
                    onChanged: widget.onChanged,
                    onSelectionComplete: _handleSelectionComplete,
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
