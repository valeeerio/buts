# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Buste Paga

- [ ] **Redesign Archivio (pagina principale)**
- [ ] **Redesign pagina dettaglio busta paga**
- [ ] **Separazione nella sidebar inferiore tra il "+" e le due sezioni**
      (Archivio/Statistiche) — oggi sono tutti e tre nella stessa
      `LiquidGlassSurface` (`_BustePagaSidecar` in
      `buste_paga_section_screen.dart`), da distinguere visivamente/
      strutturalmente.

## Budget

## Infrastruttura

## Fatto

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
