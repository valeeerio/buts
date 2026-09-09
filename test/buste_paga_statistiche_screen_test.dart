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
import 'package:buts/widgets/progress_ring_tile.dart';
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
    // Il toggle "Confronta con l'anno precedente" aggiunto in cima dal Task
    // 5 (redesign Statistiche 2026-09-08) spinge la card Straordinario oltre
    // il cache extent iniziale della `CustomScrollView` — stesso motivo per
    // cui gli altri test su quella card già scorrono esplicitamente prima di
    // cercarne i widget interni (vedi `buste_paga_statistiche_screen_repro_
    // test.dart`).
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

    final rings =
        tester.widgetList<ProgressRingTile>(find.byType(ProgressRingTile));
    final permessiRing = rings.singleWhere((r) => r.label == 'Permessi');

    // Valore atteso: SOLO `rolResidui` dell'ultima busta paga (5), formattato
    // come le altre quantità della schermata. Se il codice sommasse
    // indebitamente `permessiGodutiMese` (12), il valore mostrato sarebbe
    // "17" invece di "5" — doppio conteggio della stessa categoria di dato.
    expect(permessiRing.value, formatNumber(5));
    expect(permessiRing.value, isNot(formatNumber(5 + 12)));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Ferie/Permessi/Ex festività: il tap su un anello apre il '
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

    // Il toggle "Confronta con l'anno precedente" aggiunto in cima dal Task
    // 5 (redesign Statistiche 2026-09-08) spinge la card Ferie/Permessi/Ex
    // festività fuori dall'area visibile iniziale della `CustomScrollView` —
    // stesso motivo per cui gli altri test in questo file scorrono
    // esplicitamente prima di interagire con i widget interni.
    final ferieRingFinder = find.byWidgetPredicate(
      (w) => w is ProgressRingTile && w.label == 'Ferie',
    );
    await tester.scrollUntilVisible(
      ferieRingFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(ferieRingFinder);
    await tester.pumpAndSettle();

    // "Chiudi" segnala l'apertura del sheet di drill-down (Task 1). Il
    // netto mostrato deve essere quello dell'ULTIMA busta paga (febbraio),
    // non della prima toccata/visualizzata altrove nella schermata.
    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: il tap secco su un punto della linea apre il '
      'drill-down con la busta paga corrispondente (Task 2 redesign '
      'Statistiche 2026-09-08)', (tester) async {
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
      FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse([touchedSpot]),
    );
    await tester.pumpAndSettle();

    // "Chiudi" è il bottone del bottom sheet di drill-down
    // (`showBustaPagaDrilldown`, Task 1): la sua presenza è il segnale
    // affidabile che il sheet si sia aperto, a differenza del testo
    // "Febbraio 2026" già presente altrove nella schermata (es. sottotitolo
    // "Ultima busta paga" della card Ferie/Permessi/Ex festività).
    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.textContaining(formatEuroConSegno(1600)), findsWidgets);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'card Netto: eventi diversi dal tap secco (es. FlPanUpdateEvent) non '
      'aprono il drill-down, per non interferire con hover/scrubbing',
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
      FlPanUpdateEvent(DragUpdateDetails(globalPosition: Offset.zero)),
      LineTouchResponse([touchedSpot]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chiudi'), findsNothing);

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

  group('confronto anno su anno (Task 5 redesign Statistiche 2026-09-08)', () {
    // Un'ancora ben oltre `periodoFiltro` (2030) fa sì che l'ultima busta
    // paga REALMENTE disponibile (`sorted.last`, usata per calcolare
    // `estendiFinoA`) sia successiva alla fine del filtro esplicito: così
    // `estendiFinoA` coincide esattamente con `filtro.end` (nessuno slot
    // vuoto aggiunto in coda), e gli indici della griglia mensile
    // corrispondono 1:1 ai 2 mesi del filtro senza calcoli aggiuntivi legati
    // alla data odierna reale in cui gira il test.
    List<BustaPaga> buste() => [
          _busta(
              id: 'bp-2025-gen',
              periodo: DateTime(2025, 1),
              netto: 1000,
              straordinari: 2),
          _busta(
              id: 'bp-2025-feb',
              periodo: DateTime(2025, 2),
              netto: 1100,
              straordinari: 3),
          _busta(
              id: 'bp-2026-gen',
              periodo: DateTime(2026, 1),
              netto: 1400,
              straordinari: 5),
          _busta(
              id: 'bp-2026-feb',
              periodo: DateTime(2026, 2),
              netto: 1600,
              straordinari: 10),
          _busta(id: 'bp-ancora', periodo: DateTime(2030, 1), netto: 9999),
        ];

    final periodoFiltro = (start: DateTime(2026, 1), end: DateTime(2026, 2));

    testWidgets(
        'con periodoFiltro == null il toggle è presente ma non '
        'interagibile', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier);
      expect(tester.takeException(), isNull);

      expect(find.text('Confronta con l\'anno precedente'), findsOneWidget);
      final toggle = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(toggle.onChanged, isNull);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets(
        'con periodoFiltro non-null il toggle è interagibile ma di default '
        'spento: nessuna seconda serie nei grafici', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier,
          periodoFiltro: periodoFiltro);
      expect(tester.takeException(), isNull);

      final toggle = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, isFalse);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(1));

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets(
        'attivando il toggle compare la linea tratteggiata Netto con i dati '
        'dello stesso range un anno prima', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier,
          periodoFiltro: periodoFiltro);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(2));

      final mainLine = lineChart.data.lineBarsData[0];
      final ghostLine = lineChart.data.lineBarsData[1];

      // La linea fantasma non ha area riempita ed è tratteggiata.
      expect(ghostLine.dashArray, [6, 4]);
      expect(ghostLine.belowBarData.show, isFalse);
      // Stesso ciano della linea principale, opacità ridotta.
      expect(ghostLine.color, mainLine.color!.withValues(alpha: 0.35));

      // Allineata indice per indice con la griglia principale (gen/feb
      // 2026 → gen/feb 2025).
      expect(ghostLine.spots[0].y, 1000);
      expect(ghostLine.spots[1].y, 1100);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets(
        'il tap sulla linea fantasma dell\'anno precedente non apre il '
        'drill-down', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier,
          periodoFiltro: periodoFiltro);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final touchCallback = lineChart.data.lineTouchData.touchCallback;
      final ghostBar = lineChart.data.lineBarsData[1];
      final ghostSpot = ghostBar.spots[0];
      final touchedGhostSpot = TouchLineBarSpot(ghostBar, 1, ghostSpot, 0);

      touchCallback!(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
        LineTouchResponse([touchedGhostSpot]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chiudi'), findsNothing);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets(
        'attivando il toggle compaiono le barre a contorno Straordinario con '
        'i dati dello stesso range un anno prima', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier,
          periodoFiltro: periodoFiltro);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Straordinario per mese'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final gruppoGennaio =
          barChart.data.barGroups.firstWhere((g) => g.x == 0);
      final gruppoFebbraio =
          barChart.data.barGroups.firstWhere((g) => g.x == 1);

      expect(gruppoGennaio.barRods, hasLength(2));
      expect(gruppoFebbraio.barRods, hasLength(2));

      final ghostGennaio = gruppoGennaio.barRods[1];
      final ghostFebbraio = gruppoFebbraio.barRods[1];

      // Nessun riempimento, solo contorno ciano.
      expect(ghostGennaio.color, CupertinoColors.transparent);
      expect(ghostGennaio.borderSide.width, greaterThan(0));
      expect(ghostGennaio.toY, 2);
      expect(ghostFebbraio.toY, 3);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets(
        'il tap su una barra fantasma dell\'anno precedente non apre il '
        'drill-down', (tester) async {
      final repo = await _setUpRepository(tester, buste: buste());

      await _pumpStatistiche(tester, repo.notifier,
          periodoFiltro: periodoFiltro);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Straordinario per mese'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final touchCallback = barChart.data.barTouchData.touchCallback;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == 1);
      final ghostRod = group.barRods[1];
      final touchedSpot = BarTouchedSpot(
        group,
        1,
        ghostRod,
        1,
        null,
        -1,
        FlSpot(group.x.toDouble(), ghostRod.toY),
        Offset.zero,
      );

      touchCallback!(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
        BarTouchResponse(touchedSpot),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chiudi'), findsNothing);

      await tester.runAsync(() => repo.db.close());
    });
  });
}
