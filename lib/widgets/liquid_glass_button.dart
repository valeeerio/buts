import 'package:flutter/cupertino.dart';

import '../theme/app_spacing.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// CTA in stile Liquid Glass: compone `SpringButton` (pressione a molla,
/// componente esistente e condiviso) con `LiquidGlassSurface`. Standard
/// per i pulsanti/CTA di tutta l'app (es. "Aggiungi busta paga" nello
/// stato vuoto, "Salva" nel form), dove un accento di colore sul vetro è
/// appropriato per segnalare l'azione principale.
class LiquidGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  const LiquidGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.radius = AppRadius.glassSmall,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm + 4,
    ),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onPressed: onPressed,
      child: LiquidGlassSurface(
        radius: radius,
        blurSigma: 24,
        elevation: 6,
        tint: tint,
        padding: padding,
        child: child,
      ),
    );
  }
}
