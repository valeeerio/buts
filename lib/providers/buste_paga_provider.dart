import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/busta_paga.dart';
import '../models/busta_paga_mock_data.dart';

/// Stato in-memory dell'archivio buste paga. Cartella separata da lib/data/
/// (riservata alla futura persistenza Drift) per evitare ambiguità quando
/// arriverà lo strato di persistenza reale — vedi skill drift-migration.
class BustePagaNotifier extends StateNotifier<List<BustaPaga>> {
  BustePagaNotifier() : super(BustaPagaMockData.initial);

  void add(BustaPaga busta) => state = [...state, busta];

  void update(BustaPaga busta) => state = [
        for (final b in state) if (b.id == busta.id) busta else b,
      ];
}

final busteRepositoryProvider =
    StateNotifierProvider<BustePagaNotifier, List<BustaPaga>>(
  (ref) => BustePagaNotifier(),
);

/// Busta paga più recente per periodo — unico punto di lettura del netto
/// per il collegamento dati verso la sezione Budget (vedi dashboard_screen.dart).
final ultimaBustaPagaProvider = Provider<BustaPaga?>((ref) {
  final buste = ref.watch(busteRepositoryProvider);
  if (buste.isEmpty) return null;
  final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));
  return sorted.first;
});
