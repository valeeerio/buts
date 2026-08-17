import 'package:buts/services/busta_paga_regex_parser.dart';
import 'package:buts/services/pdf_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copre `classificaVociDaCoordinate` (`lib/services/pdf_import_service.dart`),
/// la parte PURA (nessuna dipendenza da Syncfusion/da un PDF reale) della
/// lettura per coordinate della tabella voci/contributi/IRPEF/riga totali —
/// stesso pattern di `test/pdf_ratei_coordinate_test.dart`.
///
/// Le [ParolaVoce] usate sotto sono costruite a mano con coppie
/// (testo, coordinate): NESSUNA fixture PDF, nessun dato anagrafico. Codici
/// voce, descrizioni e le ancore X/Y riprendono cedolini reali verificati
/// manualmente (vedi ground truth della sessione di fix per le voci
/// 823/828/930 e per la riga totali), ma restano solo numeri/etichette
/// isolate — nessun nome, codice fiscale, indirizzo o dato anagrafico.
void main() {
  // Ancore X (bordo destro, salvo dove specificato) della tabella voci —
  // vedi `_xCodiceDestro`/`_xTagSinistro`/`_xQuantitaDestro`/
  // `_xTrattenuteDestro`/`_xCompetenzeDestro`/`_ancoreFlag` in
  // `pdf_import_service.dart`.
  const xCodiceDestro = 45.6;
  const xCodiceSinistro = 34.0;
  const xTagSinistro = 273.6;
  const xQuantitaDestro = 352.4;
  const xBaseDestro = 405.7; // "tariffa oraria": mai una colonna nota.
  const xTrattenuteDestro = 461.7;
  const xCompetenzeDestro = 517.6;
  const xFlagN = 559.1;

  // Ancore X della tabella contributi — vedi
  // `_xContributoDipendenteDestro` in `pdf_import_service.dart` (C/DITTA non
  // ha un'ancora dedicata nel codice: qualunque valore fuori tolleranza da
  // C/DIPENDENTE è semplicemente ignorato, 292.4 è solo il valore osservato
  // sui PDF reali per rendere la fixture realistica).
  const xContributoDipendente = 213.2;
  const xContributoDitta = 292.4;

  // Ancora X della trattenuta IRPEF — vedi `_xIrpefTrattenutaDestro`.
  const xIrpefTrattenuta = 556.1;

  // Ancore X della riga totali — vedi `_ancoreTotali`.
  const xTotCompetenze = 293.9;
  const xTotTrattenute = 358.1;
  const xTotArrPreced = 414.0;
  const xTotArrAttuale = 464.5;
  const xTotNetto = 558.5;

  ParolaVoce parola(
    String testo, {
    required double top,
    required double left,
    required double right,
  }) =>
      (
        testo: testo,
        bordoSuperiore: top,
        bordoSinistro: left,
        bordoDestro: right,
      );

  group('tabella voci — riga competenza normale (tag GIORNI)', () {
    test(
        '10 Retribuzione ordinaria: codice/descrizione/tag/quantità/importo '
        'letti correttamente, tariffa oraria (5 decimali) ignorata, flag N '
        'riconosciuto', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 300.0, left: 50.0, right: 110.0),
        parola('ordinaria', top: 300.0, left: 115.0, right: 150.0),
        parola('GIORNI', top: 300.0, left: xTagSinistro, right: 300.0),
        parola('22,000', top: 300.0, left: 335.0, right: xQuantitaDestro),
        // "Base"/tariffa oraria: 5 decimali, non è né quantità (3 decimali)
        // né importo (2 decimali) — deve restare fuori dalla descrizione.
        parola('69,65818', top: 300.0, left: 395.0, right: xBaseDestro),
        parola('1.532,48', top: 300.0, left: 480.0, right: xCompetenzeDestro),
        parola('*', top: 300.0, left: 558.0, right: xFlagN),
      ]);

      expect(risultato.righe, hasLength(1));
      final riga = risultato.righe.single;
      expect(riga.codice, '10');
      expect(riga.descrizione, 'Retribuzione ordinaria');
      expect(riga.tag, 'GIORNI');
      expect(riga.quantita, 22.0);
      expect(riga.importo, closeTo(1532.48, 0.001));
      expect(riga.colonna, ColonnaVoceCoordinate.competenze);
      expect(riga.flagN, isTrue);
    });
  });

  group(
      'tabella voci — assemblaggio descrizione: gap fra parole ADIACENTI '
      '(soglia 1.0pt, vedi _sogliaSpazioParoleDescrizione)', () {
    // Valori di gap misurati su PDF reali (bordo destro della parola
    // precedente -> bordo sinistro della successiva, stessa riga Y) — vedi
    // ground truth della sessione di fix in `pdf_import_service.dart`.
    test(
        'gap 0.1pt ("Fe"->"stivita\'"): parola spezzata da Syncfusion, unita '
        'SENZA spazio → "Festivita\'"', () {
      final risultato = classificaVociDaCoordinate([
        parola('620', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Fe', top: 300.0, left: 51.1, right: 59.1),
        parola("stivita'", top: 300.0, left: 59.2, right: 78.2),
        parola('50,00', top: 300.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, "Festivita'");
    });

    test(
        'gap 0.0pt ("Tr"->"attamento"): parola spezzata da Syncfusion, unita '
        'SENZA spazio → "Trattamento"', () {
      final risultato = classificaVociDaCoordinate([
        parola('930', top: 310.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Tr', top: 310.0, left: 51.1, right: 57.6),
        parola('attamento', top: 310.0, left: 57.6, right: 88.4),
        parola('100,00', top: 310.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'Trattamento');
    });

    test(
        'gap 1.9pt ("Retribuzione"->"ordinaria"): parole distinte, unite CON '
        'spazio → "Retribuzione ordinaria"', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 320.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 320.0, left: 50.0, right: 90.1),
        parola('ordinaria', top: 320.0, left: 92.0, right: 130.0),
        parola('1.532,48', top: 320.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'Retribuzione ordinaria');
    });

    test(
        'gap 1.8pt ("Edr"->"contrattuale"): parole distinte, unite CON '
        'spazio → "Edr contrattuale"', () {
      final risultato = classificaVociDaCoordinate([
        parola('20', top: 330.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Edr', top: 330.0, left: 50.0, right: 62.0),
        parola('contrattuale', top: 330.0, left: 63.8, right: 120.0),
        parola('20,00', top: 330.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'Edr contrattuale');
    });

    test(
        'gap 1.9pt ("Somma"->"integrativa"): parole distinte, unite CON '
        'spazio → "Somma integrativa"', () {
      final risultato = classificaVociDaCoordinate([
        parola('942', top: 340.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Somma', top: 340.0, left: 50.0, right: 75.1),
        parola('integrativa', top: 340.0, left: 77.0, right: 130.0),
        parola('42,00', top: 340.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'Somma integrativa');
    });

    test(
        'gap ESATTAMENTE alla soglia (1.0pt): non la supera → resta SENZA '
        'spazio (limite: "supera", non "raggiunge o supera")', () {
      final risultato = classificaVociDaCoordinate([
        parola('1', top: 350.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('AAA', top: 350.0, left: 50.0, right: 60.0),
        parola('BBB', top: 350.0, left: 61.0, right: 70.0),
        parola('10,00', top: 350.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'AAABBB');
    });

    test('gap appena SOPRA la soglia (1.01pt): la supera → CON spazio', () {
      final risultato = classificaVociDaCoordinate([
        parola('2', top: 360.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('CCC', top: 360.0, left: 50.0, right: 60.0),
        parola('DDD', top: 360.0, left: 61.01, right: 70.0),
        parola('10,00', top: 360.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'CCC DDD');
    });

    test(
        'stesso gap applicato alla tabella contributi (C/DIPENDENTE): '
        'parola spezzata unita SENZA spazio', () {
      final risultato = classificaVociDaCoordinate([
        parola('EBI', top: 600.0, left: 20.0, right: 40.0),
        parola('LOG', top: 600.0, left: 40.05, right: 55.0),
        parola('0,50', top: 600.0, left: 205.0, right: xContributoDipendente),
      ]);

      expect(risultato.contributiDipendente, {'EBILOG': 0.50});
    });
  });

  group('tabella voci — riga senza tag né quantità con flag N', () {
    test(
        '930 Trattamento integrativo: quantità ASSENTE (null, non 0), flag '
        'N letto', () {
      final risultato = classificaVociDaCoordinate([
        parola('930', top: 310.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Trattamento', top: 310.0, left: 50.0, right: 110.0),
        parola('integrativo', top: 310.0, left: 115.0, right: 170.0),
        parola('100,00', top: 310.0, left: 480.0, right: xCompetenzeDestro),
        parola('*', top: 310.0, left: 558.0, right: xFlagN),
      ]);

      expect(risultato.righe, hasLength(1));
      final riga = risultato.righe.single;
      expect(riga.codice, '930');
      expect(riga.descrizione, 'Trattamento integrativo');
      expect(riga.tag, isNull);
      // Bug reale corrotto in produzione (vedi diagnosi task): quantità
      // ASSENTE (nessun tag GIORNI/ORE/RATEI su questa riga) deve restare
      // `null`, distinta da "0" — mostrata "0" si legge come "zero
      // giorni/ore", fuorviante.
      expect(riga.quantita, isNull);
      expect(riga.importo, closeTo(100.00, 0.001));
      expect(riga.colonna, ColonnaVoceCoordinate.competenze);
      expect(riga.flagN, isTrue);
    });
  });

  group(
      'tabella voci — riga in colonna COMPETENZE senza alcun flag '
      '(esclusa dal lordo altrove, tramite flagN)', () {
    test('823 Addizionale Regionale Dovuta: presente ma con flagN false', () {
      final risultato = classificaVociDaCoordinate([
        parola('823', top: 320.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Addizionale', top: 320.0, left: 50.0, right: 110.0),
        parola('Regionale', top: 320.0, left: 115.0, right: 160.0),
        parola('Dovuta', top: 320.0, left: 165.0, right: 200.0),
        parola('45,00', top: 320.0, left: 480.0, right: xCompetenzeDestro),
        // Nessun token '*' in banda: nessuna colonna flag valorizzata.
      ]);

      expect(risultato.righe, hasLength(1));
      final riga = risultato.righe.single;
      expect(riga.codice, '823');
      expect(riga.descrizione, 'Addizionale Regionale Dovuta');
      expect(riga.colonna, ColonnaVoceCoordinate.competenze);
      expect(riga.flagN, isFalse);
    });
  });

  group('tabella voci — riga in colonna TRATTENUTE con flag N', () {
    test('828 Rata Addizionale Regionale: colonna trattenute, flagN true', () {
      final risultato = classificaVociDaCoordinate([
        parola('828', top: 330.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Rata', top: 330.0, left: 50.0, right: 90.0),
        parola('Addizionale', top: 330.0, left: 95.0, right: 155.0),
        parola('Regionale', top: 330.0, left: 160.0, right: 205.0),
        parola('9,39', top: 330.0, left: 450.0, right: xTrattenuteDestro),
        parola('*', top: 330.0, left: 558.0, right: xFlagN),
      ]);

      expect(risultato.righe, hasLength(1));
      final riga = risultato.righe.single;
      expect(riga.codice, '828');
      expect(riga.descrizione, 'Rata Addizionale Regionale');
      expect(riga.importo, closeTo(9.39, 0.001));
      expect(riga.colonna, ColonnaVoceCoordinate.trattenute);
      expect(riga.flagN, isTrue);
    });
  });

  group('tabella voci — righe multiple e degrado', () {
    test(
        '4 righe su Y distinti (10/930/823/828) restano distinte e '
        "nell'ordine del documento", () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 300.0, left: 50.0, right: 110.0),
        parola('1.532,48', top: 300.0, left: 480.0, right: xCompetenzeDestro),
        parola('*', top: 300.0, left: 558.0, right: xFlagN),
        parola('930', top: 310.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Trattamento', top: 310.0, left: 50.0, right: 110.0),
        parola('100,00', top: 310.0, left: 480.0, right: xCompetenzeDestro),
        parola('*', top: 310.0, left: 558.0, right: xFlagN),
        parola('823', top: 320.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Addizionale', top: 320.0, left: 50.0, right: 110.0),
        parola('45,00', top: 320.0, left: 480.0, right: xCompetenzeDestro),
        parola('828', top: 330.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Rata', top: 330.0, left: 50.0, right: 90.0),
        parola('9,39', top: 330.0, left: 450.0, right: xTrattenuteDestro),
        parola('*', top: 330.0, left: 558.0, right: xFlagN),
      ]);

      expect(risultato.righe, hasLength(4));
      expect(risultato.righe.map((r) => r.codice).toList(),
          ['10', '930', '823', '828']);
      expect(risultato.righe.map((r) => r.flagN).toList(),
          [true, true, false, true]);
    });

    test(
        'riga con codice ma senza alcun importo (es. Permessi riduz. orario '
        'goduti, gestiti altrove) → esclusa (null)', () {
      final risultato = classificaVociDaCoordinate([
        parola('210', top: 340.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Permessi', top: 340.0, left: 50.0, right: 100.0),
        parola('riduz.', top: 340.0, left: 105.0, right: 140.0),
        parola('orario', top: 340.0, left: 145.0, right: 180.0),
        parola('goduti', top: 340.0, left: 185.0, right: 220.0),
        parola('ORE', top: 340.0, left: xTagSinistro, right: 290.0),
        parola('8,000', top: 340.0, left: 335.0, right: xQuantitaDestro),
      ]);

      expect(risultato.righe, isEmpty);
    });

    test(
        'cluster senza alcun codice voce (rumore della legenda verticale '
        'nella stessa banda Y) → ignorato', () {
      final risultato = classificaVociDaCoordinate([
        parola('Imponibile', top: 350.0, left: 50.0, right: 100.0),
        parola('contributivo', top: 350.0, left: 105.0, right: 160.0),
      ]);

      expect(risultato.righe, isEmpty);
    });

    test('lista vuota → nessuna eccezione, tutto vuoto', () {
      expect(() => classificaVociDaCoordinate(const []), returnsNormally);
      final risultato = classificaVociDaCoordinate(const []);
      expect(risultato.righe, isEmpty);
      expect(risultato.contributiDipendente, isEmpty);
      expect(risultato.irpefTrattenuta, isNull);
      expect(risultato.totali, isNull);
      expect(risultato.haDatiSufficienti, isFalse);
    });

    test(
        'jitter di rendering fra parole della stessa riga (fino a qualche '
        'decimo di punto) non spezza il cluster', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 300.2, left: 50.0, right: 110.0),
        parola('ordinaria', top: 300.4, left: 115.0, right: 150.0),
        parola('1.532,48', top: 300.1, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, hasLength(1));
      expect(risultato.righe.single.descrizione, 'Retribuzione ordinaria');
    });

    test(
        'riga con Y appena sotto il minimo della banda voci (283.9 < 284.0) '
        '→ esclusa dalla tabella', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 283.9, left: xCodiceSinistro, right: xCodiceDestro),
        parola('45,00', top: 283.9, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.righe, isEmpty);
    });
  });

  group('tabella contributi — C/DIPENDENTE vs C/DITTA', () {
    test(
        'CONTRIBUTO EBILOG: vince la quota C/DIPENDENTE (0,50), C/DITTA '
        '(3,50) ignorata', () {
      final risultato = classificaVociDaCoordinate([
        parola('CONTRIBUTO', top: 600.0, left: 20.0, right: 65.0),
        parola('EBILOG', top: 600.0, left: 70.0, right: 105.0),
        parola('0,50', top: 600.0, left: 205.0, right: xContributoDipendente),
        parola('3,50', top: 600.0, left: 285.0, right: xContributoDitta),
      ]);

      expect(risultato.contributiDipendente, {'CONTRIBUTO EBILOG': 0.50});
    });

    test('due contributi diversi restano voci distinte della mappa', () {
      final risultato = classificaVociDaCoordinate([
        parola('INPS', top: 610.0, left: 20.0, right: 50.0),
        parola('88,18', top: 610.0, left: 205.0, right: xContributoDipendente),
        parola('CONTRIBUTO', top: 600.0, left: 20.0, right: 65.0),
        parola('EBILOG', top: 600.0, left: 70.0, right: 105.0),
        parola('0,50', top: 600.0, left: 205.0, right: xContributoDipendente),
        parola('3,50', top: 600.0, left: 285.0, right: xContributoDitta),
      ]);

      expect(risultato.contributiDipendente, {
        'INPS': closeTo(88.18, 0.001),
        'CONTRIBUTO EBILOG': closeTo(0.50, 0.001),
      });
    });

    test(
        'riga con solo importi, nessuna descrizione riconoscibile a '
        'sinistra → ignorata', () {
      final risultato = classificaVociDaCoordinate([
        parola('0,50', top: 620.0, left: 205.0, right: xContributoDipendente),
        parola('3,50', top: 620.0, left: 285.0, right: xContributoDitta),
      ]);

      expect(risultato.contributiDipendente, isEmpty);
    });

    test(
        'riga con descrizione ma senza alcun valore in colonna C/DIPENDENTE '
        '(solo C/DITTA) → ignorata', () {
      final risultato = classificaVociDaCoordinate([
        parola('FONDO', top: 630.0, left: 20.0, right: 55.0),
        parola('1,00', top: 630.0, left: 285.0, right: xContributoDitta),
      ]);

      expect(risultato.contributiDipendente, isEmpty);
    });
  });

  group('IRPEF trattenuta ("IRPEF + IMP. SOST.")', () {
    test('unico valore nella banda/colonna attesa → letto', () {
      final risultato = classificaVociDaCoordinate([
        parola('220,00', top: 700.0, left: 520.0, right: xIrpefTrattenuta),
      ]);

      expect(risultato.irpefTrattenuta, closeTo(220.00, 0.001));
    });

    test('nessun valore nella banda attesa → null', () {
      final risultato = classificaVociDaCoordinate([
        parola('220,00', top: 500.0, left: 520.0, right: xIrpefTrattenuta),
      ]);

      expect(risultato.irpefTrattenuta, isNull);
    });

    test(
        'lo stesso valore ripetuto due volte (jitter) non è ambiguità: '
        'resta un unico valore', () {
      final risultato = classificaVociDaCoordinate([
        parola('220,00', top: 700.0, left: 520.0, right: xIrpefTrattenuta),
        parola('220,00', top: 736.0, left: 520.0, right: xIrpefTrattenuta),
      ]);

      expect(risultato.irpefTrattenuta, closeTo(220.00, 0.001));
    });

    test(
        'due valori DIVERSI nella banda/colonna attesa → ambiguo, null '
        'invece di sceglierne uno a caso', () {
      final risultato = classificaVociDaCoordinate([
        parola('220,00', top: 700.0, left: 520.0, right: xIrpefTrattenuta),
        parola('200,00', top: 736.0, left: 520.0, right: xIrpefTrattenuta),
      ]);

      expect(risultato.irpefTrattenuta, isNull);
    });
  });

  group('riga totali', () {
    test(
        'valori positivi (08/2025), ARR. PRECED. assente quel mese → '
        'default 0 (non un errore)', () {
      final risultato = classificaVociDaCoordinate([
        parola('1.678,31', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('253,45', top: 796.3, left: 325.0, right: xTotTrattenute),
        parola('0,14', top: 796.3, left: 445.0, right: xTotArrAttuale),
        parola('1.425,00', top: 796.3, left: 525.0, right: xTotNetto),
      ]);

      final totali = risultato.totali;
      expect(totali, isNotNull);
      expect(totali!.totaleCompetenze, closeTo(1678.31, 0.001));
      expect(totali.totaleTrattenute, closeTo(253.45, 0.001));
      expect(totali.arrPreced, 0.0);
      expect(totali.arrAttuale, closeTo(0.14, 0.001));
      expect(totali.nettoInBusta, closeTo(1425.00, 0.001));
      expect(
        totali.totaleCompetenze -
            totali.totaleTrattenute -
            totali.arrPreced +
            totali.arrAttuale,
        closeTo(totali.nettoInBusta, 0.01),
      );
    });

    test(
        'segno "-" in coda su ARR. ATTUALE ("0,03-", 07/2026) → valore '
        'negativo', () {
      final risultato = classificaVociDaCoordinate([
        parola('1.543,13', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('131,84', top: 796.3, left: 325.0, right: xTotTrattenute),
        parola('0,26', top: 796.3, left: 395.0, right: xTotArrPreced),
        parola('0,03-', top: 796.3, left: 445.0, right: xTotArrAttuale),
        parola('1.411,00', top: 796.3, left: 525.0, right: xTotNetto),
      ]);

      final totali = risultato.totali;
      expect(totali, isNotNull);
      expect(totali!.arrPreced, closeTo(0.26, 0.001));
      expect(totali.arrAttuale, closeTo(-0.03, 0.001));
      // Identità: NETTO = COMP - TRATT - ARR.PRECED + ARR.ATTUALE.
      expect(
        totali.totaleCompetenze -
            totali.totaleTrattenute -
            totali.arrPreced +
            totali.arrAttuale,
        closeTo(totali.nettoInBusta, 0.01),
      );
    });

    test(
        'segno "-" in coda su ARR. PRECED. ("0,14-", 12/2025 Suppl.) con '
        'ARR. ATTUALE positivo ("0,14") → segni non confusi nonostante la '
        'stessa cifra', () {
      final risultato = classificaVociDaCoordinate([
        parola('628,96', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('174,24', top: 796.3, left: 325.0, right: xTotTrattenute),
        parola('0,14-', top: 796.3, left: 395.0, right: xTotArrPreced),
        parola('0,14', top: 796.3, left: 445.0, right: xTotArrAttuale),
        parola('455,00', top: 796.3, left: 525.0, right: xTotNetto),
      ]);

      final totali = risultato.totali;
      expect(totali, isNotNull);
      expect(totali!.arrPreced, closeTo(-0.14, 0.001));
      expect(totali.arrAttuale, closeTo(0.14, 0.001));
      expect(
        totali.totaleCompetenze -
            totali.totaleTrattenute -
            totali.arrPreced +
            totali.arrAttuale,
        closeTo(totali.nettoInBusta, 0.01),
      );
    });

    test('colonna obbligatoria mancante (NETTO assente) → totali null', () {
      final risultato = classificaVociDaCoordinate([
        parola('1.678,31', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('253,45', top: 796.3, left: 325.0, right: xTotTrattenute),
      ]);

      expect(risultato.totali, isNull);
    });

    test('Y fuori dalla banda della riga totali → ignorato, totali null', () {
      final risultato = classificaVociDaCoordinate([
        parola('1.678,31', top: 700.0, left: 260.0, right: xTotCompetenze),
        parola('253,45', top: 700.0, left: 325.0, right: xTotTrattenute),
        parola('1.425,00', top: 700.0, left: 525.0, right: xTotNetto),
      ]);

      expect(risultato.totali, isNull);
    });
  });

  group('haDatiSufficienti', () {
    test('true quando almeno una riga voce E la riga totali sono presenti', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 300.0, left: 50.0, right: 110.0),
        parola('1.532,48', top: 300.0, left: 480.0, right: xCompetenzeDestro),
        parola('1.678,31', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('253,45', top: 796.3, left: 325.0, right: xTotTrattenute),
        parola('1.425,00', top: 796.3, left: 525.0, right: xTotNetto),
      ]);

      expect(risultato.haDatiSufficienti, isTrue);
    });

    test('false quando ci sono righe voce ma manca la riga totali', () {
      final risultato = classificaVociDaCoordinate([
        parola('10', top: 300.0, left: xCodiceSinistro, right: xCodiceDestro),
        parola('Retribuzione', top: 300.0, left: 50.0, right: 110.0),
        parola('1.532,48', top: 300.0, left: 480.0, right: xCompetenzeDestro),
      ]);

      expect(risultato.haDatiSufficienti, isFalse);
    });

    test("false quando c'è la riga totali ma nessuna riga voce", () {
      final risultato = classificaVociDaCoordinate([
        parola('1.678,31', top: 796.3, left: 260.0, right: xTotCompetenze),
        parola('253,45', top: 796.3, left: 325.0, right: xTotTrattenute),
        parola('1.425,00', top: 796.3, left: 525.0, right: xTotNetto),
      ]);

      expect(risultato.haDatiSufficienti, isFalse);
    });
  });
}
