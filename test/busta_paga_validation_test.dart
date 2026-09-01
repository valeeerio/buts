// Test di regressione per `firstInvalidNumericFieldLabel`/
// `firstDuplicateTrattenutaKey` (`lib/utils/busta_paga_validation.dart`),
// condivise dal salvataggio del Dettaglio busta paga
// (`busta_paga_detail_screen.dart._save`) e del Form di import
// (`busta_paga_form_screen.dart._save`).
//
// Copre i 3 bug reali dell'audit funzionale pre-rilascio: un testo non
// numerico in un campo (bug 1), il formato USA col punto interpretato come
// separatore delle migliaia (bug 2), due trattenute con lo stesso nome che
// collassano silenziosamente su una sola voce (bug 3).
import 'package:buts/utils/busta_paga_validation.dart';
import 'package:buts/widgets/trattenuta_edit_row.dart';
import 'package:buts/widgets/voce_competenza_edit_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firstInvalidNumericFieldLabel — campi semplici', () {
    test('tutti i campi validi: nessun errore', () {
      final risultato = firstInvalidNumericFieldLabel(
        campi: const [
          ('Ore lavorate', '160'),
          ('Ferie (Maturato)', '12,83'),
          ('Ferie (Goduto)', ''),
        ],
      );
      expect(risultato, isNull);
    });

    test('un campo con lettere: ritorna la sua etichetta', () {
      final risultato = firstInvalidNumericFieldLabel(
        campi: const [
          ('Ore lavorate', '160'),
          ('Ferie (Maturato)', 'dodici'),
        ],
      );
      expect(risultato, 'Ferie (Maturato)');
    });

    test(
        'un campo in formato USA (punto): ritorna la sua etichetta, non '
        'lascia passare il valore gonfiato x10', () {
      final risultato = firstInvalidNumericFieldLabel(
        campi: const [
          ('Ore lavorate', '12.5'),
        ],
      );
      expect(risultato, 'Ore lavorate');
    });

    test('ritorna il PRIMO campo non valido, nell\'ordine dato', () {
      final risultato = firstInvalidNumericFieldLabel(
        campi: const [
          ('Ore lavorate', '160'),
          ('Ferie (Maturato)', 'x'),
          ('Ferie (Goduto)', 'y'),
        ],
      );
      expect(risultato, 'Ferie (Maturato)');
    });
  });

  group('firstInvalidNumericFieldLabel — righe di competenze', () {
    test('quantità non valida di una voce con descrizione: segnalata', () {
      final riga = VoceCompetenzaEditRow(
        descrizione: 'Retribuzione ordinaria',
        quantita: 'abc',
        importo: '1500,00',
      );
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        competenze: [riga],
      );
      expect(risultato, 'Quantità di "Retribuzione ordinaria"');
    });

    test('importo in formato USA di una voce con descrizione: segnalato', () {
      final riga = VoceCompetenzaEditRow(
        descrizione: 'Edr contrattuale',
        quantita: '',
        importo: '15.00',
      );
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        competenze: [riga],
      );
      expect(risultato, 'Importo di "Edr contrattuale"');
    });

    test(
        'riga con descrizione vuota (scartata comunque al salvataggio): '
        'non blocca, anche con un valore illeggibile residuo', () {
      final riga = VoceCompetenzaEditRow(
        descrizione: '',
        quantita: 'abc',
        importo: 'xyz',
      );
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        competenze: [riga],
      );
      expect(risultato, isNull);
    });

    test('quantità vuota (assente nel PDF): valida, non un errore', () {
      final riga = VoceCompetenzaEditRow(
        descrizione: 'Trattamento integrativo',
        quantita: '',
        importo: '100,00',
      );
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        competenze: [riga],
      );
      expect(risultato, isNull);
    });
  });

  group('firstInvalidNumericFieldLabel — righe di trattenute', () {
    test('importo non numerico di una trattenuta con chiave: segnalato', () {
      final riga = TrattenutaEditRow(chiave: 'INPS');
      riga.importo.text = 'novanta';
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        trattenute: [riga],
      );
      expect(risultato, 'Importo di "INPS"');
    });

    test('riga con chiave vuota: non blocca', () {
      final riga = TrattenutaEditRow();
      riga.importo.text = 'abc';
      addTearDown(riga.dispose);

      final risultato = firstInvalidNumericFieldLabel(
        campi: const [],
        trattenute: [riga],
      );
      expect(risultato, isNull);
    });
  });

  group('firstDuplicateTrattenutaKey', () {
    test('nessun duplicato: null', () {
      final righe = [
        TrattenutaEditRow(chiave: 'INPS', importo: 90.11),
        TrattenutaEditRow(chiave: 'IRPEF', importo: 120.0),
      ];
      addTearDown(() {
        for (final r in righe) {
          r.dispose();
        }
      });

      expect(firstDuplicateTrattenutaKey(righe), isNull);
    });

    // Bug reale: due righe con lo stesso nome (es. l'utente ridigita per
    // errore un nome già esistente in una nuova voce) collassavano
    // silenziosamente sull'ultima in `_trattenuteCorrenti` (una `Map` chiave
    // sul testo digitato) — la prima spariva dai dati salvati senza avviso.
    test('due righe con lo stesso nome: ritorna la chiave duplicata', () {
      final righe = [
        TrattenutaEditRow(chiave: 'INPS', importo: 90.11),
        TrattenutaEditRow(chiave: 'INPS', importo: 12.0),
      ];
      addTearDown(() {
        for (final r in righe) {
          r.dispose();
        }
      });

      expect(firstDuplicateTrattenutaKey(righe), 'INPS');
    });

    // Bug reale corretto: la normalizzazione qui deve essere IDENTICA a
    // quella usata dalla collisione vera in `_trattenuteCorrenti` (solo
    // `trim()`, MAI `toLowerCase()`) — un confronto case-insensitive
    // segnalerebbe "Inps"/"INPS" come duplicati anche se non collidono
    // affatto nella Map reale, bloccando il salvataggio senza motivo.
    test('duplicato rilevato solo su trim, NON case-insensitive', () {
      final righe = [
        TrattenutaEditRow(chiave: 'Inps', importo: 90.11),
        TrattenutaEditRow(chiave: '  INPS  ', importo: 12.0),
      ];
      addTearDown(() {
        for (final r in righe) {
          r.dispose();
        }
      });

      // "Inps" e "INPS" (dopo trim) restano due chiavi distinte: nessun
      // duplicato rilevato, coerente con `_trattenuteCorrenti`.
      expect(firstDuplicateTrattenutaKey(righe), isNull);
    });

    test('duplicato rilevato dopo trim degli spazi (stessa capitalizzazione)',
        () {
      final righe = [
        TrattenutaEditRow(chiave: 'INPS', importo: 90.11),
        TrattenutaEditRow(chiave: '  INPS  ', importo: 12.0),
      ];
      addTearDown(() {
        for (final r in righe) {
          r.dispose();
        }
      });

      expect(firstDuplicateTrattenutaKey(righe), 'INPS');
    });

    test('righe con chiave vuota (bottone "+ Aggiungi voce"): ignorate', () {
      final righe = [
        TrattenutaEditRow(),
        TrattenutaEditRow(),
      ];
      addTearDown(() {
        for (final r in righe) {
          r.dispose();
        }
      });

      expect(firstDuplicateTrattenutaKey(righe), isNull);
    });
  });
}
