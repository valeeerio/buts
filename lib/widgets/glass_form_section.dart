import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';

/// Sezione di form/dettaglio in stile Liquid Glass: stessa forma di
/// `CupertinoFormSection.insetGrouped` (header sopra, righe raggruppate con
/// separatori sottili, footer sotto) ma con la superficie sostituita da
/// `LiquidGlassSurface` invece del rettangolo bianco piatto.
///
/// Pensata per contenere `CupertinoFormRow`/`CupertinoTextFormFieldRow`
/// esistenti (che non dipingono un proprio sfondo, quindi si appoggiano
/// correttamente sopra il vetro).
class GlassFormSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final double radius;

  const GlassFormSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.radius = AppRadius.glass,
  });

  @override
  Widget build(BuildContext context) {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final separator =
        CupertinoDynamicColor.resolve(AppColors.separator, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                header!.toUpperCase(),
                style: AppTextStyles.cardLabel.copyWith(
                  color: labelSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          LiquidGlassSurface(
            radius: radius,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Container(height: 0.5, color: separator),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.xs,
              ),
              child: Text(
                footer!,
                style: AppTextStyles.cardLabel.copyWith(
                  color: labelSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
