# Redesign Statistiche: grafici + filtro periodo

Data: 2026-09-08

## Contesto

La schermata Statistiche (`lib/screens/buste_paga/buste_paga_statistiche_screen.dart`)
ha 3 card ("Netto e lordo" a linee, "Ferie/Permessi/Ex festività" ad anelli,
"Straordinario per mese" a barre) e un filtro periodo (`CollapsiblePeriodPicker` →
`PeriodYearMonthPicker`, schede anno + griglia mesi a doppio tocco). L'utente ha
notato due problemi visti in screenshot con un solo mese selezionato: grafici
quasi vuoti (un punto/una barra) e tabella Media/Minimo/Massimo/Totale che
ripete lo stesso valore 3 volte. Approfondendo, il problema è più ampio:
architettura e leggibilità di tutti e 3 i grafici da rivedere, sia a livello
funzionale sia estetico, più un filtro periodo percepito macchinoso, poco
accattivante e poco chiaro nell'effetto sulla pagina.

L'utente ha inoltre chiesto esplicitamente, dopo aver visto il widget home
screen iOS (già usato come riferimento per il restyling generale dell'app,
branch `style`), di applicare la stessa palette minimale ai grafici: un solo
colore funzionale (ciano), niente viola/glow decorativi.

## Decisioni prese (brainstorming con l'utente)

1. **Ambito**: redesign di tutti e 3 i grafici (non solo quello più debole),
   sia a livello di funzionalità sia di design visivo.
2. **Nuove funzionalità richieste**: drill-down (tap su un punto/barra/anello →
   dettaglio della busta paga sorgente) e confronto anno su anno. Esplicitamente
   NON richiesti: nient'altro (niente export, niente nuove metriche).
3. **Palette grafici**: solo `pulseAccent` (ciano) + neutri per ogni
   valore/serie; via `pulseSecondaryGlow` (viola) come colore-dato e ogni
   effetto glow/bagliore diffuso. Le serie di confronto (anno precedente) si
   distinguono con lo stesso ciano a opacità ridotta + tratteggio/contorno,
   mai un secondo hue. Verde/rosso restano riservati allo stato
   Confermato/Da confermare, mai usati come colore-dato nei grafici.
4. **Filtro periodo**: problema su più fronti — interazione a due tocchi
   macchinosa, aspetto del chip collassato non convincente, mancano preset
   rapidi, effetto del filtro sulla pagina poco chiaro. Va ridisegnato con
   scorciatoie rapide come interazione primaria.
5. **Approccio scelto (A, tra 2 proposti)**: linea singola + drill-down per
   Netto (il Lordo si vede solo toccando un punto, non come seconda linea
   sempre visibile) — non l'alternativa "doppia serie sempre visibile senza
   drill-down", perché sfrutta il drill-down richiesto come meccanismo reale
   di semplificazione della vista principale, non solo come aggiunta
   decorativa.

## Design

### 1. Sistema visivo comune ai 3 grafici

- Un solo colore funzionale (`AppColors.pulseAccent`) per ogni valore/serie
  principale su ogni grafico — nessun uso di `pulseSecondaryGlow` nei grafici
  (resta disponibile altrove nell'app per altri usi decorativi, fuori scope
  qui).
- Serie di confronto (anno precedente): stesso ciano, opacità ridotta (~35%,
  da tarare in implementazione) + tratto tratteggiato (linee) o solo contorno
  senza riempimento (barre) — mai un secondo hue.
- `pulsePositive`/`pulseNegative` (verde/rosso) restano riservati allo stato
  Confermato/Da confermare (badge, drill-down), mai come colore-dato nei
  grafici stessi.
- Nessun effetto "glow"/bagliore diffuso dietro punti o barre (rimuove
  `_straordinarioGlowColor` e simili) — superfici piatte, coerente con la
  direzione già applicata al resto dell'app nel branch `style`.
- Font: già di sistema ovunque (ereditato dal restyling precedente, nessuna
  modifica qui).

### 2. Card "Netto" (rinominata da "Netto e lordo")

- Titolo "Netto" — il Lordo non è più protagonista permanente della card.
- Numero grande in evidenza: Netto del periodo (media se range multi-mese,
  valore secco se singolo mese) — comportamento di calcolo invariato rispetto
  a oggi.
- Grafico a linea singola (solo Netto), monocromatico ciano.
- **Drill-down**: tap su un punto della linea apre un bottom sheet
  (`showCupertinoModalPopup`, overlay leggero — l'utente resta in Statistiche,
  non naviga altrove) con i dati della busta paga di quel punto: mese, Netto,
  Lordo, stato Confermato/Da confermare. Riusa componenti condivisi esistenti
  dove ragionevole (es. `BustaPagaHeroCard`) invece di costruire una vista ad
  hoc da zero.
- **Confronto anno su anno**: un controllo (icona/switch) in alto nella card,
  "Confronta con l'anno precedente" — se attivo, sovrappone la linea dello
  stesso range di mesi ma anno-1, in ciano trasparente/tratteggiato.
  Disattivato di default, stato locale della card (non persistito tra
  sessioni/aperture).
- La tabella Media/Minimo/Massimo/Totale (dietro "Dettagli", comportamento
  invariato) si applica sempre e solo al Netto — il Lordo non ha più una sua
  riga nella tabella, essendo visibile solo via drill-down per singola busta.

### 3. Card "Ferie, Permessi, Ex festività"

- Resta il concetto a 3 anelli di progresso, snapshot dell'ultima busta paga
  nel periodo filtrato (comportamento di selezione dati invariato).
- Tutti e 3 gli anelli diventano **ciano** (il riempimento percentuale
  comunica già il valore, non serve differenziare la categoria per colore) —
  se la leggibilità dei 3 cerchi affiancati ne risente, un'intensità/opacità
  leggermente diversa tra i 3 è ammessa in implementazione, purché resti la
  stessa tinta.
- **Drill-down**: tap su un anello (qualunque dei 3) apre lo stesso bottom
  sheet di dettaglio busta paga usato dalla card Netto (stessa busta paga
  sorgente per tutti e 3 gli anelli).
- **Nessun confronto anno su anno** per questa card: è uno snapshot puntuale,
  non un trend nel tempo — esplicitamente fuori scope per questo piano.

### 4. Card "Straordinario per mese"

- Barre piene, colore ciano pieno (via il gradiente viola→ciano attuale e via
  il glow dietro la barra più alta).
- **Drill-down**: tap su una barra apre il bottom sheet di dettaglio busta
  paga per il mese di quella barra.
- **Confronto anno su anno**: stesso controllo/stato della card Netto —
  aggiunge una seconda serie di barre per l'anno precedente, mese per mese,
  disegnate come contorno ciano senza riempimento ("barre fantasma") accanto
  a quelle piene dell'anno corrente.

### 5. Filtro periodo

- Riga di **preset rapidi** come interazione primaria: "Questo mese", "Ultimi
  3 mesi", "Anno corrente", "Da sempre" — chip orizzontali in stile coerente
  con `FlatChipButton`/palette Pulse aggiornata.
- Chip aggiuntivo "Personalizza" che apre il `PeriodYearMonthPicker` esistente
  (schede anno + griglia mesi, logica di selezione a due tocchi **invariata**
  — nessuna modifica al componente interno) solo quando serve un range non
  coperto dai preset.
- Sotto il titolo di ciascuna delle 3 card, un sottotitolo esplicito indica il
  periodo effettivo applicato a quella card (es. "Ultimi 3 mesi · mag–lug
  2026"), così l'effetto del filtro resta leggibile senza dover riaprire il
  filtro per ricordarselo.
- I preset "Questo mese"/"Ultimi 3 mesi"/"Anno corrente" restano vincolati al
  range dati realmente disponibile (stesso comportamento di clamping già
  presente per `minDate`/`maxDate` nel picker attuale) — se il preset
  eccederebbe il range disponibile, si applica il range disponibile più
  vicino, non un errore/stato vuoto.

## Interazioni / data flow

- Drill-down: nuovo bottom sheet condiviso tra le 3 card (stesso widget,
  parametrizzato sulla `BustaPaga` toccata) — non una nuova schermata, non un
  nuovo provider: i dati sono già disponibili nella lista `filtrati`/`sorted`
  già calcolata da `BustePagaStatisticheScreen.build`.
- Confronto anno su anno: stato locale (`bool` per card, o condiviso se le
  due card Netto/Straordinario devono attivarsi insieme — da decidere in fase
  di piano se serve un unico toggle per l'intera schermata o due indipendenti;
  default proposto: **un unico toggle a livello di schermata**, più semplice
  e prevedibile per l'utente, applicato sia a Netto sia a Straordinario).
- Preset filtro: producono lo stesso tipo di valore `({DateTime start,
  DateTime end})` già consumato da `periodoFiltro` — nessuna nuova fonte di
  verità, si limitano a calcolare `start`/`end` e chiamare lo stesso
  `onChanged` già cablato oggi.

## Fuori scope

- Confronto anno su anno per la card Ferie/Permessi/Ex festività (snapshot
  puntuale, non un trend).
- Nuove metriche non richieste (export dati, altre aggregazioni).
- Modifiche alla logica interna di selezione a due tocchi di
  `PeriodYearMonthPicker` (resta invariata, usata solo dietro "Personalizza").
- Font/colori del resto dell'app (già coperti dal restyling sul branch
  `style`, commit `d7ce595`).

## Rischi noti

- **Un unico toggle "confronto anno precedente" a livello schermata** è
  un'assunzione di default (vedi sopra) — se in fase di test visivo risulta
  poco intuitivo avere le due card che cambiano insieme, si può smontare in
  due toggle indipendenti senza impatto sul resto del design.
- **Leggibilità dei 3 anelli tutti dello stesso colore**: perdere la
  differenziazione per colore tra Ferie/Permessi/Ex festività potrebbe rendere
  meno immediato capire quale anello è quale a colpo d'occhio — mitigato dalle
  etichette testuali sotto ciascun anello (già presenti oggi), ma da
  verificare visivamente con l'utente prima di considerare il design finale.
- **Bottom sheet di drill-down riuso di `BustaPagaHeroCard`**: da verificare
  in implementazione se il widget esistente si adatta bene a un contesto di
  overlay compatto o se serve una versione più snella — decisione rimandata
  al piano di implementazione.
