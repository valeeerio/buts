import 'area_type.dart';

/// Riepilogo di un'area così come mostrato in dashboard: importo corrente,
/// variazione percentuale rispetto al periodo di confronto, e la serie di
/// punti per la sparkline.
///
/// Periodo di confronto per tipo di area (deciso nell'intervista di stile):
/// - Conto Principale → ultimi 7 giorni
/// - Risparmio Principale / Piccolo Risparmio / Impegni Fissi → ultimi 6 mesi
class DashboardAreaSummary {
  final AreaType type;
  final double amount;

  /// Variazione percentuale nel periodo (puà essere negativa).
  final double changePercent;

  /// Punti normalizzati per la sparkline (solo andamento, non serve la scala reale).
  final List<double> sparklinePoints;

  /// Suffisso opzionale mostrato accanto all'importo (es. "/mese" per Impegni Fissi).
  final String? amountSuffix;

  const DashboardAreaSummary({
    required this.type,
    required this.amount,
    required this.changePercent,
    required this.sparklinePoints,
    this.amountSuffix,
  });

  /// true se la variazione mostrata va colorata di verde (favorevole),
  /// false se va colorata di rosso (sfavorevole).
  bool get isChangeFavorable {
    final isIncrease = changePercent >= 0;
    return type.isIncreaseFavorable() ? isIncrease : !isIncrease;
  }
}

/// Dati di esempio (mock) per lo sviluppo della UI, coerenti con quelli
/// già validati nel mockup HTML approvato.
class DashboardMockData {
  static const totalAmount = 6262.0;

  static const List<DashboardAreaSummary> areas = [
    DashboardAreaSummary(
      type: AreaType.contoPrincipale,
      amount: 612,
      changePercent: -8,
      sparklinePoints: [10, 13, 10, 17, 15, 20, 22],
    ),
    DashboardAreaSummary(
      type: AreaType.risparmioPrincipale,
      amount: 4250,
      changePercent: 7.6,
      sparklinePoints: [22, 20, 17, 13, 8, 4],
    ),
    DashboardAreaSummary(
      type: AreaType.piccoloRisparmio,
      amount: 620,
      changePercent: 8.8,
      sparklinePoints: [23, 19, 16, 12, 7, 3],
    ),
    DashboardAreaSummary(
      type: AreaType.impegniFissi,
      amount: 780,
      changePercent: 2.1,
      sparklinePoints: [20, 19, 17, 16, 14, 12],
      amountSuffix: '/mese',
    ),
  ];

  /// Percentuale di ripartizione sul totale per il donut chart.
  static double percentOf(DashboardAreaSummary area) =>
      (area.amount / totalAmount) * 100;
}
