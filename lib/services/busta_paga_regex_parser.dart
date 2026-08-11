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
  // contrattuale, Straordinario per fascia, ecc.): descrizione in chiaro,
  // seguita dal tag "GIORNI"/"ORE", seguita dalla quantità (3 decimali) ed
  // eventualmente da tariffa (2-5 decimali, scartata) e importo (2 decimali,
  // con eventuale separatore delle migliaia "."). Tollerante a whitespace
  // generico (spazi O newline, `\s*`/`\s+`) tra questi elementi: verificato
  // che il testo reale estratto da `syncfusion_flutter_pdf` per questo
  // layout separa descrizione/tag/quantità con newline (CRLF), ma la
  // regex non fa più affidamento su un newline letterale per restare
  // robusta anche se il layout linearizza diversamente in altri casi. Il
  // gruppo descrizione (`[^\n]+?`, non-greedy) è generico — cattura
  // qualunque testo fino al tag GIORNI/ORE più vicino sulla stessa riga —
  // e validato sul campione di PDF reali disponibile: potrebbe richiedere
  // aggiustamenti su layout mai visti finora.
  static final _rigaVoceCompetenza = RegExp(
    r'([^\n]+?)\s*(?:GIORNI|ORE)\s*(\d+,\d{3})'
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

  // NOTA (bug noto, non ancora corretto qui): come per `_ratesExFestivita`
  // sotto, se il "Goduto" del mese è zero il cedolino lascia la cella VUOTA
  // invece di stampare "0,00" — il blocco avrebbe quindi solo 3 numeri reali
  // (invece di maturato/goduto/residuo) i cui primi due sarebbero in realtà
  // [residuo A.P., maturato], con goduto implicito a zero. Non applicato qui
  // perché non riprodotto su un PDF reale per Ferie in questa sessione (a
  // differenza di Ex festività) e perché `_ratesRol` richiede una struttura a
  // 4 numeri fissa (vedi sotto) che renderebbe la disambiguazione più
  // invasiva da verificare senza un caso reale — da rivedere in una sessione
  // futura se si osserva lo stesso sintomo.
  static final _ratesFerie = RegExp(
    r'(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(GIORNI\)',
  );

  // NOTA (bug noto, non ancora corretto qui): a differenza di `_ratesFerie`
  // e `_ratesExFestivita`, questa regex assume sempre esattamente 4 numeri
  // tra "(GIORNI)" e "(ORE)" (il primo, il residuo anno precedente, scartato
  // senza cattura) — se un mese avesse "Goduto" a zero e quindi cella vuota
  // (stesso rischio descritto sopra per `_ratesFerie` e in
  // `_ratesExFestivita`), il blocco avrebbe solo 3 numeri e questa regex non
  // troverebbe alcun match (nessun dato ROL estratto), non un dato errato.
  // Non riprodotto su un PDF reale in questa sessione: da rivedere in una
  // sessione futura se si osserva il sintomo.
  static final _ratesRol = RegExp(
    r'\(GIORNI\)\s*\d+,\d{2}\s+(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(ORE\)',
  );

  // Terzo blocco ratei "EX FESTIVITA'" (vedi intestazione tabella nel PDF:
  // FERIE / PERMESSI (R.O.L.) / EX FESTIVITA'), stessa struttura
  // maturato/goduto/residuo di ferie/ROL. Cercato SOLO nel testo subito dopo
  // la fine del match ROL (non con un regex libero su tutto il documento)
  // per evitare di agganciare tag "(ORE)" di sezioni successive non
  // correlate — stesso principio di scoping già usato per le trattenute
  // verificate.
  //
  // Il blocco reale può presentarsi in due forme distinte, entrambe viste su
  // PDF reali:
  // - 4 numeri "residuo A.P., maturato, goduto, residuo totale" — il
  //   gruppo 1 (opzionale) cattura il residuo A.P. che viene scartato, i
  //   gruppi 2/3/4 sono maturato/goduto/residuo;
  // - 3 numeri soli quando il cedolino lascia una cella VUOTA invece di
  //   stampare "0,00" — ambiguo tra due letture (quale cella è vuota), la
  //   disambiguazione aritmetica è fatta in Dart dopo il match (vedi punto
  //   di lettura in `parse()`), non qui nella regex.
  // Il gruppo opzionale è greedy: su un blocco a 4 numeri il primo tentativo
  // di match (a partire dalla posizione del primo numero) cattura sempre
  // correttamente tutti e 4, senza bisogno di backtracking sull'euristica
  // "ultimi 3 prima del tag" usata in precedenza.
  static final _ratesExFestivita = RegExp(
    r'(?:(\d+,\d{2})\s+)?(\d+,\d{2})\s+(\d+,\d{2})\s+(\d+,\d{2})\s*\(ORE\)',
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

  // Ore lavorate reali ("ORE LAV.", campo del blocco "Q.T.A." del
  // cedolino, distinto da "SETT. RETR."/"GG. RETR."/"GG. LAV." sulla
  // stessa riga) — il testo estratto NON mantiene l'adiacenza fisica con
  // l'etichetta della colonna, che compare in un'intestazione lontana dal
  // valore nel documento linearizzato (vedi nota in testa al file). Il
  // valore vero è però riconoscibile, su un PDF reale, come l'unico numero
  // a 2 decimali preceduto da un bordo di parola (non un altro numero) e
  // da un blocco di 2-6 cifre concatenate senza separatore (es. "42623" =
  // settimane retribuite "4" + giorni retribuiti "26" + giorni lavorati
  // "23"): quel blocco di cifre pure, mai preceduto da virgola/punto,
  // distingue questo match dalle cifre dopo la virgola di una tariffa
  // oraria a 5 decimali altrove nel documento (es. "0,34864" letta come
  // "34864" se non si richiedesse il bordo di parola prima del blocco).
  //
  // NON usata su tutto il documento (vedi `parse()`): questo pattern da
  // solo NON è ancorato all'etichetta "ORE LAV."/al blocco Q.T.A. — è solo
  // "un numero a 2 decimali dopo un blocco di 2-6 cifre pure", una forma
  // che potrebbe ripresentarsi altrove per puro caso su un PDF reale mai
  // visto, producendo un valore sbagliato senza alcun warning. Per questo
  // la ricerca in `parse()` è ristretta al segmento di testo tra la fine
  // della riga INPS e "Firma per quietanza" — lo stesso segmento già usato
  // per `_rigaTrattenutaVerificata` — perché il valore "ORE LAV." si trova
  // SEMPRE lì sui PDF reali disponibili (il blocco Q.T.A. con i dati del
  // rateo viene stampato subito prima di "Firma per quietanza"), un
  // ancoraggio riutilizzato piuttosto che una ricerca libera su tutto il
  // documento. Se il segmento non è determinabile (INPS o "Firma per
  // quietanza" assenti) si ripiega sull'intero testo come rete di
  // sicurezza. In entrambi i casi, se il pattern matcha più di una volta
  // nello scope di ricerca, è un segnale che l'ancoraggio è debole per quel
  // documento: non si prende il primo match in silenzio, si segnala un
  // warning esplicito e si ricade sulla stima da giorni×8 (vedi `parse()`).
  static final _oreLavorateDirette = RegExp(
    r'(?:^|\s)\d{2,6}\s+(\d+,\d{2})',
  );

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

    // --- anticipati qui (usati anche più sotto per le trattenute) per
    // delimitare lo scope di ricerca di "ore lavorate" subito sotto, vedi
    // commento su _oreLavorateDirette ---
    final inpsMatch = _inps.firstMatch(testo);
    final firmaIndex = testo.indexOf('Firma per quietanza');

    // --- ore lavorate: lette direttamente dal campo "ORE LAV." del blocco
    // Q.T.A. quando riconoscibile, cercando SOLO nel segmento di testo tra
    // la fine della riga INPS e "Firma per quietanza" (vedi commento su
    // _oreLavorateDirette per il perché di questo scoping) — nessun warning
    // in questo ramo, è un dato letto non stimato. Se il pattern matcha più
    // di una volta in quello scope, l'ancoraggio è ambiguo per questo
    // documento: warning esplicito, nessun match preso in silenzio. Un
    // valore implausibile (fuori dal range plausibile di ore mensili),
    // un'ambiguità o l'assenza di un match fa scattare il fallback storico:
    // stima da giorni×8, sommando le quantità di tutte le voci di
    // competenza "Retribuzione ordinaria", con lo stesso warning esplicito
    // di sempre. ---
    double? oreLavorate;
    final segmentoQta =
        (inpsMatch != null && firmaIndex != -1 && firmaIndex > inpsMatch.end)
            ? testo.substring(inpsMatch.end, firmaIndex)
            : testo;
    final oreLavorateMatches =
        _oreLavorateDirette.allMatches(segmentoQta).toList();
    if (oreLavorateMatches.length > 1) {
      warnings.add(
        'ore lavorate: possibile ambiguità nel testo estratto, verifica manualmente',
      );
    } else if (oreLavorateMatches.length == 1) {
      final valore = _toDouble(oreLavorateMatches.first.group(1)!);
      if (valore > 0 && valore <= 300) {
        oreLavorate = valore;
      }
    }
    if (oreLavorate == null) {
      double giorniOrdinari = 0;
      for (final voce in competenze) {
        if (voce.descrizione.trim().toLowerCase().startsWith('retribuzione ordinaria')) {
          giorniOrdinari += voce.quantita;
        }
      }
      if (giorniOrdinari > 0) {
        oreLavorate = giorniOrdinari * 8;
        warnings.add('ore lavorate stimate da giorni×8, non lette direttamente');
      } else {
        warnings.add('ore lavorate non determinabili');
      }
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
        double maturate, godute, residue;
        if (exFestivitaMatch.group(1) != null) {
          // 4 numeri: residuo A.P. (scartato), maturato, goduto, residuo —
          // nessuna ambiguità.
          maturate = _toDouble(exFestivitaMatch.group(2)!);
          godute = _toDouble(exFestivitaMatch.group(3)!);
          residue = _toDouble(exFestivitaMatch.group(4)!);
        } else {
          // Solo 3 numeri: il cedolino ha lasciato una cella vuota invece di
          // stampare "0,00", ambiguo tra due letture — disambiguazione
          // aritmetica (tolleranza per arrotondamenti) tra le due, vedi
          // commento su _ratesExFestivita.
          final n1 = _toDouble(exFestivitaMatch.group(2)!);
          final n2 = _toDouble(exFestivitaMatch.group(3)!);
          final n3 = _toDouble(exFestivitaMatch.group(4)!);
          const tolleranza = 0.05;
          // Bug noto e corretto: quando il "goduto" candidato (n2) è zero,
          // le due condizioni sotto diventano matematicamente identiche
          // (entrambe si riducono a "n3 == n1") — non è più possibile
          // distinguere aritmeticamente quale cella sia realmente vuota
          // (residuo A.P. o goduto). Verificale entrambe esplicitamente
          // (non un semplice if/else in cascata) e, se sono entrambe
          // soddisfatte, non scegliere in silenzio: segnala l'ambiguità.
          final mancaResiduoAP = (n3 - (n1 - n2)).abs() <= tolleranza;
          final mancaGoduto = (n3 - (n1 + n2)).abs() <= tolleranza;
          if (mancaResiduoAP && mancaGoduto) {
            // Nessun segnale testuale affidabile per disambiguare (a
            // differenza del caso "3 vs 4 numeri", qui non c'è un'ancora
            // non numerica da sfruttare): meglio segnalare l'incertezza
            // che sbagliare in silenzio.
            maturate = 0;
            godute = 0;
            residue = 0;
            warnings.add(
              'dati ex festività ambigui: impossibile stabilire quale '
              'cella sia vuota (residuo anno precedente o goduto) quando '
              'il "goduto" candidato è zero, verifica manualmente',
            );
          } else if (mancaResiduoAP) {
            // Manca il residuo A.P. (es. neoassunto senza riporto):
            // [maturato, goduto, residuo].
            maturate = n1;
            godute = n2;
            residue = n3;
          } else if (mancaGoduto) {
            // Manca il goduto (cella vuota = 0,00): [residuo A.P.
            // (scartato), maturato, residuo].
            maturate = n2;
            godute = 0;
            residue = n3;
          } else {
            // Nessuna delle due interpretazioni torna aritmeticamente:
            // tratta come dato implausibile, non indovinare.
            maturate = double.infinity;
            godute = 0;
            residue = 0;
          }
        }
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

    // --- trattenute: INPS letto direttamente, il resto aggregato
    // (inpsMatch calcolato più sopra, riusato anche per lo scoping di "ore
    // lavorate") ---
    final trattenute = <String, double>{};
    double inpsImporto = 0;
    if (inpsMatch != null) {
      inpsImporto = _toDouble(inpsMatch.group(3)!);
      trattenute['INPS'] = inpsImporto;
    } else {
      warnings.add('trattenuta INPS non trovata');
    }

    // --- netto: ultimo numero della riga dopo "Firma per quietanza"
    // (firmaIndex calcolato più sopra) ---
    double? netto;

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
          if (ultimo.startsWith('-')) {
            netto = _toDouble(ultimo.substring(1));
            warnings.add('netto: segno "-" iniziale scartato come probabile artefatto di estrazione, verificare');
          } else {
            netto = _toDouble(ultimo);
          }
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

    // Il valore finale di `netto` è sempre quello derivato (lordo -
    // trattenute, incluso l'eventuale residuo "Altre trattenute" appena
    // calcolato sopra) — non il valore grezzo letto dal PDF, che resta usato
    // solo come input intermedio per calcolare quel residuo e per il
    // controllo di coerenza "netto superiore al lordo" appena sopra.
    final nettoDerivato =
        netto != null ? computeNetto(lordo, trattenute) : null;

    return BustaPagaEstratti(
      periodo: periodo,
      lordo: lordo > 0 ? lordo : null,
      netto: nettoDerivato,
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
