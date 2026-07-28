# Buts

App personale di gestione delle finanze — Flutter, locale-first, iOS come
target primario (Cupertino/iOS nativo).

## Setup

1. Verifica l'ambiente: `flutter doctor -v`
2. Installa le dipendenze: `flutter pub get`
3. Avvia sul simulatore iOS: `flutter run`

## Struttura

L'app ha 2 sezioni principali di pari livello (Buste Paga, sezione di
apertura predefinita, e Budget con le 4 aree), navigabili via swipe
orizzontale o freccia nell'header globale. Persistenza Drift (SQLite) attiva
per l'archivio Buste Paga; le 4 aree Budget sono ancora su dati mock.

```
lib/
  main.dart                    # entry point (ProviderScope, intl 'it_IT')
  theme/                       # design tokens: colori, spaziature, tipografia
  models/                      # AreaType, DashboardAreaSummary, BustaPaga, dati mock
  data/                        # persistenza Drift (SQLite) — AppDatabase, tabelle
  providers/                   # provider Riverpod cross-sezione (buste paga)
  navigation/
    app_root_scaffold.dart      # scaffold radice: 2 sezioni (Buste Paga + Budget)
    app_section.dart            # enum sezioni
    app_section_provider.dart   # stato Riverpod sezione attiva
    app_tab.dart                 # tab bar interna alla sola sezione Budget
    root_scaffold.dart           # contenuto sezione Budget (tab bar 5 aree)
  screens/
    buste_paga/                  # sezione Buste Paga: archivio, form, dettaglio
    dashboard/                   # Dashboard della sezione Budget
    conto_principale/ ecc.       # da progettare
    placeholder_screen.dart
  widgets/                      # componenti riutilizzabili (card, donut, sparkline...)
```

Vedi `CLAUDE.md` per il contesto di progetto completo (logica delle aree, stile,
decisioni prese, prossimi passi) e `BACKLOG.md` per lo stato di avanzamento
prima di lavorare su nuove schermate con Claude Code.
