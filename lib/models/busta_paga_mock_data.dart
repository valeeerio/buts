import 'busta_paga.dart';

/// Dati mock per la sezione Buste Paga — stesso ruolo di
/// DashboardMockData: da sostituire con dati reali persistiti quando si
/// collega Drift (skill drift-migration).
class BustaPagaMockData {
  BustaPagaMockData._();

  static List<BustaPaga> get initial => [
        BustaPaga(
          id: 'bp-2026-05',
          periodo: DateTime(2026, 5, 1),
          lordo: 2450.00,
          netto: 1780.30,
          trattenute: const {'INPS': 245.00, 'IRPEF': 380.50, 'Addizionali': 44.20},
          straordinari: 85.40,
          ferieMaturate: 96,
          ferieGodute: 88,
          ferieResidue: 8,
          rolMaturati: 32,
          rolGoduti: 28,
          rolResidui: 4,
          permessiGoduti: 6,
          oreLavorate: 168,
        ),
        BustaPaga(
          id: 'bp-2026-06',
          periodo: DateTime(2026, 6, 1),
          lordo: 2450.00,
          netto: 1798.10,
          trattenute: const {'INPS': 245.00, 'IRPEF': 372.10, 'Addizionali': 34.80},
          straordinari: 120.00,
          ferieMaturate: 104,
          ferieGodute: 88,
          ferieResidue: 16,
          rolMaturati: 34.6,
          rolGoduti: 28,
          rolResidui: 6.6,
          permessiGoduti: 6,
          oreLavorate: 176,
        ),
      ];
}
