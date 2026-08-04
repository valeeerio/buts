import 'package:buts/models/busta_paga.dart';
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

    test(
        'preferisce "Mens.supplementare MM/YYYY" al mese per esteso trovato '
        'altrove nel testo (13esima/14esima)', () {
      final testo = _testoSintetico.replaceFirst(
        'MARZO 2026',
        'Mens.supplementare 12/2025 MARZO 2026',
      );
      final risultato = parser.parse(testo);

      expect(risultato.periodo, '2025-12');
    });

    test(
        'deduce il tipo 13esima dal mese di "Mens.supplementare" quando le '
        'parole esplicite mancano', () {
      final testo = _testoSintetico.replaceFirst(
        'MARZO 2026',
        'Mens.supplementare 12/2025 MARZO 2026',
      );
      final risultato = parser.parse(testo);

      expect(risultato.tipo, TipoBustaPaga.tredicesima);
      expect(
        risultato.warnings.any((w) => w.contains('dedotto dal mese')),
        isTrue,
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

    test(
        'riconosce il tipo tredicesima dalla parola esplicita nel testo '
        '(non dedotta dal mese)', () {
      final testo = _testoSintetico.replaceFirst(
        'MARZO 2026',
        'MARZO 2026 tredicesima',
      );
      final risultato = parser.parse(testo);

      expect(risultato.tipo, TipoBustaPaga.tredicesima);
      expect(
        risultato.warnings.any((w) => w.contains('dedotto dal mese')),
        isFalse,
      );
    });

    test(
        'riconosce il tipo quattordicesima dalla parola esplicita nel testo '
        '(non dedotta dal mese)', () {
      final testo = _testoSintetico.replaceFirst(
        'MARZO 2026',
        'MARZO 2026 quattordicesima',
      );
      final risultato = parser.parse(testo);

      expect(risultato.tipo, TipoBustaPaga.quattordicesima);
      expect(
        risultato.warnings.any((w) => w.contains('dedotto dal mese')),
        isFalse,
      );
    });

    test('warning "periodo non trovato" quando manca sia il mese per esteso '
        'sia "Mens.supplementare"', () {
      final testo = _testoSintetico.replaceFirst('MARZO 2026', '');
      final risultato = parser.parse(testo);

      expect(risultato.periodo, isNull);
      expect(risultato.warnings, contains('periodo non trovato'));
    });

    test('warning "lordo non trovato" quando nessuna riga di competenza '
        'è riconoscibile', () {
      final testo = _testoSintetico
          .replaceFirst('20,000 50,00000 1.000,00\n', '')
          .replaceFirst('20,000 1,00000 20,00\n', '')
          .replaceFirst('3,000 10,00000 30,00\n', '');
      final risultato = parser.parse(testo);

      expect(risultato.lordo, isNull);
      expect(
        risultato.warnings,
        contains('lordo non trovato (nessuna riga di competenza riconosciuta)'),
      );
    });

    test('warning "trattenuta INPS non trovata" quando la riga INPS manca',
        () {
      final testo = _testoSintetico.replaceFirst(
        'INPS1.050,00 5,84061,32',
        '1.050,00 5,84061,32',
      );
      final risultato = parser.parse(testo);

      expect(risultato.trattenute.containsKey('INPS'), isFalse);
      expect(risultato.warnings, contains('trattenuta INPS non trovata'));
    });

    test('warning "netto non trovato" quando manca "Firma per quietanza"',
        () {
      final testo = _testoSintetico.replaceFirst('Firma per quietanza', '');
      final risultato = parser.parse(testo);

      expect(risultato.netto, isNull);
      expect(risultato.warnings, contains('netto non trovato'));
    });

    test('calcola correttamente "Altre trattenute (IRPEF + varie)" come '
        'lordo - netto - INPS', () {
      // Nel testo sintetico invariato lordo (1050.00) - netto (988.68) -
      // INPS (61.32) fa esattamente 0, quindi la voce non viene aggiunta
      // (soglia > 0.01): qui si abbassa il netto per ottenere un residuo
      // positivo e verificarne il valore calcolato.
      final testo = _testoSintetico.replaceFirst(
        '1.050,00 61,32-988,68',
        '1.050,00 61,32-950,00',
      );
      final risultato = parser.parse(testo);

      expect(risultato.lordo, closeTo(1050.00, 0.001));
      expect(risultato.netto, closeTo(950.00, 0.001));
      expect(risultato.trattenute['INPS'], closeTo(61.32, 0.001));
      // 1050.00 - 950.00 - 61.32
      expect(
        risultato.trattenute['Altre trattenute (IRPEF + varie)'],
        closeTo(38.68, 0.001),
      );
    });

    test('somma più righe "Straordinario" invece di leggere solo la prima',
        () {
      final testo = _testoSintetico.replaceFirst(
        'Ferie godute',
        'Straordinario notturno (50%)\nORE\n2,000\nFerie godute',
      );
      final risultato = parser.parse(testo);

      // 3,000 (riga originale) + 2,000 (riga aggiunta)
      expect(risultato.straordinari, closeTo(5.00, 0.001));
    });

    test(
        'somma più righe "Retribuzione ordinaria" invece di leggere solo la '
        'prima', () {
      final testo = _testoSintetico.replaceFirst(
        'Edr contrattuale - esempio',
        'Retribuzione ordinaria\nGIORNI\n5,000\nEdr contrattuale - esempio',
      );
      final risultato = parser.parse(testo);

      // (20 + 5) giorni × 8
      expect(risultato.oreLavorate, closeTo(200, 0.001));
    });

    test('warning "netto superiore al lordo" quando il netto estratto '
        'supera il lordo', () {
      final testo = _testoSintetico.replaceFirst(
        '1.050,00 61,32-988,68',
        '1.050,00 61,32-1.500,00',
      );
      final risultato = parser.parse(testo);

      expect(risultato.lordo, closeTo(1050.00, 0.001));
      expect(risultato.netto, closeTo(1500.00, 0.001));
      expect(
        risultato.warnings,
        contains('netto superiore al lordo, verifica i dati estratti'),
      );
    });
  });
}
