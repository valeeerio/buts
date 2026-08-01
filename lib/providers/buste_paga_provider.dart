import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/busta_paga.dart';

/// Istanza applicativa del database Drift. `keepAlive: true` perché il
/// database vive per tutta la sessione app (non va ricreato/chiuso tra un
/// rebuild e l'altro dei widget che lo osservano).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Archivio buste paga persistito su Drift (SQLite), esposto alla UI come
/// `List<BustaPaga>` sincrono.
///
/// Pattern scelto: `StateNotifier<List<BustaPaga>>` che si inizializza
/// leggendo tutte le righe dal DB in modo asincrono (`_loadFromDb`), poi ogni
/// scrittura (`add`/`update`) aggiorna prima lo stato locale in memoria
/// (percepito come sincrono dalla UI esistente, che non deve cambiare) e in
/// parallelo persiste su Drift. Alternativa scartata: `StreamProvider` con
/// `select(bustePagaTable).watch()` — più "drift-idiomatico" e reattivo per
/// query dirette, ma avrebbe richiesto cambiare la firma pubblica di
/// `busteRepositoryProvider` da `StateNotifierProvider<..., List<BustaPaga>>`
/// a uno `StreamProvider<List<BustaPaga>>`, rompendo il contratto con la UI
/// esistente (`ref.watch(busteRepositoryProvider)` sincrono,
/// `.notifier.add/update`) che il task richiede esplicitamente di non
/// toccare.
class BustePagaNotifier extends StateNotifier<List<BustaPaga>> {
  BustePagaNotifier(this._db) : super(const []) {
    _initialize();
  }

  final AppDatabase _db;

  Future<void> _initialize() async {
    final righe = await _db.select(_db.bustePagaTable).get();
    state = righe.map((r) => r.toDomain()).toList();
  }

  void add(BustaPaga busta) {
    state = [...state, busta];
    _db.into(_db.bustePagaTable).insertOnConflictUpdate(busta.toCompanion());
  }

  void update(BustaPaga busta) {
    state = [
      for (final b in state) if (b.id == busta.id) busta else b,
    ];
    _db.into(_db.bustePagaTable).insertOnConflictUpdate(busta.toCompanion());
  }

  /// Elimina una singola busta paga per id (swipe-to-delete dall'Archivio,
  /// con conferma già ottenuta dalla UI prima della chiamata).
  void remove(String id) {
    state = state.where((b) => b.id != id).toList();
    (_db.delete(_db.bustePagaTable)..where((t) => t.id.equals(id))).go();
  }

  /// Solo per test manuale in sviluppo (bottone debug-only in
  /// `BustePagaStatisticheScreen`): inserisce un set di buste paga di
  /// esempio realistiche nell'archivio reale, per popolare rapidamente più
  /// mesi/anni senza dover importare PDF veri. Id prefissati `dbg-`
  /// (diversi dal formato reale `bp-<timestamp>` usato dal form), così sono
  /// identificabili e rimovibili singolarmente dal dettaglio se non servono
  /// più. Richiamabile più volte senza duplicare: `add` fa upsert per id.
  void seedDebugData() {
    for (final busta in _debugSeedEntries()) {
      add(busta);
    }
  }

  /// Rimuove solo le buste paga di test inserite da [seedDebugData] (id
  /// prefissati `dbg-`), senza toccare dati reali importati da PDF (id
  /// `bp-<timestamp>`).
  Future<void> clearDebugData() async {
    state = state.where((b) => !b.id.startsWith('dbg-')).toList();
    await (_db.delete(_db.bustePagaTable)..where((t) => t.id.like('dbg-%')))
        .go();
  }
}

List<BustaPaga> _debugSeedEntries() {
  const specifiche = <(int anno, int mese, bool confermato)>[
    (2024, 1, true), (2024, 3, true), (2024, 5, false), (2024, 7, true),
    (2024, 9, true), (2024, 11, false),
    (2025, 1, true), (2025, 3, true), (2025, 5, true), (2025, 7, false),
    (2025, 9, true), (2025, 11, true),
    (2026, 1, true), (2026, 2, true), (2026, 3, false), (2026, 4, true),
    (2026, 7, true), (2026, 8, false),
  ];
  return [
    for (final (anno, mese, confermato) in specifiche)
      _debugBusta(anno: anno, mese: mese, confermato: confermato),
  ];
}

BustaPaga _debugBusta({
  required int anno,
  required int mese,
  required bool confermato,
}) {
  final baseAnno = {2024: 2320.0, 2025: 2380.0, 2026: 2450.0}[anno]!;
  final lordo = baseAnno + (mese % 4) * 5;
  final inps = lordo * 0.10;
  final irpef = lordo * 0.16;
  final addizionali = lordo * 0.018;
  final netto = lordo - inps - irpef - addizionali;
  final ferieMaturate = mese * 8.0;
  final ferieGodute = (ferieMaturate * 0.8).roundToDouble();
  final rolMaturati = mese * 2.6;
  final rolGoduti = (rolMaturati * 0.75).roundToDouble();

  double due(double v) => double.parse(v.toStringAsFixed(2));

  return BustaPaga(
    id: 'dbg-$anno-${mese.toString().padLeft(2, '0')}',
    periodo: DateTime(anno, mese, 1),
    lordo: due(lordo),
    netto: due(netto),
    trattenute: {
      'INPS': due(inps),
      'IRPEF': due(irpef),
      'Addizionali': due(addizionali),
    },
    straordinari: due(40 + (mese % 6) * 12),
    ferieMaturate: due(ferieMaturate),
    ferieGodute: due(ferieGodute),
    ferieResidue: due(ferieMaturate - ferieGodute),
    rolMaturati: due(rolMaturati),
    rolGoduti: due(rolGoduti),
    rolResidui: due(rolMaturati - rolGoduti),
    permessiGoduti: due((mese % 8).toDouble()),
    oreLavorate: due(160 + (mese % 12)),
    statoVerifica: confermato
        ? StatoVerificaBustaPaga.confermato
        : StatoVerificaBustaPaga.daConfermare,
  );
}

final busteRepositoryProvider =
    StateNotifierProvider<BustePagaNotifier, List<BustaPaga>>(
  (ref) => BustePagaNotifier(ref.watch(databaseProvider)),
);

/// Busta paga più recente per periodo — unico punto di lettura del netto
/// dell'ultimo periodo disponibile.
final ultimaBustaPagaProvider = Provider<BustaPaga?>((ref) {
  final buste = ref.watch(busteRepositoryProvider);
  if (buste.isEmpty) return null;
  final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));
  return sorted.first;
});

/// Predicato condiviso "questa busta paga entra nelle Statistiche": solo
/// buste confermate (un dato non ancora verificato non deve influenzare
/// medie/trend) e di tipo mensile (13esima/14esima sono importi anomali
/// rispetto al trend mensile, li distorcerebbero). Usato sia da
/// [periodoRangeDisponibileProvider] sia dalla schermata Statistiche
/// (`buste_paga_statistiche_screen.dart`), così lo slider di periodo copre
/// esattamente lo stesso sottoinsieme di dati che poi i grafici mostrano.
bool bustaInclusaInStatistiche(BustaPaga b) =>
    b.statoVerifica == StatoVerificaBustaPaga.confermato &&
    b.tipo == TipoBustaPaga.mensile;

/// Intervallo di periodi coperto dalle buste paga incluse nelle Statistiche
/// (vedi [bustaInclusaInStatistiche]), usato come estremi min/max del
/// selettore di periodo in Statistiche (`CupertinoRangeSlider`). `null` se
/// nessuna busta paga soddisfa il predicato.
final periodoRangeDisponibileProvider =
    Provider<({DateTime start, DateTime end})?>((ref) {
  final buste =
      ref.watch(busteRepositoryProvider).where(bustaInclusaInStatistiche);
  if (buste.isEmpty) return null;
  final periodi = buste.map((b) => b.periodo).toList()..sort();
  return (start: periodi.first, end: periodi.last);
});
