import 'package:buts/widgets/collapsible_period_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  ({DateTime start, DateTime end})? lastRange;

  Widget buildApp({
    required DateTime minDate,
    required DateTime maxDate,
    required DateTime startValue,
    required DateTime endValue,
  }) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: CollapsiblePeriodPicker(
          minDate: minDate,
          maxDate: maxDate,
          startValue: startValue,
          endValue: endValue,
          onChanged: (range) => lastRange = range,
        ),
      ),
    );
  }

  setUp(() {
    lastRange = null;
  });

  testWidgets(
      'stato iniziale collassato: mostra il chip riassuntivo e non '
      'la griglia mesi', (tester) async {
    await tester.pumpWidget(
      buildApp(
        minDate: DateTime(2024, 1),
        maxDate: DateTime(2024, 12),
        startValue: DateTime(2024, 3),
        endValue: DateTime(2024, 5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marzo 2024 → Maggio 2024'), findsOneWidget);
    // La griglia mesi (schede anno) non è ancora nell'albero.
    expect(find.text('2024'), findsNothing);
    expect(find.text('Mag'), findsNothing);
  });

  testWidgets('tap sul chip espande mostrando schede anno e griglia mesi',
      (tester) async {
    await tester.pumpWidget(
      buildApp(
        minDate: DateTime(2024, 1),
        maxDate: DateTime(2024, 12),
        startValue: DateTime(2024, 3),
        endValue: DateTime(2024, 5),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marzo 2024 → Maggio 2024'));
    await tester.pumpAndSettle();

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Mag'), findsOneWidget);
  });

  testWidgets(
      'una selezione a due tocchi completata richiude automaticamente il '
      'picker', (tester) async {
    var start = DateTime(2024, 1);
    var end = DateTime(2024, 1);

    Widget build() => buildApp(
          minDate: DateTime(2024, 1),
          maxDate: DateTime(2024, 12),
          startValue: start,
          endValue: end,
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // Espande.
    await tester.tap(find.text('Gennaio 2024'));
    await tester.pumpAndSettle();
    expect(find.text('Mag'), findsOneWidget);

    // Primo tocco: nuovo inizio a marzo (range collassato a un solo mese,
    // il picker resta ancora espanso in attesa del secondo tocco).
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(lastRange!.start, DateTime(2024, 3));
    expect(lastRange!.end, DateTime(2024, 3));
    start = lastRange!.start;
    end = lastRange!.end;
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Mag'), findsOneWidget);

    // Secondo tocco: completa il range -> il picker si richiude da solo.
    await tester.tap(find.text('Ago'));
    await tester.pump();
    expect(lastRange!.start, DateTime(2024, 3));
    expect(lastRange!.end, DateTime(2024, 8));
    start = lastRange!.start;
    end = lastRange!.end;
    await tester.pumpWidget(build());
    // Attende il ritardo di auto-chiusura più l'animazione di collasso.
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Mag'), findsNothing);
    expect(find.text('Marzo 2024 → Agosto 2024'), findsOneWidget);
  });
}
