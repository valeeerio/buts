import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
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

  VoceCompetenzaEditRow({
    String descrizione = '',
    String quantita = '',
    String importo = '',
  })  : id = _nextId++,
        descrizione = TextEditingController(text: descrizione),
        quantita = TextEditingController(text: quantita),
        importo = TextEditingController(text: importo);

  double get quantitaValue {
    final text = quantita.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  double get importoValue {
    final text = importo.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
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
                  controller: row.descrizione,
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
                child: Center(
                  child: inlineNumberField(row.quantita),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: inlineNumberField(row.importo, prefix: '€ '),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
