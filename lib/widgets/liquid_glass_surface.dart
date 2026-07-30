import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import 'squircle_clipper.dart';

/// Superficie "Liquid Glass": approssimazione Flutter-only (senza ponte
/// nativo iOS/`UIGlassEffect`) del materiale in vetro liquido introdotto da
/// Apple con iOS 26 — vedi HIG "Materials" / WWDC25 "Meet Liquid Glass".
///
/// Combina:
/// - blur del contenuto sottostante (`BackdropFilter`) per il comportamento
///   "adattivo" del materiale rispetto a ciò che ha dietro;
/// - un riempimento quasi neutro sopra il blur (poco colore, coerente con
///   l'uso sobrio del colore richiesto dalle linee guida sul Liquid Glass);
/// - un bordo con gradiente di luce (riflesso speculare in alto a sinistra,
///   ombra sottile in basso a destra) per simulare l'effetto "lente" con
///   cui il vetro rifrange i bordi;
/// - un'ombra morbida a rilievo (`PhysicalShape`) per staccare la
///   superficie dal contenuto sotto, come fa il vetro reale galleggiando
///   sopra i livelli di contenuto;
/// - una curva continua ("squircle", vedi `squircle_clipper.dart`) al
///   posto del semplice `BorderRadius.circular`.
///
/// Direzione di stile validata: è il mattone di base per ogni superficie/
/// card dell'app (sostituisce il precedente `MaterialSurface`, rimosso).
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;

  /// Raggio della curva continua. Default: `AppSpacing.glass` (hero card).
  final double radius;

  /// Intensità del blur (sigma): più alta produce un effetto vetro più
  /// marcato.
  final double blurSigma;

  /// Elevazione dell'ombra a rilievo sotto la superficie.
  final double elevation;

  final EdgeInsetsGeometry? padding;

  /// Accento di colore opzionale, mescolato a bassissima opacità nel
  /// riempimento — riservato a superfici "azione primaria" (es.
  /// `LiquidGlassButton`). Lasciare `null` per il vetro neutro standard.
  final Color? tint;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.blurSigma = 34,
    this.elevation = 10,
    this.padding,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fill = CupertinoDynamicColor.resolve(AppColors.glassFill, context);
    final highlight =
        CupertinoDynamicColor.resolve(AppColors.glassHighlight, context);
    final shadowEdge =
        CupertinoDynamicColor.resolve(AppColors.glassShadowEdge, context);

    final baseFill = tint == null
        ? fill
        : Color.alphaBlend(
            tint!.withValues(alpha: isDark ? 0.32 : 0.24),
            fill,
          );

    final clipper = SquircleClipper(radius: radius);

    return PhysicalShape(
      clipper: clipper,
      color: const Color(0x00000000),
      elevation: elevation,
      shadowColor: CupertinoColors.black.withValues(
        alpha: isDark ? 0.55 : 0.16,
      ),
      // Clip esplicito (oltre a quello di `PhysicalShape`): su alcune
      // combinazioni motore/versione (Impeller) un `BackdropFilter` senza
      // un clip layer diretto come antenato può "sfondare" il proprio
      // bounding box e dipingere sopra il resto dell'albero. Il clip qui è
      // ridondante nella maggior parte dei casi ma innocuo, ed è quello che
      // rende il blur affidabile in ogni configurazione.
      child: ClipPath(
        clipper: clipper,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseFill,
                      baseFill.withValues(
                        alpha: (baseFill.a - (isDark ? 0.05 : 0.08)).clamp(
                          0.0,
                          1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SpecularBorderPainter(
                  clipper: clipper,
                  highlight: highlight,
                  shadowEdge: shadowEdge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Traccia il bordo della squircle con uno stroke a gradiente: chiaro in
/// alto a sinistra (riflesso), in ombra in basso a destra — l'"illuminated
/// edge" tipico del Liquid Glass.
class _SpecularBorderPainter extends CustomPainter {
  final SquircleClipper clipper;
  final Color highlight;
  final Color shadowEdge;

  _SpecularBorderPainter({
    required this.clipper,
    required this.highlight,
    required this.shadowEdge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlight,
          highlight.withValues(alpha: highlight.a * 0.3),
          shadowEdge,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularBorderPainter oldDelegate) =>
      oldDelegate.highlight != highlight ||
      oldDelegate.shadowEdge != shadowEdge ||
      oldDelegate.clipper.radius != clipper.radius;
}
