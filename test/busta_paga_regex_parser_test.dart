import 'package:buts/services/busta_paga_regex_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testo sintetico (dati fittizi) che riproduce la struttura del layout
/// "JOB" (Sistemi S.p.A.) su cui sono tarati i pattern regex — non è il
/// testo di una busta paga reale.
const _testoSintetico = '''
JOB - Copyright Sistemi S.p.A. - Autorizzazione INAIL   N°  792   del  03/01/20185MARZO 2026
MINIMOEPA -CCNL 06/12/241.000,0000010,000005,84 6,00 2,00 9,17 (GIORNI)7,00 8,00 3,00 12,00 (ORE)5,00 3,00 8,00 (ORE)9,12
Retribuzione ordinaria
GIORNI
20,000 50,00000 1.000,00
*
*
*
*
Edr contrattuale - esempio
GIORNI
20,000 1,00000 20,00
*
*
*
*
Straordinario diurno (30%)
ORE
3,000 10,00000 30,00
*
*
*
Ferie godute
GIORNI
1,000
INPS1.050,00 5,84061,32 CONTRIBUTO EBILOG0,50 3,50
Firma per quietanza
1.050,00 61,32-988,68
''';

void main() {
  group('BustaPagaRegexParser', () {
    const parser = BustaPagaRegexParser();

    test('estrae correttamente periodo, lordo, netto e trattenute', () {
      final risultato = parser.parse(_testoSintetico);

      expect(risultato.periodo, '2026-03');
      expect(risultato.lordo, closeTo(1050.00, 0.001));
      expect(risultato.netto, closeTo(988.68, 0.001));
      expect(risultato.trattenute['INPS'], closeTo(61.32, 0.001));
    });

    test('estrae ferie, ROL e permessi (goduti = ROL goduti)', () {
      final risultato = parser.parse(_testoSintetico);

      expect(risultato.ferieMaturate, closeTo(6.00, 0.001));
      expect(risultato.ferieGodute, closeTo(2.00, 0.001));
      expect(risultato.ferieResidue, closeTo(9.17, 0.001));
      expect(risultato.rolMaturati, closeTo(8.00, 0.001));
      expect(risultato.rolGoduti, closeTo(3.00, 0.001));
      expect(risultato.rolResidui, closeTo(12.00, 0.001));
      expect(risultato.permessiGoduti, risultato.rolGoduti);
    });

    test('estrae straordinari e stima ore lavorate da giorni×8', () {
      final risultato = parser.parse(_testoSintetico);

      expect(risultato.straordinari, closeTo(3.00, 0.001));
      expect(risultato.oreLavorate, closeTo(160, 0.001)); // 20 giorni × 8
      expect(
        risultato.warnings,
        contains('ore lavorate stimate da giorni×8, non lette direttamente'),
      );
    });

    test('testo vuoto o non riconosciuto produce campi nulli/zero e warning', () {
      final risultato = parser.parse('testo qualunque non riconoscibile');

      expect(risultato.periodo, isNull);
      expect(risultato.lordo, isNull);
      expect(risultato.netto, isNull);
      expect(risultato.ferieMaturate, 0);
      expect(risultato.warnings, isNotEmpty);
    });
  });
}
