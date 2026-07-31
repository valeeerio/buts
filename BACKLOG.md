# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Buste Paga

- [ ] **Uniformare stile etichetta "colonna" tra hero Archivio e dettaglio**:
      le intestazioni Ferie/ROL/Ore nell'hero (`lib/widgets/
      busta_paga_summary_hero.dart:66-88`) usano `AppTextStyles.subtitle`
      (15px, w700), mentre "Maturato/Goduto/Residuo" nel dettaglio busta
      paga (`_tableHeaderRow` in `busta_paga_detail_screen.dart`) usano
      `AppTextStyles.cardLabel` (12px, w700) — stesso ruolo semantico
      (etichetta di colonna sopra un valore), basi tipografiche diverse.
      Emerso da audit di coerenza whole-project del 2026-07-31.
- [ ] **Sostituire i `TextStyle(...)` scritti a mano in
      `busta_paga_form_screen.dart`** (righe 305-309, 335, 440) con token
      `AppTextStyles.*.copyWith(...)`, pattern usato ovunque nel resto del
      codebase — unico file dove compaiono stili non derivati dal catalogo.
      Emerso da audit di coerenza whole-project del 2026-07-31.

## Budget

## Infrastruttura

## Fatto

- [x] **Modifica inline nel dettaglio busta paga** (2026-07-31, branch
      `dettagli-buste-paga`, merged in `main`): "Modifica" non apre più
      `BustaPagaFormScreen` — le stesse card del dettaglio (hero Netto,
      periodo, `_StatRow` Ferie/ROL/Ore e Lordo/Straordinari, tabella
      Maturazioni, Trattenute con swipe-to-delete al posto del bottone
      "meno") diventano editabili sul posto, stesso layout della vista di
      sola lettura. "Conferma" mostra un popup "Dati confermati"; "Salva"
      calcola un diff dei campi cambiati e mostra un popup di riepilogo
      prima di applicare (con reset automatico a "Da confermare" se la
      busta era "Confermata"); "Annulla" scarta le modifiche.
      `BustaPagaFormScreen` ora usata solo per l'import PDF (`.daImport`,
      rimossa la modalità "existing"). La schermata è `ConsumerStatefulWidget`.
      Hero card fissa in alto fuori dallo scroll, resto del contenuto con
      scroll naturale e una leggera dissolvenza finale verso la barra
      flottante (abbandonato un precedente approccio a `ShaderMask` su
      tutto il viewport, che non garantiva lo stesso effetto percepito
      dell'Archivio per via di viewport di altezza diversa tra le due
      schermate). Fix contestuali da design-audit: touch target 44×44pt sul
      bottone rimuovi-trattenuta del form, nuovo token
      `AppTextStyles.heroAmount` al posto di un `fontSize` hardcoded.
- [x] **Redesign pagina dettaglio busta paga** (2026-07-31, branch
      `dettagli-buste-paga`): hero con badge di stato (verde/rosso, stessa
      semantica del pallino in Archivio), riga di mini-statistiche
      Ferie/ROL/Ore lavorate e riga Lordo/Straordinari unificate in
      un'unica `LiquidGlassSurface` a scomparti (`_StatRow`, fix di un bug
      di rendering con `BackdropFilter` multipli ravvicinati — vedi sotto),
      tabella unica "Ferie, ROL e permessi" (Maturato/Goduto/Residuo) al
      posto di 3 sezioni separate, chip documento PDF tappabile, sezioni
      Trattenute senza più titoli ridondanti sopra la card. Aggiunta una
      barra flottante in basso con "Conferma" (solo se stato "Da
      confermare") e "Modifica" (spostata qui dalla nav bar in alto); la
      schermata ora è `ConsumerWidget` e legge sempre lo stato corrente dal
      provider, aggiornandosi subito dopo conferma o modifica.
- [x] **Fix bug visivo `LiquidGlassSurface` con più superfici di vetro
      affiancate** (2026-07-31): card ravvicinate (es. mini-statistiche in
      riga) mostravano una "cucitura" netta per via di `BackdropFilter`
      multipli a pochi pixel di distanza. Corretto a livello di
      composizione — mai più superfici di vetro affiancate, ma un'unica
      `LiquidGlassSurface` con scomparti interni piatti separati da un
      divisore sottile (pattern già usato dalla sidecar, esteso a
      `_StatRow` nel dettaglio). Contestualmente irrobustito anche il
      riempimento a gradiente di `LiquidGlassSurface`: calcolato ora via
      `CustomPaint` sulla `size` reale invece che sulle constraints di
      layout (che possono essere illimitate dentro `ListView`/`Row`).
- [x] **Nuovo componente condiviso `FlatChipButton`**
      (`lib/widgets/flat_chip_button.dart`, 2026-07-31): chip piatto
      icona+testo senza vetro, con stato `filled` per differenziare
      selezionato/non selezionato. Uniforma lo stile dei bottoni
      "Conferma"/"Modifica" nel dettaglio busta paga e dei tab
      Archivio/Statistiche nella sidecar in basso (che prima usava una
      `LiquidGlassSurface` con highlight animato che scorreva dietro il
      tab attivo) — decisione esplicita dell'utente di estendere questo
      stile a tutta la sotto-navigazione.
- [x] **Redesign Archivio (pagina principale)** (2026-07-31): barra di
      ricerca per periodo (mese/anno) nel titolo, raggruppamento delle
      buste paga per anno con header sticky fluido (`flutter_sticky_header`,
      transizione di sovrapposizione tra un anno e l'altro durante lo
      scroll), swipe-to-delete con alert di conferma su ogni busta paga.
- [x] **Redesign hero "ultima busta paga"** (2026-07-31): pallino di stato
      verde/rosso, mese in grassetto, netto e residui Ferie/ROL/Ore
      allineati geometricamente (baseline).
- [x] **Redesign card riga busta paga nell'elenco** (2026-07-31): pallino di
      stato, mese in grassetto, netto in evidenza.
- [x] **Separazione nella sidebar inferiore tra il "+" e le due sezioni**
      (2026-07-31) — dopo varie iterazioni (incavo "a puzzle", poi
      abbandonato per un bug visivo nel materiale vetro non risolto):
      pillola Archivio/Statistiche con indicatore di sezione attiva che
      scorre animato, "+" separato con lo stesso blu di sistema.
- [x] **Colore blu di sistema (`AppColors.systemBlue`) come colore
      standard di tutti i bottoni/CTA dell'app** (2026-07-31): lente di
      ricerca, picker periodo e "Aggiungi voce" nel form, "Salva",
      condivisione PDF nel dettaglio, "+" e indicatore sezione attiva
      nella sidebar.
- [x] **Fix bug dark/light mode: header sticky dell'anno restava coi
      colori della luminosità precedente** (2026-07-31).
- [x] **Fix bug visivo nel materiale `LiquidGlassSurface`**: il gradiente
      diagonale diventava quasi orizzontale su superfici larghe e basse,
      letto come "riempimento non pieno" (2026-07-31).
- [x] **Rimozione del seed automatico di dati mock** all'avvio con
      archivio vuoto; aggiunti bottoni debug-only (solo `kDebugMode`) per
      inserire/rimuovere dati di prova reali dall'archivio (2026-07-31).

## Decisioni archiviate (non da rimettere in discussione senza motivo nuovo)

- **AI locale on-device per estrazione dati busta paga — abbandonata
  (2026-07-30)**. Alla luce di quanto emerso nella sessione odierna,
  l'utente ha deciso di abbandonare l'idea. Il parser regex
  (`lib/services/busta_paga_regex_parser.dart`, mirato al layout del
  software paghe "JOB") resta l'unico meccanismo di precompilazione dati da
  PDF, nessun piano di sostituirlo con un modello locale.

## Manutenzione ricorrente (da fare periodicamente, non una tantum)

- `design-audit` dopo ogni serie di modifiche UI o prima di una consegna
- `flutter-check` dopo ogni modifica a codice Dart prima di considerare concluso un task
- `drift-migration` ogni volta che si tocca `lib/data/` o lo schema dati cambia
