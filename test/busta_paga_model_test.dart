import 'package:buts/models/busta_paga.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeLordo', () {
    test('somma gli importi di tutte le voci', () {
      const competenze = [
        VoceCompetenza(
            descrizione: 'Retribuzione ordinaria',
            quantita: 20.0,
            importo: 1000.0),
        VoceCompetenza(
            descrizione: 'Edr contrattuale', quantita: 20.0, importo: 20.0),
        VoceCompetenza(
            descrizione: 'Straordinario diurno (30%)',
            quantita: 3.0,
            importo: 30.0),
      ];

      expect(computeLordo(competenze), closeTo(1050.0, 0.001));
    });

    test('ignora correttamente le voci con importo 0 (es. righe senza '
        'importo associato)', () {
      const competenze = [
        VoceCompetenza(
            descrizione: 'Permessi riduz. orario goduti',
            quantita: 4.030,
            importo: 0),
        VoceCompetenza(
            descrizione: 'Retribuzione ordinaria',
            quantita: 20.0,
            importo: 1000.0),
      ];

      expect(computeLordo(competenze), closeTo(1000.0, 0.001));
    });

    test('lista vuota produce 0', () {
      expect(computeLordo(const []), 0);
    });
  });

  group('computeStraordinari', () {
    test('somma le quantità delle sole voci "straordinario"', () {
      const competenze = [
        VoceCompetenza(
            descrizione: 'Retribuzione ordinaria',
            quantita: 20.0,
            importo: 1000.0),
        VoceCompetenza(
            descrizione: 'Straordinario diurno (30%)',
            quantita: 3.0,
            importo: 30.0),
        VoceCompetenza(
            descrizione: 'Straordinario notturno (50%)',
            quantita: 2.0,
            importo: 20.0),
      ];

      expect(computeStraordinari(competenze), closeTo(5.0, 0.001));
    });

    test('è case-insensitive sul prefisso "straordinario"', () {
      const competenze = [
        VoceCompetenza(
            descrizione: 'STRAORDINARIO FESTIVO',
            quantita: 4.0,
            importo: 40.0),
      ];

      expect(computeStraordinari(competenze), closeTo(4.0, 0.001));
    });

    test('lista vuota produce 0', () {
      expect(computeStraordinari(const []), 0);
    });
  });
}
