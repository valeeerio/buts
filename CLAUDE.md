# Buts — app personale di tracciamento buste paga

Contesto di progetto per Claude Code. Leggi questo file prima di lavorare su qualunque
schermata: contiene le decisioni già prese (non da rimettere in discussione senza
motivo) e cosa manca ancora.

## Cos'è l'app

App mobile Flutter (iOS come target primario, look-and-feel Cupertino/iOS nativo),
uso personale locale — nessun backend cloud nella v1, nessun account, dati sul device.

**Funzione unica dell'app: tracciare i dati della busta paga** (netto, lordo
derivato dalle voci di competenza, straordinari, ferie maturate/godute/residue,
ROL, ex festività, permessi, ore lavorate). Non ci sono altre sezioni: l'app si
apre direttamente sull'archivio Buste Paga, che è la schermata radice.

**Sezione Buste Paga**: `buste_paga_section_screen.dart` è il contenitore radice
dell'app: barra di benvenuto in cima (saluto dinamico in base all'ora del giorno,
`greetingFor()`, + data corrente) e sotto-navigazione **Archivio**
(`buste_paga_archivio_view.dart`, hero ultima busta paga + elenco — la hero è
`BustaPagaSummaryHero` in `lib/widgets/busta_paga_summary_hero.dart`: mese
(pallino di stato + label) e netto in evidenza impilati a sinistra, a destra un
gruppetto compatto `_StatTrio` con Ferie/Permessi/Ex fest. separati da
divisori verticali sottili, centrato verticalmente rispetto all'altezza
combinata di mese+netto — tutto dentro un'unica `LiquidGlassSurface`) /
**Statistiche** (`buste_paga_statistiche_screen.dart`, grafici `fl_chart`:
andamento netto/lordo, ferie/ROL/permessi residui, straordinario per mese —
mostrati sempre, anche con 0 o 1 busta paga: ogni grafico senza dati sufficienti
mostra il messaggio "Non ci sono dati" al posto di bloccare l'intera pagina). La
sotto-navigazione non è più
un tab in alto ma una **sidecar flottante ancorata in basso**, widget privato
`_BustePagaSidecar`: i due segmenti Archivio/Statistiche sono `FlatChipButton`
(`lib/widgets/flat_chip_button.dart`, vedi sotto) — solo il segmento attivo ha il
riempimento colorato, senza più una `LiquidGlassSurface` di sfondo con highlight
animato — più il bottone "+" (cerchio blu pieno) come terzo elemento. Nessuna
navigazione radice a più sezioni sopra di essa.

**Solo import PDF, niente inserimento manuale**: il bottone "+" nella sidecar
avvia direttamente `PdfImportService.pickAndImport()` (`lib/services/
pdf_import_service.dart`, solo PDF con testo selezionabile, niente OCR per
scansioni/foto in v1, validazione via `syncfusion_flutter_pdf`, selezione con
`file_selector`, file copiato in `buste_paga_pdf/` nella application documents
directory). Il controllo anti-duplicati (stesso anno+mese+tipo per le
mensili, stesso anno+tipo per 13a/14a) gira **due volte**: subito dopo la
selezione del file (prima ancora di aprire il form, così l'alert "busta paga
già presente" appare appena l'utente sceglie il PDF dall'archivio del
telefono) e di nuovo al salvataggio del form, come rete di sicurezza. Se il
file non ha testo estraibile, o il parser regex
(`lib/services/busta_paga_regex_parser.dart`, mirato al layout del software paghe
"JOB") non riconosce i dati principali (netto e periodo entrambi assenti), viene
mostrato un alert bloccante e **il form non si apre** — non esiste più un modo di
aprire il form vuoto per un inserimento libero da zero. Il form
(`busta_paga_form_screen.dart`) si apre **solo** per l'import: precompilato dai
dati estratti da un import riuscito (costruttore `.daImport`, con banner di
conferma esplicita "dati estratti automaticamente, verifica prima di salvare"
finché `_valoriDaConferma == true`), **ricostruito sullo stesso impianto del
dettaglio in modifica** (vedi sotto): banner di conferma, hero, statistiche,
tabella maturazioni, chip documento (non tappabile), trattenute con
swipe-to-delete, barra flottante Salva/Annulla in basso — non più 7
`GlassFormSection` separate con `CupertinoFormRow`/tasto Salva in nav bar.
Non esiste più una modalità "existing"/di modifica di una busta paga già
salvata (rimossa il 2026-07-31): la modifica avviene interamente nel
dettaglio, vedi sotto. Estrazione automatica via AI locale on-device resta
una fase futura (vedi sotto), oggi la precompilazione è solo tramite parser
regex.

**Dettaglio busta paga** (`busta_paga_detail_screen.dart`,
`ConsumerStatefulWidget` — non più `ConsumerWidget`, serve stato locale per la
modalità modifica): hero card in cima (mese, badge di stato Confermato/Da
confermare — verde/rosso, stessa semantica del pallino in Archivio — sotto,
Lordo e Netto affiancati, separati da un divisore verticale, **visivamente
identici** in font/dimensione/peso/colore e distinti solo dall'etichetta
sopra ciascun valore, nessuno dei due più "in evidenza" dell'altro) **fissa
fuori dall'area scrollabile**, sotto una riga di
mini-statistiche Ore lavorate/Straordinari (**unica** `LiquidGlassSurface` a
scomparti, mai più superfici di vetro affiancate, vedi nota bug in "Stile
visivo" — rimossa il 2026-08-11 l'analoga riga Ferie residue/Permessi
residui/Ex festività, ridondante con la colonna "Residuo" della tabella
Maturazioni sottostante), una tabella unica "Ferie, ROL e permessi" (colonne
Maturato/Goduto/Residuo) al
posto di sezioni separate per categoria, chip documento PDF tappabile e
sezione Trattenute — nessuna di queste sezioni ha più un titolo sopra la card
(rimossi per pulizia visiva). In fondo, una barra flottante (`_ActionBar`,
stessa posizione/pattern della sidecar) con "Conferma" (visibile solo se lo
stato è "Da confermare", aggiorna lo stato senza uscire dalla schermata,
mostra un popup "Dati confermati") e "Modifica" — entrambe `FlatChipButton`.
La schermata legge sempre la versione corrente della busta paga dal provider
(`ref.watch(busteRepositoryProvider)` filtrato per id), non il valore statico
ricevuto all'apertura, così si aggiorna subito dopo "Conferma" o "Salva". Nel
dettaglio il PDF si apre nell'anteprima nativa di sistema (Quick Look su
iOS) tramite `open_filex`, che include già un bottone di condivisione
nativo — nessun visualizzatore PDF in-app, nessuna azione di condivisione
separata.

Hero card, riga di statistiche, tabella maturazioni e chip documento sono
widget pubblici condivisi in `lib/widgets/` — non più classi private di
questo file — perché riusati identici anche dal form di import (vedi sotto):
`BustaPagaHeroCard` (badge stato via `isConfermato: bool`, non un
`BustaPaga` intero), `BustaPagaStatRow` (`items: List<(String label, Widget
value)>`), `BustaPagaMaturazioniSection`, `BustaPagaDocumentoChip` — sempre
tappabile (dettaglio e form di import: il file è già copiato su disco prima
ancora che il form sia visibile) con una singola azione "Apri" che mostra
l'anteprima di sistema via `open_filex`, niente più `onTap` esterno né
distinzione di condivisione separata.

**Voci di competenza (2026-08-09)**: il "lordo" non è più un campo scalare
inserito/modificato direttamente — è derivato da `competenze`, la lista delle
singole voci del cedolino (es. "Retribuzione ordinaria", "Edr contrattuale",
"Straordinario diurno (30%)"), modello `VoceCompetenza` (`descrizione`,
`quantita`, `importo`) in `lib/models/busta_paga.dart`, colonna Drift
`competenze` serializzata JSON via `VoceCompetenzaListConverter`
(`lib/data/database.dart`). `computeLordo(competenze)` somma tutti gli
`importo`; `computeStraordinari(competenze)` somma le `quantita` (ore) delle
sole voci la cui descrizione inizia (case-insensitive) per "straordinario"
(`voceEStraordinaria`) — entrambi ricalcolati e scritti nei campi memorizzati
`lordo`/`straordinari` ad ogni salvataggio, non getter derivati al volo.
Il parser regex estrae `competenze` riga per riga dal blocco competenze del
PDF, escludendo esplicitamente "Ferie godute" (già in Maturazioni) e
"Permessi riduz. orario goduti" (letto invece in `permessiGodutiMese`, vedi
sotto). Editing: `BustaPagaCompetenzeSection`
(`lib/widgets/busta_paga_competenze_section.dart`) + riga editabile
`VoceCompetenzaEditRow` (`lib/widgets/voce_competenza_edit_row.dart`,
swipe-to-delete come le Trattenute), sostituisce il vecchio campo Lordo
tappabile in hero sia nel dettaglio in modifica sia nel form di import.

Insieme a `competenze`, il PDF distingue due dati aggiuntivi prima non letti
dal parser: **`permessiGodutiMese`** (riga "Permessi riduz. orario goduti"
del mese, in ore — distinta dal cumulativo annuo `permessiGoduti`, che nel
layout JOB coincide coi ROL goduti) e **`exFestivitaMaturate`/
`exFestivitaGodute`/`exFestivitaResidue`** (terza categoria di ratei del PDF,
"EX FESTIVITA'", stessa struttura maturato/goduto/residuo di Ferie/ROL — riga
in più nella tabella "Ferie, ROL e permessi" di `BustaPagaMaturazioniSection`).
Migrazione Drift additiva `schemaVersion` 4→6 (v5: `competenze` +
`permessiGodutiMese`; v6: le tre colonne ex festività), tutte con default
sulla colonna (`'[]'`/`0`) per compatibilità con le buste paga salvate prima
di questa modifica — nessun dato esistente toccato o perso.

**Modifica inline (2026-07-31)**: "Modifica" non naviga più verso
`busta_paga_form_screen.dart` — attiva `_isEditing = true` sulla stessa
schermata di dettaglio, e le stesse card diventano editabili sul posto (hero
Netto e periodo tappabile con lo stesso picker mese/anno del vecchio form,
`BustaPagaStatRow` Ore/Straordinari, tabella Maturazioni, righe
Trattenute con `Dismissible`+`SwipeDeleteBackground` al posto di un bottone
"meno" per rimuoverle). **Requisito non negoziabile confermato più volte
dall'utente**: entrare in modifica non deve cambiare NULLA visivamente
(allineamento, prefissi "€"/"− €", stile) rispetto alla vista di sola lettura,
a parte rendere il testo tappabile — verificare questo ad ogni modifica a
questa schermata, è la causa di diversi bug corretti in questa sessione. La
barra in basso diventa "Salva"/"Annulla" (`FlatChipButton`, ~50/50, "Salva" blu
di sistema, "Annulla" grigio). "Salva" valida il Netto (obbligatorio/numerico),
calcola un diff campo per campo rispetto ai valori originali e, se non vuoto,
mostra un popup "Hai modificato i seguenti dati, confermi?" con l'elenco
vecchio → nuovo prima di applicare (`copyWith` con `statoVerifica` che torna
automaticamente a `daConfermare` se la busta era "Confermata"); se il diff è
vuoto esce dalla modifica senza popup. "Annulla" scarta tutti i controller e
torna alla vista di sola lettura. Ferie residue/ROL residui/Ex festività
residue non hanno più una riga di mini-statistiche dedicata (rimossa il
2026-08-11, ridondante): il campo "Residuo" della tabella Maturazioni resta
l'unico punto, di sola lettura o editabile, in cui questi dati sono
mostrati/modificati.

Componenti di stile riutilizzabili dell'app (Liquid Glass, vedi sezione "Stile
visivo" sotto): `lib/widgets/liquid_glass_surface.dart` (superficie in vetro
traslucido/blur, standard per ogni card/sezione — hero card, righe elenco, sezioni
del form, dettaglio, card statistiche), `lib/widgets/liquid_glass_button.dart` (CTA
in vetro, compone `LiquidGlassSurface` con `lib/widgets/spring_button.dart` per la
pressione a molla) e `lib/widgets/squircle_clipper.dart` (curva "continua" a
superellisse usata dal clip del vetro). `lib/widgets/glass_form_section.dart`
compone `LiquidGlassSurface` nella forma di una sezione di form/dettaglio
raggruppata (header opzionale, righe con separatori, footer), usata da form e
dettaglio busta paga. `lib/widgets/flat_chip_button.dart` (`FlatChipButton`) è il
chip piatto icona+testo **senza vetro** (parametro `filled` per lo stato
selezionato/non selezionato) usato dalla sotto-navigazione e dalla barra
Conferma/Modifica/Salva-Annulla — scelta deliberata di rompere col Liquid Glass
per queste CTA, vedi nota in "Stile visivo". `lib/widgets/app_alert_dialog.dart`
(`AppAlertDialog`/`showAppAlertDialog`) applica la stessa scelta ai popup di
conferma/errore: card piatta (`DecoratedBox` + ombra, niente `BackdropFilter`),
titolo/messaggio centrati, pulsanti `FlatChipButton` con icona opzionale;
transizione a fade condivisa da un unico `CurvedAnimation` fra contenuto e
barrier disegnato a mano (mai affidarsi al `barrierColor` animato di
`showGeneralDialog`, che usa una curva fissa non configurabile e va facilmente
fuori sincrono col contenuto). `lib/widgets/busta_paga_hero_card.dart`,
`busta_paga_stat_row.dart`, `busta_paga_maturazioni_section.dart`,
`busta_paga_documento_chip.dart`, `trattenuta_edit_row.dart` sono i widget
condivisi tra dettaglio e form di import descritti sopra.
`lib/widgets/cupertino_range_slider.dart` è lo slider a doppio cursore del
filtro periodo in Statistiche: tracking assoluto della posizione del dito
(non a delta relativo, per evitare che il pallino "sfasi" dal punto di
presa), thumb che cresce con animazione a molla durante il drag, vibrazione
(`HapticFeedback.selectionClick()`) ad ogni cambio di mese attraversato.

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
  molla. Vincoli implementativi da non violare se si tocca il widget: (1) il
  `ClipPath` esplicito attorno al `BackdropFilter` (oltre al clip di
  `PhysicalShape`) è necessario — su device reale con Impeller, un
  `BackdropFilter` senza un clip layer diretto come antenato sbianca il resto
  dello schermo; (2) il bordo decorativo interno (`_SpecularBorderPainter`)
  deve avere `hitTest(Offset position) => false` esplicito, altrimenti
  intercetta ogni tocco prima che raggiunga il contenuto sottostante; (3) il
  riempimento a gradiente va calcolato in `CustomPaint` sulla `size` reale del
  widget, mai sulle constraints di `LayoutBuilder` (illimitate dentro
  `ListView`/`Row`). Inoltre: mai istanziare più `LiquidGlassSurface`
  affiancate a poca distanza nello stesso `Row`/`Column` — più
  `BackdropFilter` ravvicinati producono una "cucitura" di rendering visibile
  tra le superfici. Per compartimenti multipli in riga (mini-statistiche, tab
  della sotto-navigazione) usare **una sola** `LiquidGlassSurface` esterna con
  scomparti piatti interni separati da un divisore sottile (`BustaPagaStatRow`),
  oppure — per CTA/tab dove il vetro non è necessario — `FlatChipButton`.
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
  massimo. Eccezione confermata esplicitamente dall'utente (2026-07-31):
  `FlatChipButton` usa `AppRadius.glassSmall` su un bottone di altezza compatta,
  quindi visivamente molto arrotondato — resta comunque un token, non un raggio
  letterale enorme da vera capsula, e l'uso è limitato a quel componente
  (sotto-navigazione, barra Conferma/Modifica).
- **Tipografia**: system font (SF Pro su iOS via Cupertino di default). Gerarchia
  in `lib/theme/app_text_styles.dart`.
- **Icone**: sempre `CupertinoIcons` (SF Symbols-style). Mai emoji nei componenti
  di produzione — se ne trovi in mockup precedenti (HTML) sono placeholder da
  sostituire.

**Scroll e dissolvenza in fondo alla lista**: nell'Archivio (`buste_paga_
archivio_view.dart`) la lista scrollabile è avvolta in uno `ShaderMask` con
`fadeHeight` fisso in pixel (120.0), dentro un `Expanded` la cui altezza reale
è ridotta da un `Padding(bottom: _sidecarReservedHeight)` esterno (non solo
padding di contenuto) — è questo che riduce il viewport e fa coincidere la
zona di dissolvenza con le ultime righe realmente visibili sopra la sidecar.
Nel dettaglio busta paga (`busta_paga_detail_screen.dart`) è stato **abbandonato
un approccio analogo con `ShaderMask` a piena altezza** (provato con più valori
di `fadeHeight`, mai percepito come "uguale" all'Archivio a causa del viewport
di altezza diversa — niente banner di benvenuto sopra la lista nel dettaglio):
la schermata usa invece la hero card fissa fuori dallo scroll (vedi sopra) più
scroll naturale sotto, con lo stesso pattern di `Padding` esterno che riduce il
viewport (`_actionBarReservedHeight`) per il margine verso la barra flottante,
e un `ShaderMask` con `fadeHeight` piccolo (poche decine di pixel, non l'intero
margine) solo per ammorbidire lo stacco finale, non per "nascondere" più righe
di contenuto come nell'Archivio. Se si ritocca uno dei due effetti, non
assumere che debbano avere lo stesso valore assoluto di `fadeHeight`: il
viewport sottostante è diverso in altezza tra le due schermate.

## Cosa manca (prossimi passi, in ordine di priorità suggerito)

Sessione del 2026-08-09: obiettivo dichiarato dall'utente è **completare l'app
e rilasciarla**. Il lavoro sulle voci di competenza/permessi mensili/ex
festività (branch `redesign-schema-busta-paga`, vedi sopra) è pronto per il
merge in `main` — `flutter analyze`/`flutter test` verdi. Vedi `BACKLOG.md`
per le voci aperte verso il rilascio.

**Nota**: l'estrazione dati via AI locale on-device (`llama_cpp_dart`), valutata
in una fase precedente, è stata **abbandonata (2026-07-30)** — vedi "Decisioni
archiviate" in `BACKLOG.md`. Il parser regex
(`lib/services/busta_paga_regex_parser.dart`) resta l'unico meccanismo di
precompilazione dati da PDF, nessun piano di sostituirlo.

## Convenzioni di codice

- Design tokens sempre da `lib/theme/`, mai colori/spaziature hardcoded nei widget.
- Componenti riutilizzabili in `lib/widgets/`, non dentro le singole schermate.
- Preferire `CupertinoDynamicColor.resolve(context)` per ogni colore, per garantire
  che light/dark mode funzionino automaticamente.

## Come collaborare su questo progetto (regole del coordinatore)

Queste regole valgono per l'assistente che coordina il lavoro su Buts, non solo
per uno specifico agente dev — governano come si distribuisce il lavoro tra
coordinatore, agenti dev1/dev2, agente `revisore` e utente.

- **Sviluppo sempre delegato**: il coordinatore non scrive mai direttamente
  codice di feature/fix (niente `Edit`/`Write` diretti su file Dart) — delega
  sempre a un agente dev1 o dev2, interscambiabili, anche per fix piccoli o
  "ovvi". Il coordinatore assegna task e file in scope, poi lancia `revisore`.
  *Perché*: l'utente vuole poter sviluppare/testare in parallelo nella stessa
  sessione senza che il coordinatore intervenga direttamente sul codice.
- **Revisore dopo ogni dev**: al termine di ogni run di dev1/dev2, il
  coordinatore lancia sempre `revisore` con lo stesso scope/parametri passati
  all'agente dev (stessi file, stesso task) — non uno scope diverso senza
  motivo. È un passo fisso, non opzionale, anche per fix piccoli.
- **Notifica di lancio, non richiesta di conferma**: quando si lanciano
  agenti dev1/dev2 (anche in parallelo), il coordinatore comunica cosa sta
  delegando (agente, scope, file) nel momento in cui parte, ma non aspetta un
  ok esplicito prima di procedere.
- **File in uso dall'utente**: se l'utente lavora manualmente su file del
  progetto in parallelo agli agenti dev, è lui a segnalare quali file sta
  usando — il coordinatore evita di assegnarli in scrittura a un agente dev
  finché l'utente non segnala che sono di nuovo liberi.
- **Istanze dell'utente intoccabili**: se l'utente ha avviato di persona un
  simulatore iOS, `flutter run`, hot reload o altro processo, il coordinatore
  (e gli agenti che lancia) non lo ferma, non lo riavvia, e non ne lancia uno
  equivalente in parallelo che possa entrare in conflitto. Prima di comandi
  come `killall` o un nuovo `flutter run`/`build` per verifica, controllare se
  potrebbe esserci un'istanza attiva dell'utente e, in caso di dubbio,
  chiedere invece di agire. `flutter analyze`/`flutter test` restano liberi,
  non sono processi persistenti.
- **Test visivi solo dell'utente**: il coordinatore esegue solo verifiche
  statiche (`flutter analyze`, `flutter test`, `build_runner`, skill
  `flutter-check`) — non avvia mai l'app in un simulatore/device per
  osservare la UI, non fa screenshot, non esprime giudizi sull'aspetto
  visivo. Quando un task tocca UI/widget, si ferma alla verifica di
  compilazione/test e segnala che la modifica è pronta per il test visivo
  dell'utente — non dichiara mai "verificato visivamente" senza che sia stato
  l'utente a controllarlo.
- **Autonomia Git limitata**: comandi git di sola lettura (`status`, `diff`,
  `log`, `show`, `branch --list`) sono liberi. Qualunque comando che modifica
  lo stato del repo (`commit`, creazione branch/checkout, `push`, `merge`,
  `reset`, `rebase`...) parte **solo** su istruzione esplicita dell'utente in
  quel momento — mai di iniziativa, anche se sembra il passo logico dopo un
  task completato. *Nota*: `.claude/settings.local.json` pre-autorizza
  l'harness a eseguire senza prompt di conferma `git push/checkout/pull/
  merge/remote/add/commit` — questo è un permesso tecnico dell'harness, non
  un via libera a usarli di iniziativa: questa regola resta comunque il
  criterio su *quando* il coordinatore decide di lanciarli.
