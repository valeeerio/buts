import 'package:buts/widgets/period_year_month_picker.dart';
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
        child: PeriodYearMonthPicker(
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
    'primo tocco su un mese collassa il range a un solo mese',
    (tester) async {
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      await tester.pumpWidget(
        buildApp(
          minDate: minDate,
          maxDate: maxDate,
          startValue: DateTime(2024, 1),
          endValue: DateTime(2024, 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mag'));
      await tester.pumpAndSettle();

      expect(lastRange, isNotNull);
      expect(lastRange!.start, DateTime(2024, 5));
      expect(lastRange!.end, DateTime(2024, 5));
    },
  );

  testWidgets(
    'secondo tocco su un mese successivo completa il range',
    (tester) async {
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      var start = DateTime(2024, 1);
      var end = DateTime(2024, 1);

      Widget build() => buildApp(
            minDate: minDate,
            maxDate: maxDate,
            startValue: start,
            endValue: end,
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Primo tocco: nuovo inizio a marzo.
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      start = lastRange!.start;
      end = lastRange!.end;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Secondo tocco: fine ad agosto (cronologicamente dopo).
      await tester.tap(find.text('Ago'));
      await tester.pumpAndSettle();

      expect(lastRange!.start, DateTime(2024, 3));
      expect(lastRange!.end, DateTime(2024, 8));
    },
  );

  testWidgets(
    'secondo tocco cronologicamente prima del primo scambia inizio/fine',
    (tester) async {
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      var start = DateTime(2024, 1);
      var end = DateTime(2024, 1);

      Widget build() => buildApp(
            minDate: minDate,
            maxDate: maxDate,
            startValue: start,
            endValue: end,
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Primo tocco: nuovo inizio ad agosto.
      await tester.tap(find.text('Ago'));
      await tester.pumpAndSettle();
      start = lastRange!.start;
      end = lastRange!.end;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Secondo tocco su marzo (prima di agosto): il range deve restare
      // valido con inizio <= fine, quindi marzo -> agosto.
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(lastRange!.start, DateTime(2024, 3));
      expect(lastRange!.end, DateTime(2024, 8));
    },
  );

  testWidgets(
    'un tocco sullo stesso mese già impostato come unico estremo lo conferma '
    'come range di un solo mese',
    (tester) async {
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      var start = DateTime(2024, 1);
      var end = DateTime(2024, 1);

      Widget build() => buildApp(
            minDate: minDate,
            maxDate: maxDate,
            startValue: start,
            endValue: end,
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giu'));
      await tester.pumpAndSettle();
      start = lastRange!.start;
      end = lastRange!.end;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giu'));
      await tester.pumpAndSettle();

      expect(lastRange!.start, DateTime(2024, 6));
      expect(lastRange!.end, DateTime(2024, 6));
    },
  );

  testWidgets(
    'range che attraversa più anni: selezione su una scheda anno diversa '
    'completa correttamente il range assoluto',
    (tester) async {
      final minDate = DateTime(2023, 1);
      final maxDate = DateTime(2024, 12);
      var start = DateTime(2023, 1);
      var end = DateTime(2023, 1);

      Widget build() => buildApp(
            minDate: minDate,
            maxDate: maxDate,
            startValue: start,
            endValue: end,
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Primo tocco: novembre 2023 (anno attivo di default è quello di
      // endValue, cioè 2023).
      await tester.tap(find.text('Nov'));
      await tester.pumpAndSettle();
      start = lastRange!.start;
      end = lastRange!.end;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Cambia scheda anno su 2024.
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      // Secondo tocco: febbraio 2024.
      await tester.tap(find.text('Feb'));
      await tester.pumpAndSettle();

      expect(lastRange!.start, DateTime(2023, 11));
      expect(lastRange!.end, DateTime(2024, 2));
    },
  );

  testWidgets(
    'un mese fuori dal range disponibile non è tappabile',
    (tester) async {
      final minDate = DateTime(2024, 3);
      final maxDate = DateTime(2024, 9);
      await tester.pumpWidget(
        buildApp(
          minDate: minDate,
          maxDate: maxDate,
          startValue: DateTime(2024, 3),
          endValue: DateTime(2024, 3),
        ),
      );
      await tester.pumpAndSettle();

      // Gennaio 2024 è fuori dal range disponibile (anno attivo 2024, di
      // default endValue.year).
      await tester.tap(find.text('Gen'));
      await tester.pumpAndSettle();

      expect(lastRange, isNull);
    },
  );

  testWidgets(
    'un reset esterno genuino (non un\'eco del proprio ultimo emit) '
    'risincronizza lo stato interno scartando una selezione a metà pendente',
    (tester) async {
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      var start = DateTime(2024, 1);
      var end = DateTime(2024, 1);

      Widget build() => buildApp(
            minDate: minDate,
            maxDate: maxDate,
            startValue: start,
            endValue: end,
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Primo tocco: selezione a metà, pending start = marzo. Il widget
      // emette (marzo, marzo) — se ripassassimo questi stessi valori al
      // widget sarebbe una "propria eco" e lo stato interno andrebbe
      // preservato. Qui invece simuliamo un reset genuino con valori
      // diversi (es. `_periodoFiltro` ricalcolato dopo un nuovo import),
      // che deve invece risincronizzare lo stato da zero.
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(lastRange!.start, DateTime(2024, 3));
      expect(lastRange!.end, DateTime(2024, 3));

      // Reset esterno genuino: valori diversi da quanto appena emesso dal
      // widget (giugno-settembre, non marzo-marzo).
      start = DateTime(2024, 6);
      end = DateTime(2024, 9);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      // Se lo stato interno non si fosse risincronizzato (bug corretto),
      // questo tocco su novembre verrebbe interpretato come il "secondo
      // tocco" che completa il vecchio range pendente (marzo -> novembre).
      // Con la risincronizzazione corretta, invece, è un primo tocco su una
      // selezione nuova: collassa a un solo mese (novembre, novembre).
      await tester.tap(find.text('Nov'));
      await tester.pumpAndSettle();

      expect(lastRange!.start, DateTime(2024, 11));
      expect(lastRange!.end, DateTime(2024, 11));
    },
  );

  testWidgets(
    'range che attraversa 3 o più anni: l\'anno centrale, completamente '
    'incluso nel range, è evidenziato come "in range" senza essere un '
    'estremo',
    (tester) async {
      final minDate = DateTime(2021, 1);
      final maxDate = DateTime(2025, 12);

      await tester.pumpWidget(
        buildApp(
          minDate: minDate,
          maxDate: maxDate,
          startValue: DateTime(2022, 6),
          endValue: DateTime(2024, 6),
        ),
      );
      await tester.pumpAndSettle();

      Future<Color> fillColorOf(String monthLabel) async {
        final container = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.text(monthLabel),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        return (container.decoration as BoxDecoration).color!;
      }

      // Anno 2021: fuori dal range disponibile per il tab attivo di
      // default (2024), ma comunque un anno "fuori selezione" utile come
      // riferimento di colore non selezionato.
      await tester.tap(find.text('2021'));
      await tester.pumpAndSettle();
      final colorOutOfRange = await fillColorOf('Feb');

      // Anno 2022: contiene l'estremo di inizio (giugno).
      await tester.tap(find.text('2022'));
      await tester.pumpAndSettle();
      final colorEndpoint = await fillColorOf('Giu');

      // Anno 2023: completamente compreso nel range (2022-06..2024-06),
      // nessun mese di questo anno è un estremo -> tutti "in range".
      await tester.tap(find.text('2023'));
      await tester.pumpAndSettle();
      final colorMidYearMonth = await fillColorOf('Lug');

      expect(colorMidYearMonth, isNot(equals(colorOutOfRange)));
      expect(colorMidYearMonth, isNot(equals(colorEndpoint)));
    },
  );

  testWidgets(
    'con un solo mese disponibile (minDate == maxDate) il widget si '
    'costruisce senza eccezioni con una sola scheda anno e 11 mesi su 12 '
    'disabilitati',
    (tester) async {
      final onlyMonth = DateTime(2024, 5);
      await tester.pumpWidget(
        buildApp(
          minDate: onlyMonth,
          maxDate: onlyMonth,
          startValue: onlyMonth,
          endValue: onlyMonth,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2023'), findsNothing);
      expect(find.text('2025'), findsNothing);

      final disabledCells = find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 0.35,
      );
      final enabledCells = find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 1.0,
      );
      expect(disabledCells, findsNWidgets(11));
      expect(enabledCells, findsOneWidget);
    },
  );
}
