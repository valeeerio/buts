import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';

/// Riga di statistiche compatte (residui, importi): **una sola**
/// `LiquidGlassSurface` con scomparti interni separati da `VerticalDivider`,
/// invece di N `LiquidGlassSurface` affiancate — più `BackdropFilter`
/// ravvicinati (distanza di pochi pixel) producevano un artefatto di
/// rendering visibile come una "cucitura" netta tra una card e l'altra.
/// Stessa filosofia della sidecar in basso (`_BustePagaSidecar` in
/// `buste_paga_section_screen.dart`): un'unica superficie di vetro con
/// scomparti piatti dentro, mai vetro annidato.
///
/// `items` accetta un `Widget` già costruito per il valore (invece di una
/// stringa) per poter mostrare, in modalità modifica, un campo di testo al
/// posto del `Text` statico senza duplicare il layout dei compartimenti.
class BustaPagaStatRow extends StatelessWidget {
  final List<(String label, Widget value)> items;

  const BustaPagaStatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final separator =
        CupertinoDynamicColor.resolve(AppColors.separator, context);

    return LiquidGlassSurface(
      radius: AppRadius.glass,
      blurSigma: 22,
      elevation: 4,
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
                      style: AppTextStyles.subtitle.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: AppTextStyles.cardAmount.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w400,
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
