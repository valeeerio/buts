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

## Da fare — in ordine di priorità

1. **Persistenza Drift (SQLite)** — sostituire lo stato in-memory di
   `busteRepositoryProvider`/`BustaPagaMockData` con tabelle reali; poi estendere
   alle 4 aree budget (movimenti, voci ricorrenti, mesi)
   - Skill: `drift-migration` (agent dedicato: `drift-schema-architect`)
2. **Upload PDF/foto busta paga** (`fileOrigine`, oggi sempre `null`) + statistiche
   e grafici dedicati (ferie/ROL/permessi residui nel tempo, ore straordinario)
   - Skill: `flutter-ui-builder` (agent), `design-audit`, `flutter-check`
3. **Dettaglio Conto Principale** — lista movimenti/spese, aggiunta spesa
   - Skill: `new-area-screen`, poi `design-audit` a fine lavoro, `flutter-check` prima di consegnare
4. **Dettaglio Risparmio Principale** — storico versamenti + prelievo con nota obbligatoria
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
5. **Dettaglio Piccolo Risparmio** — stessa logica del Risparmio Principale, fondo separato
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
6. **Dettaglio Impegni Fissi** — lista voci ricorrenti (abbonamenti + costi fissi) con scadenze
   - Skill: `new-area-screen`, `design-audit`, `flutter-check`
7. **Flusso apertura/chiusura mese** — suddivisione manuale netto tra le 4 aree,
   deve leggere il netto da `ultimaBustaPagaProvider` (niente doppio inserimento)
   - Skill: `new-area-screen` o `flutter-ui-builder` a seconda della complessità, `flutter-check`
8. **AI locale on-device per estrazione dati busta paga** — fase successiva, no dipendenze cloud
   - Nessuna skill dedicata ancora — da valutare in fase di progettazione

## Manutenzione ricorrente (da fare periodicamente, non una tantum)

- `design-audit` dopo ogni serie di modifiche UI o prima di una consegna
- `flutter-check` dopo ogni modifica a codice Dart prima di considerare concluso un task
- `drift-migration` ogni volta che si tocca `lib/data/` o lo schema dati cambia
