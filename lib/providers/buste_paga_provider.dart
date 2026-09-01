import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../models/busta_paga.dart';
import '../services/pdf_import_service.dart';
import '../services/pdf_path_resolver.dart';

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
  BustePagaNotifier(this._db, this._pdfImportService) : super(const []) {
    _initialize();
  }

  final AppDatabase _db;
  final PdfImportService _pdfImportService;

  /// Id rimossi con [remove] mentre la SELECT iniziale di [_initialize] è
  /// (potenzialmente) ancora in volo — vedi doc su [_initialize] per il
  /// perché serve, oltre al guard "già presente in `state`" che copre solo
  /// le scritture ottimistiche di add/update. Un id qui non viene mai più
  /// rimosso a valle di un `remove` riuscito: la piccola crescita nel tempo
  /// (al massimo una entry per ogni eliminazione fatta in tutta la sessione
  /// app, un'app personale con poche decine di buste paga) è trascurabile,
  /// e gli id sono generati da timestamp (`bp-<millisecondsSinceEpoch>`, vedi
  /// `BustaPagaFormScreen._save`), quindi mai riusati da una busta paga
  /// futura.
  final Set<String> _idsRimossi = {};

  /// Legge tutte le buste paga dal DB e le fonde nello stato in memoria.
  ///
  /// Guard contro DUE race condition possibili nella finestra fra l'avvio di
  /// questa SELECT (invocata dal costruttore) e la sua risoluzione:
  /// 1. scritture ottimistiche già avvenute (`add`/`update`): non si
  ///    sovrascrive lo stato con lo snapshot iniziale, si fonde — le righe
  ///    già presenti in `state` restano quelle in memoria, si aggiungono
  ///    solo le righe dal DB non ancora rappresentate in `state`;
  /// 2. un'eliminazione (`remove`) avviata nella stessa finestra: senza il
  ///    controllo su [_idsRimossi], la riga cancellata rientrerebbe in
  ///    `state` da qui (il guard del punto 1 guarda solo gli id GIÀ presenti
  ///    in `state` in quel momento, che per una busta paga appena eliminata
  ///    può benissimo essere vuoto) — bug reale corretto qui, non
  ///    un'ipotesi: [remove] registra l'id in [_idsRimossi] in modo
  ///    sincrono, prima di qualunque `await`, quindi è già visibile qui
  ///    indipendentemente dall'ordine esatto in cui le due operazioni
  ///    asincrone vengono effettivamente eseguite dal database.
  Future<void> _initialize() async {
    final daDb = await _leggiRigheResilienti();
    final idGiaInStato = state.map((b) => b.id).toSet();
    final mancantiDaDb = daDb.where(
      (b) => !idGiaInStato.contains(b.id) && !_idsRimossi.contains(b.id),
    );
    state = [...state, ...mancantiDaDb];
    // Fire-and-forget, e SOLO dopo che lo stato è già stato riconciliato col
    // DB qui sopra (`state` a questo punto contiene già tutte le righe
    // esistenti, non è più uno stato "in caricamento"): pulizia best-effort,
    // non deve mai ritardare né bloccare l'inizializzazione dell'archivio
    // (vedi doc di [_sweepPdfOrfani]).
    _sweepPdfOrfani();
  }

  /// Legge dal DB tutte le buste paga, riga per riga, in modo resiliente a
  /// righe singolarmente corrotte.
  ///
  /// `_db.select(_db.bustePagaTable).get()` non basta: i converter JSON
  /// (`TrattenuteConverter`/`VoceCompetenzaListConverter` in
  /// `lib/data/database.dart`) vengono invocati da Drift internamente,
  /// dentro la stessa `.map().toList()` sincrona che costruisce l'intera
  /// lista di righe — se anche una sola riga ha JSON malformato in
  /// `trattenute`/`competenze`, l'intera `Future` di `.get()` fallisce prima
  /// di restituire qualunque riga, non solo quella incriminata. Per isolare
  /// il fallimento riga per riga si legge prima il solo elenco di id (colonna
  /// di solo testo, non passa per nessun converter JSON, non può fallire per
  /// questo motivo), poi si rilegge — e converte in `BustaPaga` — ogni riga
  /// singolarmente, scartando con un log solo quelle che falliscono: un
  /// singolo record corrotto non deve mai rendere invisibile tutto il resto
  /// dell'archivio.
  Future<List<BustaPaga>> _leggiRigheResilienti() async {
    final idRows = await (_db.selectOnly(_db.bustePagaTable)
          ..addColumns([_db.bustePagaTable.id]))
        .get();
    final ids = idRows.map((r) => r.read(_db.bustePagaTable.id)!).toList();

    final daDb = <BustaPaga>[];
    for (final id in ids) {
      try {
        final riga = await (_db.select(_db.bustePagaTable)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        daDb.add(riga.toDomain());
      } catch (e) {
        // Riga corrotta (es. JSON malformato in `trattenute`/`competenze`):
        // scartata singolarmente, non deve far fallire il caricamento
        // dell'intero archivio.
        debugPrint('Busta paga (id=$id) scartata perché corrotta: $e');
      }
    }
    return daDb;
  }

  /// Elimina dalla cartella `buste_paga_pdf/` i PDF non referenziati da
  /// nessuna busta paga in archivio: orfani lasciati da import interrotti a
  /// metà in sessioni precedenti a questo fix (PDF copiato su disco da
  /// `PdfImportService.pickAndImport()` prima ancora del parsing/della
  /// conferma dell'utente — vedi CLAUDE.md/istruzioni task) — oggi ogni
  /// percorso d'uscita che non porta a un salvataggio ripulisce già il
  /// proprio file (`buste_paga_section_screen.dart`, `PopScope` di
  /// `busta_paga_form_screen.dart`), ma questa spazzata resta la rete di
  /// sicurezza per gli orfani già presenti prima del fix e per qualunque
  /// caso limite non coperto (es. l'app terminata a metà di un import).
  ///
  /// Non riceve più `state` come parametro per valore: con 84 file orfani
  /// legacy da spazzare (caso reale) il loop di cancellazione può restare in
  /// volo a lungo, e nel frattempo un `add()`/`update()` può completare e
  /// referenziare un file che non lo era quando il loop è partito — uno
  /// snapshot calcolato una sola volta prima del loop non lo vedrebbe mai
  /// (bug reale corretto qui, non un'ipotesi: avrebbe cancellato il PDF di
  /// una busta paga appena salvata, lasciandola con un `fileOrigine`
  /// puntato a un file inesistente). Qui invece si legge [state] (il
  /// getter di `StateNotifier`, sempre il valore corrente) subito PRIMA di
  /// cancellare ogni singolo file, non una volta sola per l'intero loop.
  ///
  /// Guard aggiuntivo: se [state] è vuoto non fa nulla. Un archivio vuoto è
  /// indistinguibile, da qui, fra "l'utente non ha ancora nessuna busta
  /// paga" e "lo stato non è ancora stato caricato dal DB" — in entrambi i
  /// casi è più sicuro non toccare la cartella piuttosto che rischiare di
  /// cancellare PDF ancora referenziati da righe non ancora arrivate in
  /// `state`. In pratica questo metodo è comunque invocato solo a valle
  /// della riconciliazione col DB in [_initialize] (mai prima), quindi lo
  /// stato è già popolato in ogni percorso reale: il guard resta comunque
  /// come rete di sicurezza esplicita, non deve mai poter cancellare tutto
  /// per un ordine di chiamata futuro diverso da quello attuale.
  ///
  /// Stesso approccio tollerante ai fallimenti di [remove]: un singolo file
  /// non eliminabile non blocca né gli altri né l'inizializzazione
  /// dell'app. Confronta sul nome file (basename), non sul path intero, per
  /// restare valido sia con i path relativi correnti sia con eventuali
  /// vecchi path assoluti salvati prima del fix di
  /// `pdf_path_resolver.dart` (prefisso container sandbox iOS, invalidato a
  /// ogni reinstallazione ma con lo stesso basename).
  Future<void> _sweepPdfOrfani() async {
    try {
      if (state.isEmpty) return;

      final documentsDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory(p.join(documentsDir.path, pdfBusteDirName));
      if (!await pdfDir.exists()) return;

      final entries = await pdfDir.list().toList();
      for (final entry in entries) {
        if (entry is! File) continue;
        final nomeFile = p.basename(entry.path);
        // Ri-verificato sullo stato CORRENTE ad ogni iterazione, non su uno
        // snapshot preso prima del loop: vedi doc del metodo.
        final referenziatoOra = state.any((b) {
          final fileOrigine = b.fileOrigine;
          return fileOrigine != null && p.basename(fileOrigine) == nomeFile;
        });
        if (referenziatoOra) continue;
        try {
          await entry.delete();
        } catch (_) {
          // Best-effort: un singolo file non eliminabile non blocca gli
          // altri.
        }
      }
    } catch (_) {
      // Best-effort: nessun errore da propagare, non deve mai bloccare
      // l'inizializzazione dell'app.
    }
  }

  Future<void> add(BustaPaga busta) async {
    final precedente = state;
    final giaPresente = state.any((b) => b.id == busta.id);
    state = giaPresente
        ? [
            for (final b in state)
              if (b.id == busta.id) busta else b,
          ]
        : [...state, busta];
    try {
      await _db
          .into(_db.bustePagaTable)
          .insertOnConflictUpdate(busta.toCompanion());
    } catch (e) {
      state = precedente;
      rethrow;
    }
  }

  Future<void> update(BustaPaga busta) async {
    final precedente = state;
    state = [
      for (final b in state)
        if (b.id == busta.id) busta else b,
    ];
    try {
      await _db
          .into(_db.bustePagaTable)
          .insertOnConflictUpdate(busta.toCompanion());
    } catch (e) {
      state = precedente;
      rethrow;
    }
  }

  /// Elimina una singola busta paga per id (swipe-to-delete dall'Archivio,
  /// con conferma già ottenuta dalla UI prima della chiamata). Elimina anche
  /// il PDF associato su disco (`fileOrigine`), best-effort — non deve mai
  /// bloccare l'eliminazione della riga se il file è già assente.
  Future<void> remove(String id) async {
    // Registrato SUBITO, prima di qualunque `await`: vedi doc su
    // [_idsRimossi]/[_initialize] per la race condition che previene. In
    // caso di fallimento della DELETE viene rimosso di nuovo più sotto (la
    // riga non è mai stata davvero eliminata dal DB, va trattata come se
    // questo `remove` non fosse mai stato chiamato).
    _idsRimossi.add(id);
    final precedente = state;
    BustaPaga? rimossa;
    for (final b in precedente) {
      if (b.id == id) {
        rimossa = b;
        break;
      }
    }
    state = precedente.where((b) => b.id != id).toList();
    try {
      await (_db.delete(_db.bustePagaTable)..where((t) => t.id.equals(id)))
          .go();
    } catch (e) {
      state = precedente;
      _idsRimossi.remove(id);
      rethrow;
    }
    final fileOrigine = rimossa?.fileOrigine;
    if (fileOrigine != null && fileOrigine.isNotEmpty) {
      await _pdfImportService.deleteFile(fileOrigine);
    }
  }
}

final busteRepositoryProvider =
    StateNotifierProvider<BustePagaNotifier, List<BustaPaga>>(
  (ref) => BustePagaNotifier(
    ref.watch(databaseProvider),
    const PdfImportService(),
  ),
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
/// rispetto al trend mensile, li distorcerebbero). Usato dalla schermata
/// Statistiche (`buste_paga_statistiche_screen.dart`) per filtrare i dati
/// effettivamente graficati/mediati — NON dallo slider di periodo, che usa
/// invece il predicato più permissivo [_bustaInclusaInRangePeriodo] così da
/// poter coprire anche buste "Da confermare" più recenti.
bool bustaInclusaInStatistiche(BustaPaga b) =>
    b.statoVerifica == StatoVerificaBustaPaga.confermato &&
    b.tipo == TipoBustaPaga.mensile;

/// Predicato più permissivo di [bustaInclusaInStatistiche], usato solo per
/// calcolare gli estremi dello slider di periodo: stesso criterio "tipo
/// mensile" ma senza escludere le buste "Da confermare", così una busta
/// paga più recente ma non ancora confermata estende comunque l'estremo
/// massimo dello slider, anche se poi non entra nei grafici/medie di
/// Statistiche (quelli continuano a filtrare con [bustaInclusaInStatistiche]).
bool _bustaInclusaInRangePeriodo(BustaPaga b) =>
    b.tipo == TipoBustaPaga.mensile;

/// Intervallo di periodi coperto dalle buste paga mensili (confermate o
/// meno, vedi [_bustaInclusaInRangePeriodo]), usato come estremi min/max del
/// selettore di periodo in Statistiche (`PeriodYearMonthPicker`). `null` se
/// nessuna busta paga soddisfa il predicato.
final periodoRangeDisponibileProvider =
    Provider<({DateTime start, DateTime end})?>((ref) {
  final buste =
      ref.watch(busteRepositoryProvider).where(_bustaInclusaInRangePeriodo);
  if (buste.isEmpty) return null;
  final periodi = buste.map((b) => b.periodo).toList()..sort();
  return (start: periodi.first, end: periodi.last);
});
