import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'flat_chip_button.dart';

/// Un bottone di `AppAlertDialog`: stesso identico componente
/// (`FlatChipButton`, icona + testo, riempimento pieno) dei segmenti della
/// sidecar e della barra Conferma/Modifica del dettaglio busta paga —
/// [icon] è opzionale solo per compatibilità, ogni punto di chiamata dovrebbe
/// valorizzarlo per restare coerente con quello stile. [onPressed] fa
/// interamente carico di sé del `Navigator.pop`/eventuale side effect, stesso
/// contratto di `CupertinoDialogAction.onPressed` che sostituisce.
class AppAlertAction {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onPressed;

  const AppAlertAction({
    required this.label,
    required this.color,
    this.icon,
    required this.onPressed,
  });
}

/// Popup di conferma/errore dell'app — ridisegnato da zero (2026-08-01) per
/// essere un'estensione visiva della sidecar/barra Conferma-Modifica invece
/// di una card in stile Liquid Glass: **nessun vetro/`BackdropFilter`**, solo
/// una superficie piatta a colore pieno (`AppColors.surface`, la stessa
/// superficie "solida" usata da fogli/form nativi Cupertino) con un'ombra
/// leggera per staccarla dal barrier sottostante, e bottoni `FlatChipButton`
/// con icona — stesso identico linguaggio dei chip della sidecar (icona +
/// testo, riempimento pieno colorato). Titolo e messaggio centrati (stile
/// alert nativo iOS).
class AppAlertDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<AppAlertAction> actions;

  const AppAlertDialog({
    super.key,
    required this.title,
    this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final surface = CupertinoDynamicColor.resolve(AppColors.surface, context);
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.glassSmall),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black
                    .withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: labelPrimary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardLabel.copyWith(
                      color: labelSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FlatChipButton(
                          icon: actions[i].icon,
                          label: actions[i].label,
                          color: actions[i].color,
                          onPressed: actions[i].onPressed,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mostra un `AppAlertDialog`. Nessuna scala/molla: solo un fade secco,
/// stessa `Animation`/curva condivisa tra barrier e contenuto (sincronia
/// strutturale, non approssimata — il barrier è disegnato a mano qui invece
/// di affidarsi a quello di sistema, che usa `Curves.ease` fisso non
/// configurabile e non sincronizzabile con la curva del contenuto).
const _barrierColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x66000000),
  darkColor: Color(0x99000000),
);

Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppAlertAction> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AppAlertDialog(title: title, message: message, actions: actions);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final resolvedBarrierColor =
          CupertinoDynamicColor.resolve(_barrierColor, context);
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: ColoredBox(color: resolvedBarrierColor),
            ),
          ),
          FadeTransition(opacity: fade, child: child),
        ],
      );
    },
  );
}
