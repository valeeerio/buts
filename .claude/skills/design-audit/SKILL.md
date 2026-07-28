---
name: design-audit
description: Scansiona lib/ del progetto Buts per violazioni delle regole di stile fissate in CLAUDE.md (colori hardcoded, emoji, AreaType duplicato, struttura Dashboard/tab bar alterata). Usa dopo una serie di modifiche UI o prima di una consegna, per un controllo di coerenza mirato — non è un code review generico di bug.
---

# design-audit

Invoca l'agent `design-consistency-reviewer` (tool Agent, subagent_type
`design-consistency-reviewer`) passandogli come scope:

- Se l'audit è richiesto dopo modifiche recenti: la lista dei file Dart modificati
  (usa `git diff --name-only` se il repo è versionato con git, altrimenti chiedi
  all'utente quali file controllare — questo repo potrebbe non essere un git repo).
- Se l'audit è richiesto sull'intero progetto: tutti i file sotto `lib/screens/` e
  `lib/widgets/`.

L'agent deve controllare, con riferimento a `CLAUDE.md`:

1. Colori hardcoded invece dei token in `lib/theme/app_colors.dart`.
2. Colore/etichetta delle aree duplicati invece di usare `AreaType`
   (`lib/models/area_type.dart`).
3. Uso di `CupertinoDynamicColor.resolve(context)` per il supporto light/dark.
4. Icone: solo `CupertinoIcons`, nessuna emoji nei componenti di produzione.
5. Corner radius fuori dal range 8–12px di `AppRadius`, o forme a pillola/capsula.
6. Ordine dei blocchi della Dashboard non alterato senza richiesta esplicita.
7. Buste Paga assente dalla tab bar (`lib/navigation/app_tab.dart`).
8. Spaziature/stili di testo duplicati invece di riusare `app_spacing.dart` /
   `app_text_styles.dart`.

Presenta il risultato dell'agent così com'è (lista di problemi concreti file:riga, o
conferma esplicita "nessuna violazione trovata"). Non aggiungere osservazioni
stilistiche personali oltre a quelle dell'agent.
