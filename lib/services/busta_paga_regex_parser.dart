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
  final double? oreLavorate;

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
    this.oreLavorate,
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

  // Quantità: 3 decimali. Tariffa: 5 decimali. Importo: 2 decimali (con
  // eventuale separatore delle migliaia "."). Riga di una voce di
  // competenza con importo monetario (es. "22,000 69,65818 1.532,48").
  static final _rigaCompetenza =
      RegExp(r'(\d+,\d{3})\s+(\d+,\d{5})\s+([\d.]+,\d{2})');

  static final _rigaStraordinario = RegExp(
    r'Straordinario[^\n]*\n\s*ORE\s*\n\s*(\d+,\d{3})',
  );

  static final _rigaRetribuzioneOrdinaria = RegExp(
    r'Retribuzione ordinaria[^\n]*\n\s*GIORNI\s*\n\s*(\d+,\d{3})',
  );

  static final _ratesFerie = RegExp(
    r'(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(GIORNI\)',
  );

  static final _ratesRol = RegExp(
    r'\(GIORNI\)\s*\d+,\d{2}\s+(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(ORE\)',
  );

  static final _inps = RegExp(r'INPS([\d.]+,\d{2})\s+(\d,\d{2})(\d+,\d{2})');

  static final _periodo = RegExp(
    r'(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)\s+(\d{4})',
    caseSensitive: false,
  );

  static final _quattordicesima =
      RegExp(r'quattordicesima', caseSensitive: false);
  static final _tredicesima = RegExp(r'tredicesima', caseSensitive: false);

  double _toDouble(String raw) =>
      double.parse(raw.replaceAll('.', '').replaceAll(',', '.'));

  BustaPagaEstratti parse(String testo) {
    final warnings = <String>[];

    // --- periodo ---
    String? periodo;
    final periodoMatch = _periodo.firstMatch(testo);
    if (periodoMatch != null) {
      final mese = _mesi[periodoMatch.group(1)!.toLowerCase()]!;
      final anno = periodoMatch.group(2)!;
      periodo = '$anno-${mese.toString().padLeft(2, '0')}';
    } else {
      warnings.add('periodo non trovato');
    }

    // --- tipo: 13esima/14esima se il testo le nomina esplicitamente,
    // altrimenti mensile. "Quattordicesima" controllata per prima solo per
    // ordine, non per ambiguità: sono parole distinte, nessun rischio di
    // falsi positivi incrociati. ---
    final tipo = _quattordicesima.hasMatch(testo)
        ? TipoBustaPaga.quattordicesima
        : _tredicesima.hasMatch(testo)
            ? TipoBustaPaga.tredicesima
            : TipoBustaPaga.mensile;

    // --- lordo: somma degli importi di tutte le righe di competenza ---
    double lordo = 0;
    for (final m in _rigaCompetenza.allMatches(testo)) {
      lordo += _toDouble(m.group(3)!);
    }
    if (lordo == 0) warnings.add('lordo non trovato (nessuna riga di competenza riconosciuta)');

    // --- straordinari (ore) ---
    double straordinari = 0;
    final straordinarioMatch = _rigaStraordinario.firstMatch(testo);
    if (straordinarioMatch != null) {
      straordinari = _toDouble(straordinarioMatch.group(1)!);
    }

    // --- ore lavorate: stima da giorni di "Retribuzione ordinaria" × 8 ---
    double? oreLavorate;
    final retribOrdinariaMatch = _rigaRetribuzioneOrdinaria.firstMatch(testo);
    if (retribOrdinariaMatch != null) {
      oreLavorate = _toDouble(retribOrdinariaMatch.group(1)!) * 8;
      warnings.add('ore lavorate stimate da giorni×8, non lette direttamente');
    } else {
      warnings.add('ore lavorate non determinabili');
    }

    // --- ferie / ROL (maturati, goduti, residui) ---
    double ferieMaturate = 0, ferieGodute = 0, ferieResidue = 0;
    final ferieMatch = _ratesFerie.firstMatch(testo);
    if (ferieMatch != null) {
      ferieMaturate = _toDouble(ferieMatch.group(1)!);
      ferieGodute = _toDouble(ferieMatch.group(2)!);
      ferieResidue = _toDouble(ferieMatch.group(3)!);
    } else {
      warnings.add('dati ferie non trovati');
    }

    double rolMaturati = 0, rolGoduti = 0, rolResidui = 0;
    final rolMatch = _ratesRol.firstMatch(testo);
    if (rolMatch != null) {
      rolMaturati = _toDouble(rolMatch.group(1)!);
      rolGoduti = _toDouble(rolMatch.group(2)!);
      rolResidui = _toDouble(rolMatch.group(3)!);
    } else {
      warnings.add('dati ROL non trovati');
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
      final resto = lordo - netto - inpsImporto;
      if (resto > 0.01) {
        trattenute['Altre trattenute (IRPEF + varie)'] = double.parse(resto.toStringAsFixed(2));
      }
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
      oreLavorate: oreLavorate,
      tipo: tipo,
      warnings: warnings,
    );
  }
}
