---
name: new-area-screen
description: Scaffolda o estende la schermata di dettaglio di una delle 4 aree di budget di Buts (Conto Principale, Risparmio Principale, Piccolo Risparmio, Impegni Fissi), seguendo la struttura già usata nel progetto. Usa quando il task è "implementa il dettaglio dell'area X" al posto del PlaceholderScreen attuale.
---

# new-area-screen

Obiettivo: sostituire il `PlaceholderScreen` di una delle 4 aree
(`lib/screens/<area>/`) con una schermata di dettaglio reale, coerente con
`CLAUDE.md` e con gli stili già stabiliti.

## Passi

1. Leggi `CLAUDE.md` nella root per i requisiti specifici dell'area da implementare
   (sezione "Cosa manca", punto 1) e `lib/models/area_type.dart` per colore/etichetta
   dell'area.
2. Identifica quale contenuto serve in base al tipo di area, e collega il provider
   Riverpod già esistente in `lib/providers/aree_budget_provider.dart` — Drift è già
   collegato per le 4 aree, non è più mock:
   - **Conto Principale**: lista transazioni/movimenti di spesa, ordinate per data —
     da `movimentiAreaRepositoryProvider` (lista `MovimentoAreaTableData`, filtrata
     per `areaId`), scrittura tramite `movimentiAreaRepositoryProvider.notifier.aggiungi(...)`.
   - **Risparmio Principale** / **Piccolo Risparmio**: storico versamenti da
     `movimentiAreaRepositoryProvider` (stesso pattern), con azione di prelievo. Il
     vincolo "nota obbligatoria sul prelievo" è **già imposto dal repository**
     (`AreeBudgetRepository.aggiungiMovimento` lancia `MovimentoAreaNonValido` se
     manca la nota su un prelievo da queste due aree): la UI deve catturare e
     mostrare quell'eccezione (es. alert Cupertino), non reimplementare la
     validazione lato client.
   - **Impegni Fissi**: lista delle voci ricorrenti attive da
     `vociRicorrentiRepositoryProvider`, con le scadenze più vicine in evidenza;
     totale sempre da `totaleImpegniFissiProvider` (mai calcolarlo a mano nella UI,
     è già un provider derivato — non è una colonna persistita).
3. `DashboardMockData` (`lib/models/dashboard_area_summary.dart`) resta rilevante
   solo per l'item separato "Collegare Dashboard ai dati reali" (riepilogo aggregato
   con sparkline/variazione %), non per il dettaglio di una singola area: qui i dati
   vengono sempre dai provider del punto 2, mai da dati mock.
4. Delega l'implementazione vera e propria all'agent `flutter-dev` (Task/Agent
   tool), passandogli: quale area, quale contenuto secondo il punto 2, e il vincolo di
   riusare i design token esistenti.
5. Dopo l'implementazione, esegui la skill `flutter-check` per verificare che il
   progetto compili e i test passino.
6. Facoltativo ma consigliato: invoca l'agent `design-consistency-reviewer` sui file
   modificati per controllare l'aderenza allo stile prima di consegnare.

Non introdurre navigazione aggiuntiva nella tab bar: la schermata resta raggiunta come
oggi, tramite tap sulla `AreaSummaryCard` corrispondente nella Dashboard della sezione
Budget (non nella sezione Buste Paga, di pari livello ma separata).
