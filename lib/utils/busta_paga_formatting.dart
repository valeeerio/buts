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
/// dei grafici Statistiche e dal selettore di periodo (`CupertinoRangeSlider`)
/// — condivisa perché entrambi devono restare coerenti nel formato.
String periodoAxisLabel(DateTime periodo) {
  final month = DateFormat('MMM', 'it_IT').format(periodo);
  final year = DateFormat('yy', 'it_IT').format(periodo);
  return "$month '$year";
}

/// Etichetta solo anno (es. "'24"), usata sull'asse X dei grafici Statistiche
/// quando il periodo selezionato copre molti mesi e mostrare un'etichetta per
/// ogni mese affollerebbe l'asse — vedi `_periodoBottomAxisTitles` in
/// `buste_paga_statistiche_screen.dart`.
String annoAxisLabel(DateTime periodo) {
  return "'${DateFormat('yy', 'it_IT').format(periodo)}";
}

/// Formatta un numero troncando a intero se il valore è intero, altrimenti
/// mostra due cifre decimali — estratta da `_formatNumber` in
/// `BustaPagaDetailScreen`, riusata anche da `BustaPagaSummaryHero`.
String formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
