---
name: goal-planning
description: Scompone un obiettivo di alto livello indicato dall'utente in task concreti e li aggiunge al backlog del progetto Buts. Usa quando l'utente descrive un obiettivo ampio ("vorrei arrivare a...", "il prossimo traguardo è...") invece di un task puntuale.
---

# goal-planning

Non mantiene un file proprio: il suo unico output è un set di voci aggiunte al
backlog tramite la skill `backlog`.

## Passi

1. Se l'obiettivo indicato dall'utente è vago (es. "voglio migliorare le
   statistiche"), fai le domande di chiarimento necessarie prima di scomporlo —
   non indovinare lo scope.
2. Scomponi l'obiettivo in **3–7 voci concrete e actionable**: ognuna deve poter
   diventare un singolo task per `flutter-dev` o `drift-migration` senza bisogno di
   ulteriore scomposizione. Evita voci generiche tipo "migliorare X".
3. Quando possibile, associa ogni voce a un'area coerente con la struttura del
   backlog (Buste Paga / Budget / Infrastruttura).
4. Invoca la skill `backlog` per aggiungere le voci risultanti, nella sezione
   corretta.
5. Non implementare nulla in questa skill: il suo compito finisce con l'aggiornamento
   del backlog. Se l'utente vuole procedere subito con l'implementazione di una voce,
   segnalalo e passa la mano (es. a `flutter-dev`) invece di continuare qui.

## Output

Mostra all'utente l'elenco delle voci aggiunte (con l'area di appartenenza), non solo
una conferma generica.
