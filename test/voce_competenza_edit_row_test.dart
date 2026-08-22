import 'package:buts/models/busta_paga.dart';
import 'package:buts/widgets/busta_paga_competenze_section.dart';
import 'package:buts/widgets/voce_competenza_edit_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressione per il bug "quantità 0 su voci che non hanno quantità" (es.
/// "930 Trattamento integrativo", "942 Somma integrativa": nessun tag
/// GIORNI/ORE/RATEI sul PDF, la colonna quantità è vuota) — vedi
/// `VoceCompetenza.quantita`, diventato nullable per distinguere "assente"
/// da "0" stampato esplicitamente.
void main() {
  group('VoceCompetenzaEditRow.quantitaValue — assente vs zero', () {
    test('campo mai digitato (testo vuoto) -> null, non 0', () {
      final row = VoceCompetenzaEditRow(descrizione: 'X');
      addTearDown(row.dispose);

      expect(row.quantita.text, isEmpty);
      expect(row.quantitaValue, isNull);
    });

    test('"0" digitato ESPLICITAMENTE -> 0.0, distinto da assente', () {
      final row = VoceCompetenzaEditRow(descrizione: 'X', quantita: '0');
      addTearDown(row.dispose);

      expect(row.quantitaValue, isNotNull);
      expect(row.quantitaValue, 0.0);
    });

    test('un valore reale digitato si rilegge identico', () {
      final row = VoceCompetenzaEditRow(descrizione: 'X', quantita: '22,000');
      addTearDown(row.dispose);

      expect(row.quantitaValue, closeTo(22.0, 0.001));
    });
  });

  group('VoceCompetenzaEditRow — importo negativo, nessun doppio segno', () {
    // Regressione: prima del fix il controller veniva precompilato con
    // `formatEuro(importo)` (che antepone già un "-" per i negativi, es.
    // "-14,50") e il widget aggiungeva comunque un prefisso "€ " fisso,
    // producendo "€ -14,50" in editing contro "− € 14,50" mostrato in sola
    // lettura da `formatEuroConSegno` — vedi CLAUDE.md, requisito "modifica
    // inline" non negoziabile.
    test(
        'costruita con stringa negativa: negativo=true, campo mostra solo '
        'il valore assoluto', () {
      final row =
          VoceCompetenzaEditRow(descrizione: 'Storno', importo: '-14,50');
      addTearDown(row.dispose);

      expect(row.negativo, isTrue);
      expect(row.importo.text, '14,50');
      expect(row.importoValue, closeTo(-14.5, 0.001));
    });

    test(
        'costruita con stringa positiva: negativo=false, nessun segno nel '
        'campo', () {
      final row =
          VoceCompetenzaEditRow(descrizione: 'Ordinaria', importo: '1.500,00');
      addTearDown(row.dispose);

      expect(row.negativo, isFalse);
      expect(row.importo.text, '1.500,00');
      expect(row.importoValue, closeTo(1500.0, 0.001));
    });

    testWidgets(
        'riga negativa mostra il prefisso "− € ", mai un "€ -" col segno '
        'duplicato', (tester) async {
      final row =
          VoceCompetenzaEditRow(descrizione: 'Storno', importo: '-14,50');
      addTearDown(row.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 600,
                child: voceCompetenzaEditRow(row, onDismissed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('− € '), findsOneWidget);
      expect(find.text('€ '), findsNothing);

      final campoImporto = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .firstWhere((w) => w.controller == row.importo);
      expect(campoImporto.controller!.text, '14,50');
    });
  });

  group('BustaPagaCompetenzeSection — sola lettura, quantità assente', () {
    testWidgets(
        'quantità null mostra un trattino "—", non "0" (fuorviante come '
        '"zero giorni/ore")', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: BustaPagaCompetenzeSection(
              isEditing: false,
              competenze: [
                VoceCompetenza(
                  descrizione: 'Trattamento integrativo DL 3/2020',
                  quantita: null,
                  importo: 100.0,
                ),
                VoceCompetenza(
                  descrizione: 'Retribuzione ordinaria',
                  quantita: 22.0,
                  importo: 1500.0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('voceCompetenzaEditRow — quantità assente in editing', () {
    testWidgets(
        'riga costruita con quantità vuota mostra un campo vuoto (nessun '
        '"0" reale digitato, solo il placeholder grigio di '
        'inlineNumberField)', (tester) async {
      final row = VoceCompetenzaEditRow(descrizione: 'Trattamento integrativo');
      addTearDown(row.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 340,
                child: voceCompetenzaEditRow(row, onDismissed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final campoQuantita = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .firstWhere((w) => w.controller == row.quantita);

      expect(campoQuantita.controller!.text, isEmpty);
      expect(campoQuantita.placeholder, '0');
    });
  });
}
