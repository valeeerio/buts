# Restyling app: applicare lo stile del widget home screen a tutta l'app

Data: 2026-09-08
Branch di lavoro: `style` (creato da `main` dopo il merge/push della feature widget, commit `bf10491`)

## Contesto

Il redesign visivo "Pulse" (dark-first, accento ciano, superfici piatte) è già in
corso ed è per buona parte mergiato in `main`: 15 schermate usano già
`PulseSurface`, restano solo 3 riferimenti a `LiquidGlassSurface` nei file dei
widget stessi (non più nelle schermate), 11 usi di `PulseIcon` contro 7 di
`CupertinoIcons` residui, 2 usi di `ProgressRingTile`. I font brandizzati Space
Grotesk (titoli/valori) e Inter (corpo/label) sono bundlati offline e
configurati in `pubspec.yaml`.

Il widget home screen iOS (`BustaPagaWidgetExtension`, appena completato) è
stato disegnato come un'approssimazione manuale della palette Pulse esistente,
ma con font di sistema (nessun font custom caricabile comodamente
nell'estensione) e senza superficie "tessera" distinta dallo sfondo (il widget
è un unico blocco). Vedendolo, l'utente ha deciso che questo stile — inclusi i
font di sistema — gli piace di più della direzione Pulse attuale con i font
brandizzati, e vuole applicarlo a tutta l'app.

## Decisioni prese (in sede di brainstorming con l'utente)

1. **Font**: sostituire Space Grotesk/Inter con il font di sistema (SF Pro su
   iOS) in tutta l'app. I file font bundlati e la relativa configurazione in
   `pubspec.yaml` vengono rimossi (non restano come codice/asset morto).
2. **Colori**: i valori esatti usati nel widget diventano il nuovo riferimento
   per la variante **dark** dei token Pulse (non il contrario) — vedi mappatura
   sotto. La variante **light** viene ricalcolata da zero per preservare la
   stessa gerarchia e superare gli stessi rapporti di contrasto minimi già
   documentati nei commenti dei token attuali; non essendo mai stata validata
   per queste tinte esatte, la verifica di contrasto va rifatta durante
   l'implementazione, non assunta per estrapolazione dal dark.
3. **Light/dark**: l'app mantiene entrambe le modalità alla pari (non diventa
   dark-only come il widget, che è dark-forzato solo per un vincolo di
   WidgetKit, non per scelta di design).
4. **Rappresentazione dati (Ferie/ROL/Permessi/Ex festività)**: gli anelli di
   progresso (`ProgressRingTile`) restano invariati nell'Archivio — il
   restyling NON li sostituisce con le colonne piatte viste nel widget. Le
   colonne piatte con divisore (pattern del widget) vengono comunque
   promosse a componente condiviso per gli altri punti dell'app che già usano
   quel pattern (es. `_StatTrio` nella hero dell'Archivio), non per introdurlo
   dove oggi non c'è.
5. **Icone**: `PulseIcon`/set custom personalizzato restano invariati — il
   widget non ha icone, quindi non c'è nulla da "copiare" su questo fronte;
   il completamento della migrazione dei 7 `CupertinoIcons` residui a
   `PulseIcon` è comunque incluso nella Fase 3 come pulizia, essendo già un
   impegno preso in CLAUDE.md indipendente da questo restyling.

## Mappatura colori (dark) — dal widget ai token Pulse

| Token (`lib/theme/app_colors.dart`) | Valore dark attuale | Nuovo valore dark (dal widget) |
|---|---|---|
| `pulseBackground` | `#0B1016` | `#0A0F17` |
| `pulseAccent` | `#3DDBFF` | `#00B8F0` |
| `pulseTextPrimary` | `#F5F8FA` | `#FFFFFF` |
| `pulseTextSecondary` | `#97A3B3` | `#B3B3B3` (grigio neutro, non grigio-blu) |
| `pulseSurface` | `#12181F` | derivato: stesso scarto di luminosità rispetto al nuovo `pulseBackground` già usato oggi tra `pulseBackground`/`pulseSurface` attuali (circa +7/+8/+9 per canale) |
| `pulseOnAccent`, `pulsePositive`, `pulseNegative`, `pulseOnPositive`, `pulseOnNegative`, `pulseSecondaryGlow` | invariati | invariati (nessuna indicazione di cambiarli; `pulseOnAccent` va comunque riverificato per contrasto contro il nuovo `pulseAccent`) |

La variante **light** di ciascun token sopra va ricalcolata in fase di
implementazione con lo stesso metodo già documentato nei commenti esistenti
(rapporti di contrasto calcolati esplicitamente, non stimati), non è ancora
decisa in questa spec.

## Fasi

### Fase 1 — Token (`lib/theme/`)

- `lib/theme/app_colors.dart`: applicare la mappatura sopra (dark), ricalcolare
  light, aggiornare i commenti/rapporti di contrasto documentati per ogni
  token toccato (stesso stile di documentazione già in uso nel file).
- `lib/theme/app_text_styles.dart`: rimuovere `fontFamily: 'Space Grotesk'`/
  `'Inter'` da ogni ruolo tipografico, lasciando il font di sistema (nessun
  `fontFamily`), mantenendo invariata la scala di dimensioni/pesi/utilizzo
  semantico.
- `pubspec.yaml`: rimuovere la sezione `fonts:` (Space Grotesk/Inter).
- Rimuovere `assets/fonts/*.ttf`, `assets/fonts/OFL-*.txt`,
  `assets/fonts/README.md` se riguarda solo quei font.
- Verifica: `flutter analyze`/`flutter test` puliti. Nessuna verifica visiva
  possibile in questa fase da parte del coordinatore (regola CLAUDE.md); la
  fase 1 da sola cambia già l'aspetto di tutte le schermate migrate a Pulse,
  quindi la tua prima verifica visiva complessiva avviene alla fine di questa
  fase, prima di procedere alla Fase 2.

### Fase 2 — Componenti condivisi (`lib/widgets/`)

- **Correzione rispetto alla bozza iniziale**: il pattern "etichetta sopra,
  valore bold sotto, colonne separate da divisore verticale sottile" **esiste
  già** come componente condiviso, `BustaPagaStatRow`
  (`lib/widgets/busta_paga_stat_row.dart`, usato oggi in
  `busta_paga_detail_screen.dart`/`busta_paga_form_screen.dart` per Ore
  lavorate/Straordinari) — non va estratto da zero (il riferimento a
  `_StatTrio` nella bozza iniziale era basato su una parte di CLAUDE.md non
  più aggiornata rispetto al codice attuale: quella classe privata non esiste
  più in `busta_paga_summary_hero.dart`). `BustaPagaStatRow` usa già solo
  token (`AppColors.pulse*`, `AppTextStyles.pulseLabel`/`pulseDisplaySmall`),
  quindi eredita automaticamente i nuovi colori/font della Fase 1 senza
  bisogno di modifiche proprie in questa fase.
- Verificato con grep che i 3 file `liquid_glass_surface.dart`/
  `liquid_glass_button.dart`/`glass_form_section.dart` non hanno più nessun
  uso esterno (solo riferimenti interni fra loro) — dead code confermato,
  da rimuovere in questa fase.
- Verifica: `flutter analyze`/`flutter test`.

### Fase 3 — Schermate (verifica, non refactor)

**Correzione rispetto alla bozza iniziale**: verificato con grep mirato che
nessuna schermata migrata a Pulse ha colori/font hardcoded al di fuori dei
token (`AppColors.pulse*`/`AppTextStyles.pulse*`) — la Fase 1 da sola
propaga quindi il nuovo aspetto ovunque senza bisogno di modifiche di codice
per schermata. Questa fase diventa perciò una checklist di **verifica visiva**
tua, schermata per schermata, sia light sia dark, non un insieme di task di
sviluppo:
1. `busta_paga_detail_screen.dart` / `busta_paga_form_screen.dart`
2. `buste_paga_archivio_view.dart`
3. `buste_paga_statistiche_screen.dart`
4. `buste_paga_section_screen.dart` (contenitore radice, sidecar di
   navigazione)

**Migrazione icone `CupertinoIcons` → `PulseIcon` esclusa da questo piano**:
verificato che 6 dei ~10 tipi di icona ancora usati (`arrow_up_right`/
`arrow_down_right`, `info_circle`, `exclamationmark_triangle`, `bell`/
`bell_slash`) non hanno un glifo `PulseIconGlyph` equivalente già disegnato —
completarla richiederebbe progettare e implementare da zero nuova geometria
vettoriale per questi 6 glifi, un lavoro di design/implementazione a sé
stante, indipendente dal restyling colori/font oggetto di questa spec.
Rimane un impegno aperto in CLAUDE.md, da trattare come iniziativa separata.

### Fase 4 — Verifica finale

`flutter analyze`/`flutter test` complessivi; verifica visiva tua schermata
per schermata, sia light sia dark, prima di considerare il restyling
completo. Solo a quel punto si valuta un commit+push del branch `style` (su
tua istruzione esplicita, come da convenzione già in uso in questo progetto).

## Fuori scope (esplicitamente escluso da questo restyling)

- Sostituzione degli anelli di progresso con colonne piatte (decisione
  esplicita dell'utente: restano gli anelli).
- Qualunque modifica al parser PDF, al database Drift, ai provider Riverpod
  esistenti, alla logica di reminder/notifiche, o al widget home screen iOS
  stesso (già completato e mergiato in `main` prima di questo lavoro).
- Introduzione di font diversi da quello di sistema (nessuna sperimentazione
  con altri font brandizzati in questa fase).
- Completamento della migrazione icone `CupertinoIcons` → `PulseIcon`
  (richiede progettare 6 nuovi glifi vettoriali non ancora disegnati —
  iniziativa separata, vedi Fase 3).

## Rischi noti

- **Contrasto non ancora validato**: i colori esatti del widget non sono mai
  stati verificati per accessibilità (rapporti WCAG) nel contesto
  dell'interfaccia app (testo su superfici, badge, ecc.) — questa verifica va
  fatta esplicitamente durante la Fase 1, non assunta.
- **Font di sistema su superfici pensate per Space Grotesk**: alcuni layout
  potrebbero essere stati dimensionati tenendo conto delle proporzioni/altezza
  di riga di Space Grotesk (font più "squadrato" e alto) — possibile necessità
  di piccoli aggiustamenti di spaziatura durante la Fase 3, schermata per
  schermata, verificabili solo visivamente dall'utente.
- **Derivazione della variante light**: essendo calcolata da zero (nessun
  riferimento diretto dal widget, che è dark-only), richiede più iterazioni di
  verifica visiva rispetto alla variante dark.
