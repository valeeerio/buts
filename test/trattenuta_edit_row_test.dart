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

  group('inlineNumberField — filtro in scrittura (bug 1+2, livello 1)', () {
    // Regressione: senza `inputFormatters`, l'utente poteva digitare
    // lettere (bug 1, azzerate silenziosamente al salvataggio da
    // `parseItalianNumber`) o il punto in formato USA (bug 2, interpretato
    // come separatore delle migliaia e gonfiava il valore x10) in qualunque
    // campo numerico — vedi CLAUDE.md/istruzioni task. Il campo blocca ora a
    // monte entrambi i caratteri, digitando solo cifre e virgola.
    testWidgets(
        'un tap seguito da testo con lettere/punto: solo cifre e '
        'virgola restano nel controller', (tester) async {
      final row = TrattenutaEditRow(chiave: 'INPS');
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

      final campoImporto = find.byWidgetPredicate(
        (w) => w is CupertinoTextField && w.controller == row.importo,
      );
      await tester.enterText(campoImporto, '12.a5,3');
      await tester.pumpAndSettle();

      expect(row.importo.text, '125,3');
    });
  });

  group(
      'trattenutaEditRow — nessun overflow su larghezze strette con importi '
      'a 4 cifre (regressione FittedBox)', () {
    // Regressione: l'aumento di `pulseDisplaySmall` da 15 a 16px (vedi
    // CLAUDE.md/app_text_styles.dart) faceva andare in overflow la colonna
    // importo (prefisso "− €"/"+ €" dentro `IntrinsicWidth`, vedi
    // `inlineNumberField`) su larghezze di contenuto realistiche di un
    // iPhone SE-class (~307px: 375pt schermo - 20-20 margine sezione -
    // 14-14 padding `PulseSectionCard`) — non solo con importi limite, ma
    // già con un valore a 4 cifre comune (es. un conguaglio/storno da
    // mille euro). Fix: `inlineNumberField` avvolge il ramo
    // prefisso/suffisso in un `FittedBox(fit: BoxFit.scaleDown)`, che
    // riduce il font SOLO quando il contenuto eccede lo spazio disponibile.
    for (final width in [307.0, 340.0]) {
      for (final importo in [1500.0, -1500.0]) {
        testWidgets(
            'importo ${importo.abs()} (${importo < 0 ? "negativo" : "positivo"}) '
            'a ${width.toInt()}px: nessun RenderFlex overflow', (tester) async {
          final row = TrattenutaEditRow(chiave: 'INPS', importo: importo);
          addTearDown(row.dispose);

          await tester.pumpWidget(
            CupertinoApp(
              home: CupertinoPageScaffold(
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: trattenutaEditRow(row, onDismissed: () {}),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
        'il campo importo resta interattivo dentro il FittedBox: tap + '
        'digitazione aggiornano il controller', (tester) async {
      final row = TrattenutaEditRow(chiave: 'INPS', importo: 1500.0);
      addTearDown(row.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 307,
                child: trattenutaEditRow(row, onDismissed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final campoImporto = find.byWidgetPredicate(
        (w) => w is CupertinoTextField && w.controller == row.importo,
      );
      await tester.tap(campoImporto);
      await tester.pumpAndSettle();
      await tester.enterText(campoImporto, '1750,00');
      await tester.pumpAndSettle();

      expect(row.importo.text, '1750,00');
      expect(tester.takeException(), isNull);
    });
  });
}
