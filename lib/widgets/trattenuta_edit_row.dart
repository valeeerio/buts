import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'swipe_delete_background.dart';

/// Campo di testo numerico compatto, senza bordo/riempimento proprio (si
/// appoggia sopra il vetro della card ospitante), stile allineato al valore
/// che sostituisce. Riusato da `BustaPagaStatRow`, `BustaPagaMaturazioniSection`
/// e da `TrattenutaEditRow` in dettaglio/form busta paga.
///
/// Con `prefix` (es. "€ " nelle statistiche Lordo/Straordinari, "− € " nelle
/// trattenute), il blocco "prefisso + campo" si dimensiona sul proprio
/// contenuto (`IntrinsicWidth`, non una larghezza fissa arbitraria): entrare
/// in modifica non deve introdurre alcun gap visibile tra simbolo e numero
/// rispetto alla vista di sola lettura (che è un unico `Text` con
/// spaziatura naturale). `IntrinsicWidth` qui è sicuro: entrambi gli usi
/// attuali vivono dentro un `Expanded`/`Center` a larghezza già vincolata,
/// non dentro un `LayoutBuilder` a constraints illimitate (il bug storico
/// documentato altrove nel progetto riguardava tutt'altro contesto).
/// `rowAlignment` permette di riprodurre esattamente lo stesso allineamento
/// della corrispondente vista di sola lettura — centrato in tutti gli usi
/// attuali — l'unica differenza visibile tra vista e modifica deve restare
/// "il testo è ora in un campo tappabile", non lo spostamento del blocco.
Widget inlineNumberField(
  TextEditingController controller, {
  TextStyle? style,
  String? prefix,
  MainAxisAlignment rowAlignment = MainAxisAlignment.center,
}) {
  return Builder(
    builder: (context) {
      final labelPrimary =
          CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
      final resolvedStyle = (style ?? AppTextStyles.cardAmount).copyWith(
        color: labelPrimary,
        fontWeight: style == null ? FontWeight.w400 : style.fontWeight,
      );
      final field = CupertinoTextField(
        controller: controller,
        placeholder: '0',
        textAlign: TextAlign.center,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        style: resolvedStyle,
      );
      if (prefix == null) return field;
      // `IntrinsicWidth` invece di una larghezza fissa: il campo si
      // dimensiona sul testo digitato, come farebbe il `Text` di sola
      // lettura che sostituisce. Con `mainAxisSize.min` il blocco
      // "prefisso + campo" resta un'unica unità di larghezza nota, sicura
      // da centrare o allineare a destra nella riga ospitante.
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: rowAlignment,
        children: [
          Text(prefix, style: resolvedStyle),
          IntrinsicWidth(child: field),
        ],
      );
    },
  );
}

/// Riga di trattenuta in editing: chiave + importo come controller separati.
/// `id` è una chiave stabile e univoca per riga (indipendente dall'indice,
/// che cambia quando si rimuove una riga precedente), usata da `Dismissible`
/// per lo swipe-to-delete.
class TrattenutaEditRow {
  static int _nextId = 0;

  final int id;
  final TextEditingController chiave;
  final TextEditingController importo;

  TrattenutaEditRow({String chiave = '', String importo = ''})
      : id = _nextId++,
        chiave = TextEditingController(text: chiave),
        importo = TextEditingController(text: importo);

  void dispose() {
    chiave.dispose();
    importo.dispose();
  }
}

/// Riga editabile di trattenuta: chiave + importo come campi di testo,
/// stesso layout a due colonne label/valore della vista di sola lettura. La
/// rimozione avviene via swipe verso sinistra (stesso pattern usato per
/// eliminare una busta paga in `BusteePagaArchivioView`), senza alert di
/// conferma: qui si rimuove solo una riga dallo stato locale di
/// modifica/import, ancora reversibile con "Annulla".
Widget trattenutaEditRow(TrattenutaEditRow row, {required VoidCallback onDismissed}) {
  return Dismissible(
    key: ValueKey(row.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => onDismissed(),
    background: const SwipeDeleteBackground(radius: AppRadius.glassSmall),
    child: Builder(
      builder: (context) {
        final labelPrimary =
            CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: CupertinoTextField(
                  controller: row.chiave,
                  placeholder: 'Voce',
                  decoration: const BoxDecoration(),
                  padding: EdgeInsets.zero,
                  style: AppTextStyles.subtitle.copyWith(
                    color: labelPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                // Stesso prefisso "− € " e centratura della corrispondente
                // riga di sola lettura: l'importo digitato resta sempre
                // positivo, il segno e il simbolo sono un prefisso fisso,
                // non editabile.
                child: Center(
                  child: inlineNumberField(
                    row.importo,
                    prefix: '− € ',
                    style: AppTextStyles.cardAmount
                        .copyWith(fontWeight: FontWeight.w400),
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
