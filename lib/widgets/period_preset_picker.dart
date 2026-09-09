import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'collapsible_period_picker.dart';
import 'flat_chip_button.dart';

/// Sostituisce l'apertura diretta di [CollapsiblePeriodPicker] come primo
/// livello di interazione col filtro periodo: una riga di preset rapidi
/// ("Questo mese", "Ultimi 3 mesi", "Anno corrente", "Da sempre") più un
/// chip "Personalizza" che apre/chiude [CollapsiblePeriodPicker] (logica
/// interna di selezione a due tocchi invariata) solo per range non standard
/// — vedi spec redesign Statistiche 2026-09-08, Task 6.
///
/// Stesso "contratto" dati di [CollapsiblePeriodPicker] verso il chiamante
/// (`minDate`, `maxDate`, `startValue`, `endValue`, `onChanged`) — drop-in
/// replacement nello stesso punto di istanziazione
/// (`buste_paga_section_screen.dart`).
class PeriodPresetPicker extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  const PeriodPresetPicker({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
  });

  @override
  State<PeriodPresetPicker> createState() => _PeriodPresetPickerState();
}

class _PeriodPresetPickerState extends State<PeriodPresetPicker> {
  bool _personalizzaAperto = false;

  /// Clampa [range] dentro `minDate`/`maxDate` — un preset come "Ultimi 3
  /// mesi" applicato quando ci sono solo 2 mesi di storico deve ridursi al
  /// range disponibile, non restituire un range fuori dai dati reali.
  ({DateTime start, DateTime end}) _clamp(
    ({DateTime start, DateTime end}) range,
  ) {
    final start =
        range.start.isBefore(widget.minDate) ? widget.minDate : range.start;
    final end = range.end.isAfter(widget.maxDate) ? widget.maxDate : range.end;
    return (start: start, end: end);
  }

  void _applica(({DateTime start, DateTime end}) range) {
    widget.onChanged(_clamp(range));
  }

  void _questoMese() {
    final fine = widget.maxDate;
    _applica((start: DateTime(fine.year, fine.month), end: fine));
  }

  void _ultimiTreMesi() {
    final fine = widget.maxDate;
    final inizio = DateTime(fine.year, fine.month - 2);
    _applica((start: inizio, end: fine));
  }

  void _annoCorrente() {
    final fine = widget.maxDate;
    _applica((start: DateTime(fine.year, 1), end: fine));
  }

  void _daSempre() {
    _applica((start: widget.minDate, end: widget.maxDate));
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FlatChipButton(
                label: 'Questo mese',
                color: accent,
                onPressed: _questoMese,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Ultimi 3 mesi',
                color: accent,
                onPressed: _ultimiTreMesi,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Anno corrente',
                color: accent,
                onPressed: _annoCorrente,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Da sempre',
                color: accent,
                onPressed: _daSempre,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Personalizza',
                color: accent,
                filled: _personalizzaAperto,
                onPressed: () => setState(
                  () => _personalizzaAperto = !_personalizzaAperto,
                ),
              ),
            ],
          ),
        ),
        if (_personalizzaAperto) ...[
          const SizedBox(height: AppSpacing.sm),
          CollapsiblePeriodPicker(
            minDate: widget.minDate,
            maxDate: widget.maxDate,
            startValue: widget.startValue,
            endValue: widget.endValue,
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}
