// Smoke test di stabilità (NON golden/pixel): dopo la rimozione del forcing
// della dark mode (`lib/main.dart`, `ios/Runner/Info.plist`), l'app segue il
// `platformBrightness` reale del sistema — queste schermate vanno quindi
// esercitate esplicitamente sia in `Brightness.light` sia in
// `Brightness.dark` per verificare che nessuna delle due producano
// un'eccezione/overflow. Nessuna asserzione sull'aspetto visivo: solo
// `tester.takeException()` nullo.
import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/screens/buste_paga/busta_paga_detail_screen.dart';
import 'package:buts/screens/buste_paga/busta_paga_form_screen.dart';
import 'package:buts/screens/buste_paga/buste_paga_section_screen.dart';
import 'package:buts/screens/buste_paga/buste_paga_statistiche_screen.dart';
import 'package:buts/services/busta_paga_regex_parser.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({
  required String id,
  required DateTime periodo,
}) {
  return BustaPaga(
    id: id,
    periodo: periodo,
    lordo: 2000,
    netto: 1500,
    trattenute: const {'INPS': 88.18},
    straordinari: 5,
    ferieMaturate: 10,
    ferieGodute: 2,
    ferieResidue: 8,
    rolMaturati: 6,
    rolGoduti: 1,
    rolResidui: 5,
    permessiGoduti: 0,
    oreLavorate: 168,
    statoVerifica: StatoVerificaBustaPaga.confermato,
  );
}

const _estrattiImport = BustaPagaEstratti(
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

/// Stesso pattern degli altri widget test che toccano il repository reale
/// (`NativeDatabase.memory()` gira su un isolate/thread in background, serve
/// `tester.runAsync`).
Future<
    ({
      AppDatabase db,
      BustePagaNotifier notifier,
    })> _makeRepo(WidgetTester tester) async {
  late final AppDatabase db;
  late final BustePagaNotifier notifier;
  await tester.runAsync(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifier = BustePagaNotifier(db, const PdfImportService());
    await Future<void>.delayed(Duration.zero);
    await notifier.add(_busta(id: 'bp-gen', periodo: DateTime(2026, 1)));
  });
  return (db: db, notifier: notifier);
}

Widget _wrapWithBrightness({
  required Brightness brightness,
  required BustePagaNotifier notifier,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      busteRepositoryProvider.overrideWith((ref) => notifier),
    ],
    child: MediaQuery(
      data: MediaQueryData(platformBrightness: brightness),
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final label = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('Archivio (BustePagaSectionScreen) - nessuna eccezione in $label',
        (tester) async {
      final repo = await _makeRepo(tester);

      await tester.pumpWidget(_wrapWithBrightness(
        brightness: brightness,
        notifier: repo.notifier,
        child: const BustePagaSectionScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets('Dettaglio busta paga - nessuna eccezione in $label',
        (tester) async {
      final repo = await _makeRepo(tester);
      final busta = _busta(id: 'bp-gen', periodo: DateTime(2026, 1));

      await tester.pumpWidget(_wrapWithBrightness(
        brightness: brightness,
        notifier: repo.notifier,
        child: BustaPagaDetailScreen(bustaPaga: busta),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets('Form di import - nessuna eccezione in $label', (tester) async {
      final repo = await _makeRepo(tester);

      await tester.pumpWidget(_wrapWithBrightness(
        brightness: brightness,
        notifier: repo.notifier,
        child: const BustaPagaFormScreen.daImport(
          fileOrigine: '/tmp/finto.pdf',
          estratti: _estrattiImport,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      await tester.runAsync(() => repo.db.close());
    });

    testWidgets('Statistiche - nessuna eccezione in $label', (tester) async {
      final repo = await _makeRepo(tester);

      await tester.pumpWidget(_wrapWithBrightness(
        brightness: brightness,
        notifier: repo.notifier,
        child: BustePagaStatisticheScreen(
          periodoFiltro: (start: DateTime(2026, 1), end: DateTime(2026, 1)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      await tester.runAsync(() => repo.db.close());
    });
  }
}
