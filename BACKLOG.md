# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Fatto

- [x] Scaffold progetto Flutter (Cupertino, iOS target primario)
- [x] Design tokens: `theme/app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart`
- [x] `AreaType` (4 aree budget) con colori/etichette/logica variazione favorevole
- [x] Navigazione: tab bar 5 destinazioni + `RootScaffold` — skill: `new-area-screen` (per estendere le route)
- [x] Dashboard completa: header saluto, `DonutSummary`, `InsightCard`, 4× `AreaSummaryCard` (dati mock)
- [x] Pulizia ambiente (2026-07-28): rimosse piattaforme non-iOS (android/macos/linux/windows/web),
      cache `build/`, `.DS_Store`, fix bug locale `it_IT` non inizializzato in `main.dart`,
      fix test boilerplate non aggiornato, import inutilizzati
- [x] Pivot prodotto (2026-07-28): Buste Paga diventa la funzione primaria/sezione di
      apertura, gestione budget (4 aree) diventa sezione "Budget" separata di pari
      livello. Navigazione a 2 sezioni con swipe + freccia header
      (`app_root_scaffold.dart`, `app_section.dart`, `app_section_provider.dart`,
      `app_section_header.dart`). Introdotto Riverpod (`ProviderScope` in `main.dart`).
- [x] Modello dati `BustaPaga` (tutti i campi da piano_progetto §5) + provider
      in-memory (`busta_paga.dart`, `busta_paga_mock_data.dart`, `buste_paga_provider.dart`)
- [x] Schermate sezione Buste Paga: archivio + hero ultima busta paga
      (`buste_paga_section_screen.dart`), form inserimento/modifica completo
      (`busta_paga_form_screen.dart`), dettaglio (`busta_paga_detail_screen.dart`)
- [x] Collegamento dati Buste Paga → Budget: `ultimaBustaPagaProvider` letto in
      `dashboard_screen.dart` (netto visibile sotto il sottotitolo mese)
- [x] Persistenza Drift (2026-07-28): `lib/data/database.dart` (`AppDatabase`,
      tabella `BustePagaTable`, `TrattenuteConverter` JSON per la mappa trattenute,
      `schemaVersion = 1`). `busteRepositoryProvider`/`ultimaBustaPagaProvider`
      invariati nella firma pubblica, ora backed da SQLite invece che in-memory;
      seed una tantum da `BustaPagaMockData` solo se la tabella è vuota.
- [x] Schema Drift 4 aree Budget (2026-07-28, branch `feature/drift-budget-areas`):
      `AreaTable`, `MovimentoAreaTable`, `VoceRicorrenteTable`, `MeseBudgetTable` in
      `lib/data/database.dart` (`schemaVersion = 2`, migrazione non distruttiva da
      v1). Nota obbligatoria sui prelievi da Risparmio Principale/Piccolo Risparmio
      applicata a livello di repository (`AreeBudgetRepository.aggiungiMovimento`),
      totale Impegni Fissi e importo Conto Principale calcolati (non colonne). Provider
      Riverpod in `lib/providers/aree_budget_provider.dart`. **Non collegato alla
      Dashboard** (`DashboardMockData` invariato): rimandato al task "dettaglio aree",
      dove andrà deciso come derivare sparkline/variazione % dai movimenti grezzi.

## Focus attuale (dal 2026-07-28): solo Buste Paga

Sviluppo concentrato esclusivamente sulla sezione Buste Paga, branch
`feature/buste-paga`. Tre fasi, **in quest'ordine**: struttura/stile → import
PDF → AI locale per l'estrazione. Gli item relativi alla sezione Budget sono
in pausa (sezione "In pausa" più sotto, non cancellati).

- [x] **Fase 1 — Struttura e stile sezione Buste Paga** (2026-07-28): sotto-
      navigazione a tab (`CupertinoSlidingSegmentedControl`) Archivio/
      Statistiche in `buste_paga_section_screen.dart`; Archivio estratto in
      `buste_paga_archivio_view.dart`; nuova `buste_paga_statistiche_screen.dart`
      con 3 grafici `fl_chart` (netto/lordo, ferie/ROL/permessi residui,
      straordinario per mese) da `busteRepositoryProvider`, empty state se
      < 2 buste paga. Nuovi componenti riutilizzabili `lib/widgets/
      material_surface.dart` (blur/vibrancy, applicato alla hero card) e
      `lib/widgets/spring_button.dart` (pressione a molla, applicato al CTA
      "+" e al bottone "Salva" del form). `flutter analyze`/`flutter test`
      puliti, verificato su simulatore iOS.

- [x] **Fase 2 — Import PDF busta paga** (2026-07-28): `lib/services/
      pdf_import_service.dart` — selezione con `file_selector` (non
      `file_picker`: tirava dentro l'intera libreria DKImagePickerController/
      SDWebImage/TOCropViewController via SPM, inutile per un semplice
      selettore PDF — sostituito durante l'implementazione), validazione
      testo estraibile via `syncfusion_flutter_pdf` (PDF scansionati →
      errore chiaro, niente OCR), copia in `buste_paga_pdf/` nella
      application documents directory. Form: sezione "Documento"
      (allega/rimuovi, popola `fileOrigine`). Dettaglio: riga file con
      apertura via `share_plus` (foglio di condivisione di sistema, nessun
      visualizzatore PDF in-app). `flutter analyze`/`flutter test` puliti,
      verificato su simulatore iOS (incluso il primo build con le nuove
      dipendenze native).

3. **AI locale on-device per estrazione dati busta paga** — solo estrazione
   campi da documento (precompilazione form editabile, mai salvataggio senza
   conferma utente), non insight statistici. Nessuna chiamata cloud, nessun
   costo ricorrente, aumento di peso app (500MB–2GB) accettato. Il testo
   estratto dal PDF (già disponibile da `pdf_import_service.dart`) è pronto
   per essere passato al modello locale.

   **Decisione tecnica presa (2026-07-28)**, dopo ricerca mirata: libreria
   `llama_cpp_dart` (FFI su llama.cpp, xcframework iOS precompilato via CI,
   inferenza in isolate dedicato). Scartate le alternative:
   - **Apple Foundation Models** (nativo, zero peso extra, output tipizzato
     via `@Generable`) — non praticabile: richiede hardware Apple
     Intelligence (iPhone 15 Pro+/16+, A17 Pro o superiore), device di
     sviluppo/uso è un iPhone 14 Pro, non compatibile.
   - **fllama** — meno maturo, problemi Metal/SIMD segnalati su alcuni
     device, preferito `llama_cpp_dart` per lo xcframework precompilato.
   - **Google MediaPipe LLM Inference** — dichiarata da Google in
     maintenance-only su iOS, sconsigliata per nuovo sviluppo.

   Modello candidato: uno tra Llama 3.2 1B/3B, Gemma 2/3 2B, Phi-3.5-mini,
   Qwen2.5 1.5B/3B, quantizzazione GGUF Q4_K_M — scelta finale e verifica
   licenza da fare in fase di implementazione (Llama 3.2 ha restrizioni EU
   solo sui modelli multimodali, non sui 1B/3B testuali; Gemma/Qwen2.5
   licenze permissive per uso locale). Output vincolato via grammatica GBNF
   di llama.cpp (JSON Schema→GBNF nativo) per evitare JSON malformato.

   **Rischi aperti da verificare in fase di implementazione**: qualità
   reale di estrazione JSON su testo di busta paga italiana non garantita a
   priori, richiede un giro di validazione empirica con più modelli/prompt
   prima di fissare la scelta finale.
   - Nessuna skill dedicata ancora — da creare quando si affronta l'implementazione

## In pausa — riprendere dopo Buste Paga (non cancellati)

4. **Dettaglio Conto Principale** — lista movimenti/spese, aggiunta spesa; collega
   `aree_budget_provider.dart` invece dei soli dati mock
   - Skill: `new-area-screen`, poi `design-audit` a fine lavoro, `flutter-check` prima di consegnare
5. **Dettaglio Risparmio Principale** — storico versamenti + prelievo con nota obbligatoria
   (vincolo già applicato in `AreeBudgetRepository.aggiungiMovimento`)
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
6. **Dettaglio Piccolo Risparmio** — stessa logica del Risparmio Principale, fondo separato
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
7. **Dettaglio Impegni Fissi** — lista voci ricorrenti (abbonamenti + costi fissi) con scadenze;
   collega `vociRicorrentiRepositoryProvider`/`totaleImpegniFissiProvider`
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
8. **Collegare Dashboard ai dati reali delle 4 aree** — sostituire `DashboardMockData`
   con `aree_budget_provider.dart`, decidendo come derivare sparkline/variazione %
   dai movimenti grezzi (rimandato esplicitamente dal task schema Drift)
   - Skill: `flutter-check`
9. **Flusso apertura/chiusura mese** — suddivisione manuale netto tra le 4 aree,
   deve leggere il netto da `ultimaBustaPagaProvider` (niente doppio inserimento),
   scrive su `mesiBudgetRepositoryProvider`
   - Skill: `monthly-budget-flow` (task cross-sezione Buste Paga↔Budget),
     poi `flutter-check`

## Decisioni archiviate (non da rimettere in discussione senza motivo nuovo)

- **Restyling ispirato a shadcn/ui — declinato (2026-07-28)**. Valutato con una
  demo comparativa diretta (bottone Apple/Cupertino con materiali/vibrancy +
  colore dinamico + fisica a molla, vs bottone shadcn/ui con superfici piatte e
  bordi). L'utente ha confermato di restare sullo stile Apple/Cupertino nativo
  già in CLAUDE.md — nessuna azione richiesta, stack e design system invariati.

## Manutenzione ricorrente (da fare periodicamente, non una tantum)

- `design-audit` dopo ogni serie di modifiche UI o prima di una consegna
- `flutter-check` dopo ogni modifica a codice Dart prima di considerare concluso un task
- `drift-migration` ogni volta che si tocca `lib/data/` o lo schema dati cambia
