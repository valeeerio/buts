# Buts — app personale di gestione finanze

Contesto di progetto per Claude Code. Leggi questo file prima di lavorare su qualunque
schermata: contiene le decisioni già prese (non da rimettere in discussione senza
motivo) e cosa manca ancora.

## Cos'è l'app

App mobile Flutter (iOS come target primario, look-and-feel Cupertino/iOS nativo),
uso personale locale — nessun backend cloud nella v1, nessun account, dati sul device.

Gestisce: budget mensile diviso in 4 aree, spese quotidiane, voci ricorrenti
(abbonamenti + costi fissi unificati), e un modulo separato per l'archivio e
l'analisi delle buste paga.

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

**Area Buste Paga**: separata concettualmente dalle 4 aree di budget. Non è nella
tab bar principale — si apre da un ingresso secondario (icona nell'header della
Dashboard, vedi `dashboard_screen.dart` → `onOpenBustePaga`). Contiene archivio
buste paga, estrazione dati (in futuro via AI locale on-device, vedi sotto), e
statistiche su ferie/ROL/permessi/ore.

## Navigazione

Tab bar inferiore stile Instagram/WhatsApp, **Dashboard al centro**, ordine fisso
(vedi `lib/navigation/app_tab.dart`):

```
Impegni Fissi — Risparmio Principale — [ Dashboard ] — Conto Principale — Piccolo Risparmio
```

Buste Paga non è una tab: è raggiunta come push da dentro la Dashboard.

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
   in base all'ora — logica già in `_greeting`), sotto il mese corrente. Il saluto
   è l'elemento con più enfasi, non il saldo totale. A destra dell'header, l'icona
   di ingresso secondario a Buste Paga.
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

1. Dettaglio delle 4 aree (oggi solo `PlaceholderScreen`): lista transazioni/
   movimenti per Conto Principale, storico versamenti per i risparmi (con azione
   di prelievo + nota obbligatoria), lista voci ricorrenti con scadenze in evidenza
   per Impegni Fissi.
2. Schermata Area Buste Paga: archivio, upload, statistiche ferie/ROL/permessi/ore.
3. Persistenza dati: Drift (SQLite) già in `pubspec.yaml`, schema da definire
   secondo il modello dati nel piano di progetto (vedi file
   `piano_progetto_finanze_personali.md` nella cartella superiore del repo, se
   presente, per il modello dati completo).
4. Flusso di apertura/chiusura mese e suddivisione manuale del budget.
5. AI locale on-device per estrazione dati busta paga (fase successiva, nessuna
   dipendenza cloud/API a pagamento prevista).

## Convenzioni di codice

- Design tokens sempre da `lib/theme/`, mai colori/spaziature hardcoded nei widget.
- Ogni area fa riferimento a `AreaType` per colore/etichetta — non duplicare quella
  logica nei singoli widget.
- Componenti riutilizzabili in `lib/widgets/`, non dentro le singole schermate.
- Preferire `CupertinoDynamicColor.resolve(context)` per ogni colore, per garantire
  che light/dark mode funzionino automaticamente.
