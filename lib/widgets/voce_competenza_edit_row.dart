import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'swipe_delete_background.dart';
import 'trattenuta_edit_row.dart' show inlineNumberField;

/// Riga di voce di competenza in editing: descrizione, quantità e importo
/// come controller separati. `id` è una chiave stabile e univoca per riga
/// (indipendente dall'indice, che cambia quando si rimuove una riga
/// precedente), usata da `Dismissible` per lo swipe-to-delete — stesso
/// pattern gemello di `TrattenutaEditRow`, con un campo in più (quantità).
class VoceCompetenzaEditRow {
  static int _nextId = 0;

  final int id;
  final TextEditingController descrizione;
  final TextEditingController quantita;
  final TextEditingController importo;

  /// `true` se il valore ORIGINALE dell'importo di questa voce (al momento
  /// della costruzione della riga) era negativo — uno storno a debito del
  /// cedolino (vedi `_rigaVoceCompetenza` in
  /// `busta_paga_regex_parser.dart`), MAI digitato direttamente dall'utente.
  /// Il controller [importo] mostra e fa digitare SEMPRE e SOLO il valore
  /// ASSOLUTO — esattamente come la vista di sola lettura
  /// (`formatEuroConSegno`, che applica `.abs()` dentro `formatEuro`) —
  /// mentre il segno resta tracciato QUI, separato dal testo, e va
  /// riapplicato leggendo [importoValue]. Stesso pattern di
  /// `TrattenutaEditRow.negativo`/`valoreConSegno`, ma rilevato dal segno
  /// "-" iniziale della stringa già formattata passata al costruttore
  /// (`importo` resta un parametro `String`, non `double`, per compatibilità
  /// con gli altri chiamanti di questa classe che precompilano la riga con
  /// lo stesso pattern) invece che da un parametro `double` separato: prima
  /// di questo fix il controller veniva precompilato col valore CON segno
  /// (es. "-14,50") e il widget anteponeva comunque un prefisso "€ " fisso,
  /// producendo un doppio segno in editing ("€ -14,50") che la sola lettura
  /// non mostra mai (mostra invece "− € 14,50") — bug reale corretto qui,
  /// non un'ipotesi. Catturato una sola volta alla costruzione della riga,
  /// mai ricalcolato dal testo digitato in [importo].
  final bool negativo;

  VoceCompetenzaEditRow({
    String descrizione = '',
    String quantita = '',
    String importo = '',
  })  : id = _nextId++,
        descrizione = TextEditingController(text: descrizione),
        quantita = TextEditingController(text: quantita),
        negativo = importo.trim().startsWith('-'),
        importo = TextEditingController(
          text: importo.trim().startsWith('-')
              ? importo.trim().substring(1)
              : importo,
        );

  /// `null` quando il campo è vuoto — stessa convenzione della vista di sola
  /// lettura: la riga del PDF non riportava alcuna quantità (nessun tag
  /// GIORNI/ORE/RATEI, es. "930 Trattamento integrativo"), distinta da "0"
  /// digitato esplicitamente, che resta un valore reale (vedi
  /// `VoceCompetenza.quantita`). Lasciare il campo vuoto (placeholder "0"
  /// grigio di `inlineNumberField`, mai testo reale) preserva l'assenza
  /// anche al salvataggio senza modifiche (round trip).
  double? get quantitaValue =>
      quantita.text.trim().isEmpty ? null : parseItalianNumber(quantita.text);

  /// Valore "vero" dell'importo, col segno di [negativo] riapplicato al
  /// valore assoluto attualmente digitato in [importo] — unico punto da cui
  /// leggere il valore per salvataggio/calcoli live, stesso pattern di
  /// `TrattenutaEditRow.valoreConSegno`. `.abs()` sul testo digitato è una
  /// rete di sicurezza: il campo non impedisce comunque di incollare/digitare
  /// un "-" (nessun `inputFormatters` dedicato).
  double get importoValue {
    final assoluto = parseItalianNumber(importo.text).abs();
    return negativo ? -assoluto : assoluto;
  }

  void dispose() {
    descrizione.dispose();
    quantita.dispose();
    importo.dispose();
  }
}

/// Riga editabile di voce di competenza: descrizione, quantità e importo
/// come campi di testo, stesso layout a colonne label/valore/valore della
/// vista di sola lettura (`BustaPagaCompetenzeSection`). La rimozione avviene
/// via swipe verso sinistra, senza alert di conferma — stesso pattern di
/// `trattenutaEditRow`.
Widget voceCompetenzaEditRow(
  VoceCompetenzaEditRow row, {
  required VoidCallback onDismissed,
}) {
  return Dismissible(
    key: ValueKey(row.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => onDismissed(),
    background: const SwipeDeleteBackground(radius: AppRadius.pulseSmall),
    child: Builder(
      builder: (context) {
        final textPrimary =
            CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smPlus),
          child: Row(
            children: [
              Expanded(
                // Flex 3:1:4 (non più 3:2:2): l'aumento di `pulseDisplaySmall`
                // da 15 a 16px (vedi CLAUDE.md/app_text_styles.dart) fa
                // andare in overflow la colonna importo su larghezze strette
                // già con valori realistici comuni (es. "€ 234,56" o "€
                // 1.500,00") a causa del prefisso "€ "/"− € " dentro
                // `IntrinsicWidth` — la quantità (senza prefisso, campo di
                // testo "nudo") non ha lo stesso rischio, da cui la
                // redistribuzione a suo sfavore. Stesso rapporto applicato
                // anche a `BustaPagaCompetenzeSection` per non alterare
                // l'allineamento tra vista e modifica.
                flex: 3,
                // `maxLines: null` (nessun limite, cresce verticalmente)
                // invece del default di `CupertinoTextField` (1 riga, che
                // TRONCA orizzontalmente il testo che eccede la larghezza) —
                // la vista di sola lettura (`BustaPagaCompetenzeSection`,
                // `maxLines: 2, overflow: TextOverflow.ellipsis`) va invece
                // su due righe per le descrizioni lunghe: senza questo,
                // entrare in modifica cambiava l'altezza della riga e
                // tagliava silenziosamente il testo visibile — violava il
                // requisito "modifica inline" non negoziabile (vedi
                // CLAUDE.md), stesso bug reale già corretto per le
                // Trattenute (`TrattenutaEditRow`, vedi la sua doc).
                child: CupertinoTextField(
                  controller: row.descrizione,
                  placeholder: 'Voce',
                  maxLines: null,
                  decoration: const BoxDecoration(),
                  padding: EdgeInsets.zero,
                  style: AppTextStyles.pulseBodyEmphasis.copyWith(
                    color: textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: inlineNumberField(
                    row.quantita,
                    style: AppTextStyles.pulseDisplaySmall,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  // Prefisso dinamico "€ "/"− € ", non fisso: stessa
                  // convenzione della vista di sola lettura
                  // (`formatEuroConSegno`, che ANTEPONE il segno al simbolo
                  // valuta per un valore negativo — a differenza delle
                  // trattenute, il segno mostrato corrisponde 1:1 al segno
                  // del valore, non è invertito) — vedi doc di
                  // `VoceCompetenzaEditRow.negativo`.
                  child: inlineNumberField(
                    row.importo,
                    prefix: row.negativo ? '− € ' : '€ ',
                    style: AppTextStyles.pulseDisplaySmall,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
