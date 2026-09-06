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
import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
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

  testWidgets(
      'grafico "Straordinario per mese": la prima barra/etichetta a '
      'sinistra è il mese più vecchio del periodo filtrato (ordine '
      'cronologico crescente), e valore/etichetta restano allineati per '
      'ogni barra', (tester) async {
    late final AppDatabase db;
    late final BustePagaNotifier notifier;
    // Tre mesi consecutivi, l'ultimo dei quali è il mese corrente reale —
    // così `estendiFinoA` (sempre il mese corrente, salvo restrizione
    // esplicita del filtro) non aggiunge slot di coda oltre `mar` e questo
    // test resta mirato solo all'ordine cronologico/allineamento etichette,
    // non all'estensione (coperta dal test dedicato più sotto).
    final oggi = DateTime.now();
    final mesePrimo = DateTime(oggi.year, oggi.month - 2);
    final meseSecondo = DateTime(oggi.year, oggi.month - 1);
    final meseTerzo = DateTime(oggi.year, oggi.month);
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BustePagaNotifier(db, const PdfImportService());
      await Future<void>.delayed(Duration.zero);

      // Tre mesi consecutivi con ore di straordinario tutte diverse, così
      // l'ordine è verificabile senza ambiguità (nessun valore ripetuto).
      await notifier.add(_busta(
        id: 'bp-gen',
        periodo: mesePrimo,
        stato: StatoVerificaBustaPaga.confermato,
      ).copyWith(straordinari: 5));
      await notifier.add(_busta(
        id: 'bp-feb',
        periodo: meseSecondo,
        stato: StatoVerificaBustaPaga.confermato,
      ).copyWith(straordinari: 8));
      await notifier.add(_busta(
        id: 'bp-mar',
        periodo: meseTerzo,
        stato: StatoVerificaBustaPaga.confermato,
      ).copyWith(straordinari: 12));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => notifier),
        ],
        child: CupertinoApp(
          home: BustePagaStatisticheScreen(
            periodoFiltro: (start: mesePrimo, end: meseTerzo),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);

    // La card "Straordinario per mese" è la terza e ultima della
    // `CustomScrollView`: su un viewport di test standard può restare fuori
    // dal cache extent iniziale e non essere ancora costruita — occorre
    // scorrere fino in fondo prima di cercarne i widget interni.
    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Con solo 3 mesi (ben sotto la soglia di aggregazione trimestrale e
    // sotto la larghezza minima che farebbe scattare lo scroll orizzontale)
    // il grafico Straordinario renderizza un solo `BarChart` con i dati
    // reali — a differenza del ramo con scroll, che aggiungerebbe un
    // secondo `BarChart` "solo asse" con `barGroups` vuoto.
    final barChartFinder = find.byType(BarChart);
    expect(barChartFinder, findsOneWidget);
    final barChart = tester.widget<BarChart>(barChartFinder);
    final barGroups = barChart.data.barGroups;

    // Ordine cronologico crescente della griglia continua: la prima barra
    // (x = 0, più a sinistra) deve essere gennaio (il mese più vecchio del
    // periodo filtrato, valore 5), a seguire febbraio (8) e infine marzo
    // (12) più a destra.
    expect(barGroups, hasLength(3));
    expect(barGroups[0].x, 0);
    expect(barGroups[0].barRods.single.toY, 5);
    expect(barGroups[1].x, 1);
    expect(barGroups[1].barRods.single.toY, 8);
    expect(barGroups[2].x, 2);
    expect(barGroups[2].barRods.single.toY, 12);

    // Le etichette dell'asse X confermano che l'ordine visivo (sinistra →
    // destra) rispecchia l'ordine dei `barGroups` sopra, senza
    // disallineamento fra dato e etichetta: "gen" (il valore più basso, 5)
    // deve comparire più a sinistra di "feb", che a sua volta precede "mar".
    // Le stesse etichette mese compaiono anche nel grafico Netto/Lordo
    // (ordine cronologico crescente, invariato) più in alto nella stessa
    // schermata: si limita la ricerca al `SliverToBoxAdapter` della card
    // "Straordinario per mese" (lo stesso che contiene il `BarChart` trovato
    // sopra) per non trovare ambiguamente entrambe le occorrenze.
    final straordinarioCardFinder = find
        .ancestor(of: barChartFinder, matching: find.byType(SliverToBoxAdapter))
        .first;
    final genX = tester
        .getCenter(find.descendant(
            of: straordinarioCardFinder,
            matching: find.text(meseAxisLabel(mesePrimo))))
        .dx;
    final febX = tester
        .getCenter(find.descendant(
            of: straordinarioCardFinder,
            matching: find.text(meseAxisLabel(meseSecondo))))
        .dx;
    final marX = tester
        .getCenter(find.descendant(
            of: straordinarioCardFinder,
            matching: find.text(meseAxisLabel(meseTerzo))))
        .dx;
    expect(genX, lessThan(febX));
    expect(febX, lessThan(marX));

    await tester.runAsync(() => db.close());
  });

  testWidgets(
      'un filtro periodo che copre tutto lo storico disponibile (come '
      'quello proposto di default dal picker) non blocca l\'estensione dei '
      'grafici fino al mese corrente reale — regressione Bug 1: solo un '
      'filtro che restringe DELIBERATAMENTE prima dell\'ultima busta paga '
      'disponibile deve impedire l\'estensione', (tester) async {
    late final AppDatabase db;
    late final BustePagaNotifier notifier;
    // Ultima (e unica) busta paga disponibile, qualche mese prima di oggi —
    // così l'estensione a "oggi" produce sempre almeno uno slot vuoto in
    // più, indipendentemente da quando gira il test.
    final oggi = DateTime.now();
    final periodo = DateTime(oggi.year, oggi.month - 3);

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BustePagaNotifier(db, const PdfImportService());
      await Future<void>.delayed(Duration.zero);

      await notifier.add(_busta(
        id: 'bp-unica',
        periodo: periodo,
        stato: StatoVerificaBustaPaga.confermato,
      ));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => notifier),
        ],
        child: CupertinoApp(
          home: BustePagaStatisticheScreen(
            // Filtro che copre esattamente tutto lo storico disponibile
            // (start ed end coincidono con l'unica busta paga presente) —
            // il caso comune di un utente che conferma l'intervallo
            // massimo proposto dal picker, NON una restrizione deliberata.
            periodoFiltro: (start: periodo, end: periodo),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);

    // Il grafico Netto/Lordo produce uno spot per ogni mese della griglia
    // continua (`_grigliaMensile`, vedi doc di libreria): se l'estensione
    // fino a oggi funziona, la griglia copre da `periodo` a oggi incluso,
    // quindi più di un singolo mese/spot.
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final speseMesi = (oggi.year - periodo.year) * 12 +
        (oggi.month - periodo.month) +
        1;
    expect(lineChart.data.lineBarsData.first.spots, hasLength(speseMesi));
    expect(speseMesi, greaterThan(1));

    await tester.runAsync(() => db.close());
  });

  testWidgets(
      'grafico "Straordinario per mese": con l\'ultima busta paga più '
      'vecchia del mese corrente, l\'estensione fino a oggi (`estendiFinoA`) '
      'resta visibile anche nel grafico a barre — regressione: prima del fix '
      'lo slot di coda veniva "compresso via" da '
      '`BarChartAlignment.spaceEvenly` insieme ai buchi interni', (tester) async {
    late final AppDatabase db;
    late final BustePagaNotifier notifier;
    final oggi = DateTime.now();
    final periodo = DateTime(oggi.year, oggi.month - 3);

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BustePagaNotifier(db, const PdfImportService());
      await Future<void>.delayed(Duration.zero);

      await notifier.add(_busta(
        id: 'bp-unica',
        periodo: periodo,
        stato: StatoVerificaBustaPaga.confermato,
      ).copyWith(straordinari: 5));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => notifier),
        ],
        child: CupertinoApp(
          home: BustePagaStatisticheScreen(
            periodoFiltro: (start: periodo, end: periodo),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final barChartFinder = find.byType(BarChart);
    expect(barChartFinder, findsOneWidget);
    final barChart = tester.widget<BarChart>(barChartFinder);
    final barGroups = barChart.data.barGroups;

    // Griglia continua da `periodo` a oggi incluso: senza il fix, `barGroups`
    // conterrebbe un solo gruppo (il mese con dati), "comprimendo via" tutti
    // gli slot vuoti successivi aggiunti dall'estensione.
    final speseMesi =
        (oggi.year - periodo.year) * 12 + (oggi.month - periodo.month) + 1;
    expect(speseMesi, greaterThan(1));
    expect(barGroups, hasLength(speseMesi));

    // L'ultimo gruppo (il mese corrente, senza dati reali) resta a
    // altezza zero — invisibile ma presente, senza mostrare un dato
    // fittizio.
    expect(barGroups.last.x, speseMesi - 1);
    expect(barGroups.last.barRods.single.toY, 0);

    // L'etichetta del mese corrente deve comparire (leggibile) sull'asse X
    // della card Straordinario, non essere sistematicamente nascosta dal
    // diradamento delle etichette.
    final straordinarioCardFinder = find
        .ancestor(of: barChartFinder, matching: find.byType(SliverToBoxAdapter))
        .first;
    expect(
      find.descendant(
        of: straordinarioCardFinder,
        matching: find.text(meseAxisLabel(oggi)),
      ),
      findsWidgets,
    );

    await tester.runAsync(() => db.close());
  });
}
