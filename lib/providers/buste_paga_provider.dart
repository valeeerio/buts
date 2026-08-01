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

}

final busteRepositoryProvider =
    StateNotifierProvider<BustePagaNotifier, List<BustaPaga>>(
  (ref) => BustePagaNotifier(ref.watch(databaseProvider)),
);

/// Busta paga più recente per periodo — unico punto di lettura del netto
/// dell'ultimo periodo disponibile. Solo mensili: una 13esima/14esima più
/// recente di data non deve mai sostituire l'ultima mensile nell'hero.
final ultimaBustaPagaProvider = Provider<BustaPaga?>((ref) {
  final buste = ref
      .watch(busteRepositoryProvider)
      .where((b) => b.tipo == TipoBustaPaga.mensile);
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
