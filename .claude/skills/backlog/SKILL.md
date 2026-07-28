---
name: backlog
description: Legge e aggiorna BACKLOG.md nella root del progetto Buts — l'elenco di task/feature da fare. Usa quando l'utente vuole vedere, aggiungere, completare o riordinare voci di backlog.
---

# backlog

## File

`BACKLOG.md` nella root del progetto. Se non esiste ancora, crealo al primo utilizzo
con questa struttura:

```markdown
# Backlog

## Buste Paga

## Budget

## Infrastruttura

## Fatto
```

Ogni voce è una checklist item: `- [ ] descrizione breve e concreta`. Le voci senza
un'area chiara vanno sotto "Infrastruttura".

## Regole

1. **Non inventare voci.** Aggiungi solo ciò che l'utente chiede esplicitamente o
   ciò che ti passa la skill `goal-planning` dopo aver scomposto un obiettivo.
2. **Completare una voce**: sposta la checkbox a `- [x]` e spostala nella sezione
   "Fatto" invece di cancellarla — serve da storico di cosa è stato fatto e quando
   (puoi aggiungere la data tra parentesi se disponibile dal contesto).
3. **Non riordinare o riformulare** voci esistenti senza che l'utente lo chieda:
   se una voce è ambigua, chiedi prima di modificarla.
4. Quando l'utente chiede "cosa c'è in backlog" o simili, mostra il contenuto delle
   sezioni non vuote così come sono, senza commenti aggiuntivi non richiesti.
5. Se `CLAUDE.md` ha una sezione "Cosa manca" più aggiornata del backlog, segnalalo
   invece di sovrascrivere silenziosamente una delle due fonti.
