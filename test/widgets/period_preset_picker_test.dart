import 'package:buts/widgets/period_preset_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  ({DateTime start, DateTime end})? ultimoRange;

  Widget build({
    required DateTime min,
    required DateTime max,
    required DateTime start,
    required DateTime end,
  }) {
    return CupertinoApp(
      home: PeriodPresetPicker(
        minDate: min,
        maxDate: max,
        startValue: start,
        endValue: end,
        onChanged: (r) => ultimoRange = r,
      ),
    );
  }

  setUp(() => ultimoRange = null);

  testWidgets('Questo mese seleziona solo il mese di maxDate',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Questo mese'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 5), end: DateTime(2026, 5)));
  });

  testWidgets('Ultimi 3 mesi copre mese corrente + 2 precedenti',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Ultimi 3 mesi'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 3), end: DateTime(2026, 5)));
  });

  testWidgets('Ultimi 3 mesi si clampa se lo storico è più corto',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2026, 4),
      max: DateTime(2026, 5),
      start: DateTime(2026, 4),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Ultimi 3 mesi'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 4), end: DateTime(2026, 5)));
  });

  testWidgets('Anno corrente copre da gennaio a maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Anno corrente'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 1), end: DateTime(2026, 5)));
  });

  testWidgets('Da sempre copre minDate-maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 3),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Da sempre'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2024, 3), end: DateTime(2026, 5)));
  });

  testWidgets('Personalizza apre il CollapsiblePeriodPicker esistente',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    expect(find.text('Personalizza'), findsOneWidget);
    // Il CollapsiblePeriodPicker collassato non è ancora presente prima del
    // tap: verificato dall'assenza dell'etichetta del range formattata da
    // PeriodYearMonthPicker.formatRangeLabel (mostrata solo dal chip
    // riassuntivo del picker una volta aperto).
    expect(find.textContaining('Gennaio 2025'), findsNothing);

    // Il chip "Personalizza" è nell'ultima posizione della riga scorrevole
    // orizzontale di preset: portarlo in vista prima del tap, altrimenti può
    // trovarsi fuori dal viewport di test (`tester.tap` non scrolla da solo).
    await tester.ensureVisible(find.text('Personalizza'));
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();

    // Il CollapsiblePeriodPicker collassato mostra l'etichetta del range
    // corrente (vedi PeriodYearMonthPicker.formatRangeLabel) — basta
    // verificare che compaia per confermare che si sia espanso, senza
    // duplicare i test interni già esistenti su quel widget.
    expect(find.textContaining('Gennaio 2025'), findsWidgets);

    // Ritoccando "Personalizza" il picker si richiude di nuovo.
    await tester.ensureVisible(find.text('Personalizza'));
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gennaio 2025'), findsNothing);
  });
}
