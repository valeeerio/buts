import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'period_year_month_picker.dart';
import 'pulse_icon.dart';
import 'pulse_surface.dart';
import 'spring_button.dart';

/// Sostituisce interamente `PeriodPresetPicker` come punto di interazione
/// primario per il filtro periodo di Statistiche — "Opzione D" del mockup
/// scelto dall'utente 2026-09-09: il filtro sparisce quasi del tutto,
/// sostituito da una sola icona (calendario) con un badge quando il periodo
/// attivo non è "tutto lo storico". Al tap si apre un bottom sheet con i
/// preset rapidi più "Personalizza" per il range esteso.
///
/// Stesso "contratto" dati di `PeriodPresetPicker`/`CollapsiblePeriodPicker`
/// verso il chiamante — drop-in replacement nello stesso punto di
/// istanziazione (`buste_paga_section_screen.dart`).
class PeriodFilterButton extends StatelessWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  const PeriodFilterButton({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
  });

  /// Il periodo attivo è considerato "di default" (nessun filtro applicato)
  /// solo quando coincide esattamente con tutto lo storico disponibile.
  bool get _isDefault => startValue == minDate && endValue == maxDate;

  void _openSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _PeriodFilterSheet(
        minDate: minDate,
        maxDate: maxDate,
        startValue: startValue,
        endValue: endValue,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final onAccent =
        CupertinoDynamicColor.resolve(AppColors.pulseOnAccent, context);
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);

    return Semantics(
      label: 'Filtro periodo',
      button: true,
      child: SpringButton(
        onPressed: () => _openSheet(context),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PulseSurface(
                borderRadius: AppRadius.pulseSmall,
                child: Center(
                  child: PulseIcon(
                    glyph: PulseIconGlyph.filter,
                    size: 20,
                    color: textPrimary,
                  ),
                ),
              ),
              if (!_isDefault)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: onAccent, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Range che ciascun preset produrrebbe per l'attuale `minDate`/`maxDate`,
/// già clampato dentro il range disponibile — stessa logica pura ereditata
/// da `PeriodPresetPicker` (rimosso, sostituito da questo widget).
///
/// `start` ed `end` vengono clampati indipendentemente dentro
/// `[minDate, maxDate]`, ma se il range richiesto non ha alcuna
/// intersezione con i dati disponibili (interamente prima di `minDate` o
/// interamente dopo `maxDate`) il clamp indipendente produrrebbe un range
/// invertito (`start > end`) — es. "Anno precedente" quando lo storico
/// inizia a metà dell'anno corrente. In quel caso il range viene collassato
/// su un singolo giorno, l'estremo dei dati disponibili più vicino al range
/// richiesto (`minDate` se il range richiesto è tutto nel passato rispetto
/// ai dati, `maxDate` se è tutto nel futuro): il filtro risultante mostra
/// così un solo mese coerente con lo storico reale, invece di un range
/// invertito che farebbe apparire "Nessun dato" in modo indistinguibile da
/// un vero periodo senza buste paga.
({DateTime start, DateTime end}) _clampRange(
  DateTime minDate,
  DateTime maxDate,
  ({DateTime start, DateTime end}) range,
) {
  if (range.end.isBefore(minDate)) {
    return (start: minDate, end: minDate);
  }
  if (range.start.isAfter(maxDate)) {
    return (start: maxDate, end: maxDate);
  }
  final start = range.start.isBefore(minDate) ? minDate : range.start;
  final end = range.end.isAfter(maxDate) ? maxDate : range.end;
  return (start: start, end: end);
}

({DateTime start, DateTime end}) _rangeAnnoCorrente(
  DateTime minDate,
  DateTime maxDate,
) {
  final fine = maxDate;
  return _clampRange(minDate, maxDate, (start: DateTime(fine.year, 1), end: fine));
}

({DateTime start, DateTime end}) _rangeAnnoPrecedente(
  DateTime minDate,
  DateTime maxDate,
) {
  final annoPrecedente = maxDate.year - 1;
  return _clampRange(
    minDate,
    maxDate,
    (
      start: DateTime(annoPrecedente, 1),
      end: DateTime(annoPrecedente, 12, 31),
    ),
  );
}

({DateTime start, DateTime end}) _rangeTuttoLoStorico(
  DateTime minDate,
  DateTime maxDate,
) {
  return _clampRange(minDate, maxDate, (start: minDate, end: maxDate));
}

bool _corrisponde(
  ({DateTime start, DateTime end}) range,
  DateTime start,
  DateTime end,
) {
  return range.start.year == start.year &&
      range.start.month == start.month &&
      range.end.year == end.year &&
      range.end.month == end.month;
}

class _PeriodFilterSheet extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  const _PeriodFilterSheet({
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
  });

  @override
  State<_PeriodFilterSheet> createState() => _PeriodFilterSheetState();
}

class _PeriodFilterSheetState extends State<_PeriodFilterSheet> {
  bool _personalizzaAperto = false;

  // Copia locale del range attivo: usata solo per aggiornare la spunta
  // dentro il pannello "Personalizza" mentre l'utente tocca i mesi, prima
  // di chiudere il sheet con "Fatto".
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startValue;
    _end = widget.endValue;
  }

  void _applica(({DateTime start, DateTime end}) range) {
    final clamped = _clampRange(widget.minDate, widget.maxDate, range);
    widget.onChanged(clamped);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: PulseSurface(
          borderRadius: AppRadius.pulse,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _personalizzaAperto
              ? _buildPersonalizza(context, accent, textPrimary)
              : _buildLista(context, accent, textPrimary, textSecondary),
        ),
      ),
    );
  }

  Widget _buildLista(
    BuildContext context,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    final tuttoLoStorico = _rangeTuttoLoStorico(widget.minDate, widget.maxDate);
    final annoCorrente = _rangeAnnoCorrente(widget.minDate, widget.maxDate);
    final annoPrecedente = _rangeAnnoPrecedente(widget.minDate, widget.maxDate);

    final isDefault = _corrisponde(
        tuttoLoStorico, widget.startValue, widget.endValue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Periodo',
              style:
                  AppTextStyles.pulseDisplaySmall.copyWith(color: textPrimary),
            ),
            if (!isDefault)
              SpringButton(
                onPressed: () => _applica(tuttoLoStorico),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Text(
                    'Azzera',
                    style: AppTextStyles.pulseBodyEmphasis.copyWith(
                      color: accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _OpzionePeriodo(
          label: 'Tutto lo storico',
          selected: _corrisponde(
              tuttoLoStorico, widget.startValue, widget.endValue),
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => _applica(tuttoLoStorico),
        ),
        _OpzionePeriodo(
          label: 'Anno corrente',
          selected: _corrisponde(
              annoCorrente, widget.startValue, widget.endValue),
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => _applica(annoCorrente),
        ),
        _OpzionePeriodo(
          label: 'Anno precedente',
          selected: _corrisponde(
              annoPrecedente, widget.startValue, widget.endValue),
          accent: accent,
          textPrimary: textPrimary,
          onTap: () => _applica(annoPrecedente),
        ),
        _OpzionePeriodo(
          label: 'Personalizza',
          selected: false,
          accent: accent,
          textPrimary: textPrimary,
          showChevron: true,
          onTap: () => setState(() => _personalizzaAperto = true),
        ),
      ],
    );
  }

  Widget _buildPersonalizza(
    BuildContext context,
    Color accent,
    Color textPrimary,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Periodo',
              style:
                  AppTextStyles.pulseDisplaySmall.copyWith(color: textPrimary),
            ),
            SpringButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text(
                  'Fatto',
                  style: AppTextStyles.pulseBodyEmphasis.copyWith(
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PeriodYearMonthPicker(
          minDate: widget.minDate,
          maxDate: widget.maxDate,
          startValue: _start,
          endValue: _end,
          onChanged: (range) {
            setState(() {
              _start = range.start;
              _end = range.end;
            });
            widget.onChanged(range);
          },
        ),
      ],
    );
  }
}

class _OpzionePeriodo extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final bool showChevron;
  final VoidCallback onTap;

  const _OpzionePeriodo({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smPlus),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.pulseBody.copyWith(
                  color: selected ? accent : textPrimary,
                ),
              ),
            ),
            if (selected)
              PulseIcon(
                glyph: PulseIconGlyph.checkmark,
                size: 18,
                color: accent,
              )
            else if (showChevron)
              PulseIcon(
                glyph: PulseIconGlyph.chevronForward,
                size: 16,
                color: textPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
