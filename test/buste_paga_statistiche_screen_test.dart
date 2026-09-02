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
// `filtrati.length == 1` la lista non è vuota, quindi i grafici Netto/Lordo e
// Ferie/Permessi la disegnano regolarmente — solo il caso 0 buste paga
// (`filtrati.isEmpty`) attiva `_NoDataMessage`).
import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_statistiche_screen.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:buts/widgets/progress_ring_tile.dart';
import 'package:drift/native.dart';
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
  BustePagaNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busteRepositoryProvider.overrideWith((ref) => notifier),
      ],
      child: const CupertinoApp(
        home: BustePagaStatisticheScreen(),
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
    // Un messaggio per ciascuna delle 3 card (Netto/Lordo, Ferie/Permessi/Ex
    // festività, Straordinario) invece di bloccare l'intera pagina.
    expect(find.text('Non ci sono dati'), findsNWidgets(3));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      '1 sola busta paga: nessuna eccezione, e (comportamento reale del '
      'codice) i grafici Netto/Lordo e Ferie/Permessi disegnano comunque il '
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
    // Il blocco Netto/Lordo mostra comunque il valore dell'unica busta paga.
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
}
