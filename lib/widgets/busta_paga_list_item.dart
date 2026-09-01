import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'pulse_icon.dart';
import 'pulse_surface.dart';

/// Riga compatta per l'archivio buste paga (redesign "Pulse", vedi
/// CLAUDE.md): pallino di stato verifica, mese in grassetto, netto in
/// evidenza e chevron. L'anno non è ripetuto qui perché già visibile
/// nell'header sticky del gruppo anno.
///
/// Superficie piatta `PulseSurface` non filled, non più in vetro.
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
      isConfermato ? AppColors.pulsePositive : AppColors.pulseNegative,
      context,
    );
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);

    return PulseSurface(
      borderRadius: AppRadius.pulseSmall,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.mdMinus,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: AppSpacing.smPlus),
            decoration: BoxDecoration(
              color: statoColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              bustaPagaMeseDisplay(bustaPaga),
              style: AppTextStyles.pulseBodyEmphasis.copyWith(
                color: textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            // `formatEuroConSegno`, non "€ ${formatEuro(...)}": per un netto
            // negativo `formatEuro` porta già il proprio "-", producendo
            // "€ -1.411,00" (segno dopo il simbolo valuta) — stessa coerenza
            // già applicata alle trattenute, vedi `busta_paga_formatting.dart`.
            formatEuroConSegno(bustaPaga.netto),
            style: AppTextStyles.pulseBody.copyWith(color: textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          PulseIcon(
            glyph: PulseIconGlyph.chevronForward,
            size: 16,
            color: textSecondary,
          ),
        ],
      ),
    );
  }
}
