import 'package:buts/widgets/period_filter_button.dart';
import 'package:buts/widgets/pulse_icon.dart';
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
      home: CupertinoPageScaffold(
        child: Center(
          child: PeriodFilterButton(
            minDate: min,
            maxDate: max,
            startValue: start,
            endValue: end,
            onChanged: (r) => ultimoRange = r,
          ),
        ),
      ),
    );
  }

  setUp(() => ultimoRange = null);

  Future<void> apriSheet(WidgetTester tester) async {
    await tester.tap(find.byType(PeriodFilterButton));
    await tester.pumpAndSettle();
  }

  testWidgets('badge nascosto quando il periodo attivo è tutto lo storico',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    // Nessun Container decorativo circolare in overlay: verificato tramite
    // assenza di un secondo figlio Positioned/BoxDecoration circle nello
    // Stack del bottone (unico segnale osservabile senza esporre uno
    // Key/type dedicato al badge).
    final stack = tester.widget<Stack>(find.descendant(
      of: find.byType(PeriodFilterButton),
      matching: find.byType(Stack),
    ));
    expect(stack.children.length, 1);
  });

  testWidgets('badge visibile quando il periodo attivo non è tutto lo storico',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2026, 1),
      end: DateTime(2026, 5),
    ));

    final stack = tester.widget<Stack>(find.descendant(
      of: find.byType(PeriodFilterButton),
      matching: find.byType(Stack),
    ));
    expect(stack.children.length, 2);
  });

  testWidgets('tap apre il bottom sheet con le 3 opzioni + Personalizza',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);

    expect(find.text('Periodo'), findsOneWidget);
    expect(find.text('Tutto lo storico'), findsOneWidget);
    expect(find.text('Anno corrente'), findsOneWidget);
    expect(find.text('Anno precedente'), findsOneWidget);
    expect(find.text('Personalizza'), findsOneWidget);
  });

  testWidgets('Anno precedente applica l\'intero anno solare precedente',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    await tester.tap(find.text('Anno precedente'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2025, 1), end: DateTime(2025, 12, 31)));
    expect(find.text('Periodo'), findsNothing);
  });

  testWidgets(
      'Anno precedente viene clampato quando lo storico non copre l\'intero anno',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 3),
      max: DateTime(2026, 5),
      start: DateTime(2025, 3),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    await tester.tap(find.text('Anno precedente'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2025, 3), end: DateTime(2025, 12, 31)));
  });

  testWidgets(
      'Anno precedente collassa su minDate quando l\'intero anno precedente '
      'cade prima dello storico disponibile', (tester) async {
    // minDate = marzo 2026, maxDate = maggio 2026: l'anno precedente (2025)
    // è interamente prima dello storico disponibile. Il clamp indipendente
    // di start/end produrrebbe un range invertito (start = minDate =
    // 2026-03, end = 2025-12-31 non clampato perché non supera maxDate) —
    // scelta di design: collassare sul singolo giorno minDate, l'estremo
    // dei dati disponibili più vicino al range richiesto, cosi il filtro
    // risultante soddisfa sempre start <= end e mostra un mese coerente
    // con lo storico reale invece di un range invertito che azzererebbe
    // silenziosamente i dati nei grafici.
    await tester.pumpWidget(build(
      min: DateTime(2026, 3),
      max: DateTime(2026, 5),
      start: DateTime(2026, 3),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    await tester.tap(find.text('Anno precedente'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2026, 3), end: DateTime(2026, 3)));
    expect(ultimoRange!.start.isAfter(ultimoRange!.end), isFalse);
  });

  testWidgets('Anno corrente applica il range corretto', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    await tester.tap(find.text('Anno corrente'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2026, 1), end: DateTime(2026, 5)));
  });

  testWidgets('Tutto lo storico applica minDate-maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 3),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    await tester.tap(find.text('Tutto lo storico'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2024, 3), end: DateTime(2026, 5)));
  });

  testWidgets(
      'Personalizza mostra il PeriodYearMonthPicker esteso e "Fatto" chiude il sheet',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);
    expect(find.textContaining('Gennaio 2025'), findsNothing);

    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();

    // Il PeriodYearMonthPicker mostra l'etichetta del range corrente
    // (vedi PeriodYearMonthPicker.formatRangeLabel) e la griglia mesi.
    expect(find.textContaining('Gennaio 2025'), findsWidgets);
    expect(find.text('Fatto'), findsOneWidget);

    await tester.tap(find.text('Fatto'));
    await tester.pumpAndSettle();

    expect(find.text('Periodo'), findsNothing);
    expect(find.textContaining('Gennaio 2025'), findsNothing);
  });

  testWidgets(
      'la spunta segna "Anno corrente" quando il range attivo corrisponde',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2026, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);

    // La spunta è un'icona checkmark accanto all'etichetta selezionata:
    // verifichiamo che compaia esattamente una volta (solo per "Anno
    // corrente", nessun altro preset corrisponde a questo range).
    final checkmarks = find.byWidgetPredicate(
      (widget) =>
          widget is PulseIcon && widget.glyph == PulseIconGlyph.checkmark,
    );
    expect(checkmarks, findsOneWidget);

    final rigaAnnoCorrente = find.ancestor(
      of: find.text('Anno corrente'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: rigaAnnoCorrente, matching: checkmarks),
      findsOneWidget,
    );
  });

  testWidgets(
      'la spunta segna "Tutto lo storico" quando il range attivo corrisponde',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);

    final checkmarks = find.byWidgetPredicate(
      (widget) =>
          widget is PulseIcon && widget.glyph == PulseIconGlyph.checkmark,
    );
    expect(checkmarks, findsOneWidget);

    final rigaTuttoLoStorico = find.ancestor(
      of: find.text('Tutto lo storico'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: rigaTuttoLoStorico, matching: checkmarks),
      findsOneWidget,
    );
  });

  testWidgets(
      '"Azzera" non appare quando il filtro attivo è già tutto lo storico',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);

    expect(find.text('Azzera'), findsNothing);
  });

  testWidgets(
      '"Azzera" appare, applica tutto lo storico e chiude il sheet quando il '
      'filtro attivo è diverso', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 3),
      max: DateTime(2026, 5),
      start: DateTime(2026, 1),
      end: DateTime(2026, 5),
    ));

    await apriSheet(tester);

    expect(find.text('Azzera'), findsOneWidget);

    await tester.tap(find.text('Azzera'));
    await tester.pumpAndSettle();

    expect(ultimoRange, (start: DateTime(2024, 3), end: DateTime(2026, 5)));
    expect(find.text('Periodo'), findsNothing);
  });

  testWidgets(
      'la spunta segna "Anno precedente" quando il range attivo corrisponde',
      (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2025, 12, 31),
    ));

    await apriSheet(tester);

    final checkmarks = find.byWidgetPredicate(
      (widget) =>
          widget is PulseIcon && widget.glyph == PulseIconGlyph.checkmark,
    );
    expect(checkmarks, findsOneWidget);

    final rigaAnnoPrecedente = find.ancestor(
      of: find.text('Anno precedente'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: rigaAnnoPrecedente, matching: checkmarks),
      findsOneWidget,
    );
  });
}
