import 'package:buts/data/database.dart';
import 'package:buts/models/busta_paga.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copre `VoceCompetenzaListConverter` (`lib/data/database.dart`), in
/// particolare la retrocompatibilità del bug "quantità 0 su voci che non
/// hanno quantità": `VoceCompetenza.quantita` è diventato nullable (`null` =
/// assente, distinto da 0 stampato esplicitamente) SENZA incrementare
/// `AppDatabase.schemaVersion` — è un cambiamento di forma DENTRO la colonna
/// JSON `competenze` già esistente (schemaVersion invariato da v6), non una
/// nuova colonna: nessuna migrazione Drift necessaria, ma il converter deve
/// restare in grado di leggere sia il JSON scritto DA QUESTO fix in avanti
/// (con `"quantita":null` per una riga assente) sia quello scritto PRIMA
/// (sempre un numero reale, mai `null` — il vecchio bug scriveva
/// letteralmente 0 anche per una quantità assente).
void main() {
  const converter = VoceCompetenzaListConverter();

  group('VoceCompetenzaListConverter — round trip quantita nullable', () {
    test('quantita null sopravvive al round trip toSql -> fromSql', () {
      const competenze = [
        VoceCompetenza(
          descrizione: 'Trattamento integrativo DL 3/2020',
          quantita: null,
          importo: 100.0,
        ),
      ];

      final json = converter.toSql(competenze);
      final riletto = converter.fromSql(json);

      expect(riletto, hasLength(1));
      expect(riletto.single.quantita, isNull);
      expect(riletto.single.importo, closeTo(100.0, 0.001));
    });

    test(
        'quantita 0 ESPLICITO (distinto da assente) sopravvive al round '
        'trip come 0.0, non null', () {
      const competenze = [
        VoceCompetenza(
          descrizione: 'Voce con quantità zero reale',
          quantita: 0.0,
          importo: 10.0,
        ),
      ];

      final riletto = converter.fromSql(converter.toSql(competenze));

      expect(riletto.single.quantita, isNotNull);
      expect(riletto.single.quantita, 0.0);
    });

    test(
        'toSql scrive un null JSON letterale (non una stringa "null") per '
        'una quantità assente', () {
      const competenze = [
        VoceCompetenza(descrizione: 'X', quantita: null, importo: 1.0),
      ];

      final json = converter.toSql(competenze);

      expect(json, contains('"quantita":null'));
    });

    test(
        'retrocompatibilità: JSON scritto PRIMA di questo fix (sempre un '
        'numero reale, "quantita":0, mai null) continua a leggersi come 0.0 '
        '— nessun dato esistente perso o alterato', () {
      const jsonLegacy =
          '[{"descrizione":"930 Trattamento integrativo","quantita":0,'
          '"importo":100.0}]';

      final riletto = converter.fromSql(jsonLegacy);

      expect(riletto, hasLength(1));
      expect(riletto.single.quantita, 0.0);
      expect(riletto.single.importo, closeTo(100.0, 0.001));
    });

    test(
        'stringa vuota (nessuna competenza salvata) produce una lista '
        'vuota, nessuna eccezione', () {
      expect(converter.fromSql(''), isEmpty);
    });
  });
}
