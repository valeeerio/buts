import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'pulse_surface.dart';

/// Blocco "Netto" in evidenza per l'ultima busta paga in archivio (redesign
/// "Pulse", vedi CLAUDE.md): superficie piena color accento con label
/// "NETTO · {MESE} {ANNO}", il netto in grande e un badge di stato
/// Confermato/Da confermare — sostituisce la vecchia hero in vetro con
/// gruppetto Ferie/Permessi/Ex fest. inline (quei dati vivono ora nella
/// griglia di anelli di maturazione sotto questo blocco, vedi
/// `BustePagaArchivioView`, per evitare la stessa ridondanza già corretta nel
/// dettaglio busta paga). Tap-only, apre il dettaglio.
class BustaPagaSummaryHero extends StatelessWidget {
  final BustaPaga bustaPaga;
  final VoidCallback onTap;

  const BustaPagaSummaryHero({
    super.key,
    required this.bustaPaga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent =
        CupertinoDynamicColor.resolve(AppColors.pulseOnAccent, context);
    final secondaryGlow =
        CupertinoDynamicColor.resolve(AppColors.pulseSecondaryGlow, context);
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final badgeFill = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.pulsePositive : AppColors.pulseNegative,
      context,
    );
    final badgeText = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.pulseOnPositive : AppColors.pulseOnNegative,
      context,
    );

    return PulseSurface(
      filled: true,
      // Gradiente diagonale viola→ciano ("mesh gradient", mockup B — vedi
      // CLAUDE.md/piano sessione): il viola resta puramente decorativo qui.
      // `pulseOnAccent` sopra regge benissimo (~10:1) contro l'estremo
      // `pulseAccent` (ciano chiaro), ma contro `pulseSecondaryGlow` (viola,
      // più scuro) scende a ~3.79:1 — sotto la soglia 4.5:1 per testo
      // normale. La label "NETTO · ..." (`_NettoLabel`), che siede proprio
      // nell'angolo in alto a sinistra dominato dal viola, ha quindi uno
      // scrim chiaro dedicato per riportare quel punto sopra soglia — vedi
      // commento su `_NettoLabel`.
      filledGradientColors: [secondaryGlow, accent],
      borderRadius: AppRadius.pulse,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _NettoLabel(
                  text:
                      'NETTO · ${bustaPagaPeriodoDisplay(bustaPaga).toUpperCase()}',
                  color: onAccent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeFill,
                  borderRadius: BorderRadius.circular(AppRadius.pulseSmall),
                ),
                child: Text(
                  isConfermato ? 'Confermato' : 'Da confermare',
                  style: AppTextStyles.pulseLabel.copyWith(color: badgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // `formatEuroConSegno`, non "€ ${formatEuro(...)}": stessa
            // coerenza di `BustaPagaListItem`, vedi `busta_paga_formatting.dart`.
            formatEuroConSegno(bustaPaga.netto),
            style: AppTextStyles.pulseDisplayLarge.copyWith(color: onAccent),
          ),
        ],
      ),
    );
  }
}

/// Label "NETTO · MESE ANNO", nell'angolo in alto a sinistra del blocco
/// Netto (vedi `BustaPagaSummaryHero`), dove il gradiente diagonale è al suo
/// estremo `pulseSecondaryGlow` (viola). `pulseOnAccent` (testo quasi-nero,
/// pensato per un fondo chiaro come `pulseAccent`) contro quel viola dà solo
/// ~3.79:1, sotto la soglia 4.5:1 per testo normale — il viola, pur scuro,
/// non è abbastanza scuro da reggere un testo quasi-nero sopra. Uno scrim
/// **chiaro** (bianco al 16% di opacità, sempre attivo — l'app forza sempre
/// `Brightness.dark`, vedi `main.dart`, quindi non condizionato al tema)
/// dietro la sola label schiarisce localmente il fondo sotto il testo scuro,
/// portando il contrasto a ~4.9:1 (ricalcolato componendo il bianco al 16%
/// sopra `pulseSecondaryGlow` e la luminanza risultante contro
/// `pulseOnAccent`). Contro l'altro estremo del gradiente (`pulseAccent`,
/// già chiaro) lo stesso scrim schiarisce ulteriormente il fondo, quindi non
/// può che aumentare un contrasto già ampiamente sopra soglia (~10:1) — nessun
/// rischio di regressione su quel lato.
class _NettoLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _NettoLabel({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.pulseLabel.copyWith(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pulseSmall / 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          child: label,
        ),
      ),
    );
  }
}
