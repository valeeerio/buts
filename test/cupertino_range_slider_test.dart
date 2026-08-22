import 'package:buts/widgets/cupertino_range_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Regressione: `didUpdateWidget` ricalcolava `_startFraction`/`_endFraction`
/// dalle props esterne (`startValue`/`endValue`) senza applicare il vincolo
/// del gap minimo (`_minGapFraction`) usato invece da `_applyFraction`
/// durante il drag. Se un chiamante esterno aggiornava le props con
/// `startValue == endValue` (gap nullo, sotto il minimo), il primo drag
/// successivo eseguiva `fraction.clamp(0.0, _endFraction - _minGapFraction)`
/// con `lower > upper`, sollevando un `ArgumentError` — invariante rotta
/// silenziosamente al di fuori del solo percorso di drag.
void main() {
  testWidgets(
    'un aggiornamento esterno delle props con start == end (gap nullo) non '
    'fa sollevare ArgumentError al drag successivo — il gap minimo viene '
    'applicato anche fuori dal drag',
    (tester) async {
      await initializeDateFormatting('it_IT');
      final minDate = DateTime(2024, 1);
      final maxDate = DateTime(2024, 12);
      // Il primo mount usa valori validi (gap ampio): il caso interessante
      // per `didUpdateWidget` è un aggiornamento SUCCESSIVO delle props
      // esterne che riduce il gap a zero — `startValue == endValue`,
      // allineati sull'estremo `minDate` (fraction 0), la combinazione che
      // rende `_endFraction - _minGapFraction` negativo e quindi
      // `clamp(0.0, negativo)` un `ArgumentError` in `_applyFraction`.
      var startValue = DateTime(2024, 1);
      var endValue = DateTime(2024, 12);

      Widget buildApp() {
        return CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 300,
                child: CupertinoRangeSlider(
                  minDate: minDate,
                  maxDate: maxDate,
                  startValue: startValue,
                  endValue: endValue,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Aggiornamento esterno delle props (non un drag interno) che
      // violerebbe il gap minimo se `didUpdateWidget` non lo applicasse.
      startValue = DateTime(2024, 1);
      endValue = DateTime(2024, 1);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Un drag su una qualunque delle due maniglie eseguirebbe
      // `fraction.clamp(0.0, _endFraction - _minGapFraction)` (o l'analogo
      // per la maniglia end): con l'invariante rotta, `lower > upper` fa
      // sollevare `ArgumentError` prima del fix. Il drag va sul
      // `GestureDetector` interno (l'area del track/thumb), non sulla
      // `Column` esterna del widget (che include anche la riga di
      // etichette e non riceve i gesti orizzontali).
      final trackFinder = find.descendant(
        of: find.byType(CupertinoRangeSlider),
        matching: find.byType(GestureDetector),
      );
      expect(trackFinder, findsOneWidget);
      await tester.drag(trackFinder, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
