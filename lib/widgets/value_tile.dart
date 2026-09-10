import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pulse_surface.dart';

/// Tessera piatta con un valore in evidenza e una label sotto, senza alcun
/// indicatore di progresso — usata dall'Archivio (riga Ferie/Permessi/Ex
/// festività dell'ultima busta paga) e da Statistiche (card "Ferie,
/// Permessi, Ex festività"), al posto di `ProgressRingTile`.
class ValueTile extends StatelessWidget {
  final String label;
  final String value;

  const ValueTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);

    return PulseSurface(
      borderRadius: AppRadius.pulseSmall,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pulseDisplaySmall.copyWith(
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pulseLabel.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
