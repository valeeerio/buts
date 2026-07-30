import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Approssimazione a mano (nessuna dipendenza pub esterna) di una curva
/// "continua" in stile Apple — la superellisse dietro le "squircle" usate
/// da icone e controlli iOS — al posto del doppio arco di
/// `BorderRadius.circular`. Usata dal pilota Liquid Glass della schermata
/// Archivio Buste Paga (`lib/widgets/liquid_glass_surface.dart`).
///
/// Genera il perimetro campionando, per ciascun angolo, la curva
/// |x/r|^n + |y/r|^n = 1 (superellisse), con `n` che controlla quanto la
/// curva è "continua" tra i due lati retti (2 = cerchio pieno, valori più
/// alti si avvicinano a uno spigolo vivo). 4–5 è il range che approssima
/// meglio le curve continue di iOS. Usato da `LiquidGlassSurface`, il
/// materiale in vetro standard di tutta l'app.
class SquirclePath {
  SquirclePath._();

  static const double defaultSmoothing = 4.5;

  static Path build(
    Size size,
    double radius, {
    double smoothing = defaultSmoothing,
  }) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, math.min(w, h) / 2);
    if (r <= 0.5) {
      return Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    }

    const stepsPerCorner = 14;

    Offset pointOnCorner(double cx, double cy, double angleDeg) {
      final t = angleDeg * math.pi / 180;
      final cosT = math.cos(t);
      final sinT = math.sin(t);
      final x =
          cx + r * cosT.sign * math.pow(cosT.abs(), 2 / smoothing).toDouble();
      final y =
          cy + r * sinT.sign * math.pow(sinT.abs(), 2 / smoothing).toDouble();
      return Offset(x, y);
    }

    // Centro e range angolare dell'arco per ciascun angolo, stesso schema
    // di un rounded-rect classico ma con `pointOnCorner` al posto di
    // cos/sin puri.
    final corners = <List<double>>[
      [r, r, 180.0, 270.0], // top-left
      [w - r, r, 270.0, 360.0], // top-right
      [w - r, h - r, 0.0, 90.0], // bottom-right
      [r, h - r, 90.0, 180.0], // bottom-left
    ];

    final path = Path();
    var first = true;
    for (final corner in corners) {
      final cx = corner[0];
      final cy = corner[1];
      final start = corner[2];
      final end = corner[3];
      for (var i = 0; i <= stepsPerCorner; i++) {
        final angle = start + (end - start) * i / stepsPerCorner;
        final point = pointOnCorner(cx, cy, angle);
        if (first) {
          path.moveTo(point.dx, point.dy);
          first = false;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }
    path.close();
    return path;
  }
}

/// Clipper riutilizzabile che applica [SquirclePath.build].
class SquircleClipper extends CustomClipper<Path> {
  final double radius;
  final double smoothing;

  const SquircleClipper({
    required this.radius,
    this.smoothing = SquirclePath.defaultSmoothing,
  });

  @override
  Path getClip(Size size) =>
      SquirclePath.build(size, radius, smoothing: smoothing);

  @override
  bool shouldReclip(covariant SquircleClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.smoothing != smoothing;
}
