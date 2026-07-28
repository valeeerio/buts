import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/area_type.dart';
import 'buste_paga_provider.dart' show databaseProvider;

/// Eccezione di validazione lanciata da [AreeBudgetRepository] quando un
/// movimento non rispetta un vincolo di business dello schema dati (non
/// solo di UI). Vedi in particolare `aggiungiMovimento` per il vincolo
/// "nota obbligatoria sui prelievi dai risparmi".
class MovimentoAreaNonValido implements Exception {
  MovimentoAreaNonValido(this.message);

  final String message;

  @override
  String toString() => 'MovimentoAreaNonValido: $message';
}

/// Le due aree per cui un prelievo richiede sempre nota/motivo obbligatoria
/// (CLAUDE.md, sezione "Le 4 aree di budget").
const _areeConNotaObbligatoriaSuPrelievo = {
  AreaType.risparmioPrincipale,
  AreaType.piccoloRisparmio,
};

/// Repository centrale per le 4 aree di budget, usato dai provider sotto.
/// Non espone stato reattivo direttamente: legge/scrive su Drift e i
/// provider (`StateNotifier`) tengono la copia in memoria osservata dalla
/// UI, con lo stesso pattern già in uso in `buste_paga_provider.dart`.
///
/// Punto di scrittura unico per i movimenti: `aggiungiMovimento` è l'unico
/// modo previsto per inserire un [MovimentoAreaTable], così il vincolo di
/// business "nota obbligatoria sui prelievi dai risparmi" è imposto qui,
/// non lasciato alla sola UI (vedi anche il commento su
/// `MovimentoAreaTable` in `lib/data/database.dart`).
class AreeBudgetRepository {
  AreeBudgetRepository(this._db);

  final AppDatabase _db;

  /// Crea le 4 righe [AreaTable] corrispondenti ad [AreaType.values], una
  /// sola volta, se la tabella è ancora vuota. Nomi iniziali allineati a
  /// `AreaType.label` (modificabili in seguito dall'utente).
  Future<List<AreaTableData>> seedAreeSeVuoto() async {
    final esistenti = await _db.select(_db.areaTable).get();
    if (esistenti.isNotEmpty) return esistenti;

    for (final tipo in AreaType.values) {
      await _db.into(_db.areaTable).insert(
            AreaTableCompanion.insert(nome: tipo.label, tipo: tipo),
          );
    }
    return _db.select(_db.areaTable).get();
  }

  /// Inserisce un movimento validando il vincolo di business "prelievo dai
  /// risparmi => nota obbligatoria". Lancia [MovimentoAreaNonValido] se
  /// violato, così anche eventuali chiamanti diversi dalla UI (es. script,
  /// import, test) non possono aggirare la regola.
  Future<int> aggiungiMovimento({
    required int areaId,
    required double importo,
    required DateTime data,
    required TipoMovimentoArea tipo,
    String? nota,
  }) async {
    if (tipo == TipoMovimentoArea.prelievo) {
      final riga = await (_db.select(_db.areaTable)
            ..where((t) => t.id.equals(areaId)))
          .getSingleOrNull();
      final areaType = riga?.tipo;
      final notaVuota = nota == null || nota.trim().isEmpty;
      if (areaType != null &&
          _areeConNotaObbligatoriaSuPrelievo.contains(areaType) &&
          notaVuota) {
        throw MovimentoAreaNonValido(
          'Un prelievo da ${areaType.label} richiede sempre una nota/motivo.',
        );
      }
    }

    return _db.into(_db.movimentoAreaTable).insert(
          MovimentoAreaTableCompanion.insert(
            areaId: areaId,
            importo: importo,
            data: data,
            tipo: tipo,
            nota: Value(nota),
          ),
        );
  }

  Future<List<MovimentoAreaTableData>> tuttiIMovimenti() =>
      _db.select(_db.movimentoAreaTable).get();

  Future<List<VoceRicorrenteTableData>> tutteLeVociRicorrenti() =>
      _db.select(_db.voceRicorrenteTable).get();

  Future<List<MeseBudgetTableData>> tuttiIMesiBudget() =>
      _db.select(_db.meseBudgetTable).get();

  /// Somma degli importi delle voci ricorrenti attive: è il totale
  /// dell'area Impegni Fissi, sempre calcolato a runtime (mai persistito,
  /// vedi commento su [VoceRicorrenteTable]).
  static double totaleImpegniFissi(List<VoceRicorrenteTableData> voci) {
    return voci
        .where((v) => v.attivo)
        .fold(0.0, (somma, v) => somma + v.importo);
  }

  /// Importo assegnabile al Conto Principale per un dato mese, per
  /// sottrazione (mai persistito, vedi commento su [MeseBudgetTable]):
  /// `netto - impegniFissi - risparmioPrincipale - piccoloRisparmio`.
  static double importoContoPrincipale(
    MeseBudgetTableData mese,
    double totaleImpegniFissi,
  ) {
    return mese.nettoRicevuto -
        totaleImpegniFissi -
        mese.importoRisparmioPrincipale -
        mese.importoPiccoloRisparmio;
  }
}

final areeBudgetRepositoryProvider = Provider<AreeBudgetRepository>((ref) {
  return AreeBudgetRepository(ref.watch(databaseProvider));
});

/// Le 4 aree di budget, seedate al primo avvio se la tabella è vuota (vedi
/// `AreeBudgetRepository.seedAreeSeVuoto`).
class AreeNotifier extends StateNotifier<List<AreaTableData>> {
  AreeNotifier(this._repo) : super(const []) {
    _initialize();
  }

  final AreeBudgetRepository _repo;

  Future<void> _initialize() async {
    state = await _repo.seedAreeSeVuoto();
  }
}

final areeRepositoryProvider =
    StateNotifierProvider<AreeNotifier, List<AreaTableData>>(
  (ref) => AreeNotifier(ref.watch(areeBudgetRepositoryProvider)),
);

/// Movimenti (versamenti/prelievi/spese/assegnazioni) su tutte le aree.
class MovimentiAreaNotifier extends StateNotifier<List<MovimentoAreaTableData>> {
  MovimentiAreaNotifier(this._repo) : super(const []) {
    _initialize();
  }

  final AreeBudgetRepository _repo;

  Future<void> _initialize() async {
    state = await _repo.tuttiIMovimenti();
  }

  /// Aggiunge un movimento. Può lanciare [MovimentoAreaNonValido] se viola
  /// il vincolo "nota obbligatoria sui prelievi dai risparmi" — il
  /// chiamante (UI o altro) deve gestire l'eccezione.
  Future<void> aggiungi({
    required int areaId,
    required double importo,
    required DateTime data,
    required TipoMovimentoArea tipo,
    String? nota,
  }) async {
    await _repo.aggiungiMovimento(
      areaId: areaId,
      importo: importo,
      data: data,
      tipo: tipo,
      nota: nota,
    );
    state = await _repo.tuttiIMovimenti();
  }
}

final movimentiAreaRepositoryProvider = StateNotifierProvider<
    MovimentiAreaNotifier, List<MovimentoAreaTableData>>(
  (ref) => MovimentiAreaNotifier(ref.watch(areeBudgetRepositoryProvider)),
);

/// Voci ricorrenti (abbonamenti + costi fissi unificati) dell'area Impegni
/// Fissi.
class VociRicorrentiNotifier
    extends StateNotifier<List<VoceRicorrenteTableData>> {
  VociRicorrentiNotifier(this._db) : super(const []) {
    _initialize();
  }

  final AppDatabase _db;

  Future<void> _initialize() async {
    state = await _db.select(_db.voceRicorrenteTable).get();
  }

  Future<void> aggiungi({
    required int areaId,
    required String nome,
    required double importo,
    required FrequenzaVoceRicorrente frequenza,
    required DateTime prossimaScadenza,
    bool attivo = true,
  }) async {
    await _db.into(_db.voceRicorrenteTable).insert(
          VoceRicorrenteTableCompanion.insert(
            areaId: areaId,
            nome: nome,
            importo: importo,
            frequenza: frequenza,
            prossimaScadenza: prossimaScadenza,
            attivo: Value(attivo),
          ),
        );
    state = await _db.select(_db.voceRicorrenteTable).get();
  }

  Future<void> aggiorna(VoceRicorrenteTableData voce) async {
    await _db.update(_db.voceRicorrenteTable).replace(voce);
    state = await _db.select(_db.voceRicorrenteTable).get();
  }
}

final vociRicorrentiRepositoryProvider = StateNotifierProvider<
    VociRicorrentiNotifier, List<VoceRicorrenteTableData>>(
  (ref) => VociRicorrentiNotifier(ref.watch(databaseProvider)),
);

/// Totale dell'area Impegni Fissi: somma delle voci ricorrenti attive,
/// derivato (mai persistito) da [vociRicorrentiRepositoryProvider].
final totaleImpegniFissiProvider = Provider<double>((ref) {
  final voci = ref.watch(vociRicorrentiRepositoryProvider);
  return AreeBudgetRepository.totaleImpegniFissi(voci);
});

/// Mesi/periodi di budget con la suddivisione manuale del netto tra le
/// aree.
class MesiBudgetNotifier extends StateNotifier<List<MeseBudgetTableData>> {
  MesiBudgetNotifier(this._db) : super(const []) {
    _initialize();
  }

  final AppDatabase _db;

  Future<void> _initialize() async {
    state = await _db.select(_db.meseBudgetTable).get();
  }

  Future<void> aggiungi({
    required DateTime mese,
    double nettoRicevuto = 0,
    double importoRisparmioPrincipale = 0,
    double importoPiccoloRisparmio = 0,
  }) async {
    await _db.into(_db.meseBudgetTable).insert(
          MeseBudgetTableCompanion.insert(
            mese: mese,
            nettoRicevuto: Value(nettoRicevuto),
            importoRisparmioPrincipale: Value(importoRisparmioPrincipale),
            importoPiccoloRisparmio: Value(importoPiccoloRisparmio),
          ),
        );
    state = await _db.select(_db.meseBudgetTable).get();
  }

  Future<void> aggiorna(MeseBudgetTableData mese) async {
    await _db.update(_db.meseBudgetTable).replace(mese);
    state = await _db.select(_db.meseBudgetTable).get();
  }
}

final mesiBudgetRepositoryProvider =
    StateNotifierProvider<MesiBudgetNotifier, List<MeseBudgetTableData>>(
  (ref) => MesiBudgetNotifier(ref.watch(databaseProvider)),
);
