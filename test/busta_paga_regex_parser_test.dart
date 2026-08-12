import 'package:buts/models/busta_paga.dart';
import 'package:buts/services/busta_paga_regex_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testo sintetico (dati fittizi) che riproduce la struttura del layout
/// "JOB" (Sistemi S.p.A.) su cui sono tarati i pattern regex — non è il
/// testo di una busta paga reale.
/// Frammento fedele alla struttura REALE del testo estratto da
/// `syncfusion_flutter_pdf` per il layout "JOB" (verificato al Passo 0 di
/// questa sessione su un PDF reale): righe terminate da CRLF (`\r\n`, non
/// solo `\n`), descrizione/tag unità/quantità-base-importo ciascuno sulla
/// propria riga, importo seguito da uno spazio finale prima del ritorno a
/// capo. Dati anagrafici non presenti (non serve, il parser di competenze
/// non li legge), ma i VALORI NUMERICI sono quelli reali di un cedolino
/// reale (vedi criterio di accettazione lordo/straordinari nel test sotto).
const _testoCompetenzeReali = 'Retribuzione ordinaria\r\n'
    'GIORNI\r\n'
    '22,000 69,65818 1.532,48 \r\n'
    '*\r\n'
    '*\r\n'
    '*\r\n'
    '*\r\n'
    '1\r\n'
    'Edr contrattuale - ex accordo 18.5.2021\r\n'
    'GIORNI\r\n'
    '22,000 0,34864 7,67 \r\n'
    '*\r\n'
    '*\r\n'
    '*\r\n'
    '*\r\n'
    '10\r\n'
    'Straordinario diurno (30%)\r\n'
    'ORE\r\n'
    '0,250 11,91783 2,98 \r\n'
    '*\r\n'
    '*\r\n'
    '*\r\n'
    '210\r\n'
    'Permessi riduz. orario goduti\r\n'
    'ORE\r\n'
    '4,030 828\r\n'
    'Rata Addizionale Regionale\r\n'
    '20259,39 \r\n'
    '*\r\n';

const _testoSintetico = '''
JOB - Copyright Sistemi S.p.A. - Autorizzazione INAIL   N°  792   del  03/01/20185MARZO 2026
MINIMOEPA -CCNL 06/12/241.000,0000010,000005,84 6,00 2,00 9,17 (GIORNI)7,00 8,00 3,00 12,00 (ORE)8,00 3,00 5,00 (ORE)9,12
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

/// Testo REALE (non sintetico, a differenza di [_testoCompetenzeReali] e
/// [_testoSintetico]) estratto via `syncfusion_flutter_pdf`
/// (`PdfTextExtractor`, stesso ingresso di `PdfImportService`) da un
/// cedolino Luglio 2026, layout "JOB" — usato come ground-truth per il
/// test di non-regressione principale sulla fedeltà del parser ai PDF
/// reali (vedi gruppo "ground-truth" più sotto). Dati anagrafici (nome,
/// CF, indirizzo, IBAN, matricola, posizione INPS/INAIL, ragione sociale
/// e sede del datore di lavoro) sostituiti con placeholder fittizi;
/// struttura del documento e TUTTI i valori numerici (competenze, ratei,
/// trattenute, netto) sono quelli reali del cedolino.
const _testoRealeLuglio2026 = '''
POS. INPSMESE DI RETRIBUZIONE
POS. INAILVoci di tariffa
COD.DIP.
COGNOME E NOMECODICE FISCALENATO A
IL
DESCRIZIONE QUALIFICA
CONTRATTO DI LAVORO - CNEL
INDIRIZZO
ANZ. SERVIZIO
ASSUNZIONEANZ. CONV.
SCADENZA CONTR.
FINE RAPPORTOCENTRO DI COSTOSEDE DI LAVORO
ANNI
MESI
MODALITA' DI PAGAMENTORIFERIMENTI BANCARISCATTI ANZIANITA'
LIVELLO
% PART TIME
DATAPROSSIMO
N.
RATEI
MATURATI
GODUTI
RESIDUI A.P.ELEMENTI RETRIBUTIVIRESIDUI TOTALI
A.P.A.C.
FERIE
PERMESSI (R.O.L.)
EX FESTIVITA'
RETRIBUZIONE ORARIA
RETRIBUZIONE GIORNALIERA
RETRIBUZIONE MENSILE
Unita' di
C*
I*
T*
N*VOCEDESCRIZIONEQuantita'BaseTRATTENUTECOMPETENZE* = C - Imponibile contributivo ; I - Imponibile Irpef ; T - Imponibile TFR ; N - Considerato nel netto in bustamisura
DESCRIZIONE CONTRIBUTOIMPONIBILE% C/DIPC/DIPENDENTEC/DITTA: ASS.SAN-PREV.COMPL.DESCRIZIONE CONTRIBUTOIMPONIBILE% C/DIPC/DIPENDENTEC/DITTA: ASS.SAN-PREV.COMPL.
QTASETT. RETR.GG. RETR.
GG. LAV.
ORE LAV.
CTRIMPON.CONTRIBUTIVO ANNOCONTRIBUTI ANNOIMPON.CONTRIBUTIVO MESEIMPON.CONTRIB. ARROT. MESETOTALE CONTRIBUTI
IMPONIBILE FISCALE
IRPEF LORDA
DETR. LAV.DIPENDENTEGGDETR. CONIUGEDETR. FIGLIDETR. ALTRI FAMILIARIDETR. ONERIMESE
IMPOSTA SOSTITUTIVA
IRPEF NETTAIRPEF + IMP. SOST.
IMPONIBILE
IMPOSTA
IMPONIBILE FISCALE
IRPEF LORDA
DETR.LAV.DIPENDENTEGGDETR. CONIUGEDETR. FIGLIDETR. ALTRI FAMILIARIDETR.ONERI/CANONIANNO
IMPOSTA SOSTITUTIVAIRPEF NETTA
IRPEF TRATTENUTA
IRPEF CONGUAGLIO
CONG.IRPEF+IMP.SOST.
IMPONIBILE
IMPOSTA
IMPOSTA TRATTENUTA
IMPOSTA CONGUAGLIO
RETRIBUZIONE UTILE TFR
CONTR. AGG. TFRTFR MESE
TFR ANNUO PROGR.
F.DO TFR 31/12 APANTICIPAZIONI ANNOTFR SPETTANTE AZIENDATFR A F.DO PENSIONETFR
IMPONIBILE LORDO
RIDUZIONE
IMPONIBILE NETTO
%
IRPEF
IRPEF ANT. / ACC.
TOTALE DETRAZIONIAAP
IMPONIBILE ARRETRATI AP
%
IRPEF TFR / ARR. A.P.
TABELLAN.COMPON.
FIGLI MIN.
LIV.REDDITO
GIORNI
IMPORTO ASSEGNO
TOTALE COMPETENZETOTALE TRATTENUTE
ARR. PRECED.
ARR. ATTUALE
NETTO IN BUSTAANFTOT
JOB - Copyright Sistemi S.p.A. - Autorizzazione INAIL   N°  792   del  03/01/20185LUGLIO 2026
0000000000
ACME SPA
VIA ROMA 1
Autorizzazione unica:
00100  ROMA  (RM)
00000000/00
0000
N°000000
00000000000
C.F.: 1/01/2020Del
00000000000
P.IVA:01/08/202600:00Stampato ilOra000
ROSSI MARIO
RSSMRA80A01H501U
MILANO  (MI)
01/01/1980
VIA VERDI 2
I000
N°
APPR.PROFES.IMPIEG. 10%
Trasporto e spedizioni merci
00100  ROMA  (RM)
00000
sede di Roma
 1/08/2020 1/08/2020
Amministrazione
1
BONIFICO BANCARIO
IT00 X000 0000 000X X000 0000 000
 1/09/2027
4J
MINIMOEPA -CCNL 06/12/241.509,8100022,670007,17 12,83 4,00 16,00 (GIORNI)14,87 23,33 11,50 26,70 (ORE)13,33 18,67 32,00 (ORE)9,1219069,658181.532,480
Retribuzione ordinaria
GIORNI
22,000 69,65818 1.532,48
*
*
*
*
1
Edr contrattuale - ex accordo 18.5.2021
GIORNI
22,000 0,34864 7,67
*
*
*
*
10
Straordinario diurno (30%)
ORE
0,250 11,91783 2,98
*
*
*
210
Permessi riduz. orario goduti
ORE
4,030 828
Rata Addizionale Regionale
20259,39
*
Gli elementi variabili della retribuzione sono
relativi a  6/2026
INPS1.543,00 5,84090,11 CONTRIBUTO EBILOG0,50 3,50
FONDO INTEGR. SALARIALE - FIS
1.543,00 0,2674,12 42623 175,62 12.482,00 762,28 1.543,13 1.543,00 94,73 1.452,40 334,05 84,93 221,40 31U.D.27,72 27,72 11.745,32 580,81 1523,43 212U.D.
Firma per quietanza
1.540,15 114,09 907,81 610,72 1.518,53 1.543,13 131,84 0,26 0,03-1.411,00
''';

/// Fixture SINTETICA (nessun PDF reale di 13esima/14esima disponibile in
/// questa sessione, vedi commento in cima a `busta_paga_regex_parser.dart`
/// e nel gruppo di test dedicato più sotto) che riproduce l'ipotesi più
/// plausibile per una mensilità supplementare sul layout "JOB": il blocco
/// ratei Ferie/ROL/Ex festività è assente (nessuna maturazione su una
/// tredicesima/quattordicesima), ma il documento contiene ALTROVE (dopo le
/// righe di competenza) una riga con la stessa forma sintattica esatta dei
/// tag ratei — "5,00 6,00 7,00 (GIORNI)8,00 9,00 3,00 12,00 (ORE)" — per
/// verificare che il parser non se ne agganci per errore scambiandola per
/// il blocco ratei reale (vedi gruppo di test dedicato).
const _testoTredicesimaSintetica = '''
JOB - Copyright Sistemi S.p.A. - Autorizzazione INAIL   N°  792   del  03/01/20185DICEMBRE 2026
Mens.supplementare 12/2026 tredicesima
MINIMOEPA -CCNL 06/12/241.000,0000010,00000
Retribuzione ordinaria
GIORNI
20,000 50,00000 1.000,00
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
Turni recuperabili non goduti 5,00 6,00 7,00 (GIORNI)8,00 9,00 3,00 12,00 (ORE)
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
      // Netto derivato (lordo - trattenute): 1050.00 - 61.32 (INPS) - 3.50
      // (CONTRIBUTO EBILOG) = 985.18. Diverso dal netto grezzo letto dal PDF
      // (988.68) perché nel testo sintetico il residuo "Altre trattenute"
      // risulterebbe negativo e non viene aggiunto (vedi test dedicato più
      // sotto sul calcolo di quella voce).
      expect(risultato.netto, closeTo(985.18, 0.001));
      expect(risultato.trattenute['INPS'], closeTo(61.32, 0.001));
    });

    test('estrae le voci di competenza individuali', () {
      final risultato = parser.parse(_testoSintetico);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione).toList();
      expect(descrizioni, contains('Retribuzione ordinaria'));
      expect(descrizioni, contains('Edr contrattuale - esempio'));
      expect(descrizioni, contains('Straordinario diurno (30%)'));

      final retribuzione = risultato.competenze
          .firstWhere((v) => v.descrizione == 'Retribuzione ordinaria');
      expect(retribuzione.quantita, closeTo(20.000, 0.001));
      expect(retribuzione.importo, closeTo(1000.00, 0.001));

      final straordinario = risultato.competenze
          .firstWhere((v) => v.descrizione == 'Straordinario diurno (30%)');
      expect(straordinario.quantita, closeTo(3.000, 0.001));
      expect(straordinario.importo, closeTo(30.00, 0.001));
    });

    test('esclude "Ferie godute" dalle competenze (già modellata nella '
        'tabella Maturazioni)', () {
      final risultato = parser.parse(_testoSintetico);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione.toLowerCase());
      expect(descrizioni.any((d) => d.startsWith('ferie godute')), isFalse);
    });

    test('esclude righe "Permessi riduz. orario goduti" dalle competenze',
        () {
      final testo = _testoSintetico.replaceFirst(
        'Ferie godute',
        'Permessi riduz. orario goduti\nORE\n4,030\nFerie godute',
      );
      final risultato = parser.parse(testo);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione.toLowerCase());
      expect(
          descrizioni.any((d) => d.startsWith('permessi riduz')), isFalse);
    });

    test('estrae "Permessi riduz. orario goduti" del mese in permessiGodutiMese',
        () {
      final testo = _testoSintetico.replaceFirst(
        'Ferie godute',
        'Permessi riduz. orario goduti\nORE\n4,030\nFerie godute',
      );
      final risultato = parser.parse(testo);

      expect(risultato.permessiGodutiMese, closeTo(4.030, 0.001));
    });

    test('riconosce una trattenuta nel formato verificato '
        '("CONTRIBUTO EBILOG0,50 3,50") come chiave nominata', () {
      final risultato = parser.parse(_testoSintetico);

      expect(risultato.trattenute['CONTRIBUTO EBILOG'], closeTo(3.50, 0.001));
    });

    test('non riconosce una trattenuta nel formato verificato se è fuori dal '
        'segmento INPS→Firma per quietanza', () {
      // Sposta il testo "CONTRIBUTO EBILOG0,50 3,50" fuori dal segmento
      // INPS->Firma (prima di INPS): non deve produrre una chiave nominata.
      final testo = _testoSintetico
          .replaceFirst(' CONTRIBUTO EBILOG0,50 3,50', '')
          .replaceFirst(
            'INPS1.050,00',
            'CONTRIBUTO EBILOG0,50 3,50\nINPS1.050,00',
          );
      final risultato = parser.parse(testo);

      expect(risultato.trattenute.containsKey('CONTRIBUTO EBILOG'), isFalse);
    });

    test('non riconosce una riga di trattenuta non nel formato verificato '
        '(es. senza aliquota/importo attaccati)', () {
      final testo = _testoSintetico.replaceFirst(
        ' CONTRIBUTO EBILOG0,50 3,50',
        ' RATA ADDIZIONALE REGIONALE 1.200,00',
      );
      final risultato = parser.parse(testo);

      expect(risultato.trattenute.containsKey('RATA ADDIZIONALE REGIONALE'),
          isFalse);
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

    test('estrae ex festività (maturate, godute, residue) dal terzo blocco '
        'ratei dopo il tag "(ORE)" di chiusura del ROL', () {
      final risultato = parser.parse(_testoSintetico);

      // 8,00/3,00/5,00: aritmeticamente consistenti SOLO con la lettura
      // diretta (residuo = maturato - goduto, 8-3=5), a differenza del caso
      // "goduto mancante" testato più sotto (dove vale invece la somma) —
      // valori scelti apposta per non essere ambigui tra le due letture.
      expect(risultato.exFestivitaMaturate, closeTo(8.00, 0.001));
      expect(risultato.exFestivitaGodute, closeTo(3.00, 0.001));
      expect(risultato.exFestivitaResidue, closeTo(5.00, 0.001));
    });

    test('disambigua il blocco ex festività a 3 numeri quando il "Goduto" '
        'del mese è zero e la cella è lasciata vuota invece di stampare '
        '"0,00" (visto su un PDF reale: residuo = residuo A.P. + maturato, '
        'non maturato - goduto)', () {
      final testo = _testoSintetico.replaceFirst(
        '(ORE)8,00 3,00 5,00 (ORE)',
        '(ORE)13,33 18,67 32,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.exFestivitaMaturate, closeTo(18.67, 0.001));
      expect(risultato.exFestivitaGodute, 0);
      expect(risultato.exFestivitaResidue, closeTo(32.00, 0.001));
    });

    test('scarta i dati ferie se il valore "maturato" è implausibile '
        '(numero residuo anno precedente incollato senza spazio, visto su '
        'alcuni PDF reali)', () {
      final testo = _testoSintetico.replaceFirst(
        '6,00 2,00 9,17 (GIORNI)',
        '670003,67 2,00 1,67 (GIORNI)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.ferieMaturate, 0);
      expect(risultato.ferieGodute, 0);
      expect(risultato.ferieResidue, 0);
      expect(
        risultato.warnings.any((w) => w.contains('dati ferie scartati')),
        isTrue,
      );
    });

    test('scarta i dati ROL se il valore "maturati" è implausibile', () {
      final testo = _testoSintetico.replaceFirst(
        '7,00 8,00 3,00 12,00 (ORE)',
        '7,00 670008,00 3,00 12,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.rolMaturati, 0);
      expect(risultato.rolGoduti, 0);
      expect(risultato.rolResidui, 0);
      expect(
        risultato.warnings.any((w) => w.contains('dati ROL scartati')),
        isTrue,
      );
    });

    test('NON scarta un residuo ROL alto ma legittimo (es. 150 ore accumulate '
        'in più anni senza godimento) — soglia di implausibilità alzata a '
        '1000 per non confondere questo caso con un artefatto di '
        'estrazione', () {
      final testo = _testoSintetico.replaceFirst(
        '7,00 8,00 3,00 12,00 (ORE)',
        '7,00 8,00 3,00 150,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.rolResidui, closeTo(150.00, 0.001));
      expect(
        risultato.warnings.any((w) => w.contains('dati ROL scartati')),
        isFalse,
      );
    });

    test('scarta i dati ex festività se il valore "maturate" è implausibile',
        () {
      final testo = _testoSintetico.replaceFirst(
        '12,00 (ORE)8,00 3,00 5,00 (ORE)',
        '12,00 (ORE)670008,00 3,00 5,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.exFestivitaMaturate, 0);
      expect(risultato.exFestivitaGodute, 0);
      expect(risultato.exFestivitaResidue, 0);
      expect(
        risultato.warnings
            .any((w) => w.contains('dati ex festività scartati')),
        isTrue,
      );
    });

    test('legge gli ultimi 3 numeri del blocco ex festività anche con un '
        '"residuo anno precedente" davanti (con spazio, non concatenato)',
        () {
      final testo = _testoSintetico.replaceFirst(
        '12,00 (ORE)8,00 3,00 5,00 (ORE)',
        '12,00 (ORE)1,50 5,00 3,00 8,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.exFestivitaMaturate, closeTo(5.00, 0.001));
      expect(risultato.exFestivitaGodute, closeTo(3.00, 0.001));
      expect(risultato.exFestivitaResidue, closeTo(8.00, 0.001));
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

    test(
        'lordo 0 legittimo (competenze che si compensano) non produce il '
        'warning "lordo non trovato" e non viene scartato a null', () {
      // Le tre voci del testo sintetico sommano 1.000,00 + 20,00 + 30,00 =
      // 1.050,00: aggiungendo uno storno di pari importo la somma
      // (computeLordo) risulta esattamente 0, ma `competenze` non è vuota —
      // è un lordo 0 legittimo, non "nessuna riga di competenza
      // riconosciuta" (vedi fix del 2026-08-12).
      final testo = _testoSintetico.replaceFirst(
        '3,000 10,00000 30,00\n',
        '3,000 10,00000 30,00\n'
        '*\n'
        '*\n'
        '*\n'
        'Storno retribuzione\n'
        'GIORNI\n'
        '1,000 1050,00000 -1050,00\n',
      );
      final risultato = parser.parse(testo);

      expect(risultato.competenze, isNotEmpty);
      expect(risultato.lordo, 0.0);
      expect(
        risultato.warnings,
        isNot(
          contains(
            'lordo non trovato (nessuna riga di competenza riconosciuta)',
          ),
        ),
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

    test('warning sul segno "-" scartato quando il netto lo ha davvero', () {
      final risultato = parser.parse(_testoSintetico);

      // Netto derivato, vedi commento nel test "estrae correttamente
      // periodo, lordo, netto e trattenute".
      expect(risultato.netto, closeTo(985.18, 0.001));
      expect(
        risultato.warnings.any((w) => w.startsWith('netto: segno "-"')),
        isTrue,
      );
    });

    test(
        'nessun warning sul segno "-" quando il netto non lo ha (nessun '
        'artefatto da scartare)', () {
      final testo = _testoSintetico.replaceFirst(
        '1.050,00 61,32-988,68',
        '1.050,00 61,32988,68',
      );
      final risultato = parser.parse(testo);

      expect(risultato.netto, closeTo(985.18, 0.001));
      expect(
        risultato.warnings.any((w) => w.startsWith('netto: segno "-"')),
        isFalse,
      );
    });

    test('calcola correttamente "Altre trattenute (IRPEF + varie)" come '
        'lordo - netto - INPS - trattenute nominate extra', () {
      // Nel testo sintetico invariato lordo (1050.00) - netto (988.68) -
      // INPS (61.32) - CONTRIBUTO EBILOG (3.50) è negativo, quindi la voce
      // non viene aggiunta (soglia > 0.01): qui si abbassa il netto per
      // ottenere un residuo positivo e verificarne il valore calcolato.
      final testo = _testoSintetico.replaceFirst(
        '1.050,00 61,32-988,68',
        '1.050,00 61,32-950,00',
      );
      final risultato = parser.parse(testo);

      expect(risultato.lordo, closeTo(1050.00, 0.001));
      expect(risultato.netto, closeTo(950.00, 0.001));
      expect(risultato.trattenute['INPS'], closeTo(61.32, 0.001));
      expect(
          risultato.trattenute['CONTRIBUTO EBILOG'], closeTo(3.50, 0.001));
      // 1050.00 - 950.00 - 61.32 - 3.50
      expect(
        risultato.trattenute['Altre trattenute (IRPEF + varie)'],
        closeTo(35.18, 0.001),
      );
    });

    test('propaga il segno "-" su una voce di competenza negativa (storno/'
        'conguaglio a debito) invece di scartarlo, riflettendosi in '
        'computeLordo', () {
      final testo = _testoSintetico.replaceFirst(
        '3,000 10,00000 30,00\n',
        '3,000 10,00000 30,00\n'
        '*\n'
        '*\n'
        '*\n'
        'Storno retribuzione\n'
        'GIORNI\n'
        '1,000 50,00000 -50,00\n',
      );
      final risultato = parser.parse(testo);

      final storno = risultato.competenze
          .firstWhere((v) => v.descrizione == 'Storno retribuzione');
      expect(storno.importo, closeTo(-50.00, 0.001));
      // 1000.00 (Retribuzione) + 20.00 (Edr) + 30.00 (Straordinario) - 50.00
      // (Storno) = 1000.00
      expect(risultato.lordo, closeTo(1000.00, 0.001));
    });

    test('propaga il segno "-" su una trattenuta negativa (conguaglio a '
        'credito) nel formato verificato, senza scartarlo', () {
      final testo = _testoSintetico.replaceFirst(
        'CONTRIBUTO EBILOG0,50 3,50',
        'CONTRIBUTO EBILOG0,50 -3,50',
      );
      final risultato = parser.parse(testo);

      expect(
        risultato.trattenute['CONTRIBUTO EBILOG'],
        closeTo(-3.50, 0.001),
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
      // Il warning si basa sul netto grezzo letto dal PDF (1500.00, > lordo)
      // ma il valore restituito resta il netto derivato (lordo - trattenute:
      // qui il residuo "Altre trattenute" risulterebbe negativo e non viene
      // aggiunto, quindi 1050.00 - 61.32 - 3.50 = 985.18).
      expect(risultato.netto, closeTo(985.18, 0.001));
      expect(
        risultato.warnings,
        contains('netto superiore al lordo, verifica i dati estratti'),
      );
    });
  });

  group(
      'BustaPagaRegexParser - competenze su testo fedele a un PDF reale '
      '(CRLF, dati fittizi ma valori numerici reali)', () {
    const parser = BustaPagaRegexParser();

    test(
        'riconosce le 3 voci di competenza reali e calcola lordo/'
        'straordinari corretti (criterio di accettazione: lordo 1.543,13, '
        'straordinari 0,25)', () {
      final risultato = parser.parse(_testoCompetenzeReali);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione).toList();
      expect(
        descrizioni,
        containsAll([
          'Retribuzione ordinaria',
          'Edr contrattuale - ex accordo 18.5.2021',
          'Straordinario diurno (30%)',
        ]),
      );

      // Lordo = 1.532,48 + 7,67 + 2,98 = 1.543,13 (valore reale mostrato
      // nell'app per la busta paga da cui è tratto questo campione).
      expect(risultato.lordo, closeTo(1543.13, 0.001));
      // Straordinari = 0,250 ore della voce "Straordinario diurno (30%)".
      expect(risultato.straordinari, closeTo(0.25, 0.001));
    });

    test('esclude "Permessi riduz. orario goduti" dalle competenze anche su '
        'questo testo fedele al layout reale', () {
      final risultato = parser.parse(_testoCompetenzeReali);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione.toLowerCase());
      expect(
        descrizioni.any((d) => d.startsWith('permessi riduz')),
        isFalse,
      );
    });

    test('non riconosce una riga di trattenuta senza tag GIORNI/ORE come '
        'voce di competenza (es. "Rata Addizionale Regionale")', () {
      final risultato = parser.parse(_testoCompetenzeReali);

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione.toLowerCase());
      expect(
        descrizioni.any((d) => d.contains('rata addizionale')),
        isFalse,
      );
    });
  });

  group('BustaPagaRegexParser - ore lavorate lette direttamente dal blocco '
      'Q.T.A. ("ORE LAV.")', () {
    const parser = BustaPagaRegexParser();

    test(
        'legge il valore reale "ORE LAV." (175,62) invece di stimarlo da '
        'giorni×8 (che darebbe 22×8=176, un valore diverso e non quello '
        'vero) quando il blocco Q.T.A. è riconoscibile', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(risultato.oreLavorate, closeTo(175.62, 0.001));
      expect(
        risultato.warnings
            .any((w) => w.contains('ore lavorate stimate da giorni')),
        isFalse,
      );
    });

    test('usa il fallback (stima giorni×8) con il warning esplicito quando '
        'il blocco Q.T.A. non è riconoscibile nel testo', () {
      final risultato = parser.parse(_testoSintetico);

      expect(risultato.oreLavorate, closeTo(160, 0.001)); // 20 giorni × 8
      expect(
        risultato.warnings,
        contains('ore lavorate stimate da giorni×8, non lette direttamente'),
      );
    });

    test(
        'ignora un falso positivo plausibile (blocco di cifre pure + numero '
        'a 2 decimali) inserito PRIMA della riga INPS, fuori dallo scope di '
        'ricerca ristretto al segmento INPS→"Firma per quietanza": legge '
        'comunque correttamente il valore reale (175,62)', () {
      // "12345 88,40" ha esattamente la forma che il pattern riconosce, ma
      // è inserito nel blocco anagrafico/intestazione, ben prima di INPS:
      // con lo scoping al segmento INPS→Firma non viene nemmeno considerato.
      final testo = _testoRealeLuglio2026.replaceFirst(
        'ROSSI MARIO',
        'ROSSI MARIO 12345 88,40',
      );
      final risultato = parser.parse(testo);

      expect(risultato.oreLavorate, closeTo(175.62, 0.001));
      expect(
        risultato.warnings
            .any((w) => w.contains('ore lavorate') && w.contains('ambiguità')),
        isFalse,
      );
    });

    test(
        'segnala un warning di ambiguità (invece di prendere in silenzio il '
        'primo match) e ricade sulla stima giorni×8 quando il pattern '
        'matcha più di una volta dentro lo scope di ricerca ristretto '
        '(segmento INPS→"Firma per quietanza")', () {
      // Un secondo falso positivo plausibile ("54321 12,34") inserito
      // ANCHE dentro il segmento INPS→Firma, subito prima del valore reale:
      // ora ci sono 2 match nello stesso scope, l'ancoraggio diventa
      // ambiguo per questo documento.
      final testo = _testoRealeLuglio2026.replaceFirst(
        '1.543,00 0,2674,12 42623 175,62',
        '1.543,00 0,2674,12 54321 12,34 42623 175,62',
      );
      final risultato = parser.parse(testo);

      expect(
        risultato.warnings.any(
          (w) => w.contains('ore lavorate') && w.contains('ambiguità'),
        ),
        isTrue,
      );
      // Fallback: stima da giorni×8 (22 giorni × 8 = 176), non uno dei due
      // valori ambigui letti direttamente.
      expect(risultato.oreLavorate, closeTo(176, 0.001));
      expect(
        risultato.warnings,
        contains('ore lavorate stimate da giorni×8, non lette direttamente'),
      );
    });
  });

  group('BustaPagaRegexParser - ambiguità ex festività quando il "goduto" '
      'candidato è zero (bug corretto)', () {
    const parser = BustaPagaRegexParser();

    test(
        'segnala un warning esplicito invece di scegliere in silenzio '
        'un\'interpretazione arbitraria quando le due condizioni di '
        'disambiguazione sono entrambe soddisfatte (n2 = 0, quindi '
        '"n3 == n1 - n2" e "n3 == n1 + n2" diventano identiche)', () {
      final testo = _testoSintetico.replaceFirst(
        '(ORE)8,00 3,00 5,00 (ORE)',
        '(ORE)5,00 0,00 5,00 (ORE)',
      );
      final risultato = parser.parse(testo);

      expect(risultato.exFestivitaMaturate, 0);
      expect(risultato.exFestivitaGodute, 0);
      expect(risultato.exFestivitaResidue, 0);
      expect(
        risultato.warnings.any((w) => w.contains('dati ex festività ambigui')),
        isTrue,
      );
      // Non deve anche scattare il warning generico "scartati" (implausibile):
      // è un caso distinto, con un messaggio dedicato più informativo.
      expect(
        risultato.warnings.any((w) => w.contains('dati ex festività scartati')),
        isFalse,
      );
    });

    test('non ambiguo (comportamento invariato) quando il "goduto" '
        'candidato non è zero, anche se la struttura del blocco è la '
        'stessa (3 numeri dopo il tag ROL)', () {
      final risultato = parser.parse(_testoSintetico);

      // Caso già coperto sopra ("estrae ex festività..."): nessuna
      // ambiguità, nessun warning.
      expect(
        risultato.warnings.any((w) => w.contains('dati ex festività ambigui')),
        isFalse,
      );
    });
  });

  group(
      'BustaPagaRegexParser - trattenute individuali su testo reale (Luglio '
      '2026)', () {
    const parser = BustaPagaRegexParser();

    test('estrae INPS come trattenuta nominata con l\'importo mensile '
        'corretto (90,11)', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(risultato.trattenute['INPS'], closeTo(90.11, 0.001));
    });

    test('estrae "CONTRIBUTO EBILOG" come trattenuta nominata con l\'importo '
        'corretto (3,50)', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(
        risultato.trattenute['CONTRIBUTO EBILOG'],
        closeTo(3.50, 0.001),
      );
    });

    test(
        '"FONDO INTEGR. SALARIALE - FIS" non produce una chiave nominata '
        'pulita (il nome è seguito da un ritorno a capo prima dei numeri, '
        'a differenza di CONTRIBUTO EBILOG, e i numeri della riga '
        'successiva sono ambigui — "0,2674,12" — perché condivisi col '
        'blocco Q.T.A.): resta aggregata nel residuo "Altre trattenute", '
        'la matematica del netto finale resta comunque corretta (vedi test '
        'ground-truth)', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(
        risultato.trattenute.keys
            .any((k) => k.toUpperCase().contains('FIS')),
        isFalse,
      );
    });

    test('non produce falsi positivi dai blocchi Q.T.A./IRPEF/TFR tra INPS '
        'e "Firma per quietanza" (es. nessuna chiave "U.D." o sigle simili '
        'da quel segmento)', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      // Solo le due trattenute nominate attese, nessun'altra chiave oltre
      // a INPS/CONTRIBUTO EBILOG/il residuo aggregato.
      expect(
        risultato.trattenute.keys.toSet(),
        {'INPS', 'CONTRIBUTO EBILOG', 'Altre trattenute (IRPEF + varie)'},
      );
    });
  });

  group(
      'BustaPagaRegexParser - controllo incrociato lordo calcolato vs '
      '"totale competenze" stampato sul PDF (Fix 4)', () {
    const parser = BustaPagaRegexParser();

    test('nessun warning quando il lordo calcolato coincide (entro '
        'tolleranza) col totale competenze stampato sul PDF reale', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(
        risultato.warnings
            .any((w) => w.contains('diverge dal totale competenze')),
        isFalse,
      );
    });

    test('segnala un warning esplicito (senza alterare il lordo calcolato) '
        'quando una voce di competenza mancata/alterata fa divergere '
        'computeLordo dal totale competenze stampato sul PDF', () {
      // Altera l'importo di una voce di competenza reale (7,67 -> 5,00):
      // il "totale competenze" stampato sul PDF (1.543,13, invariato)
      // diverge ora dal lordo ricalcolato (1.543,13 - 7,67 + 5,00 =
      // 1.540,46).
      final testo = _testoRealeLuglio2026.replaceFirst(
        '22,000 0,34864 7,67',
        '22,000 0,34864 5,00',
      );
      final risultato = parser.parse(testo);

      expect(risultato.lordo, closeTo(1540.46, 0.001));
      expect(
        risultato.warnings
            .any((w) => w.contains('diverge dal totale competenze')),
        isTrue,
      );
    });
  });

  group(
      'BustaPagaRegexParser - ground-truth su PDF reale (Luglio 2026): test '
      'di non-regressione principale per la fedeltà del parser ai PDF '
      'reali — dati anagrafici fittizi, struttura e valori numerici reali, '
      'vedi doc su _testoRealeLuglio2026', () {
    const parser = BustaPagaRegexParser();

    test('estrae correttamente OGNI campo di BustaPagaEstratti dal testo '
        'reale', () {
      final risultato = parser.parse(_testoRealeLuglio2026);

      expect(risultato.periodo, '2026-07');
      expect(risultato.tipo, TipoBustaPaga.mensile);

      expect(risultato.lordo, closeTo(1543.13, 0.001));
      expect(risultato.straordinari, closeTo(0.25, 0.001));

      final descrizioni =
          risultato.competenze.map((v) => v.descrizione).toList();
      expect(
        descrizioni,
        containsAll([
          'Retribuzione ordinaria',
          'Edr contrattuale - ex accordo 18.5.2021',
          'Straordinario diurno (30%)',
        ]),
      );
      final retribuzione = risultato.competenze
          .firstWhere((v) => v.descrizione == 'Retribuzione ordinaria');
      expect(retribuzione.importo, closeTo(1532.48, 0.001));
      final edr = risultato.competenze
          .firstWhere((v) => v.descrizione.startsWith('Edr contrattuale'));
      expect(edr.importo, closeTo(7.67, 0.001));
      final straordinario = risultato.competenze
          .firstWhere((v) => v.descrizione == 'Straordinario diurno (30%)');
      expect(straordinario.importo, closeTo(2.98, 0.001));

      expect(risultato.ferieMaturate, closeTo(12.83, 0.001));
      expect(risultato.ferieGodute, closeTo(4.00, 0.001));
      expect(risultato.ferieResidue, closeTo(16.00, 0.001));

      expect(risultato.rolMaturati, closeTo(23.33, 0.001));
      expect(risultato.rolGoduti, closeTo(11.50, 0.001));
      expect(risultato.rolResidui, closeTo(26.70, 0.001));
      // In questo layout "Permessi (R.O.L.)" coincide coi ROL goduti (vedi
      // commento in parse()) — mai verificato finora contro il testo reale,
      // solo indirettamente uguale a rolGoduti.
      expect(risultato.permessiGoduti, closeTo(11.50, 0.001));

      expect(risultato.exFestivitaMaturate, closeTo(18.67, 0.001));
      expect(risultato.exFestivitaGodute, 0);
      expect(risultato.exFestivitaResidue, closeTo(32.00, 0.001));

      // Mai testato finora contro un estratto REALE (solo contro fixture
      // sintetico): riga "210 Permessi riduz. orario goduti ORE 4,030".
      expect(risultato.permessiGodutiMese, closeTo(4.03, 0.001));

      // Letto direttamente dal blocco Q.T.A. ("ORE LAV."), non stimato:
      // vedi anche il gruppo dedicato sopra.
      expect(risultato.oreLavorate, closeTo(175.62, 0.001));

      expect(risultato.trattenute['INPS'], closeTo(90.11, 0.001));
      expect(
        risultato.trattenute['CONTRIBUTO EBILOG'],
        closeTo(3.50, 0.001),
      );
      // Valore esatto del residuo aggregato (mai verificato finora, solo
      // indirettamente tramite il netto finale): lordo (1.543,13) - netto
      // grezzo letto dal PDF (1.411,00) - INPS (90,11) - CONTRIBUTO EBILOG
      // (3,50) = 38,52.
      expect(
        risultato.trattenute['Altre trattenute (IRPEF + varie)'],
        closeTo(38.52, 0.001),
      );

      // Controllo incrociato (Fix 4): il "totale competenze" stampato dal
      // PDF (1.543,13, subito dopo "ORE LAV." nel blocco Q.T.A.) coincide
      // col lordo calcolato — nessun warning di divergenza.
      expect(
        risultato.warnings.any((w) => w.contains('diverge dal totale competenze')),
        isFalse,
      );

      // Netto derivato (lordo - trattenute, incluso il residuo "Altre
      // trattenute" che assorbe IRPEF/FIS/arrotondamenti non modellati
      // individualmente dal parser). Tolleranza 0,01 (non un intervallo
      // ampio): il residuo è calcolato per costruzione come
      // "lordo - netto grezzo - INPS - trattenute nominate", quindi il
      // netto derivato torna a coincidere esattamente col netto grezzo
      // letto dal PDF (1.411,00) quando quel netto grezzo è corretto — non
      // c'è nessun arretrato/conguaglio non modellato su questo cedolino
      // specifico che introduca uno scarto strutturale.
      expect(risultato.netto, closeTo(1411.00, 0.01));

      expect(
        risultato.warnings.any((w) => w.startsWith('netto: segno "-"')),
        isTrue,
      );
    });
  });

  group(
    'robustezza su 13esima/14esima (fixture ipotetica, nessun PDF reale disponibile)',
    () {
      const parser = BustaPagaRegexParser();

      test(
        'una riga "trappola" dopo le competenze non viene scambiata per il '
        'blocco ratei Ferie/ROL',
        () {
          final risultato = parser.parse(_testoTredicesimaSintetica);

          // La riga "Turni recuperabili non goduti 5,00 6,00 7,00
          // (GIORNI)8,00 9,00 3,00 12,00 (ORE)" ha la stessa identica forma
          // sintattica del blocco ratei reale (3 numeri + "(GIORNI)", poi 4
          // numeri + "(ORE)") e SE cercata su tutto il documento
          // (`_ratesFerie`/`_ratesRol` con `firstMatch` non scoped)
          // matcherebbe erroneamente, popolando ferie/ROL con
          // maturato=5,00/goduto=6,00/residuo=7,00 e ROL con
          // maturato=9,00/goduto=3,00/residuo=12,00 — dati inventati che non
          // esistono in questa mensilità supplementare (nessun blocco ratei
          // reale nel testo).
          //
          // Il parser è già sicuro contro questo scenario, per due motivi
          // indipendenti verificati qui:
          // 1) `zonaRatei` (vedi `parse()`, commento "difesa aggiunta per le
          //    mensilità supplementari") restringe la ricerca di
          //    `_ratesFerie`/`_ratesRol` al testo PRIMA della prima riga di
          //    competenza riconosciuta (`_rigaVoceCompetenza.firstMatch`) —
          //    la riga trappola, che si trova DOPO le competenze in questa
          //    fixture, non rientra mai in quello scope;
          // 2) anche senza scoping, la riga trappola non avrebbe comunque
          //    fatto match come voce di competenza valida ("8,00"/"9,00" ecc.
          //    hanno 2 decimali, mentre `_rigaVoceCompetenza` richiede una
          //    quantità a 3 decimali dopo il tag GIORNI/ORE) — ma è (1),
          //    verificato sotto tramite i warning attesi, a garantire che
          //    `_ratesFerie`/`_ratesRol` non la raggiungano affatto.
          //
          // Nessuna modifica allo scoping è stata necessaria: era già
          // presente e sufficiente. Questo test la blinda da regressioni
          // future.
          expect(risultato.ferieMaturate, 0);
          expect(risultato.ferieGodute, 0);
          expect(risultato.ferieResidue, 0);
          expect(risultato.rolMaturati, 0);
          expect(risultato.rolGoduti, 0);
          expect(risultato.rolResidui, 0);
          expect(
            risultato.warnings,
            containsAll(['dati ferie non trovati', 'dati ROL non trovati']),
          );

          // Tipo dedotto da "Mens.supplementare 12/2026 tredicesima": la
          // parola "tredicesima" è presente esplicitamente nel testo, quindi
          // letta direttamente (non dedotta dal mese, niente warning di
          // deduzione).
          expect(risultato.tipo, TipoBustaPaga.tredicesima);
          expect(
            risultato.warnings
                .any((w) => w.contains('tipo mensilità dedotto')),
            isFalse,
          );

          // Lordo/straordinari derivati dalle competenze, non toccati da
          // questo fix: Retribuzione ordinaria 1.000,00 + Straordinario
          // diurno (30%) 30,00 = 1.030,00; straordinari = 3,00 ore (quantità
          // dell'unica voce "Straordinario...").
          expect(risultato.lordo, closeTo(1030.00, 0.001));
          expect(risultato.straordinari, closeTo(3.00, 0.001));
        },
      );
    },
  );
}
