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
2. Identifica quale contenuto serve in base al tipo di area:
   - **Conto Principale**: lista transazioni/movimenti di spesa, ordinate per data.
   - **Risparmio Principale** / **Piccolo Risparmio**: storico versamenti, con azione
     di prelievo che richiede sempre una nota/motivo obbligatoria (non deve essere
     possibile confermare un prelievo senza nota).
   - **Impegni Fissi**: lista delle voci ricorrenti attive (abbonamenti + costi fissi
     unificati), con le scadenze più vicine in evidenza.
3. Usa dati mock coerenti con `DashboardMockData` (`lib/models/
   dashboard_area_summary.dart`) finché Drift non è collegato — non inventare uno
   shape di dati diverso da quello già usato altrove per la stessa area.
4. Delega l'implementazione vera e propria all'agent `flutter-dev` (Task/Agent
   tool), passandogli: quale area, quale contenuto secondo il punto 2, e il vincolo di
   riusare i design token esistenti.
5. Dopo l'implementazione, esegui la skill `flutter-check` per verificare che il
   progetto compili e i test passino.
6. Facoltativo ma consigliato: invoca l'agent `design-consistency-reviewer` sui file
   modificati per controllare l'aderenza allo stile prima di consegnare.

Non introdurre navigazione aggiuntiva nella tab bar: la schermata resta raggiunta come
oggi, tramite tap sulla `AreaSummaryCard` corrispondente in Dashboard.
