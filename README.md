# Buts

App personale di gestione delle finanze — Flutter, locale-first.

## Setup

1. Verifica l'ambiente: `flutter doctor -v`
2. Genera i file di piattaforma (mancano ancora `ios/` e `android/`):
   ```
   flutter create . --platforms=ios,android --org com.valeriomortella
   ```
   (questo comando aggiunge le cartelle native senza toccare `lib/`, `pubspec.yaml`
   già presenti)
3. Installa le dipendenze:
   ```
   flutter pub get
   ```
4. Avvia in un simulatore/dispositivo:
   ```
   flutter run
   ```

## Struttura

```
lib/
  main.dart              # entry point
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
decisioni prese, prossimi passi) prima di lavorare su nuove schermate con Claude Code.
