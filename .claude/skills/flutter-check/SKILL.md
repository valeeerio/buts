---
name: flutter-check
description: Verifica rapida di sanità del progetto Buts prima di considerare concluso un task Flutter — lancia flutter analyze e flutter test (e build_runner se ci sono modifiche a tabelle Drift), riporta gli errori in modo sintetico. Usa quando hai appena modificato codice Dart e vuoi controllare che compili e passi i test prima di consegnare.
---

# flutter-check

Esegui questi passi nella root del progetto (`/Users/valeriomortella/Sviluppo/Buts/app`):

1. **Analisi statica**:
   ```
   flutter analyze
   ```
   Riporta ogni errore/warning con file:riga. Se ci sono solo info-level lint già
   presenti prima delle tue modifiche, non serve risolverli a meno che riguardino i
   file che hai appena toccato.

2. **Rigenerazione codice, solo se hai modificato file Drift** (tabelle in `lib/data/`
   annotate con Drift o classi `@DriftDatabase`/`@TableIndex` ecc.):
   ```
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
   Esegui questo passo automaticamente: è deterministico e non distruttivo per il
   codice sorgente (rigenera solo i file `.g.dart`).

3. **Test**:
   ```
   flutter test
   ```
   Riporta test falliti con nome del test e assert che ha fallito.

4. Se `flutter analyze` o `flutter test` non sono disponibili (es. ambiente senza SDK
   Flutter installato/configurato), dillo esplicitamente invece di inventare un esito.

Non correggere automaticamente errori pre-esistenti fuori dallo scope del task corrente
senza dirlo all'utente: segnalali e chiedi se vuole che vengano risolti ora.

Alla fine, dai un riepilogo in 2-3 righe: analyze OK/KO, build_runner eseguito o non
necessario, test passati/falliti (quanti).
