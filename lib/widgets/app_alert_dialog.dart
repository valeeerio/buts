import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'flat_chip_button.dart';
import 'liquid_glass_surface.dart';

/// Un bottone di `AppAlertDialog`: stesso identico stile piatto
/// (`FlatChipButton`, senza icona) dei due bottoni della sidecar e della
/// barra Conferma/Modifica del dettaglio busta paga — [onPressed] fa
/// interamente carico di sé del `Navigator.pop`/eventuale side effect,
/// stesso contratto di `CupertinoDialogAction.onPressed` che sostituisce.
class AppAlertAction {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const AppAlertAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });
}

/// Popup di conferma/errore dell'app: sostituisce `CupertinoAlertDialog`
/// (chrome nativo iOS) con una `LiquidGlassSurface` — stesso materiale di
/// ogni altra card dell'app — e bottoni piatti (`FlatChipButton` senza
/// icona, affiancati 50/50 se sono due) al posto delle azioni di sistema a
/// lista con divisori. Titolo e messaggio allineati a sinistra (non
/// centrati come l'alert nativo), coerente con l'allineamento a sinistra
/// usato in tutta l'app e più leggibile per messaggi multi-riga (es. il
/// riepilogo diff di "Conferma modifiche").
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        // `RepaintBoundary`: isola il vetro (blur/riempimento/bordo
        // identici a ogni altra card, valori di default di
        // `LiquidGlassSurface` — nessuno sconto qui, era la causa
        // dell'aspetto "troppo trasparente"/bordo diverso dal resto
        // dell'app) in un layer che Flutter può renderizzare una volta
        // sola e riusare mentre la transizione anima solo l'opacità (vedi
        // `showAppAlertDialog`) — niente più ricalcolo del blur ad ogni
        // frame, che era la causa reale degli scatti, non l'intensità del
        // blur in sé.
        child: RepaintBoundary(
          child: LiquidGlassSurface(
            radius: AppRadius.glassSmall,
            borderWidth: 1.8,
            // Blur/elevazione molto più leggeri del default (34/10, tarato
            // per le card statiche di sfondo): un popup centrato sopra un
            // barrier già scurito non ha bisogno dell'effetto vetro
            // marcato, che qui leggeva come "troppo vivo" — con un blur
            // così basso la superficie si legge come una card quasi
            // opaca (il riempimento `glassFill` resta lo stesso token
            // condiviso, ~70% opaco in light/~25% in dark) invece che
            // come vetro sfocato.
            blurSigma: 6,
            elevation: 4,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Centrato come un alert nativo iOS (a differenza del resto
              // dell'app, allineata a sinistra) — scelta esplicita
              // dell'utente per questo componente: un popup è un'interruzione
              // centrata sullo schermo, non una card in un flusso di lettura
              // verticale.
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

/// Curva "a molla" con leggero overshoot, stesso spirito di `SpringButton`
/// (`lib/widgets/spring_button.dart`) — non condivisa da lì perché è solo
/// una `Curve`, non serve importare codice del bottone.
const _springOvershoot = Cubic(0.34, 1.56, 0.64, 1.0);

/// Mostra un `AppAlertDialog`, sostituendo `showCupertinoDialog` con una
/// transizione dedicata: la transizione di default di `showCupertinoDialog`
/// è tarata sul vero `CupertinoAlertDialog` nativo (leggero), non su una
/// `LiquidGlassSurface` con `BackdropFilter`. Fade + scale "a molla" con
/// overshoot: reso di nuovo economico dal `RepaintBoundary` interno di
/// `AppAlertDialog`, che cachea il vetro come layer/texture — la
/// `ScaleTransition` trasforma quel layer già renderizzato invece di
/// ricalcolare/ri-sfocare il `BackdropFilter` ad ogni frame, evitando gli
/// scatti che avevano motivato la rimozione della scala in precedenza. Il
/// barrier sfuma sulla stessa curva del fade, invece di apparire "di scatto".
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
    barrierColor: const CupertinoDynamicColor.withBrightness(
      color: Color(0x66000000),
      darkColor: Color(0x99000000),
    ),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AppAlertDialog(title: title, message: message, actions: actions);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: _springOvershoot),
        ),
        child: FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        ),
      );
    },
  );
}
