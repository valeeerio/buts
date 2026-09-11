// Test di regressione per il bug "flash 'nessuna busta paga' all'avvio"
// (vedi CLAUDE.md/istruzioni task): finché la SELECT iniziale dal DB
// (`BustePagaNotifier._initialize`) è ancora in volo, `BustePagaArchivioView`
// non deve mostrare `_EmptyState` (l'invito "Nessuna busta paga in
// archivio") — uno stato in caricamento è indistinguibile da un archivio
// genuinamente vuoto solo guardando `busteRepositoryProvider` da solo,
// serve il guard su `busteCaricamentoCompletatoProvider`
// (`sorted.isEmpty && !caricamentoCompletato` in
// `buste_paga_archivio_view.dart`).
//
// Per tenere la lettura iniziale sospesa in modo deterministico (non un
// semplice ritardo temporizzato, fragile) si usa un `LazyDatabase` la cui
// funzione di apertura resta sospesa su un `Completer` non risolto: finché
// il completer non viene completato dal test, `BustePagaNotifier._initialize`
// (che deve aprire il DB prima di poter eseguire qualunque SELECT) resta
// "in volo" in modo affidabile, senza dipendere da dettagli interni di come
// Drift/`NativeDatabase` eseguono le singole query.
import 'dart:async';

import 'package:buts/data/database.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_archivio_view.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _emptyStateText = 'Nessuna busta paga in archivio';

Future<void> _pumpArchivio(
  WidgetTester tester,
  BustePagaNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busteRepositoryProvider.overrideWith((ref) => notifier),
      ],
      child: CupertinoApp(
        home: BustePagaArchivioView(
          onOpenDetail: (_) {},
          onAdd: () {},
          searchActive: false,
          query: '',
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
      "finché la SELECT iniziale dal DB è ancora in volo l'Archivio non "
      "mostra l'invito 'nessuna busta paga', e lo mostra correttamente solo "
      'dopo che il caricamento è completato con un risultato genuinamente '
      'vuoto', (tester) async {
    final gate = Completer<void>();
    late final AppDatabase db;
    late final BustePagaNotifier notifier;

    // `NativeDatabase.memory()` fa I/O reale su un thread in background (FFI
    // sqlite3), quindi va guidato con `tester.runAsync`, come negli altri
    // test su `BustePagaNotifier`. Il `LazyDatabase` sotto ritarda l'apertura
    // vera e propria del DB finché `gate` non viene completato: qualunque
    // query (a partire dalla SELECT di `_initialize`) deve aspettare che il
    // DB sia aperto, quindi resta sospesa con lui in modo affidabile.
    final executor = LazyDatabase(() async {
      await gate.future;
      return NativeDatabase.memory();
    });
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(executor);
      // Il costruttore avvia `_initialize()` senza attenderlo (fire-and-
      // forget): resta sospeso sull'apertura del DB finché `gate` non viene
      // completato più sotto, esattamente lo scenario di timing che questo
      // test copre.
      notifier = BustePagaNotifier(db, const PdfImportService());
    });

    await _pumpArchivio(tester, notifier);
    expect(tester.takeException(), isNull);

    // Caricamento iniziale ancora in corso: `state` è `[]` ma
    // `caricamentoCompletato` è `false` — non deve comparire l'invito ad
    // aggiungere una busta paga, sarebbe fuorviante.
    expect(notifier.caricamentoCompletato, isFalse);
    expect(find.text(_emptyStateText), findsNothing);

    // Sblocca l'apertura del DB sospesa e lascia completare `_initialize()`
    // (apertura DB + SELECT), tutto dentro lo stesso `runAsync`: solo il
    // event loop reale attivato da `runAsync` fa avanzare l'I/O reale di
    // `NativeDatabase` (FFI sqlite3), non il normale `pump()` (fake-async).
    await tester.runAsync(() async {
      gate.complete();
      var tentativi = 0;
      while (!notifier.caricamentoCompletato && tentativi < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        tentativi++;
      }
    });
    await tester.pump();

    // Il caricamento è ora genuinamente completato, con un risultato
    // vuoto (nessuna busta paga mai importata in questo DB di test):
    // l'invito deve comparire, il blocco non deve essere permanente.
    expect(notifier.caricamentoCompletato, isTrue);
    expect(find.text(_emptyStateText), findsOneWidget);

    await tester.runAsync(() => db.close());
  });
}
