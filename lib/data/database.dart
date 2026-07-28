import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models/area_type.dart';
import '../models/busta_paga.dart';

part 'database.g.dart';

/// Tipo di movimento registrato su un'area di budget.
///
/// - `versamento`: accantonamento manuale verso Risparmio Principale o
///   Piccolo Risparmio.
/// - `prelievo`: uscita da Risparmio Principale o Piccolo Risparmio verso il
///   Conto Principale. Richiede sempre una nota/motivo (vincolo di business,
///   vedi [MovimentoAreaTable.nota] e `AreeBudgetRepository.aggiungiMovimento`).
/// - `spesa`: uscita di spesa quotidiana dal Conto Principale.
/// - `assegnazioneMensile`: quota assegnata a un'area in sede di suddivisione
///   manuale del netto mensile (vedi [MeseBudgetTable]).
enum TipoMovimentoArea { versamento, prelievo, spesa, assegnazioneMensile }

/// Cadenza di una voce ricorrente (abbonamento/costo fisso) dell'area
/// Impegni Fissi.
enum FrequenzaVoceRicorrente { mensile, annuale, altro }

/// Serializza/deserializza la mappa `trattenute` (nome trattenuta -> importo)
/// come JSON in una singola colonna testo.
///
/// Scelta architetturale: la mappa `trattenute` di una busta paga è un
/// dettaglio informativo a bassa cardinalità (poche voci per riga, es. INPS/
/// IRPEF/Addizionali), non interrogata singolarmente altrove nell'app (non
/// servono query tipo "somma di IRPEF nel tempo" in v1 — le statistiche
/// previste in piano_progetto_finanze_personali.md §3.5/§5 sono su
/// netto/lordo/ferie/ROL/permessi/ore, non sulle singole trattenute). Una
/// tabella figlia normalizzata (`TrattenutaBustaPaga(bustaPagaId, nome,
/// importo)`) sarebbe più "corretta" relazionalmente ma aggiungerebbe join e
/// gestione transazionale per un beneficio che oggi non serve. Il piano di
/// progetto stesso descrive il campo come `trattenute (json)` (§5). Se in
/// futuro servissero query/aggregazioni sulle singole trattenute, migrare a
/// tabella figlia con una migrazione dedicata.
class TrattenuteConverter extends TypeConverter<Map<String, double>, String> {
  const TrattenuteConverter();

  @override
  Map<String, double> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const {};
    final decoded = jsonDecode(fromDb) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  @override
  String toSql(Map<String, double> value) => jsonEncode(value);
}

/// Tabella Drift per l'archivio Buste Paga (modulo separato dalle 4 aree di
/// budget, vedi CLAUDE.md). Colonne allineate 1:1 al modello di dominio
/// `BustaPaga` (lib/models/busta_paga.dart) e al modello dati di
/// piano_progetto_finanze_personali.md §5.
class BustePagaTable extends Table {
  /// id applicativo (stringa) generato lato Dart, non autoincrement: mantiene
  /// coerenza con gli id già usati dal modello di dominio/mock esistenti
  /// (es. 'bp-2026-05') e semplifica il mapping da/verso `BustaPaga`.
  TextColumn get id => text()();
  DateTimeColumn get periodo => dateTime()();
  TextColumn get fileOrigine => text().nullable()();
  RealColumn get lordo => real()();
  RealColumn get netto => real()();

  /// Mappa nome trattenuta -> importo, serializzata come JSON. Vedi
  /// [TrattenuteConverter] per la motivazione della scelta.
  TextColumn get trattenute =>
      text().map(const TrattenuteConverter()).withDefault(const Constant('{}'))();

  RealColumn get straordinari => real()();
  RealColumn get ferieMaturate => real()();
  RealColumn get ferieGodute => real()();
  RealColumn get ferieResidue => real()();
  RealColumn get rolMaturati => real()();
  RealColumn get rolGoduti => real()();
  RealColumn get rolResidui => real()();
  RealColumn get permessiGoduti => real()();
  RealColumn get oreLavorate => real()();

  /// Stato di verifica (v1: sempre `confermato`, inserimento manuale; il
  /// valore `daConfermare` è predisposto per la Fase 3 AI on-device — vedi
  /// StatoVerificaBustaPaga).
  IntColumn get statoVerifica =>
      intEnum<StatoVerificaBustaPaga>().withDefault(
        Constant(StatoVerificaBustaPaga.confermato.index),
      )();

  @override
  Set<Column> get primaryKey => {id};
}

/// Le 4 aree di budget fisse dell'app (vedi CLAUDE.md e [AreaType]). Il
/// `tipo` è la chiave concettuale stabile (una riga per valore di
/// [AreaType]); `nome` è invece modificabile dall'utente in futuro senza
/// alterare il comportamento dell'area, che resta legato a `tipo`.
class AreaTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text()();

  /// Mappa 1:1 su [AreaType]. Una sola riga per valore atteso (seed al primo
  /// avvio, vedi `AreeBudgetRepository`), applicativamente univoca anche se
  /// non è imposto un vincolo UNIQUE esplicito qui: aggiungerlo forzerebbe a
  /// gestire conflitti di seed idempotente lato SQL invece che lato
  /// repository, dove il controllo "seed solo se la tabella è vuota" è già
  /// sufficiente e più semplice da leggere.
  IntColumn get tipo => intEnum<AreaType>()();
}

/// Movimento su un'area di budget: versamento/prelievo verso i risparmi,
/// spesa dal Conto Principale, o assegnazione mensile in sede di
/// suddivisione del netto (vedi [MeseBudgetTable]).
///
/// Vincolo di business (non solo di UI): un [TipoMovimentoArea.prelievo] da
/// Risparmio Principale o Piccolo Risparmio richiede sempre una nota/motivo
/// non vuota (CLAUDE.md, sezione "Le 4 aree di budget"). Drift non permette
/// un CHECK SQL condizionale pulito che dipenda dal `tipo` di un'altra
/// tabella (l'`AreaType` associato va risolto via join su [AreaTable]), per
/// cui la colonna resta `nullable()` a livello di schema e il vincolo è
/// applicato imperativamente in `AreeBudgetRepository.aggiungiMovimento`
/// (unico punto di scrittura usato dai provider), non lasciato alla sola UI.
class MovimentoAreaTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get areaId => integer().references(AreaTable, #id)();
  RealColumn get importo => real()();
  DateTimeColumn get data => dateTime()();
  IntColumn get tipo => intEnum<TipoMovimentoArea>()();

  /// Obbligatoria solo per i prelievi dai risparmi: vedi commento di classe.
  TextColumn get nota => text().nullable()();
}

/// Voce ricorrente (abbonamento o costo fisso, unificati) dell'area Impegni
/// Fissi. Il totale mensile dell'area NON va mai persistito: è sempre la
/// somma delle voci con `attivo = true`, calcolata a runtime (vedi
/// `AreeBudgetRepository.totaleImpegniFissi`) per evitare disallineamenti
/// col reale stato delle voci (CLAUDE.md, sezione "Impegni Fissi").
class VoceRicorrenteTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK verso l'area Impegni Fissi. Concettualmente è sempre la stessa area,
  /// ma il FK è mantenuto per coerenza relazionale (e per non escludere,
  /// senza una decisione esplicita, che in futuro possano esistere più
  /// aree/varianti).
  IntColumn get areaId => integer().references(AreaTable, #id)();
  TextColumn get nome => text()();
  RealColumn get importo => real()();
  IntColumn get frequenza => intEnum<FrequenzaVoceRicorrente>()();
  DateTimeColumn get prossimaScadenza => dateTime()();
  BoolColumn get attivo => boolean().withDefault(const Constant(true))();
}

/// Un mese/periodo di budget con la suddivisione manuale del netto tra le
/// aree. `totaleImpegniFissi` e `importoContoPrincipale` NON sono colonne:
/// sono sempre calcolabili (il primo come somma delle voci ricorrenti
/// attive, il secondo per sottrazione) e vanno letti tramite
/// `AreeBudgetRepository`/`MesiBudgetNotifier`, mai persistiti, per lo
/// stesso motivo di [VoceRicorrenteTable] (evitare disallineamento).
class MeseBudgetTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Convenzione: primo giorno del mese (es. 2026-07-01).
  DateTimeColumn get mese => dateTime()();
  RealColumn get nettoRicevuto => real().withDefault(const Constant(0))();
  RealColumn get importoRisparmioPrincipale =>
      real().withDefault(const Constant(0))();
  RealColumn get importoPiccoloRisparmio =>
      real().withDefault(const Constant(0))();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'buts.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // Assicura il binding nativo sqlite3 corretto anche su iOS/Android
        // via sqlite3_flutter_libs (necessario per NativeDatabase).
        applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      },
    );
  });
}

@DriftDatabase(tables: [
  BustePagaTable,
  AreaTable,
  MovimentoAreaTable,
  VoceRicorrenteTable,
  MeseBudgetTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Costruttore per i test, che permette di iniettare una connessione
  /// in-memory (es. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 -> v2: introduzione delle 4 aree di budget (Area,
          // MovimentoArea, VoceRicorrente, MeseBudget). Chi arriva da uno
          // schema v1 ha già `BustePagaTable`, che resta invariata: qui
          // creiamo solo le tabelle nuove, mai un reset distruttivo del DB.
          if (from < 2) {
            await m.createTable(areaTable);
            await m.createTable(movimentoAreaTable);
            await m.createTable(voceRicorrenteTable);
            await m.createTable(meseBudgetTable);
          }
        },
      );
}

/// Mapping tra la riga Drift generata (`BustePagaTableData`) e il modello di
/// dominio `BustaPaga` usato dal resto dell'app (UI, provider). Mantiene la
/// classe generata da Drift come dettaglio di questo layer di persistenza.
extension BustaPagaRowMapping on BustePagaTableData {
  BustaPaga toDomain() {
    return BustaPaga(
      id: id,
      periodo: periodo,
      fileOrigine: fileOrigine,
      lordo: lordo,
      netto: netto,
      trattenute: trattenute,
      straordinari: straordinari,
      ferieMaturate: ferieMaturate,
      ferieGodute: ferieGodute,
      ferieResidue: ferieResidue,
      rolMaturati: rolMaturati,
      rolGoduti: rolGoduti,
      rolResidui: rolResidui,
      permessiGoduti: permessiGoduti,
      oreLavorate: oreLavorate,
      statoVerifica: statoVerifica,
    );
  }
}

extension BustaPagaDomainMapping on BustaPaga {
  BustePagaTableCompanion toCompanion() {
    return BustePagaTableCompanion.insert(
      id: id,
      periodo: periodo,
      fileOrigine: Value(fileOrigine),
      lordo: lordo,
      netto: netto,
      trattenute: Value(trattenute),
      straordinari: straordinari,
      ferieMaturate: ferieMaturate,
      ferieGodute: ferieGodute,
      ferieResidue: ferieResidue,
      rolMaturati: rolMaturati,
      rolGoduti: rolGoduti,
      rolResidui: rolResidui,
      permessiGoduti: permessiGoduti,
      oreLavorate: oreLavorate,
      statoVerifica: Value(statoVerifica),
    );
  }
}
