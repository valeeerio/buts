// Copre la sincronizzazione tap<->swipe tra Archivio e Statistiche
// introdotta in `BustePagaSectionScreen` (vedi CLAUDE.md): un unico
// `PageController` guida sia il tap sui tab della nav bar sia lo swipe
// orizzontale sul corpo della pagina, e `_onPageChanged` è l'unico punto che
// scrive lo stato `_tab` — quindi le due modalità non possono disallinearsi.
// Verifica anche la pillola animata (`AnimatedAlign`) che indica il tab
// attivo nella nav bar.
import 'package:buts/data/database.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/buste_paga_section_screen.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Stesso motivo degli altri test su `BustePagaNotifier`: `NativeDatabase.
/// memory()` fa I/O reale su un thread in background (FFI sqlite3), quindi
/// va guidato con `tester.runAsync` invece di un `await` diretto nel corpo
/// di `testWidgets`.
Future<
    ({
      AppDatabase db,
      BustePagaNotifier notifier,
    })> _setUpRepository(WidgetTester tester) async {
  late final AppDatabase db;
  late final BustePagaNotifier notifier;
  await tester.runAsync(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifier = BustePagaNotifier(db, const PdfImportService());
    await Future<void>.delayed(Duration.zero);
  });
  return (db: db, notifier: notifier);
}

Future<void> _pumpSection(
  WidgetTester tester,
  BustePagaNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busteRepositoryProvider.overrideWith((ref) => notifier),
      ],
      child: const CupertinoApp(home: BustePagaSectionScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Alignment corrente della pillola animata di sfondo dei tab, `null` se non
/// trovata (test fallirebbe comunque su `findsOneWidget` a monte).
Alignment? _pillAlignment(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is AnimatedAlign &&
        widget.duration == const Duration(milliseconds: 200),
  );
  expect(finder, findsOneWidget);
  return tester.widget<AnimatedAlign>(finder).alignment as Alignment?;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
      'stato iniziale: tab Archivio attivo e pillola allineata a sinistra',
      (tester) async {
    final repo = await _setUpRepository(tester);

    await _pumpSection(tester, repo.notifier);

    expect(find.text('Cerca'), findsNothing); // sanity: header di benvenuto
    expect(_pillAlignment(tester), Alignment.centerLeft);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'tap sul tab Statistiche cambia pagina, aggiorna la nav bar e sposta '
      'la pillola a destra', (tester) async {
    final repo = await _setUpRepository(tester);

    await _pumpSection(tester, repo.notifier);

    await tester.tap(find.text('Statistiche'));
    await tester.pumpAndSettle();

    // Header della pagina Statistiche visibile: prova che il `PageView` è
    // effettivamente passato alla seconda pagina.
    expect(find.text('Netto, ferie, straordinari'), findsOneWidget);
    expect(_pillAlignment(tester), Alignment.centerRight);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'swipe orizzontale sul corpo pagina cambia pagina e aggiorna lo stato '
      'tab attivo nella nav bar', (tester) async {
    final repo = await _setUpRepository(tester);

    await _pumpSection(tester, repo.notifier);

    // Trascina il `PageView` da destra verso sinistra: stesso gesto di uno
    // swipe utente per passare da Archivio a Statistiche.
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Netto, ferie, straordinari'), findsOneWidget);
    expect(_pillAlignment(tester), Alignment.centerRight);

    // Tornando indietro con lo swipe opposto si rientra in Archivio, con la
    // pillola di nuovo a sinistra: verifica la sincronizzazione nei due
    // versi, non solo andata.
    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(_pillAlignment(tester), Alignment.centerLeft);

    await tester.runAsync(() => repo.db.close());
  });
}
