# Buts — app personale di tracciamento buste paga

Contesto di progetto per Claude Code. Leggi questo file prima di lavorare su qualunque
schermata: contiene le decisioni già prese (non da rimettere in discussione senza
motivo) e cosa manca ancora.

## Cos'è l'app

App mobile Flutter (iOS come target primario, look-and-feel Cupertino/iOS nativo),
uso personale locale — nessun backend cloud nella v1, nessun account, dati sul device.

**Funzione unica dell'app: tracciare i dati della busta paga** (netto, lordo,
straordinari, ferie maturate/godute/residue, ROL, permessi, ore lavorate). Non ci
sono altre sezioni: l'app si apre direttamente sull'archivio Buste Paga, che è la
schermata radice.

**Sezione Buste Paga**: `buste_paga_section_screen.dart` è il contenitore radice
dell'app: header con CTA "+" e sotto-navigazione interna a tab
(`CupertinoSlidingSegmentedControl`) — **Archivio**
(`buste_paga_archivio_view.dart`, hero ultima busta paga + elenco) e **Statistiche**
(`buste_paga_statistiche_screen.dart`, grafici `fl_chart`: andamento netto/lordo,
ferie/ROL/permessi residui, straordinario per mese — richiede almeno 2 buste paga
in archivio, altrimenti empty state). Questa sotto-navigazione è interna alla
schermata radice, non c'è una navigazione radice a più sezioni sopra di essa.
Form di inserimento manuale con tutti i campi (`busta_paga_form_screen.dart`),
dettaglio (`busta_paga_detail_screen.dart`).
Import PDF: sezione "Documento" nel form, solo PDF con testo selezionabile (niente
OCR per scansioni/foto in v1 — `lib/services/pdf_import_service.dart`, validazione
via `syncfusion_flutter_pdf`, selezione con `file_selector`). Il file viene copiato
in `buste_paga_pdf/` nella application documents directory (non solo il path
originale); nel dettaglio si apre via foglio di condivisione di sistema
(`share_plus`), nessun visualizzatore PDF in-app. Estrazione automatica dei campi
via AI locale on-device resta una fase futura (vedi sotto), in v1 l'inserimento è
solo manuale.

Componenti di stile riutilizzabili introdotti per questa sezione (validi ovunque
serva più "materialità" Apple): `lib/widgets/material_surface.dart` (superficie
traslucida/sfocata via `BackdropFilter`, usata sulla hero card) e
`lib/widgets/spring_button.dart` (pressione con rimbalzo a molla, usato sui CTA
principali). Restano dentro i design token esistenti — nessun nuovo colore o corner
radius introdotto.

## Navigazione

L'app è **a sezione singola**: `BustePagaSectionScreen` è la root dell'app
(`lib/main.dart`), nessuno swipe/header di navigazione radice, nessuna tab bar
inferiore. L'unica sotto-navigazione è quella interna già descritta sopra
(Archivio/Statistiche).

**Stato Riverpod**: `ProviderScope` è alla radice (`main.dart`). In uso per i dati
Buste Paga, persistiti su Drift (`busteRepositoryProvider`, `ultimaBustaPagaProvider`
in `lib/providers/buste_paga_provider.dart`).

## Stile visivo — non negoziabile senza conferma esplicita dell'utente

Direzione: **struttura/interazione di Revolut** (card-based, whitespace generoso,
palette semantica ristretta, alta densità informativa ma ordinata) **vestita con
estetica Apple/iOS nativa** (system font, colori semantici di sistema, corner radius
leggero, superfici pulite, no pill/capsule).

- **Colori**: colori semantici Apple — vedi `lib/theme/app_colors.dart`. systemRed
  riservato ad alert e variazioni sfavorevoli. Light e dark mode entrambi previsti
  fin da subito tramite `CupertinoDynamicColor`.
- **Forme**: corner radius leggero, 8–12px (vedi `lib/theme/app_spacing.dart` →
  `AppRadius`). Mai pill/capsule stondate al massimo.
- **Tipografia**: system font (SF Pro su iOS via Cupertino di default). Gerarchia
  in `lib/theme/app_text_styles.dart`.
- **Icone**: sempre `CupertinoIcons` (SF Symbols-style). Mai emoji nei componenti
  di produzione — se ne trovi in mockup precedenti (HTML) sono placeholder da
  sostituire.

## Cosa manca (prossimi passi, in ordine di priorità suggerito)

1. Upload PDF/foto busta paga nel form (`fileOrigine`, oggi sempre `null`) e
   statistiche/grafici dedicati (andamento ferie/ROL/permessi residui, ore
   straordinario per mese).
2. AI locale on-device per estrazione dati busta paga (fase successiva, nessuna
   dipendenza cloud/API a pagamento prevista, sostituisce progressivamente
   l'inserimento manuale del form).

## Convenzioni di codice

- Design tokens sempre da `lib/theme/`, mai colori/spaziature hardcoded nei widget.
- Componenti riutilizzabili in `lib/widgets/`, non dentro le singole schermate.
- Preferire `CupertinoDynamicColor.resolve(context)` per ogni colore, per garantire
  che light/dark mode funzionino automaticamente.
