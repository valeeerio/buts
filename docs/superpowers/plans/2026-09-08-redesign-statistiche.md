# Redesign Statistiche: grafici + filtro periodo — Implementation Plan

> **Per chi esegue questo piano:** questo progetto usa il workflow del
> coordinatore documentato in `CLAUDE.md` ("Come collaborare su questo
> progetto"): ogni task va delegato a un agente dev (`dev1`/`dev2`), seguito
> **sempre** da una revisione con l'agente `revisore` sullo stesso scope. I
> passaggi "Commit" restano manuali (git-ops), solo su istruzione esplicita
> dell'utente.

**Goal:** Ridisegnare le 3 card della schermata Statistiche (Netto, Ferie/
Permessi/Ex festività, Straordinario) con palette monocromatica ciano,
drill-down al tap sui dati, confronto anno su anno per Netto/Straordinario, e
sostituire il filtro periodo con preset rapidi + opzione "Personalizza".

**Architecture:** Le 3 card restano nello stesso file
`lib/screens/buste_paga/buste_paga_statistiche_screen.dart` (pattern
consolidato: `_ChartCard` genitore generico + una classe chart privata per
card). Nuovo widget pubblico condiviso `BustaPagaDrilldownSheet` in
`lib/widgets/` per il drill-down (riusato da tutte e 3 le card). Nuovo widget
pubblico `PeriodPresetPicker` in `lib/widgets/` per i preset del filtro,
usato al posto diretto di `CollapsiblePeriodPicker` in
`buste_paga_section_screen.dart` (che resta disponibile dietro "Personalizza").
`BustePagaStatisticheScreen` passa da `ConsumerWidget` a
`ConsumerStatefulWidget` per tenere lo stato locale del toggle "Confronta con
l'anno precedente".

**Tech Stack:** Flutter/Dart, `fl_chart` (LineChart/BarChart già in uso),
Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-08-redesign-statistiche-design.md`

## Global Constraints

- Palette: solo `AppColors.pulseAccent` (ciano) per ogni valore/serie
  principale nei 3 grafici. Via `AppColors.pulseSecondaryGlow` (viola) come
  colore-dato e ogni glow/bagliore diffuso. Serie di confronto (anno
  precedente) = stesso ciano a opacità ridotta + tratteggio/contorno, mai un
  secondo hue. `pulsePositive`/`pulseNegative` solo per badge di stato, mai
  come colore-dato nei grafici.
- Font di sistema (già applicato a tutta l'app, nessuna modifica qui).
- Nessuna modifica alla logica interna di selezione a due tocchi di
  `PeriodYearMonthPicker` — resta invariata, usata solo dietro "Personalizza".
- Nessun confronto anno su anno per la card Ferie/Permessi/Ex festività
  (snapshot puntuale, fuori scope).
- Ogni task verificato con `flutter analyze`/`flutter test` puliti prima di
  passare al successivo.
- Verifica visiva finale sempre a carico dell'utente (light e dark), mai del
  coordinatore/agenti.

---

## Task 1: Bottom sheet di drill-down condiviso

**Files:**
- Create: `lib/widgets/busta_paga_drilldown_sheet.dart`
- Test: `test/widgets/busta_paga_drilldown_sheet_test.dart`

**Interfaces:**
- Consumes: `BustaPagaHeroCard` (`lib/widgets/busta_paga_hero_card.dart`,
  parametri `isConfermato`, `periodoLabel`, `lordoDisplay`, `nettoDisplay` —
  tutte stringhe già formattate), `PulseSurface`
  (`lib/widgets/pulse_surface.dart`), `formatEuroConSegno`/`periodoLabel` da
  `lib/utils/busta_paga_formatting.dart` (stesse funzioni già usate altrove
  per formattare `BustaPaga`).
- Produces: funzione top-level `Future<void> showBustaPagaDrilldown(
  BuildContext context, BustaPaga busta)` — questa è la firma che i Task 2/3/4
  chiameranno al tap sui dati del grafico. Nessun altro simbolo pubblico.

- [ ] **Step 1: Scrivere il widget del contenuto del sheet**

Nuovo file `lib/widgets/busta_paga_drilldown_sheet.dart`:

```dart
import 'package:flutter/cupertino.dart';

import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'busta_paga_hero_card.dart';
import 'pulse_surface.dart';
import 'spring_button.dart';

/// Bottom sheet di sola lettura con i dati essenziali di una busta paga,
/// aperto al tap su un punto/barra/anello dei grafici in Statistiche
/// (drill-down, vedi CLAUDE.md/spec redesign 2026-09-08). Stesso pattern
/// `showCupertinoModalPopup` + `PulseSurface` già usato per i picker in
/// `busta_paga_detail_screen.dart` (`_pickPeriodo`/`_pickTipo`), non un
/// nuovo pattern di overlay.
Future<void> showBustaPagaDrilldown(
  BuildContext context,
  BustaPaga busta,
) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => _BustaPagaDrilldownSheet(busta: busta),
  );
}

class _BustaPagaDrilldownSheet extends StatelessWidget {
  final BustaPaga busta;

  const _BustaPagaDrilldownSheet({required this.busta});

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final isConfermato =
        busta.statoVerifica == StatoVerificaBustaPaga.confermato;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SafeArea(
        top: false,
        child: PulseSurface(
          borderRadius: AppRadius.pulse,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BustaPagaHeroCard(
                isConfermato: isConfermato,
                periodoLabel: bustaPagaPeriodoDisplay(busta),
                lordoDisplay: formatEuroConSegno(busta.lordo),
                nettoDisplay: formatEuroConSegno(busta.netto),
              ),
              const SizedBox(height: AppSpacing.md),
              _RigaResiduo(
                label: 'Ferie residue',
                value: formatNumber(busta.ferieResidue),
                textSecondary: textSecondary,
              ),
              _RigaResiduo(
                label: 'Permessi residui',
                value: formatNumber(busta.rolResidui),
                textSecondary: textSecondary,
              ),
              _RigaResiduo(
                label: 'Ex festività residue',
                value: formatNumber(busta.exFestivitaResidue),
                textSecondary: textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              SpringButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.mdMinus,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pulseSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Chiudi',
                    style: AppTextStyles.pulseBodyEmphasis.copyWith(
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RigaResiduo extends StatelessWidget {
  final String label;
  final String value;
  final Color textSecondary;

  const _RigaResiduo({
    required this.label,
    required this.value,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.pulseBody.copyWith(color: textSecondary)),
          Text(
            value,
            style: AppTextStyles.pulseBodyEmphasis.copyWith(color: textPrimary),
          ),
        ],
      ),
    );
  }
}
```

Verifica prima di procedere: `bustaPagaPeriodoDisplay`/`formatNumber` sono i
nomi reali esportati da `lib/utils/busta_paga_formatting.dart` (usati già
altrove, es. `busta_paga_summary_hero.dart` per `bustaPagaPeriodoDisplay`,
`home_widget_service.dart` per `formatNumber`) — se la firma reale differisce
leggermente, adattare mantenendo lo stesso comportamento (numero già
formattato in italiano), non inventare una nuova funzione di formattazione.
`AppRadius.pulse`/`pulseSmall` sono già usati altrove nel file
`app_spacing.dart` — verificarne l'import corretto.

- [ ] **Step 2: Scrivere il test widget**

`test/widgets/busta_paga_drilldown_sheet_test.dart`:

```dart
import 'package:buts/models/busta_paga.dart';
import 'package:buts/widgets/busta_paga_drilldown_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

BustaPaga _busta({
  required StatoVerificaBustaPaga stato,
}) {
  return BustaPaga(
    id: 'bp-test',
    periodo: DateTime(2026, 5),
    lordo: 1563.99,
    netto: 1427.00,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 20,
    ferieGodute: 7.67,
    ferieResidue: 12.33,
    rolMaturati: 30,
    rolGoduti: 5.94,
    rolResidui: 24.06,
    permessiGoduti: 0,
    exFestivitaMaturate: 32,
    exFestivitaGodute: 5.33,
    exFestivitaResidue: 26.67,
    oreLavorate: 168,
    statoVerifica: stato,
  );
}

void main() {
  testWidgets('mostra periodo, netto, lordo e i 3 residui', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showBustaPagaDrilldown(
              context,
              _busta(stato: StatoVerificaBustaPaga.confermato),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Maggio 2026'), findsOneWidget);
    expect(find.textContaining('1.427,00'), findsOneWidget);
    expect(find.textContaining('1.563,99'), findsOneWidget);
    expect(find.text('Ferie residue'), findsOneWidget);
    expect(find.text('Permessi residui'), findsOneWidget);
    expect(find.text('Ex festività residue'), findsOneWidget);
  });

  testWidgets('il bottone Chiudi chiude il sheet', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showBustaPagaDrilldown(
              context,
              _busta(stato: StatoVerificaBustaPaga.daConfermare),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Chiudi'), findsOneWidget);

    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.text('Chiudi'), findsNothing);
  });
}
```

- [ ] **Step 3: Eseguire i test e verificare**

Run: `flutter test test/widgets/busta_paga_drilldown_sheet_test.dart`
Expected: entrambi i test passano.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 4: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/widgets/busta_paga_drilldown_sheet.dart test/widgets/busta_paga_drilldown_sheet_test.dart
git commit -m "feat(statistiche): aggiungi bottom sheet di drill-down busta paga

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Card "Netto" — linea singola, drill-down, via il Lordo dalla vista principale

**Files:**
- Modify: `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
  (classe `_NettoLordoChart`, righe ~1150-1346; funzione `_nettoLordoStats`,
  righe ~585-624; costanti colore righe 50-63; il punto in cui `_ChartCard`
  viene istanziato per questa card, con `title`/`subtitle`)
- Test: `test/buste_paga_statistiche_screen_test.dart` (esistente — leggerlo
  per capire i test attuali su questa card prima di modificarli)

**Interfaces:**
- Consumes: `showBustaPagaDrilldown` dal Task 1.
- Produces: la card ora si chiama internamente "Netto" (non più "Netto e
  lordo") — questo è un cambio visibile all'utente, non un'interfaccia
  consumata da altro codice.

- [ ] **Step 1: Leggere il file per il contesto esatto attuale**

Prima di modificare, leggere `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
righe 1150-1346 (`_NettoLordoChart`) e 585-624 (`_nettoLordoStats`) per
avere il codice esatto attuale da cui partire — questo piano descrive il
comportamento target, non un diff riga-per-riga da applicare alla cieca,
perché il file è grande e i numeri di riga possono essere leggermente
sfalsati rispetto a quando è stato scritto questo piano.

- [ ] **Step 2: Rinominare la classe e rimuovere la serie Lordo**

Rinominare `_NettoLordoChart` in `_NettoChart` (aggiornare anche il punto di
istanziazione). Rimuovere interamente `_lordoLine`/il relativo
`LineChartBarData` viola dall'array `lineBarsData` — resta solo la linea
Netto (`_nettoLine`, `AppColors.pulseAccent`). Rimuovere anche il parametro/
riferimento a `_lordoColor` se non più usato altrove nel file (verificare con
grep prima di rimuovere la costante `_lordoColor` a riga ~53: se
`_nettoLordoStats`/altre viste la referenziano ancora, valutare caso per
caso, ma l'obiettivo finale è che nessun grafico usi più `pulseSecondaryGlow`
come colore-dato).

Nel tooltip (`_tooltipItem`, righe ~1268-1291), rimuovere la riga "Lordo" —
resta solo periodo + Netto.

- [ ] **Step 3: Rimuovere il glow/shadow dalla linea Netto**

Nel `LineChartBarData` di `_nettoLine`, rimuovere il parametro `shadow:
Shadow(...)` (il vincolo globale del piano vieta glow/bagliori nei grafici).
Mantenere `belowBarData`/l'area sotto la linea se contribuisce alla
leggibilità (non è un "glow", è un riempimento pieno a bassa opacità — non
vietato dal vincolo, che riguarda specificamente bagliori/ombre diffuse),
ma verificare che il gradiente dell'area resti in tonalità ciano (nessun
cambiamento necessario se già lo è).

- [ ] **Step 4: Collegare il tap sui punti al drill-down**

`LineTouchData` espone `touchCallback: (FlTouchEvent event, LineTouchResponse?
response)`. Aggiungere (o estendere se già presente per altro) questo
callback: quando `event is FlTapUpEvent` (tap secco, non hover/drag — così il
tooltip nativo di fl_chart resta utilizzabile per lo scrubbing senza aprire
il sheet ad ogni sfioramento) e `response?.lineBarSpots` non è vuoto,
recuperare l'indice dello spot toccato (`response!.lineBarSpots!.first.spotIndex`)
e risalire alla `BustaPaga` corrispondente nella griglia mensile calcolata da
`_grigliaMensile` (saltare gli spot corrispondenti a `busta: null`, cioè mesi
senza dati — nessuna azione al tap su un buco della griglia). Se trovata,
chiamare `showBustaPagaDrilldown(context, busta)`.

Questo richiede che `_NettoChart` (ora `StatelessWidget`, verificare se serve
diventare `StatefulWidget` per tenere un riferimento stabile alla griglia
mensile calcolata — probabile che no, dato che può essere ricalcolata al
volo dentro il callback dagli stessi `buste`/`estendiFinoA` già ricevuti come
parametri) abbia accesso a un `BuildContext` valido nel `touchCallback` (lo
ha, essendo dentro `build`).

- [ ] **Step 5: Aggiornare titolo, sottotitolo e tabella statistiche**

Nel punto in cui `_ChartCard` è istanziato per questa card, cambiare
`title: 'Netto e lordo'` in `title: 'Netto'`.

In `_nettoLordoStats` (righe ~585-624), rimuovere la colonna Lordo dai dati
restituiti (`_StatsTableData.colonne` deve contenere solo `['Netto']`, ogni
riga di `righe` un solo valore invece di due) — la tabella Media/Minimo/
Massimo/Totale mostrerà quindi una sola colonna. Rinominare la funzione in
`_nettoStats` se il nome aiuta la leggibilità (facoltativo, non
obbligatorio).

- [ ] **Step 6: Verificare e aggiornare i test esistenti**

Leggere `test/buste_paga_statistiche_screen_test.dart` per trovare i test che
assumono la presenza della linea/colonna Lordo nella card Netto e
aggiornarli di conseguenza (aspettative sul numero di colonne della tabella,
eventuali asserzioni sul colore/presenza della serie Lordo). Non rimuovere
test che restano validi (es. calcolo di Media/Minimo/Massimo sul Netto).

- [ ] **Step 7: Eseguire i test**

Run: `flutter test`
Expected: tutti verdi, incluso il file di test aggiornato.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 8: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/screens/buste_paga/buste_paga_statistiche_screen.dart test/buste_paga_statistiche_screen_test.dart
git commit -m "feat(statistiche): card Netto a linea singola con drill-down

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Card "Ferie, Permessi, Ex festività" — anelli monocromatici + drill-down

**Files:**
- Modify: `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
  (classe `_FerieRolPermessiSnapshot`, righe ~1360-1429; costanti
  `_ferieColor`/`_permessiRolColor`/`_exFestivitaColor`, righe 55-58)
- Test: `test/buste_paga_statistiche_screen_test.dart`

**Interfaces:**
- Consumes: `showBustaPagaDrilldown` dal Task 1.

- [ ] **Step 1: Unificare i 3 colori degli anelli**

Sostituire `_ferieColor`/`_permessiRolColor`/`_exFestivitaColor` (righe
55-58) con un singolo riferimento a `AppColors.pulseAccent` per tutti e 3, o
mantenere 3 costanti separate ma tutte assegnate allo stesso colore con
opacità leggermente diverse se la leggibilità dei 3 cerchi affiancati ne
risente (es. 1.0 / 0.8 / 0.6) — decisione di dettaglio lasciata
all'implementazione, il vincolo è "stessa tinta ciano per tutti e 3, mai 3
hue diversi".

- [ ] **Step 2: Rendere ogni anello tappabile**

In `_FerieRolPermessiSnapshot.build`, avvolgere ciascuno dei 3
`ProgressRingTile` (righe ~1391-1425) in un `GestureDetector` (o
`CupertinoButton` con `padding: EdgeInsets.zero` se serve un feedback di
pressione coerente col resto dell'app — verificare come altri elementi
tappabili nello stesso file gestiscono il feedback, es. `SpringButton` se già
importato) con `onTap: () => showBustaPagaDrilldown(context, ultima)` — la
stessa variabile `ultima` (riga ~1380) usata per calcolare i 3 progressi,
quindi il tap su qualsiasi anello apre lo stesso dettaglio.

- [ ] **Step 3: Verificare e aggiornare i test esistenti**

Leggere `test/buste_paga_statistiche_screen_test.dart` per eventuali
asserzioni sui colori distinti dei 3 anelli e aggiornarle. Aggiungere (o
verificare che esista già una copertura equivalente) un test che tocca un
anello e verifica che il sheet di drill-down si apra con i dati della busta
paga attesa (`ultima`).

- [ ] **Step 4: Eseguire i test**

Run: `flutter test`
Expected: tutti verdi.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 5: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/screens/buste_paga/buste_paga_statistiche_screen.dart test/buste_paga_statistiche_screen_test.dart
git commit -m "feat(statistiche): anelli Ferie/Permessi/Ex festività monocromatici e tappabili

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Card "Straordinario per mese" — barre piene ciano + drill-down

**Files:**
- Modify: `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
  (classe `_StraordinarioChart`/`_StraordinarioChartState`, righe
  ~1446-1743+; costanti `_straordinarioGradientTop`/`_straordinarioGradientBottom`/
  `_straordinarioGlowColor`, righe 61-63)
- Test: `test/buste_paga_statistiche_screen_test.dart`

**Interfaces:**
- Consumes: `showBustaPagaDrilldown` dal Task 1.

- [ ] **Step 1: Sostituire il gradiente viola→ciano con ciano pieno**

Nel `BarChartRodData` (righe ~1717-1732), sostituire il `gradient:
LinearGradient(colors: [...])` con un riempimento `color:
AppColors.pulseAccent` risolto via `CupertinoDynamicColor.resolve` (niente
più `gradientTop`/`gradientBottom`), mantenendo la differenza di opacità già
esistente tra la barra del mese col valore massimo (piena) e le altre
(alpha ridotto, es. 0.55, valore già in uso oggi — riusarlo) per continuità
visiva.

- [ ] **Step 2: Rimuovere il glow dietro la barra massima**

Rimuovere il `Positioned`/`Container` con `BoxShadow`
(`glowDietroBarraMassima`, righe ~1610-1637) e ogni calcolo di posizionamento
associato che serviva solo a quello (verificare che non sia riusato per
altro prima di rimuovere il codice di calcolo della coordinata X).

- [ ] **Step 3: Collegare il tap sulle barre al drill-down**

`BarChartData` espone `barTouchData: BarTouchData(touchCallback: (event,
response) {...})`, stesso pattern del Task 2 Step 4: su `FlTapUpEvent` con
`response?.spot != null`, usare `response!.spot!.touchedBarGroupIndex` per
risalire al mese/`BustaPaga` corrispondente nella griglia (stessa logica di
`_grigliaMensile`/`_grigliaTrimestrale` già usata per costruire le barre —
se il grafico è in modalità trimestrale, il drill-down su una barra
trimestrale può aprire la busta paga dell'ULTIMO mese del trimestre, scelta
più semplice e prevedibile di un menu di scelta fra 3 mesi — nessuna busta
paga per mesi senza dati: nessuna azione al tap su un buco).

- [ ] **Step 4: Verificare e aggiornare i test esistenti**

Leggere `test/buste_paga_statistiche_screen_test.dart` per asserzioni sul
gradiente/colore delle barre e aggiornarle. Aggiungere un test che tocca una
barra e verifica l'apertura del drill-down con la busta paga attesa.

- [ ] **Step 5: Eseguire i test**

Run: `flutter test`
Expected: tutti verdi.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 6: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/screens/buste_paga/buste_paga_statistiche_screen.dart test/buste_paga_statistiche_screen_test.dart
git commit -m "feat(statistiche): barre Straordinario piene ciano e tappabili

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Confronto anno su anno (Netto + Straordinario)

**Files:**
- Modify: `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
  (`BustePagaStatisticheScreen`: da `ConsumerWidget` a
  `ConsumerStatefulWidget`; `_NettoChart`; `_StraordinarioChart`/
  `_StraordinarioChartState`)
- Test: `test/buste_paga_statistiche_screen_test.dart`

**Interfaces:**
- Consumes: nessuna dipendenza dai task precedenti a livello di firma, ma
  richiede che Task 2 e Task 4 siano già completi (i grafici devono già
  essere monocromatici a singola serie prima di aggiungere la seconda serie
  "fantasma").
- Produces: `_NettoChart`/`_StraordinarioChart` guadagnano un nuovo parametro
  opzionale `List<BustaPaga>? busteAnnoPrecedente` (nome indicativo — stesso
  tipo `List<BustaPaga>` del parametro `buste` principale, i dati dello
  stesso range di mesi ma anno-1). Quando `null` o vuoto, il comportamento è
  identico a prima di questo task (nessuna seconda serie disegnata).

- [ ] **Step 1: Convertire `BustePagaStatisticheScreen` in `ConsumerStatefulWidget`**

```dart
class BustePagaStatisticheScreen extends ConsumerStatefulWidget {
  final ({DateTime start, DateTime end})? periodoFiltro;

  const BustePagaStatisticheScreen({super.key, this.periodoFiltro});

  // ... costanti statiche invariate (_fadeHeight, _nettoColor, ecc.) ...

  @override
  ConsumerState<BustePagaStatisticheScreen> createState() =>
      _BustePagaStatisticheScreenState();
}

class _BustePagaStatisticheScreenState
    extends ConsumerState<BustePagaStatisticheScreen> {
  bool _confrontaAnnoPrecedente = false;

  @override
  Widget build(BuildContext context) {
    // corpo del vecchio `build(BuildContext context, WidgetRef ref)`,
    // sostituendo `periodoFiltro` con `widget.periodoFiltro` ovunque compare,
    // e `ref` resta disponibile come proprietà di `ConsumerState`.
    ...
  }
}
```

Attenzione: tutte le costanti statiche (`_fadeHeight`, `_nettoColor`, ecc.,
righe 46-63) restano sulla classe `BustePagaStatisticheScreen` (il widget),
non sullo `State` — riferirle come `BustePagaStatisticheScreen._nettoColor`
dentro lo `State`, o re-importarle localmente se il file usa già un pattern
simile altrove (verificare come altri `ConsumerStatefulWidget` del progetto,
es. `busta_paga_detail_screen.dart`, gestiscono costanti statiche
condivise fra widget e state, per coerenza di stile).

- [ ] **Step 2: Calcolare i dati dell'anno precedente**

Aggiungere una funzione pura (accanto alle altre funzioni helper del file,
es. vicino a `_grigliaMensile`):

```dart
/// Sottoinsieme di [buste] che cade nello stesso range di [start]/[end] ma
/// un anno prima — stesso identico criterio di inclusione di [filtrati]
/// nella schermata (nessun filtro aggiuntivo), usato per il confronto anno
/// su anno opzionale di Netto/Straordinario.
List<BustaPaga> _busteAnnoPrecedente({
  required List<BustaPaga> tutte,
  required DateTime start,
  required DateTime end,
}) {
  final startAnnoPrima = DateTime(start.year - 1, start.month);
  final endAnnoPrima = DateTime(end.year - 1, end.month);
  return tutte
      .where((b) =>
          !b.periodo.isBefore(startAnnoPrima) &&
          !b.periodo.isAfter(endAnnoPrima))
      .toList()
    ..sort((a, b) => a.periodo.compareTo(b.periodo));
}
```

Nel `build` di `_BustePagaStatisticheScreenState`, quando
`_confrontaAnnoPrecedente == true` e `filtro != null` (il confronto anno su
anno richiede un range esplicito — se `periodoFiltro` è `null`, ovvero "Da
sempre", non c'è un "anno prima" ben definito: in quel caso disabilitare/
nascondere il controllo del toggle, non provare a calcolarlo), calcolare
`busteAnnoPrecedente = _busteAnnoPrecedente(tutte: sorted, start: filtro.start,
end: filtro.end)` e passarlo a `_NettoChart`/`_StraordinarioChart`.

- [ ] **Step 3: Disegnare la serie "fantasma" in `_NettoChart`**

Aggiungere il parametro `List<BustaPaga>? busteAnnoPrecedente` al
costruttore. Se non nullo/non vuoto, calcolare una seconda griglia mensile
(`_grigliaMensile(busteAnnoPrecedente, estendiFinoA: ...)`, stessa lunghezza
in mesi della griglia principale) e aggiungere un secondo
`LineChartBarData` a `lineBarsData`: stesso colore `AppColors.pulseAccent`
ma con `color: color.withValues(alpha: 0.35)`, `dashArray: [6, 4]` (tratto
tratteggiato — parametro nativo `LineChartBarData.dashArray`), nessun
`belowBarData` (niente area riempita per la serie di confronto, solo la
linea). Escludere questa seconda serie da `LineTouchData`/dal drill-down
(il tap continua a riferirsi solo alla serie principale) — verificare se
`fl_chart` permette di escludere singole serie dal touch tramite l'ordine in
`lineBarsData`/proprietà dedicate, altrimenti nel `touchCallback` ignorare
gli spot che appartengono all'indice della serie di confronto.

- [ ] **Step 4: Disegnare le barre "fantasma" in `_StraordinarioChart`**

Stesso principio: parametro `List<BustaPaga>? busteAnnoPrecedente`,
raggruppare le barre in coppie affiancate per mese (fl_chart supporta più
`BarChartRodData` per singolo `BarChartGroupData` — usare
`barsSpace`/`BarChartGroupData(barRods: [rodCorrente, rodAnnoPrima])`),
la barra dell'anno precedente disegnata con `color: Colors.transparent,
border: Border.all(color: AppColors.pulseAccent.resolved, width: 1.5)`
(contorno, nessun riempimento — fl_chart non ha un parametro "outline"
diretto su `BarChartRodData`, verificare se serve simularlo con un
`BackgroundBarChartRodData` o un rod separato con `color` a bordo; usare il
proprio giudizio implementativo per ottenere l'effetto "solo contorno"
descritto nella spec, mantenendo il vincolo di palette).

- [ ] **Step 5: Aggiungere il controllo del toggle nella UI**

Aggiungere un controllo (es. `CupertinoSwitch` piccolo, o un
`FlatChipButton` non-primary con icona, da scegliere in base a cosa si
integra meglio visivamente — decisione di dettaglio implementativa) con
etichetta "Confronta con l'anno precedente", posizionato una sola volta a
livello di schermata (non duplicato per ogni card) in un punto ragionevole
del layout (es. sopra la prima card, o nell'header insieme al filtro
periodo — verificare lo spazio disponibile leggendo il resto del `build`
prima di decidere), che aggiorna `_confrontaAnnoPrecedente` via `setState`.
Disabilitato/nascosto quando `periodoFiltro == null` (vedi Step 2).

- [ ] **Step 6: Verificare e aggiornare i test esistenti**

Aggiungere test che: attivando il toggle con un `periodoFiltro` non-null,
la seconda serie/le barre fantasma compaiono; con `periodoFiltro == null` il
controllo non è interagibile o non è presente.

- [ ] **Step 7: Eseguire i test**

Run: `flutter test`
Expected: tutti verdi.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 8: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/screens/buste_paga/buste_paga_statistiche_screen.dart test/buste_paga_statistiche_screen_test.dart
git commit -m "feat(statistiche): confronto anno su anno per Netto e Straordinario

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Filtro periodo — preset rapidi + sottotitolo periodo su ogni card

**Files:**
- Create: `lib/widgets/period_preset_picker.dart`
- Modify: `lib/screens/buste_paga/buste_paga_section_screen.dart` (punto di
  istanziazione di `CollapsiblePeriodPicker`, righe ~695-704)
- Modify: `lib/screens/buste_paga/buste_paga_statistiche_screen.dart`
  (passare un `subtitle` calcolato a ogni `_ChartCard`)
- Test: `test/widgets/period_preset_picker_test.dart`,
  `test/buste_paga_statistiche_screen_test.dart`

**Interfaces:**
- Consumes: `CollapsiblePeriodPicker`/`PeriodYearMonthPicker` esistenti
  (invariati), `FlatChipButton`.
- Produces: `PeriodPresetPicker` — stesso "contratto" dati di
  `CollapsiblePeriodPicker` verso il chiamante (`minDate`, `maxDate`,
  `startValue`, `endValue`, `onChanged: ValueChanged<({DateTime start,
  DateTime end})>`), drop-in replacement nello stesso punto di
  istanziazione.

- [ ] **Step 1: Scrivere `PeriodPresetPicker`**

Nuovo file `lib/widgets/period_preset_picker.dart`:

```dart
import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'collapsible_period_picker.dart';
import 'flat_chip_button.dart';

/// Sostituisce l'apertura diretta di [CollapsiblePeriodPicker] come primo
/// livello di interazione col filtro periodo: una riga di preset rapidi
/// ("Questo mese", "Ultimi 3 mesi", "Anno corrente", "Da sempre") più un
/// chip "Personalizza" che apre [CollapsiblePeriodPicker] (logica interna
/// di selezione a due tocchi invariata) solo per range non standard — vedi
/// spec redesign Statistiche 2026-09-08.
class PeriodPresetPicker extends StatefulWidget {
  final DateTime minDate;
  final DateTime maxDate;
  final DateTime startValue;
  final DateTime endValue;
  final ValueChanged<({DateTime start, DateTime end})> onChanged;

  const PeriodPresetPicker({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
  });

  @override
  State<PeriodPresetPicker> createState() => _PeriodPresetPickerState();
}

class _PeriodPresetPickerState extends State<PeriodPresetPicker> {
  bool _personalizzaAperto = false;

  /// Clampa [range] dentro [minDate]/[maxDate] — un preset come "Ultimi 3
  /// mesi" applicato quando ci sono solo 2 mesi di storico deve ridursi al
  /// range disponibile, non restituire un range fuori dai dati reali.
  ({DateTime start, DateTime end}) _clamp(
    ({DateTime start, DateTime end}) range,
  ) {
    final start = range.start.isBefore(widget.minDate) ? widget.minDate : range.start;
    final end = range.end.isAfter(widget.maxDate) ? widget.maxDate : range.end;
    return (start: start, end: end);
  }

  void _applica(({DateTime start, DateTime end}) range) {
    widget.onChanged(_clamp(range));
  }

  void _questoMese() {
    final fine = widget.maxDate;
    _applica((start: DateTime(fine.year, fine.month), end: fine));
  }

  void _ultimiTreMesi() {
    final fine = widget.maxDate;
    final inizio = DateTime(fine.year, fine.month - 2);
    _applica((start: inizio, end: fine));
  }

  void _annoCorrente() {
    final fine = widget.maxDate;
    _applica((start: DateTime(fine.year, 1), end: fine));
  }

  void _daSempre() {
    _applica((start: widget.minDate, end: widget.maxDate));
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FlatChipButton(
                label: 'Questo mese',
                color: accent,
                onPressed: _questoMese,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Ultimi 3 mesi',
                color: accent,
                onPressed: _ultimiTreMesi,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Anno corrente',
                color: accent,
                onPressed: _annoCorrente,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Da sempre',
                color: accent,
                onPressed: _daSempre,
              ),
              const SizedBox(width: AppSpacing.sm),
              FlatChipButton(
                label: 'Personalizza',
                color: accent,
                filled: _personalizzaAperto,
                onPressed: () =>
                    setState(() => _personalizzaAperto = !_personalizzaAperto),
              ),
            ],
          ),
        ),
        if (_personalizzaAperto) ...[
          const SizedBox(height: AppSpacing.sm),
          CollapsiblePeriodPicker(
            minDate: widget.minDate,
            maxDate: widget.maxDate,
            startValue: widget.startValue,
            endValue: widget.endValue,
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}
```

Nota su `_ultimiTreMesi`: `DateTime(fine.year, fine.month - 2)` — il
costruttore `DateTime` normalizza automaticamente un mese `<= 0`
sottraendo dall'anno (comportamento Dart standard, stesso pattern già usato
altrove nel progetto, es. `targetPerCiclo` in `reminder_schedule.dart` con
logica equivalente ma esplicita per mese 0/negativo — verificare che
`DateTime(2026, -1)` produca davvero novembre 2025 come atteso scrivendo un
test dedicato nello Step 2, non assumerlo).

- [ ] **Step 2: Scrivere i test**

`test/widgets/period_preset_picker_test.dart`:

```dart
import 'package:buts/widgets/period_preset_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({DateTime start, DateTime end})? ultimoRange;

  Widget build({required DateTime min, required DateTime max, required DateTime start, required DateTime end}) {
    return CupertinoApp(
      home: PeriodPresetPicker(
        minDate: min,
        maxDate: max,
        startValue: start,
        endValue: end,
        onChanged: (r) => ultimoRange = r,
      ),
    );
  }

  setUp(() => ultimoRange = null);

  testWidgets('Questo mese seleziona solo il mese di maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Questo mese'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 5), end: DateTime(2026, 5)));
  });

  testWidgets('Ultimi 3 mesi copre mese corrente + 2 precedenti', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Ultimi 3 mesi'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 3), end: DateTime(2026, 5)));
  });

  testWidgets('Ultimi 3 mesi si clampa se lo storico è più corto', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2026, 4),
      max: DateTime(2026, 5),
      start: DateTime(2026, 4),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Ultimi 3 mesi'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 4), end: DateTime(2026, 5)));
  });

  testWidgets('Anno corrente copre da gennaio a maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Anno corrente'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2026, 1), end: DateTime(2026, 5)));
  });

  testWidgets('Da sempre copre minDate-maxDate', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2024, 3),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    await tester.tap(find.text('Da sempre'));
    await tester.pump();
    expect(ultimoRange, (start: DateTime(2024, 3), end: DateTime(2026, 5)));
  });

  testWidgets('Personalizza apre il CollapsiblePeriodPicker esistente', (tester) async {
    await tester.pumpWidget(build(
      min: DateTime(2025, 1),
      max: DateTime(2026, 5),
      start: DateTime(2025, 1),
      end: DateTime(2026, 5),
    ));
    expect(find.text('Personalizza'), findsOneWidget);
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();
    // Il CollapsiblePeriodPicker collassato mostra l'etichetta del range
    // corrente (vedi PeriodYearMonthPicker.formatRangeLabel) — basta
    // verificare che compaia un testo con l'anno per confermare che si sia
    // espanso, senza duplicare i test interni già esistenti su quel widget.
    expect(find.textContaining('2025'), findsWidgets);
  });
}
```

- [ ] **Step 3: Sostituire `CollapsiblePeriodPicker` con `PeriodPresetPicker`**

In `lib/screens/buste_paga/buste_paga_section_screen.dart`, righe ~695-704,
sostituire l'istanziazione:

```dart
child: PeriodPresetPicker(
  minDate: periodoRangeDisponibile.start,
  maxDate: periodoRangeDisponibile.end,
  startValue: _periodoFiltro?.start ?? periodoRangeDisponibile.start,
  endValue: _periodoFiltro?.end ?? periodoRangeDisponibile.end,
  onChanged: (range) => setState(() => _periodoFiltro = range),
),
```

(stesso identico set di parametri di prima, solo il nome del widget cambia —
nessun'altra modifica necessaria in questo file, dato che `PeriodPresetPicker`
ha lo stesso "contratto" dati).

- [ ] **Step 4: Aggiungere il sottotitolo di periodo effettivo a ogni card**

In `buste_paga_statistiche_screen.dart`, calcolare una label leggibile del
periodo effettivo (riusare `PeriodYearMonthPicker.formatRangeLabel(filtro.start,
filtro.end)` se `filtro != null`, altrimenti una stringa fissa tipo "Tutto lo
storico") e passarla come `subtitle` a ciascuna delle 3 istanze di
`_ChartCard` (il parametro esiste già, verificare se oggi è `null`/non
passato per queste card, o se già usato per altro e quindi da concatenare
invece di sovrascrivere).

- [ ] **Step 5: Eseguire i test**

Run: `flutter test`
Expected: tutti verdi, incluso il nuovo file di test.

Run: `flutter analyze`
Expected: nessun problema.

- [ ] **Step 6: Commit** (solo su istruzione esplicita dell'utente)

```bash
git add lib/widgets/period_preset_picker.dart lib/screens/buste_paga/buste_paga_section_screen.dart lib/screens/buste_paga/buste_paga_statistiche_screen.dart test/widgets/period_preset_picker_test.dart test/buste_paga_statistiche_screen_test.dart
git commit -m "feat(statistiche): filtro periodo con preset rapidi e sottotitolo per card

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Verifica finale (non un task di sviluppo)

Dopo i 6 task sopra: `flutter analyze`/`flutter test` complessivi puliti.
Checklist di verifica visiva tua (light e dark):

1. Card Netto: linea singola ciano, tap su un punto apre il drill-down coi
   dati corretti (incluso Lordo, non più visibile nella linea), tabella
   Dettagli mostra una sola colonna.
2. Card Ferie/Permessi/Ex festività: 3 anelli tutti ciano, leggibilità delle
   3 etichette ancora chiara senza la differenziazione per colore, tap su
   ciascuno apre lo stesso drill-down.
3. Card Straordinario: barre piene ciano (niente più gradiente viola), tap
   su una barra apre il drill-down del mese corretto.
4. Toggle "Confronta con l'anno precedente": attivandolo compaiono la linea
   tratteggiata (Netto) e le barre a contorno (Straordinario) per lo stesso
   range un anno prima; disattivato/nascosto con filtro "Da sempre".
5. Filtro: i 4 preset producono il range atteso, "Personalizza" apre il
   picker esistente invariato, ogni card mostra un sottotitolo col periodo
   effettivo applicato.

Se qualcosa non torna visivamente, segnalalo con schermata + dettaglio — si
delega un fix mirato a dev1/dev2 seguito da `revisore`, senza rifare l'intero
task.
