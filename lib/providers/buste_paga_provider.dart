import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/busta_paga.dart';
import '../models/busta_paga_mock_data.dart';

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

    if (righe.isEmpty) {
      // Seed una tantum dei dati mock, solo se l'archivio è vuoto (es. primo
      // avvio in sviluppo). Se l'utente ha già svuotato l'archivio
      // volontariamente in passato, questo controllo si basa unicamente su
      // "tabella vuota adesso", quindi il seed potrebbe ripresentarsi in quel
      // caso: accettabile in v1 pre-release, dato che non esiste ancora un
      // flusso utente di cancellazione totale dell'archivio.
      for (final busta in BustaPagaMockData.initial) {
        await _db.into(_db.bustePagaTable).insert(busta.toCompanion());
      }
      final seedate = await _db.select(_db.bustePagaTable).get();
      state = seedate.map((r) => r.toDomain()).toList();
      return;
    }

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
