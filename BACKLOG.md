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

## Da fare — in ordine di priorità

1. **Upload PDF/foto busta paga** (`fileOrigine`, oggi sempre `null`) + statistiche
   e grafici dedicati (ferie/ROL/permessi residui nel tempo, ore straordinario)
   - Skill: `flutter-ui-builder` (agent), `design-audit`, `flutter-check`
2. **Dettaglio Conto Principale** — lista movimenti/spese, aggiunta spesa; collega
   `aree_budget_provider.dart` invece dei soli dati mock
   - Skill: `new-area-screen`, poi `design-audit` a fine lavoro, `flutter-check` prima di consegnare
3. **Dettaglio Risparmio Principale** — storico versamenti + prelievo con nota obbligatoria
   (vincolo già applicato in `AreeBudgetRepository.aggiungiMovimento`)
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
4. **Dettaglio Piccolo Risparmio** — stessa logica del Risparmio Principale, fondo separato
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
5. **Dettaglio Impegni Fissi** — lista voci ricorrenti (abbonamenti + costi fissi) con scadenze;
   collega `vociRicorrentiRepositoryProvider`/`totaleImpegniFissiProvider`
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
6. **Collegare Dashboard ai dati reali delle 4 aree** — sostituire `DashboardMockData`
   con `aree_budget_provider.dart`, decidendo come derivare sparkline/variazione %
   dai movimenti grezzi (rimandato esplicitamente dal task schema Drift)
   - Skill: `flutter-check`
7. **Flusso apertura/chiusura mese** — suddivisione manuale netto tra le 4 aree,
   deve leggere il netto da `ultimaBustaPagaProvider` (niente doppio inserimento),
   scrive su `mesiBudgetRepositoryProvider`
   - Skill: `monthly-budget-flow` (nuova, task cross-sezione Buste Paga↔Budget),
     poi `flutter-check`
8. **AI locale on-device per estrazione dati busta paga** — fase successiva, no dipendenze cloud
   - Nessuna skill dedicata ancora — da valutare in fase di progettazione

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
