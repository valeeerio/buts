import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressione per il bug critico riscontrato dall'utente dopo un re-import
/// del PDF di Luglio 2026: diversi valori (Ferie/Permessi/Ex festività
/// Maturato, Ore lavorate, Straordinari, trattenute INPS/EBILOG) venivano
/// salvati moltiplicati per ~100 (es. 12,83 → 1283).
///
/// Causa radice: `formatNumber` (usata per precompilare i
/// `TextEditingController` di Ferie/ROL/Ex festività/Ore lavorate/quantità
/// competenze in `busta_paga_form_screen.dart` e `busta_paga_detail_screen
/// .dart`, sia in editing sia — indirettamente, tramite `straordinari`
/// derivato da `computeStraordinari` sulle competenze — nei valori derivati)
/// usava `toStringAsFixed`, locale-INDIPENDENTE e quindi sempre con il PUNTO
/// come separatore decimale (es. "12.83"). Al salvataggio quel testo veniva
/// riletto con `parseItalianNumber`, che tratta il punto come separatore
/// delle MIGLIAIA (convenzione italiana) e lo rimuove: "12.83" → "1283" →
/// 1283.0. Solo i valori che capitano ad essere esattamente interi (es.
/// 4,00 o 16,00) sfuggivano al bug, perché `formatNumber` per un intero non
/// stampa alcun punto decimale — coerente con l'osservazione originale
/// (Ferie Goduto/Residuo corretti, Maturato corrotto; Permessi con tutti e 3
/// i valori non interi, tutti corrotti; Ex festività Goduto/Residuo interi e
/// corretti, Maturato non intero e corrotto).
void main() {
  group('formatNumber / parseItalianNumber round trip', () {
    test(
      'un valore precompilato con formatNumber si rilegge identico con parseItalianNumber',
      () {
        // Valori reali (Luglio 2026) coinvolti nel bug originale.
        const valori = [
          12.83, // Ferie maturate
          4.0, // Ferie godute (intero, "sfuggiva" già prima del fix)
          16.0, // Ferie residue (intero)
          23.33, // Permessi (ROL) maturati
          11.5, // Permessi (ROL) goduti
          26.7, // Permessi (ROL) residui
          18.67, // Ex festività maturate
          0.0, // Ex festività godute (intero)
          32.0, // Ex festività residue (intero)
          175.62, // Ore lavorate
          0.25, // Straordinari (quantità voce di competenza)
          90.11, // Trattenuta INPS
          3.5, // Trattenuta CONTRIBUTO EBILOG
        ];

        for (final valore in valori) {
          final formattato = formatNumber(valore);
          final riletto = parseItalianNumber(formattato);
          expect(
            riletto,
            closeTo(valore, 0.001),
            reason:
                '$valore formattato come "$formattato" doveva rileggersi '
                'identico, non $riletto',
          );
        }
      },
    );

    test('formatNumber usa sempre la virgola come separatore decimale', () {
      expect(formatNumber(12.83), '12,83');
      expect(formatNumber(4.0), '4');
      expect(formatNumber(175.62), '175,62');
      expect(formatNumber(0.25), '0,25');
    });
  });

  group('formatEuro / parseItalianNumber round trip (trattenute)', () {
    // Regressione per il bug critico riscontrato dall'utente dopo l'import
    // del PDF di Giugno 2026: il Netto salvato risultava -€15.754,84 invece
    // di ~€1.487,00 (lordo €1.661,16).
    //
    // Causa radice, distinta dal bug di `formatNumber` sopra: in
    // `BustaPagaFormScreen.daImport` (`_BustaPagaFormScreenState.initState`),
    // le righe `TrattenutaEditRow` iniziali venivano precompilate con
    // `e.value.toStringAsFixed(2)` — locale-INDIPENDENTE, quindi sempre col
    // PUNTO come separatore decimale (es. "97.00") — invece che con
    // `formatEuro` (virgola decimale, "97,00"). Al salvataggio quel testo
    // veniva riletto con `parseItalianNumber`, che tratta il punto come
    // separatore delle MIGLIAIA: "97.00" → "9700" → 9700.0, cento volte il
    // valore reale. Con le tre trattenute reali di Giugno (INPS 97,00 +
    // CONTRIBUTO EBILOG 3,50 + "Altre trattenute" 73,66 = 174,16) la somma
    // gonfiata era 9700 + 350 + 7366 = 17416, e il Netto derivato
    // (lordo - somma trattenute) risultava 1.661,16 - 17.416 = -15.754,84 —
    // esattamente il valore assurdo osservato. Fix: precompilare sempre con
    // `formatEuro` (già il pattern corretto usato per le stesse righe in
    // `busta_paga_detail_screen.dart`), coerente col resto del round trip.
    test(
      'un importo di trattenuta precompilato con formatEuro si rilegge '
      'identico con parseItalianNumber (non gonfiato x100)',
      () {
        const trattenuteReali = {
          'INPS': 97.00,
          'CONTRIBUTO EBILOG': 3.50,
          'Altre trattenute (IRPEF + varie)': 73.66,
        };

        double sommaRiletta = 0;
        for (final valore in trattenuteReali.values) {
          final formattato = formatEuro(valore);
          final riletto = parseItalianNumber(formattato);
          expect(
            riletto,
            closeTo(valore, 0.001),
            reason:
                '$valore formattato come "$formattato" doveva rileggersi '
                'identico, non $riletto',
          );
          sommaRiletta += riletto;
        }

        const lordo = 1661.16;
        final netto = lordo - sommaRiletta;
        expect(netto, closeTo(1487.00, 0.01));

        // Riproduzione esplicita del sintomo col vecchio bug (toStringAsFixed
        // invece di formatEuro), per documentare il valore assurdo osservato.
        double sommaConVecchioBug = 0;
        for (final valore in trattenuteReali.values) {
          final formattatoConBug = valore.toStringAsFixed(2);
          sommaConVecchioBug += parseItalianNumber(formattatoConBug);
        }
        final nettoConVecchioBug = lordo - sommaConVecchioBug;
        expect(nettoConVecchioBug, closeTo(-15754.84, 0.01));
      },
    );
  });

  group('formatTrattenuta', () {
    // Regressione: il parser regex accetta un segno "-" opzionale davanti
    // all'importo di una trattenuta (vedi `_rigaTrattenutaVerificata` in
    // `busta_paga_regex_parser.dart`, un conguaglio/storno a CREDITO del
    // dipendente). `formatEuro` di per sé aggiunge già un "-" per i valori
    // negativi: un prefisso "− €" fisso davanti a quel segno produceva un
    // doppio segno fuorviante ("− € -3,50").
    test('importo positivo (caso comune): prefisso "− €", nessun segno extra',
        () {
      expect(formatTrattenuta(90.11), '− € 90,11');
    });

    test('importo negativo (accredito/conguaglio): prefisso "+ €", valore '
        'assoluto, mai un doppio segno', () {
      expect(formatTrattenuta(-3.50), '+ € 3,50');
      expect(formatTrattenuta(-3.50).contains('-'), isFalse);
      expect(formatTrattenuta(-3.50).contains('+'), isTrue);
    });

    test('importo zero: prefisso "− €" (ramo del caso comune)', () {
      expect(formatTrattenuta(0), '− € 0,00');
    });
  });

  group('trattenutaPrefix (parità lettura/modifica)', () {
    // Regressione: `TrattenutaEditRow` in editing usava un prefisso "€ "
    // fisso invece di quello dinamico "− €"/"+ €" mostrato in sola lettura
    // da `formatTrattenuta` — violava il requisito "modifica inline" di
    // CLAUDE.md ("entrare in modifica non deve cambiare NULLA visivamente").
    // Il fix riusa [trattenutaPrefix] sia da `formatTrattenuta` sia dal
    // widget di editing (calcolato in tempo reale sul testo del
    // controller via `parseItalianNumber`): questi test verificano che il
    // prefisso calcolato durante la digitazione sia sempre identico a
    // quello mostrato in sola lettura per lo stesso valore.
    test('digitando un valore positivo il prefisso è "− €", come in lettura',
        () {
      const testoDigitato = '90,11';
      final valore = parseItalianNumber(testoDigitato);
      final prefissoInEditing = trattenutaPrefix(valore);
      final prefissoInLettura =
          formatTrattenuta(valore).substring(0, prefissoInEditing.length);
      expect(prefissoInEditing, '− € ');
      expect(prefissoInEditing, prefissoInLettura);
    });

    test(
        'digitando un valore che inizia con "-" il prefisso diventa "+ €", '
        'come in lettura', () {
      const testoDigitato = '-3,50';
      final valore = parseItalianNumber(testoDigitato);
      final prefissoInEditing = trattenutaPrefix(valore);
      final prefissoInLettura =
          formatTrattenuta(valore).substring(0, prefissoInEditing.length);
      expect(prefissoInEditing, '+ € ');
      expect(prefissoInEditing, prefissoInLettura);
    });

    test(
        'testo vuoto/parziale (es. solo "-" appena digitato) non fa '
        'sfarfallare il prefisso: resta "− €" finché non è un numero '
        'negativo valido', () {
      expect(trattenutaPrefix(parseItalianNumber('')), '− € ');
      expect(trattenutaPrefix(parseItalianNumber('-')), '− € ');
      expect(trattenutaPrefix(parseItalianNumber('-3')), '+ € ');
    });
  });
}
