/// Estrazione automatica dei campi di [BustaPaga] da testo PDF (output di
/// [PdfImportService]) tramite pattern regex mirati al layout del software
/// payroll "JOB" (Sistemi S.p.A.) — non un parser generico per qualunque
/// busta paga italiana.
///
/// Il testo estratto da `syncfusion_flutter_pdf` per questo layout non
/// rispecchia l'ordine visivo della tabella (celle su colonne diverse
/// finiscono concatenate senza separatore). I pattern sotto sono stati
/// derivati manualmente confrontando 3 buste paga reali dello stesso
/// software, sfruttando regolarità strutturali stabili:
/// - le quantità hanno sempre 3 decimali ("22,000"), le tariffe orarie 5
///   decimali ("69,65818"), gli importi 2 decimali ("1.532,48") — questo
///   evita ambiguità nel separare numeri concatenati senza spazi;
/// - il blocco "ratei" (ferie/ROL/ex festività) usa i tag letterali
///   "(GIORNI)"/"(ORE)" come ancore non numeriche, permettendo di
///   catturare solo i 3 numeri (maturati/goduti/residui) immediatamente
///   prima del tag, ignorando il residuo-anno-precedente che li precede
///   incollato ad altri numeri senza spazio (fonte di ambiguità, non ci
///   serve comunque).
///
/// Se il layout del software payroll cambia, questi pattern smettono di
/// funzionare silenziosamente (ritornano `null`/campi a 0) — è un limite
/// noto e accettato: l'alternativa (LLM locale) è stata valutata e scartata
/// per ora, vedi BACKLOG.md.
library;

import '../models/busta_paga.dart';

class BustaPagaEstratti {
  final String? periodo; // formato YYYY-MM
  final double? lordo;
  final double? netto;
  final Map<String, double> trattenute;
  final double straordinari;
  final double ferieMaturate;
  final double ferieGodute;
  final double ferieResidue;
  final double rolMaturati;
  final double rolGoduti;
  final double rolResidui;
  final double permessiGoduti;

  /// Permessi riduz. orario goduti nel mese — vedi
  /// `BustaPaga.permessiGodutiMese`.
  final double permessiGodutiMese;

  /// Ex festività maturate/godute/residue — vedi
  /// `BustaPaga.exFestivitaMaturate` e affini.
  final double exFestivitaMaturate;
  final double exFestivitaGodute;
  final double exFestivitaResidue;

  final double? oreLavorate;

  /// Voci di competenza individuali estratte dal PDF (vedi
  /// [BustaPagaRegexParser._rigaVoceCompetenza]).
  final List<VoceCompetenza> competenze;

  /// Tipo mensilità (mensile/13esima/14esima), rilevato cercando le parole
  /// "tredicesima"/"quattordicesima" nel testo del PDF — sempre valorizzato
  /// (default `mensile` se non trovate), a differenza degli altri campi che
  /// possono mancare.
  final TipoBustaPaga tipo;

  /// Campi che il parser non è riuscito a determinare con sufficiente
  /// confidenza (es. "netto", "ore lavorate stimate") — da mostrare
  /// all'utente come promemoria di verifica manuale.
  final List<String> warnings;

  const BustaPagaEstratti({
    this.periodo,
    this.lordo,
    this.netto,
    required this.trattenute,
    required this.straordinari,
    required this.ferieMaturate,
    required this.ferieGodute,
    required this.ferieResidue,
    required this.rolMaturati,
    required this.rolGoduti,
    required this.rolResidui,
    required this.permessiGoduti,
    this.permessiGodutiMese = 0,
    this.exFestivitaMaturate = 0,
    this.exFestivitaGodute = 0,
    this.exFestivitaResidue = 0,
    this.oreLavorate,
    this.competenze = const [],
    this.tipo = TipoBustaPaga.mensile,
    required this.warnings,
  });
}

class BustaPagaRegexParser {
  const BustaPagaRegexParser();

  static const _mesi = {
    'gennaio': 1,
    'febbraio': 2,
    'marzo': 3,
    'aprile': 4,
    'maggio': 5,
    'giugno': 6,
    'luglio': 7,
    'agosto': 8,
    'settembre': 9,
    'ottobre': 10,
    'novembre': 11,
    'dicembre': 12,
  };

  // Riga unificata di una voce di competenza (Retribuzione ordinaria, Edr
  // contrattuale, Straordinario per fascia, ecc.): descrizione in chiaro su
  // una riga, seguita dal tag "GIORNI"/"ORE", seguita dalla quantità (3
  // decimali) ed eventualmente da tariffa (2-5 decimali, scartata) e importo
  // (2 decimali, con eventuale separatore delle migliaia ".") sulla riga
  // successiva. Il gruppo descrizione (`[^\n]+`) è generico — cattura
  // qualunque testo sulla riga precedente al tag — e validato solo sul
  // campione di PDF reali disponibile: potrebbe richiedere aggiustamenti su
  // layout mai visti finora.
  static final _rigaVoceCompetenza = RegExp(
    r'([^\n]+)\n\s*(?:GIORNI|ORE)\s*\n\s*(\d+,\d{3})'
    r'(?:\s+[\d.]+,\d{2,5}\s+([\d.]+,\d{2}))?',
  );

  // Descrizioni (confronto case-insensitive, su prefisso trimmato) escluse
  // da `competenze`: le righe Ferie/Permessi sono già modellate altrove
  // (tabella Maturazioni, `permessiGodutiMese`) e non vanno duplicate qui,
  // pur avendo la stessa struttura sintattica di una riga di competenza.
  static const _descrizioniEscluseDaCompetenze = [
    'ferie godute',
    'permessi riduz',
  ];

  static final _rigaPermessiMese = RegExp(
    r'Permessi\s+riduz\.?\s*orario\s+goduti[^\n]*\n\s*(?:ORE|GIORNI)\s*\n\s*(\d+,\d{3})',
  );

  static final _ratesFerie = RegExp(
    r'(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(GIORNI\)',
  );

  static final _ratesRol = RegExp(
    r'\(GIORNI\)\s*\d+,\d{2}\s+(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(ORE\)',
  );

  // Terzo blocco ratei "EX FESTIVITA'" (vedi intestazione tabella nel PDF:
  // FERIE / PERMESSI (R.O.L.) / EX FESTIVITA'), stessa struttura
  // maturato/goduto/residuo di ferie/ROL ma SENZA un numero "residuo anno
  // precedente" da scartare in testa. Cercato SOLO nel testo subito dopo la
  // fine del match ROL (non con un regex libero su tutto il documento) per
  // evitare di agganciare tag "(ORE)" di sezioni successive non correlate —
  // stesso principio di scoping già usato per le trattenute verificate.
  static final _ratesExFestivita = RegExp(
    r'^\s*(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(ORE\)',
  );

  // Un valore di rateo (giorni/ore maturati/goduti/residui in un mese)
  // implausibilmente grande indica che il regex ha catturato un numero
  // "residuo anno precedente" incollato SENZA spazio al valore reale nel
  // testo estratto — visto su alcuni PDF reali (es. "670003,67" invece di
  // "3,67"), non su tutti: l'assenza dello spazio separatore è un
  // artefatto incostante di `syncfusion_flutter_pdf`, non deterministico
  // (dipende da come il layout PDF posiziona quella cella quel mese),
  // quindi non recuperabile con un regex più specifico. Soglia scelta ben
  // sopra qualunque valore mensile plausibile (giorni/ore sempre < 50) ma
  // ben sotto ai numeri concatenati osservati (dell'ordine di 670000+).
  bool _valoreRateoImplausibile(double v) => v.abs() >= 100;

  static final _inps = RegExp(r'INPS([\d.]+,\d{2})\s+(\d,\d{2})(\d+,\d{2})');

  // Nome+aliquota+importo attaccati senza spazio, pattern osservato SOLO per
  // la riga immediatamente successiva a INPS nel PDF reale (es. "CONTRIBUTO
  // EBILOG0,50 3,50"). Deliberatamente ristretto a questo segmento: un
  // regex applicato a tutta la sezione trattenute rischierebbe di leggere
  // importi annui/imponibili come se fossero l'importo mensile trattenuto
  // (es. una riga "Rata Addizionale Regionale" seguita da un imponibile
  // fiscale annuo, non un importo mensile).
  static final _rigaTrattenutaVerificata =
      RegExp(r'([A-Z][A-Z ]{2,}?)(\d,\d{2})\s+(\d+,\d{2})');

  static final _periodo = RegExp(
    r'(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)\s+(\d{4})',
    caseSensitive: false,
  );

  // Periodo di competenza delle mensilità supplementari (13esima/14esima):
  // il campo "MESE DI RETRIBUZIONE" riporta "Mens.supplementare MM/YYYY"
  // invece del nome del mese per esteso — un testo affidabile solo per
  // queste buste, va provato con priorità su [_periodo] perché su una
  // mensilità supplementare quel nome di mese per esteso trovato altrove
  // nel documento può appartenere a un contesto diverso (es. data di
  // stampa) e produrre un periodo di competenza sbagliato.
  static final _mensSupplementare = RegExp(
    r'Mens\.?\s*supplementare\s*(\d{1,2})\s*/\s*(\d{4})',
    caseSensitive: false,
  );

  static final _quattordicesima =
      RegExp(r'quattordicesima', caseSensitive: false);
  static final _tredicesima = RegExp(r'tredicesima', caseSensitive: false);

  double _toDouble(String raw) =>
      double.parse(raw.replaceAll('.', '').replaceAll(',', '.'));

  /// Deduce il tipo mensilità dal mese di "Mens.supplementare" quando il
  /// testo non nomina esplicitamente "tredicesima"/"quattordicesima" —
  /// novembre/dicembre/gennaio sono i mesi tipici di erogazione della
  /// tredicesima, giugno/luglio della quattordicesima. Mese fuori da questi
  /// pattern: nessuna deduzione (`null`), resta il fallback mensile.
  TipoBustaPaga? _tipoDaMeseSupplementare(int mese) {
    if (mese == 11 || mese == 12 || mese == 1) return TipoBustaPaga.tredicesima;
    if (mese == 6 || mese == 7) return TipoBustaPaga.quattordicesima;
    return null;
  }

  BustaPagaEstratti parse(String testo) {
    final warnings = <String>[];

    // --- periodo ---
    String? periodo;
    final supplementareMatch = _mensSupplementare.firstMatch(testo);
    if (supplementareMatch != null) {
      final mese = supplementareMatch.group(1)!.padLeft(2, '0');
      final anno = supplementareMatch.group(2)!;
      periodo = '$anno-$mese';
    } else {
      final periodoMatch = _periodo.firstMatch(testo);
      if (periodoMatch != null) {
        final mese = _mesi[periodoMatch.group(1)!.toLowerCase()]!;
        final anno = periodoMatch.group(2)!;
        periodo = '$anno-${mese.toString().padLeft(2, '0')}';
      } else {
        warnings.add('periodo non trovato');
      }
    }

    // --- tipo: 13esima/14esima se il testo le nomina esplicitamente,
    // altrimenti mensile. "Quattordicesima" controllata per prima solo per
    // ordine, non per ambiguità: sono parole distinte, nessun rischio di
    // falsi positivi incrociati. Se nessuna delle due parole matcha ma il
    // testo contiene "Mens.supplementare MM/YYYY", il tipo viene dedotto dal
    // mese (vedi `_tipoDaMeseSupplementare`) con un warning esplicito, dato
    // che è una deduzione e non una lettura diretta. ---
    TipoBustaPaga tipo;
    if (_quattordicesima.hasMatch(testo)) {
      tipo = TipoBustaPaga.quattordicesima;
    } else if (_tredicesima.hasMatch(testo)) {
      tipo = TipoBustaPaga.tredicesima;
    } else {
      tipo = TipoBustaPaga.mensile;
      if (supplementareMatch != null) {
        final meseSupplementare = int.parse(supplementareMatch.group(1)!);
        final tipoDedotto = _tipoDaMeseSupplementare(meseSupplementare);
        if (tipoDedotto != null) {
          tipo = tipoDedotto;
          warnings.add(
            'tipo mensilità dedotto dal mese "Mens.supplementare", verifica',
          );
        }
      }
    }

    // --- competenze: voci individuali, escludendo ferie/permessi (già
    // modellati altrove) ---
    final competenze = <VoceCompetenza>[];
    for (final m in _rigaVoceCompetenza.allMatches(testo)) {
      final descrizione = m.group(1)!.trim();
      final descrizioneLower = descrizione.toLowerCase();
      final esclusa = _descrizioniEscluseDaCompetenze
          .any((prefisso) => descrizioneLower.startsWith(prefisso));
      if (esclusa) continue;
      final quantita = _toDouble(m.group(2)!);
      final importoGroup = m.group(3);
      final importo = importoGroup != null ? _toDouble(importoGroup) : 0.0;
      competenze.add(VoceCompetenza(
        descrizione: descrizione,
        quantita: quantita,
        importo: importo,
      ));
    }

    // --- lordo / straordinari: derivati dalla lista competenze (unica
    // fonte di verità, vedi computeLordo/computeStraordinari) ---
    final lordo = computeLordo(competenze);
    final straordinari = computeStraordinari(competenze);
    if (lordo == 0) warnings.add('lordo non trovato (nessuna riga di competenza riconosciuta)');

    // --- permessi riduz. orario goduti nel mese: somma tutte le righe
    // trovate ---
    double permessiGodutiMese = 0;
    for (final m in _rigaPermessiMese.allMatches(testo)) {
      permessiGodutiMese += _toDouble(m.group(1)!);
    }

    // --- ore lavorate: stima da giorni×8, sommando le quantità di tutte le
    // voci di competenza "Retribuzione ordinaria" ---
    double giorniOrdinari = 0;
    for (final voce in competenze) {
      if (voce.descrizione.trim().toLowerCase().startsWith('retribuzione ordinaria')) {
        giorniOrdinari += voce.quantita;
      }
    }
    double? oreLavorate;
    if (giorniOrdinari > 0) {
      oreLavorate = giorniOrdinari * 8;
      warnings.add('ore lavorate stimate da giorni×8, non lette direttamente');
    } else {
      warnings.add('ore lavorate non determinabili');
    }

    // --- ferie / ROL (maturati, goduti, residui) ---
    double ferieMaturate = 0, ferieGodute = 0, ferieResidue = 0;
    final ferieMatch = _ratesFerie.firstMatch(testo);
    if (ferieMatch != null) {
      final maturate = _toDouble(ferieMatch.group(1)!);
      final godute = _toDouble(ferieMatch.group(2)!);
      final residue = _toDouble(ferieMatch.group(3)!);
      if (_valoreRateoImplausibile(maturate) ||
          _valoreRateoImplausibile(godute) ||
          _valoreRateoImplausibile(residue)) {
        warnings.add(
          'dati ferie scartati: valore implausibile estratto (probabile '
          'numero residuo anno precedente incollato senza spazio), '
          'verifica manualmente',
        );
      } else {
        ferieMaturate = maturate;
        ferieGodute = godute;
        ferieResidue = residue;
      }
    } else {
      warnings.add('dati ferie non trovati');
    }

    double rolMaturati = 0, rolGoduti = 0, rolResidui = 0;
    final rolMatch = _ratesRol.firstMatch(testo);
    if (rolMatch != null) {
      final maturati = _toDouble(rolMatch.group(1)!);
      final goduti = _toDouble(rolMatch.group(2)!);
      final residui = _toDouble(rolMatch.group(3)!);
      if (_valoreRateoImplausibile(maturati) ||
          _valoreRateoImplausibile(goduti) ||
          _valoreRateoImplausibile(residui)) {
        warnings.add(
          'dati ROL scartati: valore implausibile estratto (probabile '
          'numero residuo anno precedente incollato senza spazio), '
          'verifica manualmente',
        );
      } else {
        rolMaturati = maturati;
        rolGoduti = goduti;
        rolResidui = residui;
      }
    } else {
      warnings.add('dati ROL non trovati');
    }

    // --- ex festività (maturate, godute, residue): cercate solo nel testo
    // subito dopo la fine del match ROL, vedi _ratesExFestivita ---
    double exFestivitaMaturate = 0, exFestivitaGodute = 0, exFestivitaResidue = 0;
    if (rolMatch != null) {
      final dopoRol = testo.substring(rolMatch.end);
      final exFestivitaMatch = _ratesExFestivita.firstMatch(dopoRol);
      if (exFestivitaMatch != null) {
        final maturate = _toDouble(exFestivitaMatch.group(1)!);
        final godute = _toDouble(exFestivitaMatch.group(2)!);
        final residue = _toDouble(exFestivitaMatch.group(3)!);
        if (_valoreRateoImplausibile(maturate) ||
            _valoreRateoImplausibile(godute) ||
            _valoreRateoImplausibile(residue)) {
          warnings.add(
            'dati ex festività scartati: valore implausibile estratto, '
            'verifica manualmente',
          );
        } else {
          exFestivitaMaturate = maturate;
          exFestivitaGodute = godute;
          exFestivitaResidue = residue;
        }
      } else {
        warnings.add('dati ex festività non trovati');
      }
    } else {
      warnings.add('dati ex festività non trovati');
    }
    // In questo layout "Permessi (R.O.L.)" è un unico concetto: i permessi
    // goduti coincidono con i ROL goduti.
    final permessiGoduti = rolGoduti;

    // --- trattenute: INPS letto direttamente, il resto aggregato ---
    final trattenute = <String, double>{};
    final inpsMatch = _inps.firstMatch(testo);
    double inpsImporto = 0;
    if (inpsMatch != null) {
      inpsImporto = _toDouble(inpsMatch.group(3)!);
      trattenute['INPS'] = inpsImporto;
    } else {
      warnings.add('trattenuta INPS non trovata');
    }

    // --- netto: ultimo numero della riga dopo "Firma per quietanza" ---
    double? netto;
    final firmaIndex = testo.indexOf('Firma per quietanza');

    // --- trattenute nominate verificate: SOLO nel segmento tra la fine del
    // match INPS e l'inizio di "Firma per quietanza" (vedi
    // _rigaTrattenutaVerificata) ---
    double trattenuteNominateExtra = 0;
    if (inpsMatch != null && firmaIndex != -1 && firmaIndex > inpsMatch.end) {
      final segmento = testo.substring(inpsMatch.end, firmaIndex);
      for (final m in _rigaTrattenutaVerificata.allMatches(segmento)) {
        final nome = m.group(1)!.trim();
        final importo = _toDouble(m.group(3)!);
        trattenute[nome] = importo;
        trattenuteNominateExtra += importo;
      }
    }

    if (firmaIndex != -1) {
      final dopoFirma = testo.substring(firmaIndex + 'Firma per quietanza'.length);
      final righeDopoFirma = dopoFirma.split('\n').where((r) => r.trim().isNotEmpty);
      if (righeDopoFirma.isNotEmpty) {
        final rigaNetto = righeDopoFirma.first.trim();
        final numeri = RegExp(r'-?[\d.]+,\d{2}').allMatches(rigaNetto).toList();
        if (numeri.isNotEmpty) {
          final ultimo = numeri.last.group(0)!;
          // Il "-" davanti all'ultimo numero è quasi sempre un artefatto di
          // estrazione (due celle concatenate), non un netto negativo.
          netto = _toDouble(ultimo.startsWith('-') ? ultimo.substring(1) : ultimo);
          warnings.add('netto: segno "-" iniziale scartato come probabile artefatto di estrazione, verificare');
        }
      }
    }
    if (netto == null) warnings.add('netto non trovato');

    if (netto != null && lordo > 0 && inpsImporto > 0) {
      final resto = lordo - netto - inpsImporto - trattenuteNominateExtra;
      if (resto > 0.01) {
        trattenute['Altre trattenute (IRPEF + varie)'] = double.parse(resto.toStringAsFixed(2));
      }
    }

    if (netto != null && lordo > 0 && netto > lordo) {
      warnings.add('netto superiore al lordo, verifica i dati estratti');
    }

    return BustaPagaEstratti(
      periodo: periodo,
      lordo: lordo > 0 ? lordo : null,
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
      permessiGodutiMese: permessiGodutiMese,
      exFestivitaMaturate: exFestivitaMaturate,
      exFestivitaGodute: exFestivitaGodute,
      exFestivitaResidue: exFestivitaResidue,
      oreLavorate: oreLavorate,
      competenze: competenze,
      tipo: tipo,
      warnings: warnings,
    );
  }
}
