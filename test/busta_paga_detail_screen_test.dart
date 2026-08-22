// Test di regressione per `buildBustaPagaEditDiff` (funzione pura,
// `@visibleForTesting`, in `lib/screens/buste_paga/busta_paga_detail_screen.dart`)
// — costruisce l'elenco leggibile mostrato nel popup "Hai modificato i
// seguenti dati, confermi?" prima di salvare una modifica inline.
//
// Copre il bug del doppio segno ("€ -0,14") su una trattenuta negativa
// rimossa o modificata: prima del fix il loop trattenute concatenava "€ "
// a mano davanti a `formatEuro`, che antepone già un "-" al numero.
import 'package:buts/models/busta_paga.dart';
import 'package:buts/screens/buste_paga/busta_paga_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BustaPaga _busta({
  Map<String, double> trattenute = const {},
  List<VoceCompetenza> competenze = const [],
}) {
  return BustaPaga(
    id: 'test',
    periodo: DateTime(2025, 8),
    lordo: 1000,
    netto: 900,
    trattenute: trattenute,
    straordinari: 0,
    ferieMaturate: 0,
    ferieGodute: 0,
    ferieResidue: 0,
    rolMaturati: 0,
    rolGoduti: 0,
    rolResidui: 0,
    permessiGoduti: 0,
    oreLavorate: 160,
    competenze: competenze,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  group('buildBustaPagaEditDiff - trattenuta negativa (arrotondamento)', () {
    const chiave = 'Differenza di arrotondamento (mese precedente/attuale)';

    test('trattenuta negativa RIMOSSA: nessun doppio segno "€ -"', () {
      final vecchia = _busta(trattenute: {chiave: -0.14});
      final nuova = _busta(trattenute: const {});

      final diff = buildBustaPagaEditDiff(vecchia, nuova);

      expect(diff, contains('Trattenuta $chiave: rimossa (era + € 0,14)'));
      expect(diff.any((r) => r.contains('€ -')), isFalse,
          reason: 'doppio segno "€ -" nel diff: $diff');
    });

    test('trattenuta negativa MODIFICATA: nessun doppio segno "€ -"', () {
      final vecchia = _busta(trattenute: {chiave: -0.14});
      final nuova = _busta(trattenute: {chiave: -0.28});

      final diff = buildBustaPagaEditDiff(vecchia, nuova);

      expect(
        diff,
        contains('Trattenuta $chiave: + € 0,14 → + € 0,28'),
      );
      expect(diff.any((r) => r.contains('€ -')), isFalse,
          reason: 'doppio segno "€ -" nel diff: $diff');
    });

    test('trattenuta negativa AGGIUNTA: nessun doppio segno "€ -"', () {
      final vecchia = _busta(trattenute: const {});
      final nuova = _busta(trattenute: {chiave: -0.14});

      final diff = buildBustaPagaEditDiff(vecchia, nuova);

      expect(diff, contains('Trattenuta $chiave: aggiunta (+ € 0,14)'));
      expect(diff.any((r) => r.contains('€ -')), isFalse,
          reason: 'doppio segno "€ -" nel diff: $diff');
    });

    test('trattenuta positiva invariata: nessuna riga nel diff', () {
      final vecchia = _busta(trattenute: const {'INPS': 88.18});
      final nuova = _busta(trattenute: const {'INPS': 88.18});

      expect(buildBustaPagaEditDiff(vecchia, nuova), isEmpty);
    });
  });

  group('buildBustaPagaEditDiff - competenza a importo negativo (storno)', () {
    test('competenza con importo negativo RIMOSSA: nessun doppio segno', () {
      const voce = VoceCompetenza(
        descrizione: 'Storno a debito',
        quantita: null,
        importo: -50.0,
      );
      final vecchia = _busta(competenze: [voce]);
      final nuova = _busta(competenze: const []);

      final diff = buildBustaPagaEditDiff(vecchia, nuova);

      expect(diff,
          contains('Competenza Storno a debito: rimossa (era —, − € 50,00)'));
      expect(diff.any((r) => r.contains('€ -')), isFalse,
          reason: 'doppio segno "€ -" nel diff: $diff');
    });
  });

  group('buildBustaPagaEditDiff - Netto/Lordo eccezionalmente negativi', () {
    test('Netto negativo: nessun doppio segno "€ -"', () {
      final vecchia = _busta(trattenute: const {}).copyWith(netto: 50);
      final nuova = vecchia.copyWith(netto: -20);

      final diff = buildBustaPagaEditDiff(vecchia, nuova);

      expect(diff, contains('Netto: € 50,00 → − € 20,00'));
      expect(diff.any((r) => r.contains('€ -')), isFalse,
          reason: 'doppio segno "€ -" nel diff: $diff');
    });
  });

  group('valoriDerivatiEditing - fallback competenze vuote', () {
    const voce = VoceCompetenza(
      descrizione: 'Straordinario diurno (30%)',
      quantita: 10,
      importo: 150.0,
    );

    test(
        'partenza vuota, resta vuota: fallback al vecchio lordo/straordinari/netto',
        () {
      final corrente = _busta().copyWith(lordo: 0, straordinari: 0, netto: 0);

      final valori = valoriDerivatiEditing(
        corrente: corrente,
        competenze: const [],
        trattenute: const {},
        competenzeVuoteInPartenza: true,
      );

      expect(valori.lordo, 0);
      expect(valori.straordinari, 0);
      expect(valori.netto, 0);
    });

    test('partenza non vuota, svuotata dall\'utente: deriva da competenze []',
        () {
      final corrente = _busta(competenze: const [voce])
          .copyWith(lordo: 150, straordinari: 10, netto: 150);

      final valori = valoriDerivatiEditing(
        corrente: corrente,
        competenze: const [],
        trattenute: const {},
        competenzeVuoteInPartenza: false,
      );

      expect(valori.lordo, 0);
      expect(valori.straordinari, 0);
      expect(valori.netto, 0);
    });

    test(
        'partenza non vuota, modificata non svuotata: deriva da competenze correnti',
        () {
      const voceModificata = VoceCompetenza(
        descrizione: 'Straordinario diurno (30%)',
        quantita: 5,
        importo: 75.0,
      );
      final corrente = _busta(competenze: const [voce])
          .copyWith(lordo: 150, straordinari: 10, netto: 150);

      final valori = valoriDerivatiEditing(
        corrente: corrente,
        competenze: const [voceModificata],
        trattenute: const {},
        competenzeVuoteInPartenza: false,
      );

      expect(valori.lordo, 75.0);
      expect(valori.straordinari, 5.0);
      expect(valori.netto, 75.0);
    });

    test(
        'partenza vuota, righe aggiunte: deriva da competenze correnti (bug corretto)',
        () {
      final corrente = _busta().copyWith(lordo: 0, straordinari: 0, netto: 0);

      final valori = valoriDerivatiEditing(
        corrente: corrente,
        competenze: const [voce],
        trattenute: const {},
        competenzeVuoteInPartenza: true,
      );

      expect(valori.lordo, 150.0);
      expect(valori.straordinari, 10.0);
      expect(valori.netto, 150.0);
    });
  });
}
