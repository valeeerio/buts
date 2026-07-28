---
name: drift-migration
description: Guida la creazione o modifica di tabelle Drift (SQLite) nel progetto Buts, ricordando lo schema versionato con migrazioni non distruttive e il comando build_runner corretto. Usa quando il task tocca lib/data/ o richiede un cambiamento allo schema dati.
---

# drift-migration

## Quando una modifica di schema è richiesta

Prima di modificare tabelle Drift, delega la progettazione dello schema all'agent
`flutter-dev` se la modifica non è banale (nuova tabella, nuova relazione,
cambio di tipo di colonna con dati esistenti). Per aggiunte semplici (nuova colonna
nullable, nuovo indice) puoi procedere direttamente seguendo i punti sotto.

## Regole di migrazione

1. Ogni cambiamento allo schema richiede l'incremento di `schemaVersion` nella classe
   `@DriftDatabase` e l'aggiunta della logica corrispondente in `onUpgrade` (mai
   `onCreate` riscritto da zero se il DB può già contenere dati utente).
2. Mai proporre un reset/drop del database come soluzione a un problema di schema,
   salvo richiesta esplicita dell'utente — i dati sono locali e non c'è backup cloud
   (v1 dell'app, nessun account/sync).
3. Rispetta i vincoli di business già noti: i prelievi da Risparmio Principale/Piccolo
   Risparmio richiedono sempre una nota obbligatoria — se questo è modellato come
   colonna, deve essere NOT NULL o validato a livello di repository, non solo in UI.
4. Impegni Fissi non ha una tabella di "versamenti": è calcolato come somma delle voci
   ricorrenti attive, non salvarlo come valore denormalizzato senza una ragione tecnica
   esplicita (rischio di disallineamento).

## Dopo la modifica

Esegui sempre, dalla root del progetto:
```
flutter pub run build_runner build --delete-conflicting-outputs
```
per rigenerare i file `.g.dart`. Questo comando è sicuro da eseguire automaticamente:
tocca solo file generati, mai il codice sorgente scritto a mano.

Poi esegui la skill `flutter-check` per verificare che tutto compili e i test
esistenti passino.
