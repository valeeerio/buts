import 'package:intl/intl.dart';

import '../models/busta_paga.dart';

/// Label periodo condivisa ("Marzo 2026"), estratta dai getter privati
/// duplicati in `BustaPagaSummaryHero`/`BustaPagaListItem` — serve anche per
/// il match testuale della ricerca nell'Archivio.
String periodoLabel(BustaPaga bustaPaga) {
  final formatted = DateFormat('MMMM yyyy', 'it_IT').format(bustaPaga.periodo);
  return formatted[0].toUpperCase() + formatted.substring(1);
}

/// Label solo mese ("Marzo"), senza l'anno — usata dove l'anno è già
/// visibile altrove (es. header sticky del gruppo anno nell'Archivio).
String meseLabel(BustaPaga bustaPaga) {
  final formatted = DateFormat('MMMM', 'it_IT').format(bustaPaga.periodo);
  return formatted[0].toUpperCase() + formatted.substring(1);
}

/// Etichetta breve di una data periodo (es. "gen '24"), usata sull'asse X
/// dei grafici Statistiche e dal selettore di periodo (`PeriodYearMonthPicker`)
/// — condivisa perché entrambi devono restare coerenti nel formato.
String periodoAxisLabel(DateTime periodo) {
  final month = DateFormat('MMM', 'it_IT').format(periodo);
  final year = DateFormat('yy', 'it_IT').format(periodo);
  return "$month '$year";
}

/// Etichetta breve solo mese (es. "ago"), usata sull'asse X dei grafici
/// Statistiche per le etichette mensili normali — l'anno è già visibile
/// nello slider di periodo sopra i grafici, ripeterlo su ogni tick sarebbe
/// ridondante. Non usata per tooltip/tabelle statistiche sotto i grafici
/// (restano su [periodoAxisLabel], dove il contesto dello slider non è
/// detto sia visibile nello stesso colpo d'occhio).
String meseAxisLabel(DateTime periodo) {
  return DateFormat('MMM', 'it_IT').format(periodo);
}

/// Etichetta solo anno (es. "'24"), usata sull'asse X dei grafici Statistiche
/// quando il periodo selezionato copre molti mesi e mostrare un'etichetta per
/// ogni mese affollerebbe l'asse — vedi `_periodoBottomAxisTitles` in
/// `buste_paga_statistiche_screen.dart`.
String annoAxisLabel(DateTime periodo) {
  return "'${DateFormat('yy', 'it_IT').format(periodo)}";
}

/// Etichetta "13esima"/"14esima" per i tipi non mensili, `null` per
/// `TipoBustaPaga.mensile` (nessuna label da mostrare al posto del mese in
/// quel caso).
String? tipoMensilitaLabel(TipoBustaPaga tipo) {
  switch (tipo) {
    case TipoBustaPaga.tredicesima:
      return '13esima';
    case TipoBustaPaga.quattordicesima:
      return '14esima';
    case TipoBustaPaga.mensile:
      return null;
  }
}

/// Label da mostrare al posto del solo mese (es. "Agosto") quando la busta
/// paga è una 13esima/14esima — più identificativo del mese di pagamento,
/// che per queste mensilità aggiuntive è spesso incidentale. Ricade su
/// [meseLabel] per le buste mensili normali.
String bustaPagaMeseDisplay(BustaPaga bustaPaga) {
  return tipoMensilitaLabel(bustaPaga.tipo) ?? meseLabel(bustaPaga);
}

/// Label da mostrare al posto di mese+anno (es. "Agosto 2026") quando la
/// busta paga è una 13esima/14esima (es. "14esima 2026"). Ricade
/// su [periodoLabel] per le buste mensili normali.
String bustaPagaPeriodoDisplay(BustaPaga bustaPaga) =>
    periodoDisplayFor(periodo: bustaPaga.periodo, tipo: bustaPaga.tipo);

/// Come [bustaPagaPeriodoDisplay], ma su periodo/tipo passati separatamente
/// invece che su una `BustaPaga` intera — serve nel dettaglio busta paga in
/// modalità modifica, dove periodo e tipo "in corso di modifica" vivono in
/// controller/stato locali separati, non ancora ricomposti in un oggetto
/// `BustaPaga`.
String periodoDisplayFor(
    {required DateTime periodo, required TipoBustaPaga tipo}) {
  final tipoLabel = tipoMensilitaLabel(tipo);
  if (tipoLabel == null) {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }
  final anno = DateFormat('yyyy').format(periodo);
  return '$tipoLabel $anno';
}

/// Formatta un numero troncando a intero se il valore è intero, altrimenti
/// mostra due cifre decimali — estratta da `_formatNumber` in
/// `BustaPagaDetailScreen`, riusata anche da `BustaPagaSummaryHero`.
///
/// Usata per quantità NON monetarie (ferie, ROL, permessi, ore lavorate,
/// straordinari, quantità delle voci di competenza) — per importi in euro
/// usare invece [formatEuro]. Separatore decimale sempre la VIRGOLA
/// (convenzione italiana, coerente con [formatEuro]/[parseItalianNumber]):
/// `toStringAsFixed` di per sé è locale-INDIPENDENTE e userebbe sempre il
/// punto — questo valore viene riusato per precompilare i
/// `TextEditingController` di Ferie/ROL/Ex festività/Ore lavorate/quantità
/// competenze in form e dettaglio (editing inline), che al salvataggio
/// vengono riletti con [parseItalianNumber] (punto = separatore delle
/// migliaia, virgola = decimale): un valore come "12.83" prodotto con la
/// vecchia implementazione veniva quindi riletto come "1283" (il punto
/// interpretato come separatore delle migliaia e rimosso) — bug reale
/// riprodotto e corretto qui, non un'ipotesi (vedi
/// `test/busta_paga_formatting_test.dart`).
String formatNumber(double value) {
  final fixed = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return fixed.replaceAll('.', ',');
}

final NumberFormat _fixedDecimalFormat = NumberFormat('#,##0.00', 'it_IT');

/// Formatta un numero nel formato italiano con separatore delle migliaia
/// (punto) e sempre esattamente due cifre decimali fisse (virgola) — a
/// differenza di [formatNumber], che omette i decimali per i valori interi
/// e non raggruppa le migliaia. Utile dove più valori formattati convivono
/// nella stessa colonna/tabella e un numero di decimali incoerente (es.
/// "9,13" sopra "16") renderebbe più difficile scansionarla a colpo
/// d'occhio — usata dalle tabelle di riepilogo sotto i grafici in
/// `buste_paga_statistiche_screen.dart` (ferie/permessi/straordinari, non
/// importi in euro). Per importi in EURO usare [formatEuro] — stessa
/// formattazione numerica, tenuta come funzione separata per chiarezza
/// semantica nei punti di chiamata (valuta vs quantità generica).
String formatNumberFixed(double value) {
  return _fixedDecimalFormat.format(value);
}

/// Formatta un importo in EURO nel formato italiano: punto come separatore
/// delle migliaia, virgola come separatore decimale, sempre esattamente due
/// cifre decimali (es. "1.483,54", "1.411,00") — a differenza di
/// [formatNumber], che omette i decimali per i valori interi e non
/// raggruppa le migliaia, e va usata solo per quantità non monetarie.
/// Riservata a netto, lordo, importi di competenze/trattenute e ogni altro
/// valore espresso in euro.
String formatEuro(double value) {
  return _fixedDecimalFormat.format(value);
}

/// Decide il prefisso con segno da mostrare per un importo di trattenuta, a
/// partire dal solo valore numerico: "− € " per il caso comune (importo ≥ 0,
/// sottratto dal lordo), "+ € " per un valore negativo — che nel parser
/// regex (vedi `_rigaTrattenutaVerificata` in `busta_paga_regex_parser.dart`)
/// rappresenta un conguaglio/storno A CREDITO del dipendente, non "una
/// trattenuta negativa". Condivisa fra [formatTrattenuta] (vista di sola
/// lettura) e `trattenutaEditRow` (vista di modifica, calcolato in tempo
/// reale sul testo digitato) così le due viste restano garantite identiche
/// per lo stesso valore — vedi requisito "modifica inline" in `CLAUDE.md`.
String trattenutaPrefix(double value) => value < 0 ? '+ € ' : '− € ';

/// Formatta l'importo di una trattenuta con segno esplicito: "− € 90,11"
/// per il caso comune (importo positivo, sottratto dal lordo), "+ € 3,50"
/// per un valore negativo. Usa sempre il valore ASSOLUTO dentro [formatEuro]
/// (che da solo aggiunge già un "-" per i negativi): un prefisso "− €" fisso
/// davanti al segno di `formatEuro` produrrebbe un doppio segno fuorviante
/// ("− € -3,50") — bug reale corretto qui, non un'ipotesi.
String formatTrattenuta(double value) {
  return '${trattenutaPrefix(value)}${formatEuro(value.abs())}';
}

/// Formatta un importo in euro con prefisso "€ " anteponendo il segno "−"
/// PRIMA del simbolo valuta per i valori negativi, invece di concatenare
/// ingenuamente "€ " al risultato di [formatEuro] (che per un negativo
/// produce già un "-" tutto suo, es. "€ -1.411,00" — un segno fuorviante,
/// dopo il simbolo valuta invece che prima). Stessa coerenza già applicata a
/// [formatTrattenuta]/[trattenutaPrefix], ma SENZA la loro inversione di
/// segno (lì un valore positivo è "una trattenuta", quindi mostrato con "−";
/// qui il segno mostrato corrisponde 1:1 al segno del valore, non è una
/// trattenuta con convenzione invertita). Riservata a importi normalmente
/// non negativi ma che possono eccezionalmente esserlo (es. il netto, se le
/// trattenute superano il lordo) — bug reale corretto qui, non un'ipotesi.
String formatEuroConSegno(double value) {
  return value < 0
      ? '− € ${formatEuro(value.abs())}'
      : '€ ${formatEuro(value)}';
}

/// Versione COMPATTA di [formatEuroConSegno], per etichette con spazio
/// ristretto (asse Y del grafico Netto/Lordo in Statistiche, vedi
/// `_valueLeftAxisTitles` in `buste_paga_statistiche_screen.dart`) — NON per
/// importi normali (tooltip, tabella riepilogativa), che restano su
/// [formatEuroConSegno] con i due decimali esatti. Arrotonda all'euro (zero
/// decimali) e, per i valori con modulo ≥ 1000, passa a notazione "k" con al
/// più una cifra decimale (es. "1,5k", oppure "2k" se il migliaio è esatto) —
/// una stringa come "− € 3.245,67" (12 caratteri) forzava lo scale-down di
/// `FittedBox` ben sotto la soglia di leggibilità (~9-11px) nello spazio
/// riservato all'asse; la versione compatta ("− € 3,2k", 8 caratteri) ci sta
/// alla dimensione naturale del font. Stessa convenzione di segno/simbolo di
/// [formatEuroConSegno]: "−" prima di "€" per i negativi.
String formatEuroConSegnoCompatto(double value) {
  final negative = value < 0;
  final abs = value.abs();
  // La decisione tra notazione "k" e numero secco va presa sul valore GIÀ
  // arrotondato all'euro (stesso arrotondamento poi effettivamente
  // mostrato nel ramo secco) — non su `abs` non arrotondato. Altrimenti un
  // valore come 999.6 (sotto soglia, ma che arrotonda a 1000) finiva nel
  // ramo secco producendo "€ 1000" invece di "€ 1k" (bug corretto qui). Il
  // ramo "k" riparte a sua volta da questo intero già arrotondato, così non
  // ci sono due arrotondamenti indipendenti che possano disallinearsi tra
  // soglia e cifra mostrata.
  final roundedAbs = abs.round();
  final String numberPart;
  if (roundedAbs >= 1000) {
    final kRounded = (roundedAbs / 100).round() / 10;
    numberPart = kRounded == kRounded.roundToDouble()
        ? '${kRounded.toStringAsFixed(0)}k'
        : '${kRounded.toStringAsFixed(1).replaceAll('.', ',')}k';
  } else {
    numberPart = roundedAbs.toString();
  }
  return negative ? '− € $numberPart' : '€ $numberPart';
}

/// Converte un numero in formato italiano digitato dall'utente (punto come
/// separatore delle migliaia, virgola come separatore decimale — es.
/// "1.234,56" o "1234,56") in un `double`, tornando `0` se il testo è vuoto o
/// non valido. Una sostituzione ingenua virgola→punto rompe con l'input
/// "1.234,56" (diventa "1.234.56", due punti, `tryParse` fallisce e
/// l'importo viene silenziosamente azzerato): qui si rimuovono prima i punti
/// delle migliaia, poi si converte la virgola decimale in punto.
double parseItalianNumber(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final normalized = trimmed.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

/// Come [parseItalianNumber], ma ritorna `null` invece di azzerare
/// silenziosamente un testo non numerico (lettere, testo incollato per
/// errore) — usata dalla validazione al salvataggio (vedi
/// [isValidItalianNumberField]), non da [parseItalianNumber] stesso, che
/// resta usato ovunque nell'app un valore "sicuro" (già validato prima del
/// salvataggio) serva senza dover propagare un `null`. Un testo vuoto ritorna
/// `null` qui: la distinzione fra "vuoto" e "non valido" è responsabilità del
/// chiamante (vedi [isValidItalianNumberField], che tratta il vuoto come
/// valido — placeholder "0" dei campi numerici dell'app).
double? tryParseItalianNumber(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}

/// `true` se [text] è un input accettabile per un campo numerico dell'app
/// (Ore lavorate, Ferie/ROL/Ex festività Maturato-Goduto-Residuo, quantità e
/// importo delle voci di Competenze, importo delle Trattenute) — usata dalla
/// validazione al salvataggio in `busta_paga_detail_screen.dart`/
/// `busta_paga_form_screen.dart` (bug reale corretto: prima di questo fix
/// `parseItalianNumber` azzerava silenziosamente qualunque testo non
/// numerico, senza bloccare il salvataggio né avvisare l'utente — vedi
/// istruzioni task/CLAUDE.md).
///
/// Un testo VUOTO è considerato valido (equivale a "0"): ogni campo numerico
/// di questa app mostra un placeholder "0" grigio quando vuoto
/// (`inlineNumberField`) e più punti del codice si affidano esplicitamente a
/// questa convenzione (es. `VoceCompetenzaEditRow.quantitaValue`, dove vuoto
/// significa "quantità assente" nel PDF, un valore reale e distinto da "0"
/// digitato) — bloccare il salvataggio per un campo lasciato vuoto
/// romperebbe quell'invariante consolidata, non è il bug da correggere qui.
///
/// Un testo che contiene un punto è valido SOLO se il punto è un separatore
/// delle migliaia sintatticamente corretto (gruppi di esattamente 3 cifre fra
/// un punto e l'altro, es. "1.483,54", "12.345,00", "1.234.567,89") — mai se
/// il punto è seguito da un gruppo di 1-2 cifre non allineato a un
/// raggruppamento da migliaia (es. "12.5", "1.5": notazione decimale
/// ambigua stile USA). Prima di questo fix qualunque punto veniva rifiutato
/// in blocco: i controller di editing di Competenze/Trattenute vengono però
/// precompilati con [formatEuro], che INSERISCE il punto delle migliaia per
/// ogni importo ≥ 1.000 (es. "1.483,54") — un cedolino reale con una sola
/// voce ≥ 1.000€ non toccata dall'utente veniva quindi bloccato al
/// salvataggio come "valore non valido", bug reale corretto qui, non
/// un'ipotesi. `inputFormatters` su `inlineNumberField` impedisce comunque
/// di DIGITARE il punto (livello 1); questo controllo (livello 2, rete di
/// sicurezza per valori precompilati o incollati) valida la sintassi del
/// punto invece di rifiutarlo sempre.
bool isValidItalianNumberField(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return true;
  if (!_italianNumberPattern.hasMatch(trimmed)) return false;
  return tryParseItalianNumber(trimmed) != null;
}

/// Pattern di un numero in formato italiano sintatticamente valido: o senza
/// alcun punto (`-?\d+(,\d+)?`, es. "123", "1234,56" — l'utente può digitare
/// senza separatore delle migliaia, non è obbligatorio), oppure con punti
/// SOLO come separatore delle migliaia in posizione corretta
/// (`-?\d{1,3}(\.\d{3})*(,\d+)?`, es. "1.483,54", "12.345,00",
/// "1.234.567,89" — ogni gruppo fra un punto e l'altro deve avere
/// esattamente 3 cifre). Qualunque altro uso del punto (es. "12.5", "1.5":
/// un gruppo di 1-2 cifre dopo il punto, tipico della notazione decimale
/// USA) non soddisfa nessuna delle due alternative e viene quindi rifiutato.
final RegExp _italianNumberPattern = RegExp(
  r'^-?\d{1,3}(\.\d{3})*(,\d+)?$|^-?\d+(,\d+)?$',
);
