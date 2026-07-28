# Buts

App personale di gestione delle finanze — Flutter, locale-first, iOS come
target primario (Cupertino/iOS nativo).

## Setup

1. Verifica l'ambiente: `flutter doctor -v`
2. Installa le dipendenze: `flutter pub get`
3. Avvia sul simulatore iOS: `flutter run`

## Struttura

```
lib/
  main.dart              # entry point (inizializza intl per 'it_IT')
  theme/                 # design tokens: colori, spaziature, tipografia
  models/                # AreaType, DashboardAreaSummary, dati mock
  navigation/             # AppTab (tab bar) + RootScaffold
  screens/
    dashboard/            # Dashboard (completa)
    conto_principale/      # da progettare
    risparmio_principale/  # da progettare
    piccolo_risparmio/     # da progettare
    impegni_fissi/         # da progettare
    buste_paga/            # da progettare
    placeholder_screen.dart
  widgets/                # componenti riutilizzabili (card, donut, sparkline...)
```

Vedi `CLAUDE.md` per il contesto di progetto completo (logica delle aree, stile,
decisioni prese, prossimi passi) e `BACKLOG.md` per lo stato di avanzamento
prima di lavorare su nuove schermate con Claude Code.
