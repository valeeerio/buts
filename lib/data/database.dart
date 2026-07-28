import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models/busta_paga.dart';

part 'database.g.dart';

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

@DriftDatabase(tables: [BustePagaTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Costruttore per i test, che permette di iniettare una connessione
  /// in-memory (es. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Nessuna migrazione ancora necessaria: schemaVersion è alla prima
          // versione. Le migrazioni future vanno aggiunte qui in modo
          // esplicito ed incrementale (mai reset distruttivo del DB).
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
