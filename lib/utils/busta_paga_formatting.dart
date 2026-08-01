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

/// Etichetta "13esima mensilità"/"14esima mensilità" per i tipi non
/// mensili, `null` per `TipoBustaPaga.mensile` (nessuna label da mostrare al
/// posto del mese in quel caso).
String? tipoMensilitaLabel(TipoBustaPaga tipo) {
  switch (tipo) {
    case TipoBustaPaga.tredicesima:
      return '13esima mensilità';
    case TipoBustaPaga.quattordicesima:
      return '14esima mensilità';
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
/// busta paga è una 13esima/14esima (es. "14esima mensilità 2026"). Ricade
/// su [periodoLabel] per le buste mensili normali.
String bustaPagaPeriodoDisplay(BustaPaga bustaPaga) =>
    periodoDisplayFor(periodo: bustaPaga.periodo, tipo: bustaPaga.tipo);

/// Come [bustaPagaPeriodoDisplay], ma su periodo/tipo passati separatamente
/// invece che su una `BustaPaga` intera — serve nel dettaglio busta paga in
/// modalità modifica, dove periodo e tipo "in corso di modifica" vivono in
/// controller/stato locali separati, non ancora ricomposti in un oggetto
/// `BustaPaga`.
String periodoDisplayFor({required DateTime periodo, required TipoBustaPaga tipo}) {
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
String formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
