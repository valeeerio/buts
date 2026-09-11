// Copertura sistematica della schermata Statistiche
// (`BustePagaStatisticheScreen`), a complemento del test di riproduzione
// bug esistente (`buste_paga_statistiche_screen_repro_test.dart`, mirato a
// un crash specifico del grafico Straordinario).
//
// CLAUDE.md richiede esplicitamente: "i grafici sono mostrati sempre, anche
// con 0 o 1 busta paga: ogni grafico senza dati sufficienti mostra il
// messaggio 'Non ci sono dati' al posto di bloccare l'intera pagina" — questi
// test verificano quel comportamento leggendo il codice reale della
// schermata invece di assumerlo (vedi in particolare il caso "1 sola busta
// paga", dove il codice attuale NON mostra "Non ci sono dati": con
// `filtrati.length == 1` la lista non è vuota, quindi i grafici Netto e
// Ferie/Permessi la disegnano regolarmente — solo il caso 0 buste paga
// (`filtrati.isEmpty`) attiva `_NoDataMessage`).
import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_statistiche_screen.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:buts/theme/app_colors.dart';
import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:buts/widgets/value_tile.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({
  required String id,
  required DateTime periodo,
  double netto = 1500,
  double lordo = 2000,
  double straordinari = 5,
  double ferieMaturate = 10,
  double ferieGodute = 2,
  double ferieResidue = 8,
  double rolMaturati = 6,
  double rolGoduti = 1,
  double rolResidui = 5,
  double permessiGoduti = 0,
  double permessiGodutiMese = 0,
  double exFestivitaMaturate = 4,
  double exFestivitaGodute = 1,
  double exFestivitaResidue = 3,
  StatoVerificaBustaPaga stato = StatoVerificaBustaPaga.confermato,
}) {
  return BustaPaga(
    id: id,
    periodo: periodo,
    lordo: lordo,
    netto: netto,
    trattenute: const {},
    straordinari: straordinari,
    ferieMaturate: ferieMaturate,
    ferieGodute: ferieGodute,
    ferieResidue: ferieResidue,
    rolMaturati: rolMaturati,
    rolGoduti: rolGoduti,
    rolResidui: rolResidui,
    permessiGoduti: permessiGoduti,
    permessiGodutiMese: permessiGodutiMese,
    exFestivitaMaturate: exFestivitaMaturate,
    exFestivitaGodute: exFestivitaGodute,
    exFestivitaResidue: exFestivitaResidue,
    oreLavorate: 168,
    statoVerifica: stato,
  );
}

/// Stesso motivo del test di riproduzione bug: `NativeDatabase.memory()` fa
/// I/O reale su un thread in background (FFI sqlite3), quindi va guidato con
/// `tester.runAsync` invece di un `await` diretto nel corpo di `testWidgets`.
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

Future<void> _pumpStatistiche(
  WidgetTester tester,
  BustePagaNotifier notifier, {
  ({DateTime start, DateTime end})? periodoFiltro,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busteRepositoryProvider.overrideWith((ref) => notifier),
      ],
      child: CupertinoApp(
        home: BustePagaStatisticheScreen(periodoFiltro: periodoFiltro),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
      '0 buste paga: la schermata si apre senza eccezioni e ogni grafico '
      'mostra "Non ci sono dati"', (tester) async {
    final repo = await _setUpRepository(tester, buste: const []);

    await _pumpStatistiche(tester, repo.notifier);

    expect(tester.takeException(), isNull);

    // La card Straordinario potrebbe restare oltre il cache extent iniziale
    // della `CustomScrollView` a seconda del viewport di test — stesso
    // motivo per cui gli altri test su quella card già scorrono
    // esplicitamente prima di cercarne i widget interni (vedi
    // `buste_paga_statistiche_screen_repro_test.dart`).
    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Un messaggio per ciascuna delle 3 card (Netto, Ferie/Permessi/Ex
    // festività, Straordinario) invece di bloccare l'intera pagina.
    expect(find.text('Non ci sono dati'), findsNWidgets(3));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      '1 sola busta paga: nessuna eccezione, e (comportamento reale del '
      'codice) i grafici Netto e Ferie/Permessi disegnano comunque il '
      'singolo punto invece di mostrare "Non ci sono dati", perché la lista '
      'filtrata non è vuota', (tester) async {
    final repo = await _setUpRepository(tester, buste: [
      _busta(id: 'bp-unica', periodo: DateTime(2026, 3)),
    ]);

    await _pumpStatistiche(tester, repo.notifier);

    expect(tester.takeException(), isNull);
    // `_NoDataMessage` scatta solo quando `filtrati.isEmpty` — con 1 busta
    // paga confermata la lista ha lunghezza 1, quindi nessuna delle card
    // mostra il messaggio "Non ci sono dati".
    expect(find.text('Non ci sono dati'), findsNothing);
    // Il blocco Netto mostra comunque il valore dell'unica busta paga.
    expect(find.text(formatEuroConSegno(1500)), findsOneWidget);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'più buste paga con permessiGodutiMese valorizzato: l\'anello '
      '"Permessi" dello snapshot usa il residuo cumulativo (rolResidui) '
      'dell\'ultima busta paga, SENZA sommarci permessiGodutiMese (mensile, '
      'stessa categoria letta a granularità diversa — sommarli produrrebbe '
      'un doppio conteggio)', (tester) async {
    final buste = [
      _busta(
        id: 'bp-gen',
        periodo: DateTime(2026, 1),
        rolResidui: 20,
        permessiGodutiMese: 3,
      ),
      _busta(
        id: 'bp-feb',
        periodo: DateTime(2026, 2),
        rolResidui: 17,
        permessiGodutiMese: 4,
      ),
      // Ultima busta paga del periodo: quella che alimenta lo snapshot
      // (`_FerieRolPermessiSnapshot` usa `buste.last`).
      _busta(
        id: 'bp-mar',
        periodo: DateTime(2026, 3),
        rolResidui: 5,
        permessiGodutiMese: 12,
      ),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);

    expect(tester.takeException(), isNull);

    final tiles = tester.widgetList<ValueTile>(find.byType(ValueTile));
    final permessiTile = tiles.singleWhere((t) => t.label == 'Permessi');

    // Valore atteso: SOLO `rolResidui` dell'ultima busta paga (5), formattato
    // come le altre quantità della schermata. Se il codice sommasse
    // indebitamente `permessiGodutiMese` (12), il valore mostrato sarebbe
    // "17" invece di "5" — doppio conteggio della stessa categoria di dato.
    expect(permessiTile.value, formatNumber(5));
    expect(permessiTile.value, isNot(formatNumber(5 + 12)));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Ferie/Permessi/Ex festività: il tap su una tessera apre il '
      'drill-down con i dati dell\'ultima busta paga (Task 3 redesign '
      'Statistiche 2026-09-08)', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      // Ultima busta paga del periodo: quella che alimenta lo snapshot
      // (`_FerieRolPermessiSnapshot` usa `buste.last`) e che il drill-down
      // deve mostrare, a prescindere da quale dei 3 anelli viene toccato.
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // La card Ferie/Permessi/Ex festività può restare fuori dall'area
    // visibile iniziale della `CustomScrollView` a seconda del viewport di
    // test — stesso motivo per cui gli altri test in questo file scorrono
    // esplicitamente prima di interagire con i widget interni.
    final ferieTileFinder = find.byWidgetPredicate(
      (w) => w is ValueTile && w.label == 'Ferie',
    );
    await tester.scrollUntilVisible(
      ferieTileFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(ferieTileFinder);
    await tester.pumpAndSettle();

    // "Chiudi" segnala l'apertura del sheet di drill-down (Task 1). Il
    // netto mostrato deve essere quello dell'ULTIMA busta paga (febbraio),
    // non della prima toccata/visualizzata altrove nella schermata.
    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: il grafico non ha alcuna interazione al tocco '
      '(2026-09-10, richiesta esplicita dell\'utente: "il tap sui grafici '
      'non mi piace per niente... eliminalo del tutto") — `lineTouchData` è '
      'disattivato e nessun tap apre il drill-down', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // Il grafico Netto è l'unico `LineChart` della schermata (nessuna
    // seconda serie Lordo): `lineTouchData.enabled` deve essere `false`,
    // niente tooltip nativo né callback residuo.
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.lineTouchData.enabled, isFalse);

    // Un tap secco sull'area del grafico non apre alcun drill-down né
    // mostra un tooltip.
    await tester.tap(find.byType(LineChart));
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsNothing);
    expect(find.text('Vedi dettaglio'), findsNothing);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Straordinario: le barre sono un riempimento pieno ciano '
      '(niente più gradiente viola→ciano, Task 4 redesign Statistiche '
      '2026-09-08)', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), straordinari: 3),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), straordinari: 10),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // La card "Straordinario per mese" è l'ultima della `CustomScrollView`:
    // su un viewport di test standard può restare fuori dal cache extent
    // iniziale e non essere ancora costruita (vedi
    // `buste_paga_statistiche_screen_repro_test.dart`) — occorre scorrere
    // fino in fondo prima di cercarne i widget interni.
    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final accent = CupertinoDynamicColor.resolve(
        AppColors.pulseAccent, tester.element(find.byType(BarChart)));
    final barChart = tester.widget<BarChart>(find.byType(BarChart));
    final rods = [
      for (final group in barChart.data.barGroups) group.barRods.single,
    ];

    // Nessuna barra usa più un gradiente: ogni `BarChartRodData` ha un
    // riempimento a colore pieno ciano, opaco per la barra del mese col
    // valore massimo (febbraio) e a opacità ridotta per le altre.
    for (final rod in rods) {
      expect(rod.gradient, isNull);
      expect(rod.color, isNotNull);
    }
    final barGennaio = rods[0];
    final barFebbraio = rods[1];
    expect(barFebbraio.color, accent);
    expect(barGennaio.color, accent.withValues(alpha: 0.55));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Straordinario: il grafico non ha alcuna interazione al tocco '
      '(2026-09-10, richiesta esplicita dell\'utente: "il tap sui grafici '
      'non mi piace per niente... eliminalo del tutto") — `barTouchData` è '
      'disattivato e nessun tap apre il drill-down', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // La card "Straordinario per mese" è l'ultima della `CustomScrollView`:
    // su un viewport di test standard può restare fuori dal cache extent
    // iniziale e non essere ancora costruita (vedi
    // `buste_paga_statistiche_screen_repro_test.dart`) — occorre scorrere
    // fino in fondo prima di cercarne i widget interni.
    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final barChart = tester.widget<BarChart>(find.byType(BarChart));
    expect(barChart.data.barTouchData.enabled, isFalse);

    // Un tap secco su una barra non apre alcun drill-down.
    await tester.tap(find.byType(BarChart));
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsNothing);

    await tester.runAsync(() => repo.db.close());
  });

  // Redesign "molto storico" (2026-09-11, vedi CLAUDE.md): opzione B+D —
  // scroll orizzontale a larghezza fissa per mese (nessuna etichetta mai
  // diradata/nascosta) + un'etichetta "in vista" fissa in alto nella card
  // che riassume il range di mesi effettivamente visibile nello scroll.
  testWidgets(
      'card Netto: con molto storico il grafico diventa scrollabile in '
      'orizzontale e nessuna etichetta di mese viene mai diradata/nascosta',
      (tester) async {
    final buste = <BustaPaga>[];
    var periodo = DateTime(2015, 1);
    for (var i = 0; i < 40; i++) {
      buste.add(_busta(id: 'bp-$i', periodo: periodo, netto: 1500 + i.toDouble()));
      periodo = DateTime(periodo.year, periodo.month + 1);
    }
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // Il grafico Netto è la prima card, visibile senza scorrere la pagina:
    // un solo `SingleChildScrollView` orizzontale (quello di Straordinario,
    // più in basso, non è ancora costruito perché fuori dal cache extent
    // iniziale della `CustomScrollView`).
    final scrollFinder = find.byType(SingleChildScrollView);
    expect(scrollFinder, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).scrollDirection,
      Axis.horizontal,
    );

    // Nessun diradamento: l'etichetta del primo mese importato (confine
    // anno, formato completo "gen '15") e quella dell'ultimo ("apr" 2018)
    // restano entrambe presenti nell'albero — con la vecchia logica a
    // soglia annuale (40 mesi > `_yearlyLabelsThreshold`, 14) sarebbero
    // state sostituite da sole etichette d'anno.
    expect(find.text(periodoAxisLabel(DateTime(2015, 1))), findsOneWidget);
    expect(find.textContaining(meseAxisLabel(DateTime(2018, 4))),
        findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: con molto storico lo scroll iniziale parte già '
      'posizionato sull\'estremità più recente dello storico', (tester) async {
    final buste = <BustaPaga>[];
    var periodo = DateTime(2015, 1);
    for (var i = 0; i < 40; i++) {
      buste.add(_busta(id: 'bp-$i', periodo: periodo, netto: 1500 + i.toDouble()));
      periodo = DateTime(periodo.year, periodo.month + 1);
    }
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.hasClients, isTrue);
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: un\'etichetta "in vista" fissa in alto nella card '
      'riassume il range di mesi visibile — presente sia col grafico '
      'scrollabile sia con uno storico che entra per intero nella card',
      (tester) async {
    // Storico breve: nessuno scroll necessario, l'etichetta deve comunque
    // comparire (copre subito l'intero range filtrato).
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Nessun'altra etichetta della schermata usa "→": la subtitle del
    // periodo filtrato resta "Tutto lo storico" (nessun filtro applicato in
    // questo test) senza freccia — l'unica corrispondenza possibile è
    // l'etichetta "in vista" di `_ChartCard`.
    expect(find.textContaining('→'), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Straordinario: con molto storico lo scroll iniziale parte già '
      'posizionato sull\'estremità più recente dello storico (comportamento '
      'nuovo di questo redesign — prima di questo il grafico Straordinario '
      'non aveva scroll orizzontale)', (tester) async {
    final buste = <BustaPaga>[];
    var periodo = DateTime(2022, 1);
    // 24 mesi: sotto la soglia di aggregazione trimestrale
    // (`_quarterlyAggregationThreshold`, 24 — la condizione è "> 24", quindi
    // 24 mesi restano barre mensili), ma già abbastanza larghi
    // (24 * `_minGroupSlotWidth` 36px = 864px) da superare la larghezza
    // disponibile nella card e forzare lo scroll orizzontale.
    for (var i = 0; i < 24; i++) {
      buste.add(_busta(
        id: 'bp-$i',
        periodo: periodo,
        straordinari: 5 + i.toDouble(),
      ));
      periodo = DateTime(periodo.year, periodo.month + 1);
    }
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);

    // La card Straordinario può restare oltre il cache extent iniziale della
    // `CustomScrollView` a seconda del viewport di test (stesso motivo degli
    // altri test di questo file che scorrono esplicitamente prima di cercare
    // widget interni a quella card).
    await tester.scrollUntilVisible(
      find.text('Straordinario per mese'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Con questi 24 mesi anche il grafico Netto (slot da 56px) risulta
    // scrollabile: ci aspettiamo due `SingleChildScrollView` nell'albero (uno
    // per Netto, uno per Straordinario) — quello di Straordinario è
    // l'ultimo, essendo la terza card della schermata.
    final scrollFinder = find.byType(SingleChildScrollView);
    expect(scrollFinder, findsNWidgets(2));

    final straordinarioController =
        tester.widget<SingleChildScrollView>(scrollFinder.last).controller!;
    expect(straordinarioController.hasClients, isTrue);
    expect(
      straordinarioController.offset,
      closeTo(straordinarioController.position.maxScrollExtent, 0.5),
    );

    await tester.runAsync(() => repo.db.close());
  });

  // Bug corretto (segnalato da revisore su questo redesign): `_NettoChart`/
  // `_StraordinarioChart` venivano ricostruiti senza `Key` quando cambiava il
  // filtro periodo — Flutter riusava lo stesso `State`, quindi
  // `_initialScrollDone` (`_VisibleRangeReporterMixin`) restava `true` per
  // sempre dopo il primo scroll-to-end: un cambio di filtro con la card
  // ancora scrollabile prima e dopo non faceva mai ripartire né lo
  // scroll-to-end né il ricalcolo dell'etichetta "in vista", che restavano
  // bloccati ai valori del periodo precedente. Fix: una `Key` derivata dai
  // dati (`_chartDataKey`) forza un nuovo `State` a ogni cambio di dataset.
  testWidgets(
      'card Netto: cambiare filtro periodo con la card sempre scrollabile fa '
      'ripartire lo scroll-to-end e l\'etichetta "in vista" sul nuovo '
      'periodo, invece di restare bloccati su quelli del periodo precedente',
      (tester) async {
    // Due blocchi di dati non contigui e di lunghezza diversa (20 vs 40
    // mesi): lunghezza diversa così il `maxScrollExtent` cambia sensibilmente
    // fra i due filtri (uno scroll "rimasto fermo" sarebbe rilevabile), date
    // in anni diversi così le rispettive etichette "in vista" (che includono
    // sempre l'anno, vedi `_viewRangeLabel`) sono facilmente distinguibili.
    final busteVecchie = <BustaPaga>[];
    var periodo = DateTime(2000, 1);
    for (var i = 0; i < 20; i++) {
      busteVecchie.add(_busta(id: 'bp-old-$i', periodo: periodo));
      periodo = DateTime(periodo.year, periodo.month + 1);
    }
    final busteNuove = <BustaPaga>[];
    periodo = DateTime(2015, 1);
    for (var i = 0; i < 40; i++) {
      busteNuove.add(_busta(id: 'bp-new-$i', periodo: periodo));
      periodo = DateTime(periodo.year, periodo.month + 1);
    }
    final repo = await _setUpRepository(
      tester,
      buste: [
        ...busteVecchie,
        ...busteNuove,
        // Busta paga successiva a ENTRAMBI i filtri sotto, così
        // `ultimoConfermato` (l'ultima busta paga REALE dell'intero
        // archivio, non filtrata) resta oltre `filtroNuovo.end`: altrimenti
        // `estendiFinoA` estenderebbe la griglia fino al mese corrente reale
        // invece di fermarsi ad aprile 2018 (vedi doc di `estendiFinoA` in
        // `BustePagaStatisticheScreen.build`), e le etichette attese sotto
        // non corrisponderebbero più all'estremità del grafico.
        _busta(id: 'bp-oltre-entrambi', periodo: DateTime(2020, 1)),
      ],
    );

    final filtroVecchio = (start: DateTime(2000, 1), end: DateTime(2001, 8));
    final filtroNuovo = (start: DateTime(2015, 1), end: DateTime(2018, 4));

    await _pumpStatistiche(tester, repo.notifier, periodoFiltro: filtroVecchio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    var controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.hasClients, isTrue);
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );
    // L'etichetta "in vista" copre l'estremità più recente del periodo
    // vecchio (agosto 2001), mai il nuovo periodo (2018).
    expect(find.textContaining("Ago '01"), findsWidgets);
    expect(find.textContaining("'18"), findsNothing);

    // Cambio filtro sullo STESSO albero di widget (stesso `pumpWidget`, non
    // un nuovo `ProviderScope`/`CupertinoApp`): riproduce esattamente lo
    // scenario reale in cui l'utente sceglie un nuovo periodo dal filtro e
    // `BustePagaStatisticheScreen` viene ricostruita con un `periodoFiltro`
    // diverso, non rimontata da zero.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => repo.notifier),
        ],
        child: CupertinoApp(
          home: BustePagaStatisticheScreen(periodoFiltro: filtroNuovo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.hasClients, isTrue);
    // Senza il fix questo controller sarebbe lo stesso di prima (`State`
    // riusato), fermo al vecchio offset — ben lontano dal nuovo
    // `maxScrollExtent`, più ampio (40 mesi contro i 20 del filtro
    // precedente). Con il fix lo scroll riparte da capo verso la nuova
    // estremità più recente.
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );
    // L'etichetta "in vista" deve aggiornarsi al nuovo periodo (aprile 2018)
    // e non mostrare più quella del periodo precedente (bug reale
    // riprodotto: senza il fix "Ago '01" restava visibile anche dopo il
    // cambio filtro, perché `onVisibleRangeChanged` non veniva mai
    // richiamato di nuovo).
    expect(find.textContaining("Ago '01"), findsNothing);
    expect(find.textContaining("Apr '18"), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  // Caso limite reale corretto in `_chartDataKey` (segnalato da revisore):
  // una busta paga INTERNA al range filtrato (né la prima né l'ultima per
  // data) che cambia periodo dal dettaglio ("Modifica inline") lascia
  // `buste.length`/id della prima/id dell'ultima IDENTICI — l'unica cosa che
  // cambia è quale mese della griglia mensile ha un buco. Una chiave basata
  // solo su lunghezza + id di bordo non cambierebbe affatto, quindi lo
  // `State` di `_NettoChart` verrebbe riusato: uno scroll manuale fatto
  // dall'utente PRIMA della modifica (qui simulato con `jumpTo(0)`, lontano
  // dall'estremità più recente) resterebbe bloccato lì per sempre invece di
  // ripartire con un nuovo scroll-to-end sul nuovo dataset, come fanno tutti
  // gli altri cambi di dati di questa schermata. Il fix (impronta a bit della
  // forma della griglia inclusa nella chiave, vedi doc di `_chartDataKey`)
  // forza un nuovo `State` anche in questo caso.
  testWidgets(
      'card Netto: cambiare il periodo di una busta paga interna al range '
      '(count/primo/ultimo id invariati) fa ripartire lo scroll-to-end '
      'invece di restare bloccato sulla posizione scrollata manualmente '
      'prima della modifica', (tester) async {
    // Solo 3 buste paga reali su uno storico di 20 mesi (Gen '16 → Ago '17):
    // la griglia mensile continua (`_grigliaMensile`) copre comunque tutti e
    // 20 gli slot fra la prima e l'ultima busta paga, quindi il grafico
    // resta scrollabile (20 * 56px slotWidth) esattamente come nel test
    // sopra basato su 20 mesi consecutivi — non serve un dato per ogni mese.
    final buste = [
      _busta(id: 'bp-first', periodo: DateTime(2016, 1)),
      _busta(id: 'bp-mid', periodo: DateTime(2016, 10)),
      _busta(id: 'bp-last', periodo: DateTime(2017, 8)),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scrollFinder = find.byType(SingleChildScrollView).first;
    var controller =
        tester.widget<SingleChildScrollView>(scrollFinder).controller!;
    expect(controller.hasClients, isTrue);
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );

    // L'utente scorre manualmente lontano dall'estremità più recente (es.
    // per rivedere l'inizio dello storico) prima di andare a modificare una
    // busta paga dal dettaglio.
    controller.jumpTo(0);
    await tester.pump();
    expect(controller.offset, closeTo(0, 0.5));

    // Modifica inline dal dettaglio: sposta "bp-mid" da Ottobre 2016 a Marzo
    // 2017, restando comunque strettamente interna al range (Gen '16 → Ago
    // '17) — `buste.length` (3), id della prima ("bp-first") e id
    // dell'ultima ("bp-last") restano identici, cambia solo quale mese della
    // griglia ha un buco.
    await tester.runAsync(
      () => repo.notifier.update(
        buste[1].copyWith(periodo: DateTime(2017, 3)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView).first)
        .controller!;
    expect(controller.hasClients, isTrue);
    // Senza il fix questo sarebbe lo stesso controller di prima, ancora fermo
    // a offset 0 (bug: la chiave non catturava il cambio di "forma" della
    // griglia). Con il fix lo `State` riparte da zero e rilancia lo
    // scroll-to-end sulla nuova griglia.
    expect(controller.offset, isNot(closeTo(0, 0.5)));
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 0.5),
    );

    await tester.runAsync(() => repo.db.close());
  });
}
