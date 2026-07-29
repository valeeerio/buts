---
name: folder-audit
description: Audit generico di organizzazione e naming di una cartella qualsiasi del progetto Buts indicata dall'utente — non stile visivo (per quello usa design-audit). Usa quando l'utente chiede di controllare la coerenza interna di una cartella specifica (es. lib/data/, lib/providers/, lib/services/).
---

# folder-audit

Ambito complementare a `design-audit`: qui l'attenzione è sull'organizzazione dei
file, non sull'estetica dei widget.

## Passi

1. Se l'utente non ha indicato una cartella precisa, chiedi quale (non assumere
   `lib/` intera: l'audit è pensato per un ambito mirato).
2. `Glob` di tutti i file nella cartella indicata (e sottocartelle).
3. Verifica, confrontando con le convenzioni già in uso nel resto del repo (`Grep`
   su cartelle analoghe per pattern di naming/struttura):
   - **Naming coerente**: i file seguono lo stesso schema di naming già in uso altrove
     nel progetto per lo stesso tipo di contenuto (es. `*_screen.dart`,
     `*_provider.dart`, `*_service.dart`, tabelle Drift in `lib/data/`).
   - **Duplicazioni**: logica o modelli ripetuti tra più file della cartella invece
     di essere centralizzati in un unico punto (es. design token, enum condivisi).
   - **File fuori posto**: contenuto che appartiene concettualmente a un'altra
     cartella secondo la struttura del progetto (`lib/screens/`, `lib/widgets/`,
     `lib/models/`, `lib/providers/`, `lib/data/`, `lib/services/`).
   - **Responsabilità sovrapposte**: due file che sembrano fare la stessa cosa con
     nomi diversi.
4. Non applicare correzioni automaticamente: questa skill è di sola analisi.

## Output

Lista di problemi concreti (file + descrizione del problema), non stile visivo. Se
non trovi problemi, dillo esplicitamente invece di inventare osservazioni marginali.
