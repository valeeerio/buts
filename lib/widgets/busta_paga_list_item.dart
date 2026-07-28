import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Riga compatta per l'archivio buste paga: periodo, netto in evidenza,
/// badge di stato verifica e chevron. Stile ispirato ad `AreaSummaryCard`
/// ma senza sparkline/variazione %, non applicabili a una busta paga.
class BustaPagaListItem extends StatelessWidget {
  final BustaPaga bustaPaga;
  final VoidCallback onTap;

  const BustaPagaListItem({
    super.key,
    required this.bustaPaga,
    required this.onTap,
  });

  String get _periodoLabel {
    final formatted =
        DateFormat('MMMM yyyy', 'it_IT').format(bustaPaga.periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final badgeColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemOrange,
      context,
    );
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(AppColors.surface, context),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _periodoLabel,
                    style: AppTextStyles.cardLabel.copyWith(
                      color: labelSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '€ ${bustaPaga.netto.toStringAsFixed(2)}',
                    style: AppTextStyles.cardAmount.copyWith(
                      color: labelPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                isConfermato ? 'Confermato' : 'Da confermare',
                style: AppTextStyles.changeBadge.copyWith(color: badgeColor),
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
