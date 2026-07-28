/// Stato di verifica di una busta paga inserita: in v1 (inserimento
/// manuale) è sempre `confermato`; il valore `daConfermare` resta previsto
/// per la Fase 3 (estrazione AI on-device), dove l'utente dovrà confermare
/// i campi estratti automaticamente prima che entrino in archivio.
enum StatoVerificaBustaPaga { daConfermare, confermato }

/// Dati ricavabili da una busta paga. Nomi campo allineati 1:1 a
/// piano_progetto_finanze_personali.md §5 per rendere meccanica la futura
/// mappatura a tabella Drift (skill drift-migration / agent
/// drift-schema-architect) quando si passerà dalla persistenza in-memory
/// a SQLite.
class BustaPaga {
  final String id;
  final DateTime periodo;
  final String? fileOrigine;
  final double lordo;
  final double netto;
  final Map<String, double> trattenute;
  final double straordinari;
  final double ferieMaturate;
  final double ferieGodute;
  final double ferieResidue;
  final double rolMaturati;
  final double rolGoduti;
  final double rolResidui;
  final double permessiGoduti;
  final double oreLavorate;
  final StatoVerificaBustaPaga statoVerifica;

  const BustaPaga({
    required this.id,
    required this.periodo,
    this.fileOrigine,
    required this.lordo,
    required this.netto,
    required this.trattenute,
    required this.straordinari,
    required this.ferieMaturate,
    required this.ferieGodute,
    required this.ferieResidue,
    required this.rolMaturati,
    required this.rolGoduti,
    required this.rolResidui,
    required this.permessiGoduti,
    required this.oreLavorate,
    this.statoVerifica = StatoVerificaBustaPaga.confermato,
  });

  BustaPaga copyWith({
    String? id,
    DateTime? periodo,
    String? fileOrigine,
    double? lordo,
    double? netto,
    Map<String, double>? trattenute,
    double? straordinari,
    double? ferieMaturate,
    double? ferieGodute,
    double? ferieResidue,
    double? rolMaturati,
    double? rolGoduti,
    double? rolResidui,
    double? permessiGoduti,
    double? oreLavorate,
    StatoVerificaBustaPaga? statoVerifica,
  }) {
    return BustaPaga(
      id: id ?? this.id,
      periodo: periodo ?? this.periodo,
      fileOrigine: fileOrigine ?? this.fileOrigine,
      lordo: lordo ?? this.lordo,
      netto: netto ?? this.netto,
      trattenute: trattenute ?? this.trattenute,
      straordinari: straordinari ?? this.straordinari,
      ferieMaturate: ferieMaturate ?? this.ferieMaturate,
      ferieGodute: ferieGodute ?? this.ferieGodute,
      ferieResidue: ferieResidue ?? this.ferieResidue,
      rolMaturati: rolMaturati ?? this.rolMaturati,
      rolGoduti: rolGoduti ?? this.rolGoduti,
      rolResidui: rolResidui ?? this.rolResidui,
      permessiGoduti: permessiGoduti ?? this.permessiGoduti,
      oreLavorate: oreLavorate ?? this.oreLavorate,
      statoVerifica: statoVerifica ?? this.statoVerifica,
    );
  }
}
