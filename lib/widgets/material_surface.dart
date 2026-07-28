import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Superficie traslucida/sfocata in stile Apple (vibrancy materials):
/// applica un blur al contenuto sottostante e sovrappone un colore di base
/// semi-trasparente con bordo sottile. Pensata come alternativa a un
/// `Container` piatto per card che vogliono più "materialità" (profondità,
/// leggero effetto vetro smerigliato).
///
/// Degrada bene anche su sfondo neutro: senza contenuto colorato dietro il
/// blur è meno vistoso ma resta un accento di profondità valido (bordo +
/// leggera trasparenza sopra `AppColors.surface`).
class MaterialSurface extends StatelessWidget {
  final Widget child;

  /// Colore di base della superficie. Default: `AppColors.surface`.
  final Color? baseColor;

  final BorderRadius? borderRadius;

  /// Intensità del blur (sigma). 18-20 è il range consigliato per un
  /// effetto "materiale" percepibile senza diventare illeggibile.
  final double blurSigma;

  const MaterialSurface({
    super.key,
    required this.child,
    this.baseColor,
    this.borderRadius,
    this.blurSigma = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final resolvedBase =
        baseColor ?? CupertinoDynamicColor.resolve(AppColors.surface, context);
    // In dark mode una saturazione/opacità più bassa resta più leggibile
    // sopra contenuti scuri; in light mode si può osare un filo di più.
    final surfaceOpacity = isDark ? 0.55 : 0.72;
    final borderColor = CupertinoDynamicColor.resolve(
      AppColors.separator,
      context,
    ).withValues(alpha: isDark ? 0.5 : 0.6);
    final resolvedRadius = borderRadius ?? BorderRadius.circular(AppRadius.card);

    return ClipRRect(
      borderRadius: resolvedRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: resolvedBase.withValues(alpha: surfaceOpacity),
            borderRadius: resolvedRadius,
            border: Border.all(color: borderColor, width: 0.6),
          ),
          child: child,
        ),
      ),
    );
  }
}
