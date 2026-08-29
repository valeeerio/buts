import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pulse_surface.dart';

/// Riga di statistiche compatte (residui, importi): **una sola**
/// `PulseSurface` con scomparti interni separati da un divisore sottile,
/// invece di N superfici affiancate — stessa filosofia di
/// `BustaPagaListItem`/`_MaturazioniRingsRow` nell'Archivio, mai superfici
/// annidate/affiancate.
///
/// `items` accetta un `Widget` già costruito per il valore (invece di una
/// stringa) per poter mostrare, in modalità modifica, un campo di testo al
/// posto del `Text` statico senza duplicare il layout dei compartimenti.
class BustaPagaStatRow extends StatelessWidget {
  final List<(String label, Widget value)> items;

  const BustaPagaStatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final separator = textSecondary.withValues(alpha: 0.3);

    return PulseSurface(
      borderRadius: AppRadius.pulse,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: separator,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      items[i].$1,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pulseLabel.copyWith(
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: AppTextStyles.pulseDisplaySmall.copyWith(
                        color: textPrimary,
                      ),
                      child: items[i].$2,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
