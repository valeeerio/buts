// Riproduzione mirata del bug segnalato dall'utente: la schermata
// Statistiche va in crash (null-check operator, ripetuto a ogni frame)
// quando il periodo filtrato produce dati REALI (non vuoti) per il grafico
// Straordinario — scenario descritto: un mese confermato (con dati) e un
// mese NON confermato nel periodo filtrato.
//
// Causa: `_StraordinarioChart` (a differenza degli altri due grafici della
// schermata) non aveva più un'altezza esplicita dopo il redesign "Pulse"
// 2026-08-30 — il `LayoutBuilder`/`BarChart` interni ricevevano un vincolo
// di altezza ILLIMITATO dalla `Column` di `PulseSurface` dentro lo
// `SliverToBoxAdapter`, che fl_chart non gestisce correttamente.
import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_statistiche_screen.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({
  required String id,
  required DateTime periodo,
  required StatoVerificaBustaPaga stato,
}) {
  return BustaPaga(
    id: id,
    periodo: periodo,
    lordo: 2000,
    netto: 1500,
    trattenute: const {},
    straordinari: 5,
    ferieMaturate: 10,
    ferieGodute: 2,
    ferieResidue: 8,
    rolMaturati: 6,
    rolGoduti: 1,
    rolResidui: 5,
    permessiGoduti: 0,
    oreLavorate: 168,
    statoVerifica: stato,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
      'periodo con un mese confermato + un mese non confermato non fa '
      'crashare i grafici', (tester) async {
    // `runAsync`: `NativeDatabase.memory()` esegue le query reali su un
    // isolate/thread in background (FFI sqlite3) — un `await` diretto nel
    // corpo di `testWidgets` (a differenza di un `test()` in tempo reale)
    // non fa avanzare quell'I/O reale e resta bloccato per sempre, senza
    // nulla a che vedere con il codice sotto test — `tester.runAsync` è
    // l'unico modo corretto di mischiare I/O reale e pump sincroni in un
    // widget test.
    late final AppDatabase db;
    late final BustePagaNotifier notifier;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BustePagaNotifier(db, const PdfImportService());
      await Future<void>.delayed(Duration.zero);

      await notifier.add(_busta(
        id: 'bp-gen',
        periodo: DateTime(2026, 1),
        stato: StatoVerificaBustaPaga.confermato,
      ));
      await notifier.add(_busta(
        id: 'bp-feb',
        periodo: DateTime(2026, 2),
        stato: StatoVerificaBustaPaga.daConfermare,
      ));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => notifier),
        ],
        child: CupertinoApp(
          home: BustePagaStatisticheScreen(
            periodoFiltro: (start: DateTime(2026, 1), end: DateTime(2026, 2)),
          ),
        ),
      ),
    );

    // Niente `pumpAndSettle`: se il bug fosse presente il widget resta
    // continuamente "dirty" (eccezione a ogni frame) e non si stabilizza
    // mai — qualche `pump` esplicito basta per rilevare l'eccezione.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);

    await tester.runAsync(() => db.close());
  });
}
