import 'package:flutter/cupertino.dart';

/// Contro-traslazione di una barra flottante (es. "Salva/Annulla" del form di
/// import, "Conferma/Modifica" del dettaglio busta paga) durante le
/// transizioni di push/pop di `CupertinoPageRoute`: la barra è già dentro un
/// `Positioned` ancorato in basso, ma la route intera (compresa quella sotto,
/// quando è una pop) viene traslata orizzontalmente dalla transizione
/// standard iOS — senza questo wrapper la barra scorrerebbe via insieme al
/// resto della pagina invece di restare visivamente ferma. La
/// contro-traslazione va espressa in pixel assoluti (frazione della
/// larghezza schermo), non frazionale rispetto alla larghezza della barra
/// stessa, perché la barra è più stretta dello schermo intero (ha margini
/// laterali via `AppSpacing.screenHorizontal`): usare `FractionalTranslation`
/// o un offset relativo alla propria larghezza produrrebbe uno spostamento
/// diverso da quello subito dal resto della pagina e la barra
/// "scivolerebbe" comunque, solo a una velocità diversa. Durante lo
/// swipe-to-pop interattivo (`popGestureInProgress`) il valore
/// dell'animazione è già lineare rispetto al gesto e va usato direttamente;
/// altrimenti si applica la stessa curva (`Curves.fastEaseInToSlowEaseOut`,
/// quella usata da `CupertinoPageTransition` in Flutter 3.44) usata dalla
/// transizione di sistema, così il movimento resta sincronizzato.
///
/// Condiviso tra `busta_paga_form_screen.dart` (barra "Salva/Annulla") e
/// `busta_paga_detail_screen.dart` (barra "Conferma/Modifica"): entrambe le
/// route sono pushate allo stesso modo con `CupertinoPageRoute`, quindi
/// devono comportarsi in modo identico durante l'animazione di navigazione.
class StationaryPushBar extends StatelessWidget {
  final Widget child;
  const StationaryPushBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeAnimation = route?.animation;
    if (route == null || routeAnimation == null) return child;

    return AnimatedBuilder(
      animation: routeAnimation,
      builder: (context, builtChild) {
        final linear = route.popGestureInProgress;
        final double t;
        if (linear) {
          t = routeAnimation.value;
        } else {
          final curve = routeAnimation.status == AnimationStatus.reverse
              ? Curves.fastEaseInToSlowEaseOut.flipped
              : Curves.fastEaseInToSlowEaseOut;
          t = curve.transform(routeAnimation.value.clamp(0.0, 1.0));
        }
        final dxFraction = (1.0 - t).clamp(0.0, 1.0);
        final dxPixels = dxFraction * MediaQuery.sizeOf(context).width;
        return Transform.translate(
          offset: Offset(-dxPixels, 0),
          child: Opacity(
            opacity: (1.0 - dxFraction).clamp(0.0, 1.0),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
