import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum InsightMode { positive, warning }

/// Card di insight/alert automatico, posizionata sotto il donut summary e
/// prima delle 4 card delle aree. Deve distinguersi visivamente dalle altre
/// card (sfondo colorato tenue + icona di stato), non essere una card bianca
/// uguale alle altre.
class InsightCard extends StatelessWidget {
  final InsightMode mode;
  final String text;

  const InsightCard({super.key, required this.mode, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = mode == InsightMode.positive
        ? AppColors.systemGreen
        : AppColors.systemOrange;
    final resolvedColor = CupertinoDynamicColor.resolve(color, context);
    final icon = mode == InsightMode.positive
        ? CupertinoIcons.check_mark
        : CupertinoIcons.exclamationmark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: resolvedColor.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: resolvedColor, shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: CupertinoColors.white),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.insightText.copyWith(
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelPrimary, context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
