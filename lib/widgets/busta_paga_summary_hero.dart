import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'spring_button.dart';

/// Blocco "Netto" in evidenza per l'ultima busta paga in archivio (redesign
/// "Pulse", vedi CLAUDE.md): testo libero direttamente sullo sfondo della
/// pagina, senza più una superficie/card a gradiente attorno — riga in alto
/// con label "NETTO · {MESE} {ANNO}" a sinistra e stato Confermato/Da
/// confermare allineato a destra sulla stessa riga, sotto il netto in
/// grande da solo. Tap-only sull'intera area, apre il dettaglio.
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
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final statoColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.pulsePositive : AppColors.pulseNegative,
      context,
    );

    return SpringButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'NETTO · ${bustaPagaPeriodoDisplay(bustaPaga).toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.pulseLabel
                        .copyWith(color: textSecondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  label: isConfermato ? 'Confermato' : 'Da confermare',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(right: AppSpacing.smPlus),
                          decoration: BoxDecoration(
                            color: statoColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        isConfermato ? 'Confermato' : 'Da confermare',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.pulseLabel
                            .copyWith(color: statoColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // `formatEuroConSegno`, non "€ ${formatEuro(...)}": stessa
              // coerenza di `BustaPagaListItem`, vedi `busta_paga_formatting.dart`.
              formatEuroConSegno(bustaPaga.netto),
              style: AppTextStyles.pulseDisplayLarge.copyWith(
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
