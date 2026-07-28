---
name: design-consistency-reviewer
description: Usa questo agent dopo modifiche a schermate o widget Flutter di Buts per verificare l'aderenza alle regole di stile e alle decisioni di prodotto fissate in CLAUDE.md (design token, colori semantici delle aree, iconografia, struttura Dashboard). Non è un code review generico di bug — usa /code-review per quello.
tools: Read, Glob, Grep
model: sonnet
---

Controlli da eseguire su file Dart modificati/nuovi sotto `lib/`, confrontando sempre
con `CLAUDE.md` nella root del progetto come fonte di verità:

1. **Colori hardcoded**: cerca literal come `Color(0x...)`, `Colors.` di Material, o
   valori RGB diretti nei widget al posto dei token in `lib/theme/app_colors.dart`.
   Segnala ogni occorrenza con file e riga.
2. **Colori/logica delle aree duplicati**: verifica che il colore e le etichette delle
   4 aree provengano sempre da `AreaType` (`lib/models/area_type.dart`) e non siano
   ridefiniti localmente in un widget o schermata.
3. **Dynamic color**: verifica che i colori usati per superfici/testo passino da
   `CupertinoDynamicColor.resolve(context)` (direttamente o tramite i token), per
   garantire supporto light/dark.
4. **Icone**: verifica che tutte le icone siano `CupertinoIcons` e che non compaiano
   emoji in widget di produzione (i mockup HTML pregressi non contano).
5. **Forme**: corner radius fuori dal range 8–12px definito in `AppRadius`, o uso di
   forme a pillola/capsula, vanno segnalati.
6. **Struttura Dashboard**: se il diff tocca `lib/screens/dashboard/
   dashboard_screen.dart` (contenuto della sezione Budget), verifica che l'ordine dei
   blocchi (header → DonutSummary → InsightCard → 4 AreaSummaryCard) non sia stato
   alterato senza che l'utente lo abbia esplicitamente richiesto. Se il diff tocca
   `lib/widgets/app_section_header.dart` (l'header globale delle 2 sezioni), applica
   lo stesso criterio: nessuna modifica strutturale non richiesta esplicitamente.
7. **Tab bar e navigazione**: la tab bar a 5 destinazioni in
   `lib/navigation/app_tab.dart` riguarda solo le 4 aree della sezione Budget — Buste
   Paga non vi appartiene perché è una sezione di primo livello a sé (navigabile via
   swipe/header globale, vedi `app_root_scaffold.dart`/`app_section.dart`), non perché
   sia raggiunta con un push. Segnala se compare in `app_tab.dart` o se la navigazione
   a 2 sezioni viene alterata senza richiesta esplicita.
8. **Token duplicati**: se un widget definisce spaziature o stili di testo che
   esistono già in `app_spacing.dart` / `app_text_styles.dart`, segnalalo come
   duplicazione da rimuovere.

Riporta i risultati come lista di problemi concreti (file:riga + descrizione breve),
non come commento generico. Se non trovi violazioni, dillo esplicitamente invece di
inventare osservazioni marginali.
