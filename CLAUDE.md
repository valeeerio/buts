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

Componenti di stile riutilizzabili dell'app (Liquid Glass, vedi sezione "Stile
visivo" sotto): `lib/widgets/liquid_glass_surface.dart` (superficie in vetro
traslucido/blur, standard per ogni card/sezione — hero card, righe elenco, sezioni
del form, dettaglio, card statistiche, sotto-navigazione), `lib/widgets/
liquid_glass_button.dart` (CTA in vetro, compone `LiquidGlassSurface` con
`lib/widgets/spring_button.dart` per la pressione a molla) e `lib/widgets/
squircle_clipper.dart` (curva "continua" a superellisse usata dal clip del vetro).
`lib/widgets/glass_form_section.dart` compone `LiquidGlassSurface` nella forma di
una sezione di form/dettaglio raggruppata (header, righe con separatori, footer),
usata da form e dettaglio busta paga.

## Navigazione

L'app è **a sezione singola**: `BustePagaSectionScreen` è la root dell'app
(`lib/main.dart`), nessuno swipe/header di navigazione radice, nessuna tab bar
inferiore. L'unica sotto-navigazione è quella interna già descritta sopra
(Archivio/Statistiche).

**Stato Riverpod**: `ProviderScope` è alla radice (`main.dart`). In uso per i dati
Buste Paga, persistiti su Drift (`busteRepositoryProvider`, `ultimaBustaPagaProvider`
in `lib/providers/buste_paga_provider.dart`).

## Stile visivo — non negoziabile senza conferma esplicita dell'utente

Direzione: **"Liquid Glass"**, approssimazione Flutter-only (nessun ponte nativo
iOS/`UIGlassEffect`) del materiale in vetro liquido introdotto da Apple con iOS 26
(HIG "Materials" / WWDC25 "Meet Liquid Glass"). Card, sezioni, righe di elenco e CTA
sono superfici in vetro traslucido/sfocato che rifrangono ciò che hanno dietro,
non più rettangoli piatti a tinta unita. Sostituisce la direzione precedente
("struttura Revolut + estetica Apple, superfici piatte") — validata dall'utente
sul pilota Archivio Buste Paga ed estesa a tutta l'app.

- **Materiale**: ogni superficie/card usa `lib/widgets/liquid_glass_surface.dart`
  (`LiquidGlassSurface`) — mai `Container`/`DecoratedBox` con colore pieno per una
  card. Combina `BackdropFilter` (blur del contenuto sottostante), un riempimento
  quasi neutro (`glassFill`), un bordo con gradiente di luce catturata
  (`glassHighlight`/`glassShadowEdge`) e un'ombra a rilievo (`PhysicalShape`). I CTA
  usano `lib/widgets/liquid_glass_button.dart` (`LiquidGlassButton`), che compone
  `LiquidGlassSurface` con `lib/widgets/spring_button.dart` per la pressione a
  molla. **Nota implementativa**: `LiquidGlassSurface` applica un `ClipPath`
  esplicito attorno al `BackdropFilter` (oltre al clip di `PhysicalShape`) — su
  device reale con Impeller, un `BackdropFilter` senza un clip layer diretto come
  antenato può sbiancare il resto dello schermo. Non rimuovere quel `ClipPath` se
  si tocca il widget.
- **Colori**: colori semantici Apple — vedi `lib/theme/app_colors.dart`. systemRed
  riservato ad alert e variazioni sfavorevoli. La palette del vetro (`glassFill`,
  `glassHighlight`, `glassShadowEdge`) resta volutamente sobria/neutra: il colore è
  riservato ad accenti puntuali (badge di stato, CTA primaria via il parametro
  `tint` di `LiquidGlassSurface`/`LiquidGlassButton`), mai come riempimento pieno
  della superficie. Light e dark mode entrambi previsti fin da subito tramite
  `CupertinoDynamicColor`.
- **Forme**: corner radius "squircle" continui (superellisse, non il doppio arco di
  `BorderRadius.circular`) via `lib/widgets/squircle_clipper.dart`, applicati da
  `LiquidGlassSurface`/`LiquidGlassButton`. Raggi in `lib/theme/app_spacing.dart` →
  `AppRadius.glass` (28, hero card/contenitori principali) e `AppRadius.glassSmall`
  (18, righe elenco/chip/CTA compatte). I raggi piccoli precedenti
  (`small`/`medium`/`large`/`card`) restano solo per dettagli minuti che non sono
  superfici di vetro (badge, barre di grafici). Mai pill/capsule stondate al
  massimo.
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
