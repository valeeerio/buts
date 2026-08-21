import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:buts/providers/buste_paga_provider.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copre due bug corretti in `BustePagaNotifier`
/// (`lib/providers/buste_paga_provider.dart`):
/// 1. `add()` non deduplicava lo stato in memoria come `update()` quando
///    invocato due volte con lo stesso id;
/// 2. `_initialize()` non era resiliente a righe con JSON malformato in
///    `trattenute`/`competenze`, e faceva sparire l'intero archivio.
void main() {
  BustaPaga bustaPaga({
    required String id,
    DateTime? periodo,
    double netto = 1500,
  }) {
    return BustaPaga(
      id: id,
      periodo: periodo ?? DateTime(2026, 1),
      lordo: 2000,
      netto: netto,
      trattenute: const {},
      straordinari: 0,
      ferieMaturate: 0,
      ferieGodute: 0,
      ferieResidue: 0,
      rolMaturati: 0,
      rolGoduti: 0,
      rolResidui: 0,
      permessiGoduti: 0,
      oreLavorate: 168,
    );
  }

  group('BustePagaNotifier.add — dedup dello stato in memoria', () {
    test('add() con id già presente in state sostituisce, non appende',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final notifier = BustePagaNotifier(db, const PdfImportService());

      // Attende l'inizializzazione (archivio vuoto) prima di procedere.
      await Future<void>.delayed(Duration.zero);

      await notifier.add(bustaPaga(id: 'bp-1', netto: 1000));
      await notifier.add(bustaPaga(id: 'bp-1', netto: 2000));

      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.netto, 2000);

      await db.close();
    });
  });

  group('BustePagaNotifier._initialize — resilienza a righe corrotte', () {
    test(
        'una riga con JSON malformato in trattenute non fa sparire le altre '
        'righe valide dall\'archivio', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Riga valida, scritta tramite il normale companion/converter.
      await db
          .into(db.bustePagaTable)
          .insertOnConflictUpdate(bustaPaga(id: 'bp-valida').toCompanion());

      // Riga corrotta: scritta con SQL diretto per bypassare il converter e
      // simulare un JSON malformato già presente sul disco dell'utente.
      await db.customStatement(
        '''
        INSERT INTO ${db.bustePagaTable.actualTableName}
          (id, periodo, lordo, netto, trattenute, straordinari,
           ferie_maturate, ferie_godute, ferie_residue, rol_maturati,
           rol_goduti, rol_residui, permessi_goduti, ore_lavorate)
        VALUES
          ('bp-corrotta', 1700000000000, 2000, 1500, '{questo non è json',
           0, 0, 0, 0, 0, 0, 0, 0, 168)
        ''',
      );

      final notifier = BustePagaNotifier(db, const PdfImportService());

      // Attende che l'inizializzazione asincrona sia completata.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.map((b) => b.id), contains('bp-valida'));
      expect(notifier.state.map((b) => b.id), isNot(contains('bp-corrotta')));

      await db.close();
    });
  });
}
