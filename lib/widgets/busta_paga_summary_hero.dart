import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// Card in evidenza per l'ultima busta paga in archivio: mese e netto a
/// sinistra, residui di Ferie/ROL/Ore a destra. Tap-only, apre il dettaglio.
///
/// Usa `LiquidGlassSurface`, vedi `liquid_glass_surface.dart` per i dettagli
/// del materiale approssimato.
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
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final statoColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );

    return SpringButton(
      onPressed: onTap,
      child: LiquidGlassSurface(
        radius: AppRadius.glass,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: statoColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bustaPagaMeseDisplay(bustaPaga),
                      style: AppTextStyles.subtitle.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Ferie',
                    style: AppTextStyles.subtitle.copyWith(
                      color: labelPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'ROL',
                    style: AppTextStyles.subtitle.copyWith(
                      color: labelPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Ore',
                    style: AppTextStyles.subtitle.copyWith(
                      color: labelPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      '€ ${bustaPaga.netto.toStringAsFixed(2)}',
                      style: AppTextStyles.greeting.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatNumber(bustaPaga.ferieResidue),
                    style: AppTextStyles.cardAmount.copyWith(
                      color: labelPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    formatNumber(bustaPaga.rolResidui),
                    style: AppTextStyles.cardAmount.copyWith(
                      color: labelPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    formatNumber(bustaPaga.oreLavorate),
                    style: AppTextStyles.cardAmount.copyWith(
                      color: labelPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
