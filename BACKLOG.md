# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Buste Paga

- [ ] **Uniformare stile etichetta "colonna" tra hero Archivio e dettaglio**:
      le intestazioni Ferie/ROL/Ore nell'hero (`BustaPagaSummaryHero` in
      `lib/widgets/busta_paga_summary_hero.dart`) usano
      `AppTextStyles.subtitle` (15px, w700), mentre "Maturato/Goduto/Residuo"
      nel dettaglio (`_tableHeaderRow` in
      `lib/widgets/busta_paga_maturazioni_section.dart`) usano
      `AppTextStyles.cardLabel` (12px, w700) — stesso ruolo semantico
      (etichetta di colonna sopra un valore), basi tipografiche diverse.

## Budget

## Infrastruttura

## Fatto

Storico compresso il 2026-08-02 — dettaglio recuperabile dai commit Git su
`main`. Riassunto dei blocchi di lavoro completati fin qui: seed mock
rimosso e sostituito da import PDF reale con parser regex dedicato;
introduzione del tipo mensilità (mensile/13esima/14esima) nel modello, nel
parser e nelle statistiche; redesign completo in stile "Liquid Glass" di
Archivio, hero, dettaglio e Statistiche; passaggio della modifica busta
paga da un form separato a editing inline nel dettaglio; estrazione dei
widget condivisi tra dettaglio e form di import; redesign dei popup in
stile flat coerente con la sotto-navigazione; fix del tracking dello
slider di periodo. Vedi `CLAUDE.md` per lo stato architetturale attuale.

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
