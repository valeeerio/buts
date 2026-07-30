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
dell'app: barra di benvenuto in cima (saluto dinamico in base all'ora del giorno,
`greetingFor()`, + data corrente) e sotto-navigazione **Archivio**
(`buste_paga_archivio_view.dart`, hero ultima busta paga + elenco) / **Statistiche**
(`buste_paga_statistiche_screen.dart`, grafici `fl_chart`: andamento netto/lordo,
ferie/ROL/permessi residui, straordinario per mese — mostrati sempre, anche con 0
o 1 busta paga: ogni grafico senza dati sufficienti mostra il messaggio "Non ci
sono dati" al posto di bloccare l'intera pagina). La sotto-navigazione non è più
un tab in alto ma una **sidecar flottante ancorata in basso** (`LiquidGlassSurface`,
widget privato `_BustePagaSidecar`), che incorpora anche il bottone "+" come terzo
elemento accanto ai due segmenti Archivio/Statistiche. Nessuna navigazione radice
a più sezioni sopra di essa.

**Solo import PDF, niente inserimento manuale**: il bottone "+" nella sidecar
avvia direttamente `PdfImportService.pickAndImport()` (`lib/services/
pdf_import_service.dart`, solo PDF con testo selezionabile, niente OCR per
scansioni/foto in v1, validazione via `syncfusion_flutter_pdf`, selezione con
`file_selector`, file copiato in `buste_paga_pdf/` nella application documents
directory). Se il file non ha testo estraibile, o il parser regex
(`lib/services/busta_paga_regex_parser.dart`, mirato al layout del software paghe
"JOB") non riconosce i dati principali (netto e periodo entrambi assenti), viene
mostrato un alert bloccante e **il form non si apre** — non esiste più un modo di
aprire il form vuoto per un inserimento libero da zero. Il form
(`busta_paga_form_screen.dart`) si apre solo in due casi: precompilato dai dati
estratti da un import riuscito (costruttore `.daImport`, con banner di conferma
esplicita "dati estratti automaticamente, verifica prima di salvare" finché
`_valoriDaConferma == true`) oppure in modifica di una busta paga esistente
(`existing`, dal dettaglio) — in entrambi i casi i campi restano editabili prima
del salvataggio. Estrazione automatica via AI locale on-device resta una fase
futura (vedi sotto), oggi la precompilazione è solo tramite parser regex.

**Dettaglio busta paga** (`busta_paga_detail_screen.dart`): hero card in cima
(mese, badge di stato Confermato/Da confermare, netto in evidenza massima), sotto
una riga di mini-card per ROL residui e ore lavorate, poi le sezioni dettagliate
esistenti (Documento, Importi, Ferie, ROL, Permessi e ore, Trattenute) — "Netto"
non è ripetuto nella sezione Importi per evitare il doppione con la hero.
Nel dettaglio il PDF si apre via foglio di condivisione di sistema (`share_plus`),
nessun visualizzatore PDF in-app.

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
(`lib/main.dart`), nessuno swipe/header di navigazione radice. L'unica
sotto-navigazione è la sidecar flottante in basso già descritta sopra
(Archivio/Statistiche + "+"), non una tab bar Cupertino/Material standard.

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
  si tocca il widget. **Altra nota implementativa (bug corretto il 2026-07-30)**:
  il bordo decorativo (`_SpecularBorderPainter`, un `CustomPaint` interno) deve
  avere `hitTest(Offset position) => false` esplicito — senza quell'override, il
  default di `RenderCustomPaint.hitTestSelf` è `true`, e quel `CustomPaint`
  (in cima allo `Stack` interno, quindi il primo testato) intercetta ogni tocco
  sull'intera superficie prima che raggiunga il contenuto reale sottostante
  (bottoni, righe, sotto-navigazione). Se si riscrive `LiquidGlassSurface`,
  mantenere quell'override.
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

1. AI locale on-device per estrazione dati busta paga (fase successiva, nessuna
   dipendenza cloud/API a pagamento prevista, sostituisce/affianca il parser
   regex oggi usato per precompilare il form dopo l'import PDF).

## Convenzioni di codice

- Design tokens sempre da `lib/theme/`, mai colori/spaziature hardcoded nei widget.
- Componenti riutilizzabili in `lib/widgets/`, non dentro le singole schermate.
- Preferire `CupertinoDynamicColor.resolve(context)` per ogni colore, per garantire
  che light/dark mode funzionino automaticamente.
