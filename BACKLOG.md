# Backlog Buts

Traccia lo stato di avanzamento dello sviluppo. Aggiornare ad ogni sessione di
lavoro: spostare le voci tra le sezioni, non cancellarle (storico utile).
Contesto di prodotto/stile completo in `CLAUDE.md`.

Legenda skill: skill di Claude Code da invocare per quel task (vedi
`.claude/skills` o l'elenco skill disponibili in sessione).

## Buste Paga

## Budget

## Infrastruttura

## Analisi tecnica (2026-08-03)

Note emerse da una revisione dello script di parsing PDF e della schermata
Statistiche — non sono task spuntabili, solo materiale da cui aprire
eventuali task in una sessione futura, quando/se l'utente deciderà di
intervenire.

**Parser regex** (`lib/services/busta_paga_regex_parser.dart`, tarato sul
solo layout del software paghe "JOB"):
- Righe multiple "Straordinario"/"Retribuzione ordinaria": il parser
  prende solo il primo match (`firstMatch`) — buste con più voci
  straordinario (es. diurno+notturno) perdono dati silenziosamente, senza
  warning.
- Straordinari mancanti non generano warning, a differenza di tutti gli
  altri campi estratti — incoerenza.
- Nessuna validazione incrociata tra campi (es. netto > lordo, ferie
  residue negative, somma trattenute non coerente con lordo-netto) —
  il candidato più concreto per un futuro task leggero di warning
  aggiuntivi nel parser, se si vorrà aprirlo.
- Gap di copertura in `test/busta_paga_regex_parser_test.dart`: nessun
  test con "tredicesima"/"quattordicesima" esplicite nel testo (solo il
  percorso di deduzione dal mese è testato), nessun test per i warning
  `periodo`/`lordo`/`INPS`/`netto non trovato` singolarmente, nessun test
  per il calcolo di "Altre trattenute (IRPEF+varie)", nessun test con
  righe multiple Straordinario/Ordinario, nessun test di integrazione con
  un PDF reale (solo testo sintetico).

**Statistiche — campi del modello mai visualizzati** (nessuna decisione
presa su quali implementare, elenco di candidati per una futura sessione
dedicata): `trattenute` (mappa INPS + "Altre trattenute IRPEF+varie", mai
mostrata nel tempo), `ferieMaturate`/`ferieGodute` (solo il residuo è
mostrato oggi), `rolMaturati`/`rolGoduti` (idem), `oreLavorate` (stimato
dal parser ma mai graficato). Quando si deciderà di espandere Statistiche,
l'utente li vuole descritti come task pronti da implementare — stesso
pattern dei 3 grafici esistenti (LineChart/BarChart + tabella
riepilogativa sotto) — non come mockup preliminari da validare prima.

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
