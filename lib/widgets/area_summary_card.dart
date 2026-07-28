import 'package:flutter/cupertino.dart';
import '../models/dashboard_area_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sparkline.dart';

/// Card compatta (singola riga) per una delle 4 aree in dashboard.
/// Tap-only: nessuna azione rapida inline, il tap apre il dettaglio dell'area.
class AreaSummaryCard extends StatelessWidget {
  final DashboardAreaSummary area;
  final VoidCallback onTap;

  const AreaSummaryCard({
    super.key,
    required this.area,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(area.type.color, context);
    final changeColor = CupertinoDynamicColor.resolve(
      area.isChangeFavorable ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );
    final sign = area.changePercent >= 0 ? '+' : '';

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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    area.type.shortLabel,
                    style: AppTextStyles.cardLabel.copyWith(
                      color: CupertinoDynamicColor.resolve(
                          AppColors.labelSecondary, context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.cardAmount.copyWith(
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelPrimary, context),
                      ),
                      children: [
                        TextSpan(text: '€ ${area.amount.toStringAsFixed(0)}'),
                        if (area.amountSuffix != null)
                          TextSpan(
                            text: area.amountSuffix,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: CupertinoDynamicColor.resolve(
                                  AppColors.labelSecondary, context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Sparkline(points: area.sparklinePoints, color: color),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Text(
                '$sign${area.changePercent.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: AppTextStyles.changeBadge.copyWith(color: changeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
