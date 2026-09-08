# Restyling app: stile del widget home screen — Implementation Plan

> **Per chi esegue questo piano:** questo progetto usa il workflow del
> coordinatore documentato in `CLAUDE.md` ("Come collaborare su questo
> progetto"), non le skill generiche `subagent-driven-development`/
> `executing-plans`: ogni task va delegato a un agente dev (`dev1`/`dev2`),
> seguito **sempre** da una revisione con l'agente `revisore` sullo stesso
> scope prima di considerarlo concluso. I passaggi "Commit" restano manuali
> (git-ops), solo su istruzione esplicita dell'utente per ogni singola volta.

**Goal:** Applicare a tutta l'app i colori esatti e il font di sistema già
usati nel widget home screen iOS, mantenendo light e dark mode alla pari e
senza toccare gli anelli di progresso già in uso per Ferie/ROL/Permessi/Ex
festività.

**Architecture:** Modifica centralizzata dei token in `lib/theme/`
(`app_colors.dart`, `app_text_styles.dart`) — dato che tutte le schermate
migrate a Pulse leggono esclusivamente da questi token (verificato via grep,
nessun colore/font hardcoded nelle schermate), il cambiamento si propaga
automaticamente ovunque senza toccare le singole schermate. Pulizia dei 3
file `LiquidGlassSurface`/`LiquidGlassButton`/`GlassFormSection`, confermati
dead code (nessun uso esterno alle proprie definizioni).

**Tech Stack:** Flutter/Dart, `CupertinoDynamicColor` per light/dark,
`flutter_test` (widget test esistenti + smoke test `light_dark_smoke_test.dart`).

**Spec:** `docs/superpowers/specs/2026-09-08-restyling-stile-widget-design.md`

## Global Constraints

- Nessuna modifica al parser PDF, al database Drift, ai provider Riverpod,
  alla logica di reminder/notifiche o al widget home screen iOS (già
  completato e mergiato in `main`).
- Gli anelli di progresso (`ProgressRingTile`) restano invariati.
- L'app mantiene sia light sia dark mode (non diventa dark-only).
- Nessun font diverso dal font di sistema (nessun `fontFamily` esplicito).
- La migrazione icone `CupertinoIcons` → `PulseIcon` resta fuori scope
  (richiede disegnare 6 nuovi glifi vettoriali, iniziativa separata).
- Ogni modifica va verificata con `flutter analyze` e `flutter test` puliti
  prima di passare al task successivo.

---

## Task 1: Font di sistema al posto di Space Grotesk/Inter

**Files:**
- Modify: `lib/theme/app_text_styles.dart` (rimuovere `fontFamily`/
  `fontFamilyFallback` dai 6 ruoli Pulse, righe 50-122)
- Modify: `pubspec.yaml` (rimuovere la sezione `fonts:`, righe 53-72 circa)
- Delete: `assets/fonts/SpaceGrotesk-Medium.ttf`,
  `assets/fonts/SpaceGrotesk-Bold.ttf`,
  `assets/fonts/SpaceGrotesk-ExtraBold.ttf`, `assets/fonts/Inter-Regular.ttf`,
  `assets/fonts/Inter-Medium.ttf`, `assets/fonts/Inter-SemiBold.ttf`,
  `assets/fonts/OFL-SpaceGrotesk.txt`, `assets/fonts/OFL-Inter.txt`,
  `assets/fonts/README.md` (se descrive solo questi font — verificarne il
  contenuto prima di cancellarlo)
- Test: `test/light_dark_smoke_test.dart` (esistente, nessuna modifica —
  usato per la verifica)

**Interfaces:**
- Consumes: nessuna dipendenza da task precedenti (primo task del piano).
- Produces: `AppTextStyles.pulseDisplayLarge`/`pulseDisplay`/
  `pulseDisplaySmall`/`pulseBody`/`pulseBodyEmphasis`/`pulseLabel` restano gli
  stessi nomi/firme (`TextStyle` const), usati identicamente da tutto il resto
  dell'app — il Task 2 e la Fase 3 di verifica dipendono dal fatto che questi
  nomi non cambino.

- [ ] **Step 1: Rimuovere `fontFamily`/`fontFamilyFallback` da ogni ruolo Pulse**

In `lib/theme/app_text_styles.dart`, sostituire l'intero blocco commentato e i
6 stili (righe 40-123) con:

```dart
  // --- Pulse ---
  // Ruoli tipografici della direzione "Pulse" (vedi CLAUDE.md, "Stile
  // visivo"): font di sistema ovunque (nessun `fontFamily` esplicito — su
  // iOS risolve a SF Pro Text/Display tramite CupertinoTheme). Fino al
  // 2026-09-08 questi ruoli usavano Space Grotesk/Inter bundlati offline;
  // rimossi su richiesta esplicita dell'utente dopo aver visto lo stile del
  // widget home screen (che usa già solo il font di sistema).

  /// Titoli/numeri di massimo rilievo (es. netto del mese in evidenza).
  static const pulseDisplayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  /// Titoli di sezione e valori numerici secondari (es. importi in tessere).
  static const pulseDisplay = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.15,
  );

  /// Valori numerici compatti (es. celle di tabella, badge di variazione).
  static const pulseDisplaySmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Corpo testo standard.
  static const pulseBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Corpo testo enfatizzato (peso medium).
  static const pulseBodyEmphasis = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Label/UI compatta (es. etichette sopra i valori nelle tessere).
  static const pulseLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );
}
```

Nota: `FontWeight.w800`/`w700` restano invariati — il font di sistema (SF Pro)
supporta questi pesi nativamente, nessun bisogno di ricalibrare la scala.

- [ ] **Step 2: Rimuovere la dichiarazione dei font da `pubspec.yaml`**

Cancellare l'intero blocco (commento + `fonts:` + le due famiglie), righe
53-72 circa:

```yaml
  # (blocco da rimuovere per intero)
  # visivo"): Space Grotesk (titoli/numeri/valori) + Inter (corpo/label).
  # Licenza SIL Open Font License, file in assets/fonts/ (vedi
  # assets/fonts/README.md per provenienza e come rigenerarli).
  fonts:
    - family: Space Grotesk
      fonts:
        - asset: assets/fonts/SpaceGrotesk-Medium.ttf
          weight: 500
        - asset: assets/fonts/SpaceGrotesk-Bold.ttf
          weight: 700
        - asset: assets/fonts/SpaceGrotesk-ExtraBold.ttf
          weight: 800
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
```

- [ ] **Step 3: Rimuovere i file font e le licenze non più referenziati**

```bash
git rm assets/fonts/SpaceGrotesk-Medium.ttf assets/fonts/SpaceGrotesk-Bold.ttf \
  assets/fonts/SpaceGrotesk-ExtraBold.ttf assets/fonts/Inter-Regular.ttf \
  assets/fonts/Inter-Medium.ttf assets/fonts/Inter-SemiBold.ttf \
  assets/fonts/OFL-SpaceGrotesk.txt assets/fonts/OFL-Inter.txt
```

Leggere `assets/fonts/README.md` prima di cancellarlo: se descrive solo la
provenienza di Space Grotesk/Inter, rimuoverlo con `git rm
assets/fonts/README.md`; se contiene altro contenuto rilevante, lasciarlo e
segnalarlo nel report del task.

- [ ] **Step 4: Verificare che nessun altro file referenzi ancora quei font**

```bash
grep -rn "Space Grotesk\|'Inter'\|\"Inter\"" lib/ pubspec.yaml
```

Expected: nessun risultato (a parte eventuali commenti storici in altri file
che non è necessario ripulire in questo task).

- [ ] **Step 5: `flutter pub get` e verifica statica**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: `flutter analyze` → "No issues found!"; `flutter test` → tutti i
test passano, incluso `light_dark_smoke_test.dart` (verifica che nessuna
schermata lanci eccezioni né in light né in dark dopo la rimozione dei font
custom).

- [ ] **Step 6: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/theme/app_text_styles.dart pubspec.yaml pubspec.lock assets/fonts/
git commit -m "style: sostituisci Space Grotesk/Inter col font di sistema

Rimuove i font brandizzati bundlati offline: l'utente ha chiesto di
applicare a tutta l'app lo stesso font di sistema già usato dal widget
home screen iOS.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Ricalibrare i token colore Pulse sui valori esatti del widget

**Files:**
- Modify: `lib/theme/app_colors.dart` (righe 99-167: `pulseBackground`,
  `pulseSurface`, `pulseAccent`, `pulseOnAccent`, `pulseTextPrimary`,
  `pulseTextSecondary`)
- Test: `test/light_dark_smoke_test.dart` (esistente, nessuna modifica)

**Interfaces:**
- Consumes: nessuna dipendenza diretta dal Task 1 (file diverso), ma va
  eseguito dopo per convenzione dell'ordine delle fasi nella spec.
- Produces: gli stessi nomi di token (`AppColors.pulseBackground` ecc.)
  restano `CupertinoDynamicColor` con la stessa struttura — nessuna schermata
  va modificata perché tutte risolvono già questi token via
  `CupertinoDynamicColor.resolve(context)`.

**Valori calcolati** (metodo: luminanza relativa WCAG, `L = 0.2126R +
0.7152G + 0.0722B` su componenti linearizzate; rapporto di contrasto
`(L1+0.05)/(L2+0.05)`):

| Token | Dark (nuovo) | Dark (attuale) | Light (nuovo) | Light (attuale) |
|---|---|---|---|---|
| `pulseBackground` | `#0A0F17` | `#0B1016` | `#F4F6F8` (invariato) | `#F4F6F8` |
| `pulseSurface` | `#111720` | `#12181F` | `#FFFFFF` (invariato) | `#FFFFFF` |
| `pulseAccent` | `#00B8F0` | `#3DDBFF` | `#0089AC` | `#0A8FB0` |
| `pulseOnAccent` | `#00232B` (invariato) | `#00232B` | `#FBFEFF` (invariato) | `#FBFEFF` |
| `pulseTextPrimary` | `#FFFFFF` | `#F5F8FA` | `#0E1420` (invariato) | `#0E1420` |
| `pulseTextSecondary` | `#B3B3B3` | `#97A3B3` | `#666666` | `#5B6472` |

Contrasti verificati per i valori nuovi:
- `pulseAccent` dark (`#00B8F0`, L=0.406) vs `pulseOnAccent` dark (`#00232B`,
  L=0.0138): **7.15:1**.
- `pulseAccent` light (`#0089AC`, L=0.209) vs `pulseSurface` light
  (`#FFFFFF`, L=1.0): **4.06:1** (soglia testo grande/icone, stesso livello
  già documentato per il valore precedente).
- `pulseOnAccent` light (`#FBFEFF`) vs `pulseAccent` light nuovo: stessa
  luminanza di riferimento del vecchio accent (differenza trascurabile),
  contrasto invariato ≈4:1.
- `pulseTextSecondary` light (`#666666`, L=0.133) vs `pulseSurface` light
  (`#FFFFFF`): **5.74:1** (supera 4.5:1, testo secondario leggibile).
- `pulseSurface` dark (`#111720`) derivato con lo stesso scarto per canale
  (+7,+8,+9) già usato tra `pulseBackground`/`pulseSurface` attuali, applicato
  al nuovo `pulseBackground` dark.

`pulsePositive`/`pulseNegative`/`pulseOnPositive`/`pulseOnNegative`/
`pulseSecondaryGlow` **non cambiano** (fuori dalla palette del widget).

- [ ] **Step 1: Aggiornare i 6 token in `lib/theme/app_colors.dart`**

Sostituire il blocco (righe 99-155 circa, da `// --- Pulse ---` fino a prima
di `pulseSecondaryGlow`) con:

```dart
  // --- Pulse ---
  // Nuova direzione visiva (vedi CLAUDE.md, "Stile visivo"): superfici piatte
  // a colore pieno, dark-first, accento ciano/cobalto elettrico. Dal
  // 2026-09-08 i valori dark sono quelli esatti già validati nel widget home
  // screen iOS (`ios/BustaPagaWidgetExtension/BustaPagaWidgetView.swift`,
  // `BustaPagaWidgetColors`) su richiesta esplicita dell'utente; i valori
  // light sono stati ricalcolati per preservare la stessa gerarchia e gli
  // stessi rapporti di contrasto minimi già in uso (vedi commenti di
  // ciascun token, rapporti calcolati con la formula di luminanza relativa
  // WCAG, non stimati).

  /// Sfondo pagina. Light: bianco/grigio molto chiaro e freddo (invariato).
  /// Dark: quasi-nero freddo — valore esatto del widget home screen.
  static const pulseBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF4F6F8),
    darkColor: Color(0xFF0A0F17),
  );

  /// Superficie "tessera" (card, tile, riga di elenco): un grado più chiara
  /// dello sfondo in entrambi i temi. Dark derivato mantenendo lo stesso
  /// scarto per canale (+7,+8,+9) già usato prima di questo aggiornamento
  /// tra sfondo e superficie, applicato al nuovo `pulseBackground` dark (il
  /// widget non ha un concetto di superficie separata dallo sfondo).
  static const pulseSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF111720),
  );

  /// Accento primario ciano/cobalto elettrico: CTA, valori di rilievo,
  /// riempimento pieno del blocco netto del mese, stati attivi in
  /// navigazione. Dark: valore esatto del widget (#00B8F0). Light:
  /// ricalcolato per la stessa hue, contrasto 4.06:1 su `pulseSurface`
  /// chiara — soglia testo grande/icone (WCAG), non corpo testo piccolo.
  static const pulseAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0089AC),
    darkColor: Color(0xFF00B8F0),
  );

  /// Testo/icone sopra un riempimento pieno di `pulseAccent`. Invariato:
  /// contrasto riverificato contro i nuovi valori di `pulseAccent` — 7.15:1
  /// dark, ≈4:1 light — entrambi confermati sopra soglia.
  static const pulseOnAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFBFEFF),
    darkColor: Color(0xFF00232B),
  );

  /// Testo primario sopra le superfici Pulse. Light invariato (quasi-nero).
  /// Dark: bianco puro, valore esatto del widget (era un bianco leggermente
  /// sporcato, #F5F8FA).
  static const pulseTextPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0E1420),
    darkColor: Color(0xFFFFFFFF),
  );

  /// Testo secondario/label sopra le superfici Pulse. Dark: grigio neutro,
  /// valore esatto del widget (#B3B3B3, non più grigio-bluastro). Light:
  /// ricalcolato come grigio neutro equivalente (stessa desaturazione),
  /// contrasto 5.74:1 su `pulseSurface` chiara.
  static const pulseTextSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF666666),
    darkColor: Color(0xFFB3B3B3),
  );
```

Lasciare invariato tutto il resto del file (`pulseSecondaryGlow`,
`pulsePositive`, `pulseNegative`, `pulseOnPositive`, `pulseOnNegative`, e i
token pre-Pulse sopra come `systemGreen`/`glassFill`/ecc.).

- [ ] **Step 2: Verifica statica**

```bash
flutter analyze
flutter test
```

Expected: entrambi puliti, incluso `light_dark_smoke_test.dart` (nessuna
eccezione con i nuovi colori, né in light né in dark).

- [ ] **Step 3: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/theme/app_colors.dart
git commit -m "style: ricalibra i token colore Pulse sui valori del widget

pulseBackground/pulseAccent/pulseTextPrimary/pulseTextSecondary dark
ora combaciano esattamente coi colori già validati nel widget home
screen iOS; le varianti light sono ricalcolate mantenendo gli stessi
rapporti di contrasto minimi già documentati.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Rimuovere i widget Liquid Glass ormai morti

**Files:**
- Delete: `lib/widgets/liquid_glass_surface.dart`
- Delete: `lib/widgets/liquid_glass_button.dart`
- Delete: `lib/widgets/glass_form_section.dart`

**Interfaces:**
- Consumes: nessuna dipendenza dai Task 1/2.
- Produces: nessuna — sola rimozione, nessun altro file dipende da questi tre.

- [ ] **Step 1: Riconfermare che sono dead code**

```bash
grep -rln "LiquidGlassSurface(\|LiquidGlassButton(\|GlassFormSection(" lib/ \
  | grep -v -e liquid_glass_surface.dart -e liquid_glass_button.dart -e glass_form_section.dart
```

Expected: nessun risultato (già verificato in fase di brainstorming/spec — se
questo comando restituisce un file, FERMARSI e segnalarlo invece di
procedere: significa che qualcosa li usa ancora).

- [ ] **Step 2: Rimuovere i 3 file**

```bash
git rm lib/widgets/liquid_glass_surface.dart lib/widgets/liquid_glass_button.dart lib/widgets/glass_form_section.dart
```

- [ ] **Step 3: Verifica statica**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` pulito (nessun import rotto — se qualcosa importa
ancora uno di questi 3 file, l'analyzer lo segnala qui); `flutter test`
tutti verdi.

- [ ] **Step 4: Commit** (solo su istruzione esplicita dell'utente)

```bash
git commit -m "chore: rimuovi i widget Liquid Glass non più usati

liquid_glass_surface/liquid_glass_button/glass_form_section non hanno
più nessun uso nell'app dopo la migrazione a Pulse — dead code.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Verifica finale (non un task di sviluppo)

Dopo i 3 task sopra, per policy di questo progetto il coordinatore si ferma
alla verifica statica (`flutter analyze`/`flutter test`) — la verifica
visiva è solo tua. Checklist da percorrere sia in **light** sia in **dark**:

1. `busta_paga_detail_screen.dart` / `busta_paga_form_screen.dart`
2. `buste_paga_archivio_view.dart`
3. `buste_paga_statistiche_screen.dart`
4. `buste_paga_section_screen.dart` (contenitore radice, sidecar)

Cose da guardare in particolare: leggibilità del testo secondario grigio
neutro (nuovo, non più grigio-bluastro) su entrambe le modalità; il nuovo
accento ciano più "elettrico"/saturo rispetto a prima; eventuali righe che
sembravano dimensionate per Space Grotesk (font più "alto") e che con SF Pro
potrebbero avere spaziatura verticale leggermente diversa.

Se qualcosa non torna visivamente, segnalalo con la schermata e il dettaglio
(light o dark, quale elemento) — si delega un fix mirato a dev1/dev2 seguito
da `revisore`, come da workflow standard, senza dover rifare l'intero task.
