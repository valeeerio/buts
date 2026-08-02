# Buts

App mobile personale per tracciare le buste paga — Flutter, locale-first
(nessun backend, nessun account, dati sul device), iOS come target primario
con look-and-feel Cupertino nativo.

## Setup

1. Verifica l'ambiente: `flutter doctor -v`
2. Installa le dipendenze: `flutter pub get`
3. Avvia sul simulatore iOS: `flutter run`

## Struttura

L'app è a sezione singola: si apre direttamente sull'archivio Buste Paga,
con sotto-navigazione Archivio/Statistiche + import PDF. Persistenza Drift
(SQLite).

```
lib/
  main.dart                    # entry point (ProviderScope, intl 'it_IT')
  theme/                       # design tokens: colori, spaziature, tipografia
  models/                      # BustaPaga, TipoBustaPaga
  data/                        # persistenza Drift (SQLite) — AppDatabase, tabelle
  providers/                   # provider Riverpod (repository buste paga)
  services/                    # import PDF (file picker, copia file) e parser regex
  screens/
    buste_paga/                  # sezione radice: contenitore, archivio, statistiche,
                                  # form di import, dettaglio
  widgets/                      # componenti riutilizzabili
```

`lib/widgets/` raggruppa per famiglia di stile:
- **Liquid Glass** (`liquid_glass_surface.dart`, `liquid_glass_button.dart`,
  `squircle_clipper.dart`, `glass_form_section.dart`) — il materiale in
  vetro traslucido standard di card/sezioni.
- **Flat, senza vetro** (`flat_chip_button.dart`, `app_alert_dialog.dart`) —
  sotto-navigazione, barre di azione e popup.
- **Specifici busta paga**, condivisi tra dettaglio e form di import
  (`busta_paga_hero_card.dart`, `busta_paga_stat_row.dart`,
  `busta_paga_maturazioni_section.dart`, `busta_paga_documento_chip.dart`,
  `busta_paga_summary_hero.dart`, `busta_paga_list_item.dart`,
  `trattenuta_edit_row.dart`, `cupertino_range_slider.dart`).

Vedi `CLAUDE.md` per il contesto di progetto completo (decisioni prese,
regole di stile non negoziabili, cosa manca) e `BACKLOG.md` per lo stato di
avanzamento prima di lavorare su nuove schermate con Claude Code.
