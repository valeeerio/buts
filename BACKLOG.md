# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Buste Paga

- [ ] **Redesign pagina dettaglio busta paga**

## Budget

## Infrastruttura

## Fatto

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
