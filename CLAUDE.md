# Buts — app personale di gestione finanze

Contesto di progetto per Claude Code. Leggi questo file prima di lavorare su qualunque
schermata: contiene le decisioni già prese (non da rimettere in discussione senza
motivo) e cosa manca ancora.

## Cos'è l'app

App mobile Flutter (iOS come target primario, look-and-feel Cupertino/iOS nativo),
uso personale locale — nessun backend cloud nella v1, nessun account, dati sul device.

**Funzione primaria: tracciare i dati della busta paga** (netto, lordo, straordinari,
ferie maturate/godute/residue, ROL, permessi, ore lavorate). È la sezione che si apre
per prima all'avvio dell'app. La gestione di budget mensile diviso in 4 aree, spese
quotidiane e voci ricorrenti (abbonamenti + costi fissi unificati) è una sezione
separata di **pari livello**, non più la home — vedi "Navigazione" sotto.

## Le 4 aree di budget (concetto centrale dell'app)

Non sono categorie di spesa: sono conti/contenitori verso cui viene ripartito
manualmente lo stipendio netto ogni mese.

1. **Conto Principale** (`AreaType.contoPrincipale`, verde `systemGreen`) — budget di
   spesa libero mensile. Tutte le spese quotidiane escono da qui. È il conto su cui
   si misura lo sforamento del budget.
2. **Risparmio Principale** (`AreaType.risparmioPrincipale`, blu `systemBlue`) —
   accantonamento, versamenti manuali mensili, saldo cumulato. Prelievi verso il
   Conto Principale ammessi ma richiedono sempre un motivo/nota obbligatoria.
3. **Piccolo Risparmio** (`AreaType.piccoloRisparmio`, viola `systemPurple`) — stessa
   logica del Risparmio Principale, fondo separato per obiettivi minori/spese
   impreviste.
4. **Impegni Fissi** (`AreaType.impegniFissi`, arancione `systemOrange`) — area
   **unificata** di abbonamenti + costi fissi (Netflix, palestra, affitto, utenze,
   assicurazioni...). Non si versa qui: è la somma delle voci ricorrenti attive,
   sottratta automaticamente dal netto mensile prima di calcolare quanto assegnare
   al Conto Principale.

**Logica del mese:**
`Netto mensile − Impegni Fissi − versamento Risparmio Principale − versamento Piccolo Risparmio = importo assegnabile al Conto Principale`

Questa suddivisione è **manuale** in v1 — niente calcolo automatico AI dello split
(può arrivare in futuro, non ora).

**Sezione Buste Paga**: funzione primaria dell'app, sezione di apertura predefinita.
Contiene archivio buste paga (`lib/screens/buste_paga/buste_paga_section_screen.dart`),
form di inserimento manuale con tutti i campi (`busta_paga_form_screen.dart`),
dettaglio (`busta_paga_detail_screen.dart`). Estrazione dati via AI locale on-device
resta una fase futura (vedi sotto), in v1 l'inserimento è solo manuale. Il netto
dell'ultima busta paga (`ultimaBustaPagaProvider`, `lib/providers/buste_paga_provider.dart`)
alimenta la suddivisione mensile del budget nella sezione Budget — niente doppio
inserimento manuale del netto (vedi `dashboard_screen.dart`).

## Navigazione

L'app ha **2 sezioni principali di pari livello**, navigabili sia con swipe
orizzontale sul contenuto sia con la freccia nell'header globale persistente
(`lib/widgets/app_section_header.dart`, stato in `app_section_provider.dart`,
scaffold radice `lib/navigation/app_root_scaffold.dart`):

```
[ Buste Paga ]  ⇄  [ Budget ]
   (default)
```

- **Buste Paga**: sezione di apertura predefinita, contenuto proprio (vedi sopra),
  nessuna tab bar interna.
- **Budget**: contiene l'attuale gestione a 4 aree con la sua tab bar inferiore
  stile Instagram/WhatsApp, **Dashboard al centro**, ordine fisso (vedi
  `lib/navigation/app_tab.dart`, contenuto in `lib/navigation/root_scaffold.dart`):

  ```
  Impegni Fissi — Risparmio Principale — [ Dashboard ] — Conto Principale — Piccolo Risparmio
  ```

  Questa tab bar a 5 destinazioni resta valida **solo dentro** la sezione Budget,
  non è la navigazione radice dell'app.

**Stato Riverpod**: `ProviderScope` è alla radice (`main.dart`). In uso per lo stato
di sezione attiva (`activeSectionProvider`) e per i dati Buste Paga in-memory
(`busteRepositoryProvider`, `ultimaBustaPagaProvider`) — persistenza Drift reale
non ancora collegata, vedi "Cosa manca".

## Stile visivo — non negoziabile senza conferma esplicita dell'utente

Direzione: **struttura/interazione di Revolut** (card-based, whitespace generoso,
palette semantica ristretta, alta densità informativa ma ordinata) **vestita con
estetica Apple/iOS nativa** (system font, colori semantici di sistema, corner radius
leggero, superfici pulite, no pill/capsule).

- **Colori**: colori semantici Apple, mappati 1:1 sulle aree — vedi
  `lib/theme/app_colors.dart`. systemRed riservato ad alert e variazioni sfavorevoli.
  Light e dark mode entrambi previsti fin da subito tramite `CupertinoDynamicColor`.
- **Forme**: corner radius leggero, 8–12px (vedi `lib/theme/app_spacing.dart` →
  `AppRadius`). Mai pill/capsule stondate al massimo.
- **Tipografia**: system font (SF Pro su iOS via Cupertino di default). Gerarchia
  in `lib/theme/app_text_styles.dart`.
- **Icone**: sempre `CupertinoIcons` (SF Symbols-style). Mai emoji nei componenti
  di produzione — se ne trovi in mockup precedenti (HTML) sono placeholder da
  sostituire.

## Dashboard — struttura già validata (non ridisegnare da zero)

Ordine dall'alto (vedi `lib/screens/dashboard/dashboard_screen.dart`):

1. Header: saluto con contesto temporale ("Buongiorno"/"Buonasera" + nome,
   in base all'ora — logica già in `_greeting`), sotto il mese corrente, sotto
   ancora il netto dell'ultima busta paga quando disponibile (collegamento dati
   verso la sezione Buste Paga). Il saluto è l'elemento con più enfasi, non il
   saldo totale. Nessuna icona di navigazione qui: Buste Paga si raggiunge da
   swipe/header globale, non da dentro la Dashboard.
2. `DonutSummary`: donut chart con ripartizione % delle 4 aree + totale al centro,
   legenda a fianco.
3. `InsightCard`: singola card di osservazione automatica (due varianti:
   positive/warning), sotto il donut, prima delle card aree. Deve distinguersi
   visivamente (sfondo colorato tenue + icona), non essere bianca come le altre.
4. 4× `AreaSummaryCard`: card compatte a riga singola, tap-only (nessuna azione
   rapida inline). Contengono: pallino colore area, nome breve + importo,
   sparkline (7gg per Conto Principale, 6 mesi per le altre 3), variazione %
   colorata (verde/rosso — attenzione: per Impegni Fissi un aumento è sfavorevole/
   rosso, per le altre un aumento è favorevole/verde — vedi
   `AreaType.isIncreaseFavorable()`).

Dati mock attuali in `lib/models/dashboard_area_summary.dart` →
`DashboardMockData` — da sostituire con dati reali quando si collega il DB.

## Cosa manca (prossimi passi, in ordine di priorità suggerito)

1. Persistenza dati: Drift (SQLite) già in `pubspec.yaml` ma non ancora collegato —
   sostituire lo stato in-memory (`BustaPagaMockData`, `busteRepositoryProvider`) con
   tabelle reali, schema secondo il modello dati nel piano di progetto (vedi file
   `piano_progetto_finanze_personali.md` nella cartella superiore del repo).
2. Upload PDF/foto busta paga nel form (`fileOrigine`, oggi sempre `null`) e
   statistiche/grafici dedicati (andamento ferie/ROL/permessi residui, ore
   straordinario per mese).
3. Dettaglio delle 4 aree della sezione Budget (oggi solo `PlaceholderScreen`): lista
   transazioni/movimenti per Conto Principale, storico versamenti per i risparmi
   (con azione di prelievo + nota obbligatoria), lista voci ricorrenti con scadenze
   in evidenza per Impegni Fissi.
4. Flusso di apertura/chiusura mese e suddivisione manuale del budget nella sezione
   Budget — deve leggere il netto da `ultimaBustaPagaProvider`, non richiederlo di
   nuovo manualmente.
5. AI locale on-device per estrazione dati busta paga (fase successiva, nessuna
   dipendenza cloud/API a pagamento prevista, sostituisce progressivamente
   l'inserimento manuale del form).

## Convenzioni di codice

- Design tokens sempre da `lib/theme/`, mai colori/spaziature hardcoded nei widget.
- Ogni area fa riferimento a `AreaType` per colore/etichetta — non duplicare quella
  logica nei singoli widget.
- Componenti riutilizzabili in `lib/widgets/`, non dentro le singole schermate.
- Preferire `CupertinoDynamicColor.resolve(context)` per ogni colore, per garantire
  che light/dark mode funzionino automaticamente.
