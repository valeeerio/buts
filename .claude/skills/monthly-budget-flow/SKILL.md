---
name: monthly-budget-flow
description: Costruisce o estende il flusso di apertura/chiusura mese di Buts (inserimento netto, suddivisione manuale tra le 4 aree Budget). Task cross-sezione — attraversa sia Buste Paga sia Budget, non rientra nello scope di new-area-screen. Usa quando il task è "implementa il flusso di apertura mese" o "collega il netto della busta paga alla suddivisione budget".
---

# monthly-budget-flow

Obiettivo: costruire/estendere la schermata di apertura mese — inserimento/
conferma del netto (precompilato da `ultimaBustaPagaProvider` se disponibile,
sezione Buste Paga), suddivisione manuale tra Risparmio Principale e Piccolo
Risparmio, riepilogo Impegni Fissi, importo assegnabile al Conto Principale.

Questo task è diverso da `new-area-screen`: non riguarda *una* delle 4 aree, ma
attraversa entrambe le sezioni dell'app (legge da Buste Paga, scrive su Budget).
Non forzarlo dentro lo scaffold di una singola area.

## Passi

1. Leggi `CLAUDE.md`, sezione "Le 4 aree di budget" → "Logica del mese":
   `Netto mensile − Impegni Fissi − versamento Risparmio Principale − versamento
   Piccolo Risparmio = importo assegnabile al Conto Principale`. La suddivisione
   resta **manuale** in v1 — non introdurre calcolo automatico/AI dello split.
2. Provider da collegare (entrambi già esistenti, non crearne di nuovi):
   - `ultimaBustaPagaProvider` (`lib/providers/buste_paga_provider.dart`) per il
     netto di partenza — precompilato ma modificabile dall'utente, non un valore
     bloccato.
   - `totaleImpegniFissiProvider` (`lib/providers/aree_budget_provider.dart`) per
     il totale Impegni Fissi in sola lettura (mai un campo editabile: è calcolato).
   - `mesiBudgetRepositoryProvider` per leggere/scrivere il `MeseBudgetTableData`
     del mese corrente (`.notifier.aggiungi(...)` per un nuovo mese,
     `.notifier.aggiorna(...)` per modificarne uno esistente).
   - `AreeBudgetRepository.importoContoPrincipale(mese, totaleImpegniFissi)` per il
     calcolo finale — mai duplicare quella formula nella UI.
3. Delega l'implementazione all'agent `flutter-ui-builder`, specificando
   esplicitamente che è un task cross-sezione (naviga/legge da entrambe le
   sezioni, non va inserito nello scaffold di una singola area) e passandogli i
   provider del punto 2.
4. Dopo l'implementazione, esegui la skill `flutter-check`.
5. Facoltativo ma consigliato: invoca l'agent `design-consistency-reviewer` sui
   file modificati prima di consegnare.
