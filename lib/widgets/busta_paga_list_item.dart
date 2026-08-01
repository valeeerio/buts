import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// Riga compatta per l'archivio buste paga: pallino di stato verifica
/// (verde/rosso), mese in grassetto, netto in evidenza e chevron. L'anno non
/// è ripetuto qui perché già visibile nell'header sticky del gruppo anno.
///
/// Superficie in vetro (`LiquidGlassSurface`), con la stessa curva continua
/// della hero card ma più contenuta (`AppRadius.glassSmall`).
class BustaPagaListItem extends StatelessWidget {
  final BustaPaga bustaPaga;
  final VoidCallback onTap;

  const BustaPagaListItem({
    super.key,
    required this.bustaPaga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final statoColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return SpringButton(
      onPressed: onTap,
      child: LiquidGlassSurface(
        radius: AppRadius.glassSmall,
        blurSigma: 22,
        elevation: 4,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: statoColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                bustaPagaMeseDisplay(bustaPaga),
                style: AppTextStyles.cardAmount.copyWith(
                  color: labelPrimary,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '€ ${bustaPaga.netto.toStringAsFixed(2)}',
              style: AppTextStyles.cardAmount.copyWith(
                color: labelPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: labelSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
