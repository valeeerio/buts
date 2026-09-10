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
import 'package:flutter/gestures.dart';
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
      'card Netto: un tocco/scrub su un punto della linea mostra il '
      'tooltip custom con la busta paga corrispondente, SENZA aprire il '
      'drill-down (2026-09-10: il tap secco sul grafico non apre più '
      'direttamente il dettaglio, solo il tooltip)', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    // Il grafico Netto è ora l'unico `LineChart` della schermata (nessuna
    // seconda serie Lordo): recuperiamo direttamente `lineTouchData.
    // touchCallback` invece di simulare coordinate pixel-perfette di tap,
    // molto più fragile con fl_chart (vedi anche
    // `buste_paga_statistiche_screen_repro_test.dart`, che ispeziona i dati
    // del widget invece di simulare gesture per lo stesso motivo).
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final touchCallback = lineChart.data.lineTouchData.touchCallback;
    expect(touchCallback, isNotNull);

    final bar = lineChart.data.lineBarsData.single;
    // Il secondo mese (febbraio) è lo spot con indice 1 nella griglia
    // mensile continua costruita da `_grigliaMensile` — corrisponde alla
    // seconda busta paga.
    final spot = bar.spots[1];
    final touchedSpot = TouchLineBarSpot(bar, 0, spot, 0);

    touchCallback!(
      FlTapUpEvent(TapUpDetails(
          kind: PointerDeviceKind.touch, localPosition: const Offset(80, 90))),
      LineTouchResponse([touchedSpot]),
    );
    await tester.pumpAndSettle();

    // Il tooltip custom mostra il periodo e il netto della busta toccata,
    // ma nessun drill-down si apre da solo: "Chiudi" (bottone del bottom
    // sheet) non deve comparire.
    expect(find.text('Chiudi'), findsNothing);
    expect(find.text('Vedi dettaglio'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    // Solo il tap sulla riga "Vedi dettaglio" dentro il tooltip apre il
    // drill-down.
    await tester.tap(find.text('Vedi dettaglio'));
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: eventi di scrubbing (es. FlPanUpdateEvent) aggiornano '
      'anch\'essi il tooltip custom, senza mai aprire il drill-down da soli',
      (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final touchCallback = lineChart.data.lineTouchData.touchCallback;
    final bar = lineChart.data.lineBarsData.single;
    final spot = bar.spots[1];
    final touchedSpot = TouchLineBarSpot(bar, 0, spot, 0);

    touchCallback!(
      FlPanUpdateEvent(DragUpdateDetails(
          globalPosition: Offset.zero, localPosition: const Offset(80, 90))),
      LineTouchResponse([touchedSpot]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsNothing);
    expect(find.text('Vedi dettaglio'), findsOneWidget);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: se `buste` cambia (es. filtro periodo più stretto) '
      'mentre il tooltip custom è aperto su un punto che non esiste più '
      'nella griglia ricalcolata, il tooltip si chiude senza lanciare '
      'eccezioni (bug fix: `_spotIndex` della griglia vecchia non deve '
      'essere riusato su una griglia più corta)', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
      _busta(id: 'bp-mar', periodo: DateTime(2026, 3), netto: 1800),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    // Nessun filtro: la griglia copre gen/feb/mar (+ eventuale estensione).
    await _pumpStatistiche(tester, repo.notifier);
    expect(tester.takeException(), isNull);

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final touchCallback = lineChart.data.lineTouchData.touchCallback;
    final bar = lineChart.data.lineBarsData.single;
    // Tocca l'ultimo spot (marzo, indice 2), fuori dai limiti di una
    // griglia più corta come quella prodotta dal filtro sotto.
    final spot = bar.spots[2];
    final touchedSpot = TouchLineBarSpot(bar, 0, spot, 0);

    touchCallback!(
      FlTapUpEvent(TapUpDetails(
          kind: PointerDeviceKind.touch, localPosition: const Offset(80, 90))),
      LineTouchResponse([touchedSpot]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vedi dettaglio'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1800)), findsWidgets);

    // L'utente restringe il filtro periodo a solo gennaio: `filtrati` (e
    // quindi la griglia ricalcolata) diventa più corta dell'`spotIndex` 2
    // rimasto in `_spotAttivo` dallo stato precedente.
    await _pumpStatistiche(
      tester,
      repo.notifier,
      periodoFiltro: (start: DateTime(2026, 1), end: DateTime(2026, 1)),
    );
    await tester.pumpAndSettle();

    // Nessuna eccezione (in particolare nessun `RangeError` sull'indicizzazione
    // della griglia) e il tooltip obsoleto non è più mostrato.
    expect(tester.takeException(), isNull);
    expect(find.text('Vedi dettaglio'), findsNothing);
    expect(find.textContaining(formatEuroConSegno(1800)), findsNothing);

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
      'card Straordinario: il tap secco su una barra apre il drill-down '
      'con la busta paga corrispondente (Task 4 redesign Statistiche '
      '2026-09-08)', (tester) async {
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

    // Stesso approccio del test analogo per `_NettoChart` (Task 2): si
    // invoca direttamente `barTouchData.touchCallback` invece di simulare
    // coordinate pixel di tap, più fragile con fl_chart.
    final barChart = tester.widget<BarChart>(find.byType(BarChart));
    final touchCallback = barChart.data.barTouchData.touchCallback;
    expect(touchCallback, isNotNull);

    // Il secondo mese (febbraio) è il gruppo con indice x == 1 nella
    // griglia mensile continua costruita da `_grigliaMensile`.
    final group = barChart.data.barGroups.firstWhere((g) => g.x == 1);
    final rod = group.barRods.single;
    final touchedSpot = BarTouchedSpot(
      group,
      1,
      rod,
      0,
      null,
      -1,
      FlSpot(group.x.toDouble(), rod.toY),
      Offset.zero,
    );

    touchCallback!(
      FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
      BarTouchResponse(touchedSpot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Straordinario: eventi diversi dal tap secco non aprono il '
      'drill-down, per non interferire con hover/scrubbing', (tester) async {
    final buste = [
      _busta(id: 'bp-gen', periodo: DateTime(2026, 1), netto: 1400),
      _busta(id: 'bp-feb', periodo: DateTime(2026, 2), netto: 1600),
    ];
    final repo = await _setUpRepository(tester, buste: buste);

    await _pumpStatistiche(tester, repo.notifier);

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
    final touchCallback = barChart.data.barTouchData.touchCallback;
    final group = barChart.data.barGroups.firstWhere((g) => g.x == 1);
    final rod = group.barRods.single;
    final touchedSpot = BarTouchedSpot(
      group,
      1,
      rod,
      0,
      null,
      -1,
      FlSpot(group.x.toDouble(), rod.toY),
      Offset.zero,
    );

    touchCallback!(
      FlPanUpdateEvent(DragUpdateDetails(globalPosition: Offset.zero)),
      BarTouchResponse(touchedSpot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsNothing);

    await tester.runAsync(() => repo.db.close());
  });

}
