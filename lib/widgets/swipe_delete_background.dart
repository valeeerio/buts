import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'squircle_clipper.dart';

/// Sfondo rivelato dallo swipe-to-delete su una busta paga (hero o riga
/// elenco): riempimento pieno rosso di sistema (azione distruttiva
/// standard iOS, a differenza delle altre superfici dell'app non è vetro),
/// con la stessa curva squircle della `LiquidGlassSurface` che rivela,
/// tramite [radius] passato dal chiamante (`AppRadius.glass` per l'hero,
/// `AppRadius.glassSmall` per le righe).
class SwipeDeleteBackground extends StatelessWidget {
  final double radius;

  const SwipeDeleteBackground({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    final destructive = CupertinoDynamicColor.resolve(
      AppColors.systemRed,
      context,
    );
    // `CupertinoColors.white` letterale invece di un token `AppColors`:
    // l'icona va comunque risolta esplicitamente tramite
    // `CupertinoDynamicColor.resolve` (convenzione di progetto per ogni
    // colore), anche se il valore risultante coincide nei due temi — stesso
    // pattern già usato in `cupertino_range_slider.dart` per il thumb.
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.white,
      context,
    );
    return ClipPath(
      clipper: SquircleClipper(radius: radius),
      child: Container(
        color: destructive,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
        ),
        child: Icon(
          CupertinoIcons.trash,
          color: iconColor,
        ),
      ),
    );
  }
}
