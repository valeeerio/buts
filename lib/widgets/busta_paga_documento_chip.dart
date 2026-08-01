import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// Riga compatta per il PDF di origine: icona documento e nome file. Con
/// [onTap] valorizzato (dettaglio busta paga già salvata) è tappabile via
/// `SpringButton` e mostra il trailing "Condividi" + icona — con [onTap]
/// nullo (form di import, file ancora in fase di revisione) resta un
/// widget statico, senza azione né trailing.
class BustaPagaDocumentoChip extends StatelessWidget {
  final String filePath;
  final VoidCallback? onTap;

  const BustaPagaDocumentoChip({super.key, required this.filePath, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    final surface = LiquidGlassSurface(
      radius: AppRadius.glassSmall,
      blurSigma: 22,
      elevation: 4,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.doc_text, size: 20, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              p.basename(filePath),
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitle.copyWith(color: labelPrimary),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Condividi',
              style: AppTextStyles.cardLabel.copyWith(color: labelSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.square_arrow_up, size: 16, color: accent),
          ],
        ],
      ),
    );

    if (onTap == null) return surface;
    return SpringButton(onPressed: onTap!, child: surface);
  }
}
