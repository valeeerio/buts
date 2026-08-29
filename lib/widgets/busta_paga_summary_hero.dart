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
    final isDarkMode =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
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
                  showScrim: !isDarkMode,
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

/// Label "NETTO · MESE ANNO" con uno scrim scuro discreto dietro al solo
/// testo, in light mode: `pulseOnAccent` (bianco) su `pulseAccent` light dà
/// solo 3.72:1, insufficiente per il rapporto di contrasto normale 4.5:1
/// richiesto (a 14px logici il testo non raggiunge davvero la soglia WCAG di
/// "testo grande bold", che corrisponde a ~18.7px logici, non 14px). Uno
/// scrim nero al 18% di opacità dietro la sola label — non l'intero blocco
/// Netto — scurisce il colore di sfondo effettivo sotto il testo bianco a
/// sufficienza da superare 4.5:1 (~5.22:1 con questo valore, ricalcolato
/// componendo `Colors.black` al 18% sopra `pulseAccent` light) restando
/// visivamente sottile. In dark mode `pulseOnAccent` su `pulseAccent` dark è
/// già ampiamente sopra soglia (~10:1+), nessuno scrim necessario lì.
class _NettoLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool showScrim;

  const _NettoLabel({
    required this.text,
    required this.color,
    required this.showScrim,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: AppTextStyles.pulseLabel.copyWith(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );

    if (!showScrim) {
      return Align(alignment: Alignment.centerLeft, child: label);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.pulseSmall / 2),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 0,
            right: 4,
            top: 2,
            bottom: 2,
          ),
          child: label,
        ),
      ),
    );
  }
}
