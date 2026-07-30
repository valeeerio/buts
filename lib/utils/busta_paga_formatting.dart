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

/// Formatta un numero troncando a intero se il valore è intero, altrimenti
/// mostra due cifre decimali — estratta da `_formatNumber` in
/// `BustaPagaDetailScreen`, riusata anche da `BustaPagaSummaryHero`.
String formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
