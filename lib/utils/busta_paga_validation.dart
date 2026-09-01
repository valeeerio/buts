import '../widgets/trattenuta_edit_row.dart';
import '../widgets/voce_competenza_edit_row.dart';
import 'busta_paga_formatting.dart';

/// Cerca il primo campo numerico non valido fra [campi] (coppie
/// etichetta/testo, es. Ore lavorate, Ferie/ROL/Ex festività
/// Maturato-Goduto-Residuo) e le righe editabili di [competenze]/[trattenute]
/// — ritorna l'etichetta del campo da correggere, o `null` se sono tutti
/// validi. Condivisa fra il salvataggio del Dettaglio busta paga
/// (`busta_paga_detail_screen.dart._save`) e del Form di import
/// (`busta_paga_form_screen.dart._save`), stesso "livello 2" di validazione
/// (rete di sicurezza oltre agli `inputFormatters` di `inlineNumberField`)
/// per lo stesso identico bug: prima di questo fix un testo non numerico
/// (lettere, formato USA col punto) veniva letto da `parseItalianNumber` e
/// azzerato/gonfiato in silenzio, senza bloccare il salvataggio — vedi
/// `isValidItalianNumberField`.
///
/// Righe di [competenze]/[trattenute] con descrizione/chiave vuota sono
/// escluse dal controllo: vengono comunque scartate al salvataggio (vedi
/// `_competenzeCorrenti`/`_trattenuteCorrenti` in entrambe le schermate),
/// quindi un valore residuo non valido in una riga già vuota non deve
/// bloccare nulla.
String? firstInvalidNumericFieldLabel({
  required List<(String label, String text)> campi,
  List<VoceCompetenzaEditRow> competenze = const [],
  List<TrattenutaEditRow> trattenute = const [],
}) {
  for (final (label, text) in campi) {
    if (!isValidItalianNumberField(text)) return label;
  }
  for (final row in competenze) {
    final descrizione = row.descrizione.text.trim();
    if (descrizione.isEmpty) continue;
    if (!isValidItalianNumberField(row.quantita.text)) {
      return 'Quantità di "$descrizione"';
    }
    if (!isValidItalianNumberField(row.importo.text)) {
      return 'Importo di "$descrizione"';
    }
  }
  for (final row in trattenute) {
    final chiave = row.chiave.text.trim();
    if (chiave.isEmpty) continue;
    if (!isValidItalianNumberField(row.importo.text)) {
      return 'Importo di "$chiave"';
    }
  }
  return null;
}

/// Cerca la prima chiave di trattenuta duplicata (confronto SOLO su `trim()`,
/// case-SENSITIVE — stessa normalizzazione usata dalla collisione reale in
/// `_trattenuteCorrenti`, vedi sotto) fra le righe editabili di [trattenute]
/// — ritorna la chiave (col testo esatto digitato dall'utente nella riga
/// duplicata) o `null` se non ce ne sono. Righe con chiave vuota sono escluse
/// (scartate comunque al salvataggio).
///
/// Bug reale corretto qui: `_trattenuteCorrenti` costruisce una
/// `Map<String, double>` usando la chiave digitata (solo `trim()`, MAI
/// `toLowerCase()`) come chiave della mappa — due righe con lo stesso nome
/// (a meno di maiuscole/minuscole) NON collidono affatto oggi nel
/// salvataggio reale, restano due voci distinte. Una normalizzazione
/// case-insensitive qui segnalerebbe quindi falsi duplicati (es. "Irpef" e
/// "IRPEF") che non causano alcuna perdita di dati, bloccando il salvataggio
/// senza motivo — questa funzione deve rilevare ESATTAMENTE (né più né meno)
/// i casi che causerebbero davvero una collisione nella Map reale. Condivisa
/// fra `busta_paga_detail_screen.dart._save` e
/// `busta_paga_form_screen.dart._save`.
String? firstDuplicateTrattenutaKey(List<TrattenutaEditRow> trattenute) {
  final viste = <String>{};
  for (final row in trattenute) {
    final chiave = row.chiave.text.trim();
    if (chiave.isEmpty) continue;
    if (!viste.add(chiave)) return chiave;
  }
  return null;
}
