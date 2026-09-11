// Copre il fix "le buste paga sembrano arrivare in ritardo scorrendo la
// lista" (vedi CLAUDE.md/istruzioni task): `StaggeredFadeSlideIn` in
// `_bustaPagaRow` (buste_paga_archivio_view.dart) deve giocare l'animazione
// di ingresso una sola volta per id, non ad ogni ricostruzione della riga.
//
// Un test end-to-end "scrolla fuori e dentro dal viewport" è stato scartato
// perché fragile: con `flutter_test` non c'è un modo affidabile di forzare
// `SliverList.separated` a disporre e ricreare l'`Element` di una riga
// specifica (dipende da cache extent, dimensioni reali dei widget, velocità
// di scroll) senza legare il test a dettagli di implementazione del
// viewport più che al comportamento che vogliamo garantire.
//
// Il test sotto verifica invece il comportamento osservabile che conta,
// tramite lo stesso meccanismo usato dal codice reale (`playId`/`playedIds`
// di `StaggeredFadeSlideIn`, vedi staggered_fade_slide_in.dart): quando la
// vista si ricostruisce con nuove righe (qui, a seguito di un nuovo import —
// la stessa causa di rebuild di un rientro nel viewport durante lo scroll),
// le righe già presenti in una build precedente si mostrano SUBITO
// nell'opacità finale (nessuna animazione rigiocata), mentre una riga
// genuinamente nuova parte dall'opacità iniziale e anima verso quella
// finale.
import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_archivio_view.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:buts/widgets/staggered_fade_slide_in.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({required String id, required DateTime periodo}) {
  return BustaPaga(
    id: id,
    periodo: periodo,
    lordo: 2000,
    netto: 1500,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 0,
    ferieGodute: 0,
    ferieResidue: 0,
    rolMaturati: 0,
    rolGoduti: 0,
    rolResidui: 0,
    permessiGoduti: 0,
    permessiGodutiMese: 0,
    exFestivitaMaturate: 0,
    exFestivitaGodute: 0,
    exFestivitaResidue: 0,
    oreLavorate: 168,
    statoVerifica: StatoVerificaBustaPaga.confermato,
  );
}

/// Stesso motivo degli altri test su `BustePagaNotifier`:
/// `NativeDatabase.memory()` fa I/O reale su un thread in background (FFI
/// sqlite3), quindi va guidato con `tester.runAsync` invece di un `await`
/// diretto nel corpo di `testWidgets`.
Future<
    ({
      AppDatabase db,
      BustePagaNotifier notifier,
    })> _setUpRepository(
  WidgetTester tester, {
  required List<BustaPaga> buste,
}) async {
  late final AppDatabase db;
  late final BustePagaNotifier notifier;
  await tester.runAsync(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifier = BustePagaNotifier(db, const PdfImportService());
    await Future<void>.delayed(Duration.zero);
    for (final busta in buste) {
      await notifier.add(busta);
    }
  });
  return (db: db, notifier: notifier);
}

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
  // Nessun `pump` con avanzamento di tempo dopo il primo: vogliamo
  // catturare lo stato SUBITO dopo il mount, prima che il ritardo/animazione
  // di `StaggeredFadeSlideIn` sia già avanzata, per poter distinguere righe
  // "appena montate, animazione non ancora partita" da righe "già viste,
  // niente animazione".
  await tester.pump();
}

double _opacityDi(WidgetTester tester, Finder rigaFinder) {
  // `StaggeredFadeSlideIn`/`FadeTransition` avvolgono la riga (sono suoi
  // ANTENATI, non discendenti): `find.ancestor`, non `find.descendant`.
  final fade = tester.widget<FadeTransition>(
    find.ancestor(
      of: rigaFinder,
      matching: find.byType(FadeTransition),
    ),
  );
  return fade.opacity.value;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
      'una riga già mostrata in una build precedente si mostra subito in '
      "opacità finale (nessuna animazione rigiocata) quando la vista si "
      'ricostruisce, mentre una riga genuinamente nuova parte '
      "dall'opacità iniziale", (tester) async {
    final repo = await _setUpRepository(tester, buste: [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1)),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2)),
    ]);

    await _pumpArchivio(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    final rigaGen = find.byKey(const ValueKey('row-bp-gen'));
    final rigaFeb = find.byKey(const ValueKey('row-bp-feb'));
    expect(rigaGen, findsOneWidget);
    expect(rigaFeb, findsOneWidget);

    // Prima build: entrambe le righe sono avvolte in `StaggeredFadeSlideIn`
    // e la loro animazione non è ancora completata (il controller parte da
    // 0 e ha un ritardo prima di avviarsi). L'header (hero ultima busta paga
    // + riga tessere Ferie/Permessi/Ex festività) apre la stessa cascata con
    // altri 2 `StaggeredFadeSlideIn`, vedi CLAUDE.md/istruzioni task
    // "estendere la cascata già esistente anche all'header".
    expect(find.byType(StaggeredFadeSlideIn), findsNWidgets(4));
    expect(_opacityDi(tester, rigaGen), lessThan(1.0));
    expect(_opacityDi(tester, rigaFeb), lessThan(1.0));

    // Lascia completare le animazioni di ingresso della prima build.
    await tester.pumpAndSettle();
    expect(_opacityDi(tester, rigaGen), 1.0);
    expect(_opacityDi(tester, rigaFeb), 1.0);

    // Simula la causa reale di un rebuild della vista con le stesse righe
    // già presenti (un nuovo import — la stessa transizione di stato che
    // avviene quando una riga rientra nel viewport durante lo scroll):
    // aggiunge una terza busta paga e forza un secondo pump sulla STESSA
    // istanza di `_BustePagaArchivioViewState` (nessun nuovo `pumpWidget`,
    // altrimenti lo `State` — e quindi `_idGiaAnimati` — si ricreerebbe da
    // zero, invalidando il test).
    await tester.runAsync(
      () =>
          repo.notifier.add(_busta(id: 'bp-mar', periodo: DateTime(2026, 3))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final rigaMar = find.byKey(const ValueKey('row-bp-mar'));
    expect(rigaMar, findsOneWidget);

    // Le righe già viste restano immediatamente in opacità finale: nessuna
    // animazione rigiocata dal rebuild.
    expect(_opacityDi(tester, rigaGen), 1.0);
    expect(_opacityDi(tester, rigaFeb), 1.0);
    // La riga genuinamente nuova, invece, riparte dall'opacità iniziale
    // (animazione non ancora completata appena montata).
    expect(_opacityDi(tester, rigaMar), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(_opacityDi(tester, rigaMar), 1.0);

    await tester.runAsync(() => repo.db.close());
  });
}
