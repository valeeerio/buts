import 'package:buts/models/busta_paga.dart';
import 'package:buts/widgets/busta_paga_drilldown_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({
  required StatoVerificaBustaPaga stato,
}) {
  return BustaPaga(
    id: 'bp-test',
    periodo: DateTime(2026, 5),
    lordo: 1563.99,
    netto: 1427.00,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 20,
    ferieGodute: 7.67,
    ferieResidue: 12.33,
    rolMaturati: 30,
    rolGoduti: 5.94,
    rolResidui: 24.06,
    permessiGoduti: 0,
    exFestivitaMaturate: 32,
    exFestivitaGodute: 5.33,
    exFestivitaResidue: 26.67,
    oreLavorate: 168,
    statoVerifica: stato,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('mostra periodo, netto, lordo e i 3 residui', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showBustaPagaDrilldown(
              context,
              _busta(stato: StatoVerificaBustaPaga.confermato),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Maggio 2026'), findsOneWidget);
    expect(find.textContaining('1.427,00'), findsOneWidget);
    expect(find.textContaining('1.563,99'), findsOneWidget);
    expect(find.text('Ferie residue'), findsOneWidget);
    expect(find.text('Permessi residui'), findsOneWidget);
    expect(find.text('Ex festività residue'), findsOneWidget);
  });

  testWidgets('il bottone Chiudi chiude il sheet', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showBustaPagaDrilldown(
              context,
              _busta(stato: StatoVerificaBustaPaga.daConfermare),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Chiudi'), findsOneWidget);

    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.text('Chiudi'), findsNothing);
  });
}
