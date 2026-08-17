import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:buts/widgets/trattenuta_edit_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressione per il bug "doppio segno in editing" (`+ € -0,14` invece di
/// `+ € 0,14` per una "Differenza di arrotondamento" negativa, vedi
/// `TrattenutaEditRow.negativo`): `TrattenutaEditRow` precompilava il
/// controller `importo` col valore CON segno (es. "-0,14") e il widget
/// `trattenutaEditRow` anteponeva comunque un prefisso "+"/"−" calcolato
/// dallo stesso segno, producendo un doppio segno che la vista di sola
/// lettura (`formatTrattenuta`) non mostra mai.
///
/// Copre la classe pura (`negativo`/`valoreConSegno`), senza montare il
/// widget `trattenutaEditRow`: la stessa logica di segno è condivisa fra la
/// stringa mostrata in editing (`trattenutaPrefix(row.valoreConSegno)` +
/// testo digitato, sempre il valore ASSOLUTO) e il round trip di salvataggio
/// (`row.valoreConSegno`, letto da `_trattenuteCorrenti` in
/// `busta_paga_detail_screen.dart`/`busta_paga_form_screen.dart`).
void main() {
  group('TrattenutaEditRow — segno separato dal testo digitato', () {
    test(
        'valore negativo (es. Differenza di arrotondamento -0.14): il '
        "controller mostra SOLO il valore assoluto, mai il segno '-'", () {
      final row = TrattenutaEditRow(
        chiave: 'Differenza di arrotondamento (mese precedente/attuale)',
        importo: -0.14,
      );
      addTearDown(row.dispose);

      expect(row.importo.text, '0,14');
      expect(row.importo.text.contains('-'), isFalse);
      expect(row.negativo, isTrue);
    });

    test(
        'la stringa visualizzata in editing (prefisso + testo digitato) è '
        'IDENTICA a quella di sola lettura (formatTrattenuta) — niente più '
        'doppio segno', () {
      const valoreOriginale = -0.14;
      final row = TrattenutaEditRow(importo: valoreOriginale);
      addTearDown(row.dispose);

      final prefissoEditing = trattenutaPrefix(row.valoreConSegno);
      final stringaEditing = '$prefissoEditing${row.importo.text}';
      final stringaLettura = formatTrattenuta(valoreOriginale);

      expect(stringaEditing, '+ € 0,14');
      expect(stringaEditing.contains('-'), isFalse);
      expect(stringaEditing, stringaLettura);
    });

    test(
        'round trip: aprire la riga e "salvare" SENZA modificare il testo '
        'preserva esattamente il valore originale, segno incluso', () {
      const valoreOriginale = -0.14;
      final row = TrattenutaEditRow(importo: valoreOriginale);
      addTearDown(row.dispose);

      // Nessuna modifica al testo digitato: simula "Modifica" seguito subito
      // da "Salva" — vedi `_trattenuteCorrenti`, che legge
      // `row.valoreConSegno` (mai `parseItalianNumber(row.importo.text)` da
      // solo, che perderebbe il segno perché il testo è ormai sempre
      // assoluto).
      expect(row.valoreConSegno, closeTo(valoreOriginale, 0.001));
    });

    test(
        'modificare le sole cifre digitate preserva il segno negativo '
        'originale sul nuovo valore assoluto', () {
      final row = TrattenutaEditRow(importo: -0.14);
      addTearDown(row.dispose);

      row.importo.text = '0,20';

      expect(row.valoreConSegno, closeTo(-0.20, 0.001));
    });

    test(
        'valore positivo (caso comune, es. INPS): nessun cambiamento di '
        'comportamento, stessa stringa "− €" della sola lettura', () {
      const valoreOriginale = 90.11;
      final row = TrattenutaEditRow(importo: valoreOriginale);
      addTearDown(row.dispose);

      expect(row.negativo, isFalse);
      expect(row.importo.text, '90,11');
      final stringaEditing =
          '${trattenutaPrefix(row.valoreConSegno)}${row.importo.text}';
      expect(stringaEditing, formatTrattenuta(valoreOriginale));
      expect(row.valoreConSegno, closeTo(valoreOriginale, 0.001));
    });

    test(
        'riga nuova/vuota (bottone "+ Aggiungi voce"): nessun valore '
        'iniziale, prefisso positivo di default, valore 0', () {
      final row = TrattenutaEditRow();
      addTearDown(row.dispose);

      expect(row.negativo, isFalse);
      expect(row.importo.text, isEmpty);
      expect(row.valoreConSegno, 0.0);
    });

    test(
        'un segno "-" ritrovato nel testo digitato (mai prodotto dalla UI, '
        'ma non impedito a livello di input) viene neutralizzato da .abs(): '
        'non inverte due volte il segno finale', () {
      final row = TrattenutaEditRow(importo: -0.14);
      addTearDown(row.dispose);

      row.importo.text = '-0,20';

      expect(row.valoreConSegno, closeTo(-0.20, 0.001));
    });
  });

  group('trattenutaEditRow — campo chiave va a capo come la sola lettura', () {
    // Regressione: il campo chiave usava il `maxLines` di default di
    // `CupertinoTextField` (1, che TRONCA orizzontalmente il testo che
    // eccede la larghezza) mentre la vista di sola lettura
    // (`_trattenutaRow` in `busta_paga_detail_screen.dart`, un `Text` senza
    // `maxLines`) va a capo su più righe per le chiavi lunghe — violava il
    // requisito "modifica inline" non negoziabile (vedi CLAUDE.md: entrare
    // in modifica non deve cambiare NULLA visivamente).
    testWidgets(
        'CupertinoTextField della chiave ha maxLines null (nessun limite, '
        'come un Text di sola lettura), non 1', (tester) async {
      final row = TrattenutaEditRow(
        chiave: 'Differenza di arrotondamento (mese precedente/attuale)',
        importo: 0.28,
      );
      addTearDown(row.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 340,
                child: trattenutaEditRow(row, onDismissed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final campoChiave = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .firstWhere((w) => w.controller == row.chiave);

      expect(campoChiave.maxLines, isNull);
    });
  });
}
