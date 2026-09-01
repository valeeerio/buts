import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Sfondo "mesh gradient" viola↔ciano per l'intera app (direzione
/// "futuristica", mockup B — vedi CLAUDE.md/piano sessione).
///
/// Avvolge [child] disegnando dietro di esso, sopra `AppColors.pulseBackground`
/// a tinta piena, 2-3 macchie sfumate radiali statiche in
/// `AppColors.pulseSecondaryGlow` (viola) e `AppColors.pulseAccent` (ciano) a
/// bassa opacità — puro decoro di sfondo, non introduce mai il viola come
/// colore funzionale (icone/testo/bottoni restano solo ciano, vedi
/// `pulseSecondaryGlow`). Le macchie sono statiche (nessuna animazione
/// pesante) e non intercettano input: lo strato decorativo è avvolto in
/// `IgnorePointer`, così scroll/tap del contenuto sopra non ne risentono.
class PulseMeshBackground extends StatelessWidget {
  final Widget child;

  /// Se `false`, disattiva completamente le macchie decorative e mostra solo
  /// `AppColors.pulseBackground` a tinta piena — utile per schermate dove il
  /// mesh non è desiderato (es. presentazioni/preview) senza dover duplicare
  /// il widget.
  final bool showBlobs;

  const PulseMeshBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        CupertinoDynamicColor.resolve(AppColors.pulseBackground, context);
    final glowPurple =
        CupertinoDynamicColor.resolve(AppColors.pulseSecondaryGlow, context);
    final glowCyan =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBlobs)
            IgnorePointer(
              child: Stack(
                children: [
                  // Macchia viola in alto a sinistra, parzialmente fuori
                  // schermo.
                  Positioned(
                    top: -160,
                    left: -140,
                    child: _MeshBlob(color: glowPurple, diameter: 340),
                  ),
                  // Macchia ciano in basso a destra, parzialmente fuori
                  // schermo.
                  Positioned(
                    bottom: -180,
                    right: -160,
                    child: _MeshBlob(
                        color: glowCyan, diameter: 380, opacity: 0.18),
                  ),
                  // Terza macchia viola più piccola, centrale a destra, per
                  // rompere la simmetria senza invadere il contenuto.
                  Positioned(
                    top: 220,
                    right: -120,
                    child: _MeshBlob(
                        color: glowPurple, diameter: 220, opacity: 0.15),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Singola macchia sfumata radiale statica, colore pieno al centro che
/// sfuma a trasparente verso il bordo.
class _MeshBlob extends StatelessWidget {
  final Color color;
  final double diameter;
  final double opacity;

  const _MeshBlob({
    required this.color,
    required this.diameter,
    this.opacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
