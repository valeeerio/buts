// Test del blocco esplicito sul salvataggio quando il parser non riconosce
// il periodo (`BustaPagaEstratti.periodo == null`): il form deve aprire
// automaticamente il picker mese/anno, mostrare il nuovo warning e non
// permettere "Salva" finché l'utente non conferma il periodo esplicitamente
// (tramite `_pickPeriodo()`) — vedi CLAUDE.md/istruzioni task.
import 'package:buts/data/database.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/busta_paga_form_screen.dart';
import 'package:buts/services/busta_paga_regex_parser.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _estrattiSenzaPeriodo = BustaPagaEstratti(
  periodo: null,
  lordo: 2000,
  netto: 1500,
  trattenute: {},
  straordinari: 0,
  ferieMaturate: 0,
  ferieGodute: 0,
  ferieResidue: 0,
  rolMaturati: 0,
  rolGoduti: 0,
  rolResidui: 0,
  permessiGoduti: 0,
  oreLavorate: 168,
  warnings: [],
);

const _estrattiConPeriodo = BustaPagaEstratti(
  periodo: '2026-01',
  lordo: 2000,
  netto: 1500,
  trattenute: {},
  straordinari: 0,
  ferieMaturate: 0,
  ferieGodute: 0,
  ferieResidue: 0,
  rolMaturati: 0,
  rolGoduti: 0,
  rolResidui: 0,
  permessiGoduti: 0,
  oreLavorate: 168,
  warnings: [],
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  /// Stesso pattern di `test/buste_paga_statistiche_screen_repro_test.dart`:
  /// `NativeDatabase.memory()` esegue le query reali su un isolate in
  /// background (FFI sqlite3), quindi serve `tester.runAsync` per il setup.
  Future<
      ({
        AppDatabase db,
        BustePagaNotifier notifier,
      })> makeRepo(WidgetTester tester) async {
    late final AppDatabase db;
    late final BustePagaNotifier notifier;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BustePagaNotifier(db, const PdfImportService());
      await Future<void>.delayed(Duration.zero);
    });
    return (db: db, notifier: notifier);
  }

  testWidgets(
      'periodo non riconosciuto: warning aggiornato mostrato, "Salva" non '
      'salva finché il periodo non è confermato', (tester) async {
    final repo = await makeRepo(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => repo.notifier),
        ],
        child: const CupertinoApp(
          home: BustaPagaFormScreen.daImport(
            fileOrigine: '/tmp/finto.pdf',
            estratti: _estrattiSenzaPeriodo,
          ),
        ),
      ),
    );

    // Il picker mese/anno si apre in automatico al primo frame: chiudilo
    // subito (senza confermare) per verificare che il blocco resti attivo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fatto'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20)); // barrier, chiude il popup
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Periodo non riconosciuto automaticamente'),
      findsOneWidget,
    );
    expect(
      find.textContaining('non potrai salvare finché non lo confermi'),
      findsOneWidget,
    );

    // "Salva" è disabilitato (`saveEnabled == false` finché il periodo non
    // è confermato): il tap è un no-op esplicito, nessun salvataggio parte
    // nemmeno tentando di premerlo.
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(repo.notifier.state, isEmpty);

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'conferma esplicita del periodo (tap "Fatto" nel picker) sblocca il '
      'salvataggio', (tester) async {
    final repo = await makeRepo(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => repo.notifier),
        ],
        child: const CupertinoApp(
          home: BustaPagaFormScreen.daImport(
            fileOrigine: '/tmp/finto.pdf',
            estratti: _estrattiSenzaPeriodo,
          ),
        ),
      ),
    );

    // Picker aperto automaticamente: confermalo esplicitamente con "Fatto".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fatto'), findsOneWidget);
    await tester.tap(find.text('Fatto'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Salva'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(repo.notifier.state, hasLength(1));

    await tester.runAsync(() => repo.db.close());
  });

  testWidgets(
      'periodo già riconosciuto: nessuna apertura automatica del picker, '
      '"Salva" abilitato dal primo frame', (tester) async {
    final repo = await makeRepo(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busteRepositoryProvider.overrideWith((ref) => repo.notifier),
        ],
        child: const CupertinoApp(
          home: BustaPagaFormScreen.daImport(
            fileOrigine: '/tmp/finto.pdf',
            estratti: _estrattiConPeriodo,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Il picker non si apre da solo: nessun bottone "Fatto" in giro.
    expect(find.text('Fatto'), findsNothing);
    expect(
      find.textContaining('Periodo non riconosciuto automaticamente'),
      findsNothing,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Salva'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(repo.notifier.state, hasLength(1));

    await tester.runAsync(() => repo.db.close());
  });
}
