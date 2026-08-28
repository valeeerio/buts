import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Varianti disponibili di illustrazione custom, per momenti chiave
/// dell'app (stati vuoti, onboarding) — vedi CLAUDE.md sezione "Stile
/// visivo" > "Icone".
enum CustomIllustrationVariant {
  archivioVuoto,
  nessunRisultato,
  onboardingNotifiche,
}

/// Piccola illustrazione vettoriale line-art, disegnata a mano con
/// `CustomPainter` (mai asset raster/SVG, mai emoji) e colorata con
/// `AppColors.brandAccent` — riscaldamento dello stile Liquid Glass per
/// momenti chiave come stati vuoti e onboarding.
class CustomIllustration extends StatelessWidget {
  final CustomIllustrationVariant variant;
  final double size;

  const CustomIllustration({
    super.key,
    required this.variant,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(AppColors.brandAccent, context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _painterFor(variant, color),
      ),
    );
  }

  _IllustrationPainter _painterFor(
    CustomIllustrationVariant variant,
    Color color,
  ) {
    switch (variant) {
      case CustomIllustrationVariant.archivioVuoto:
        return _ArchivioVuotoPainter(color);
      case CustomIllustrationVariant.nessunRisultato:
        return _NessunRisultatoPainter(color);
      case CustomIllustrationVariant.onboardingNotifiche:
        return _OnboardingNotifichePainter(color);
    }
  }
}

abstract class _IllustrationPainter extends CustomPainter {
  final Color color;

  const _IllustrationPainter(this.color);

  double strokeWidthFor(Size size) => size.shortestSide * 0.035;

  Paint strokePaint(Size size) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidthFor(size)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint fillPaint() => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Documento stilizzato con angoli squircle, due righe corte e un "+" —
/// stato vuoto dell'Archivio.
class _ArchivioVuotoPainter extends _IllustrationPainter {
  const _ArchivioVuotoPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokePaint(size);
    final w = size.width;
    final h = size.height;

    // Documento: rettangolo con angoli arrotondati, centrato, margine
    // proporzionale per restare sempre dentro i bounds del canvas.
    final docRect = Rect.fromLTWH(
      w * 0.22,
      h * 0.12,
      w * 0.56,
      h * 0.76,
    );
    final docRRect = RRect.fromRectAndRadius(
      docRect,
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(docRRect, stroke);

    // Due righe orizzontali corte, nella metà superiore del documento.
    final lineY1 = docRect.top + docRect.height * 0.32;
    final lineY2 = docRect.top + docRect.height * 0.46;
    final lineLeft = docRect.left + docRect.width * 0.2;
    final lineRight = docRect.left + docRect.width * 0.8;
    canvas.drawLine(
        Offset(lineLeft, lineY1), Offset(lineRight, lineY1), stroke);
    canvas.drawLine(
      Offset(lineLeft, lineY2),
      Offset(lineLeft + (lineRight - lineLeft) * 0.6, lineY2),
      stroke,
    );

    // Simbolo "+" nella metà inferiore, centrato orizzontalmente.
    final plusCenter = Offset(
      docRect.center.dx,
      docRect.top + docRect.height * 0.72,
    );
    final plusArm = docRect.width * 0.14;
    canvas.drawLine(
      Offset(plusCenter.dx - plusArm, plusCenter.dy),
      Offset(plusCenter.dx + plusArm, plusCenter.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(plusCenter.dx, plusCenter.dy - plusArm),
      Offset(plusCenter.dx, plusCenter.dy + plusArm),
      stroke,
    );
  }
}

/// Lente d'ingrandimento con un trattino orizzontale al centro (nessun
/// risultato dalla ricerca/filtro).
class _NessunRisultatoPainter extends _IllustrationPainter {
  const _NessunRisultatoPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokePaint(size);
    final w = size.width;
    final h = size.height;

    final glassRadius = w * 0.28;
    final glassCenter = Offset(w * 0.42, h * 0.42);
    canvas.drawCircle(glassCenter, glassRadius, stroke);

    // Manico diagonale, dal bordo del cerchio verso l'angolo in basso a
    // destra, restando dentro i bounds.
    final handleStart = Offset(
      glassCenter.dx + glassRadius * 0.72,
      glassCenter.dy + glassRadius * 0.72,
    );
    final handleEnd = Offset(w * 0.82, h * 0.82);
    canvas.drawLine(handleStart, handleEnd, stroke);

    // Trattino orizzontale al centro della lente.
    final dashHalf = glassRadius * 0.4;
    canvas.drawLine(
      Offset(glassCenter.dx - dashHalf, glassCenter.dy),
      Offset(glassCenter.dx + dashHalf, glassCenter.dy),
      stroke,
    );
  }
}

/// Campanella stilizzata con badge di notifica — onboarding promemoria.
class _OnboardingNotifichePainter extends _IllustrationPainter {
  const _OnboardingNotifichePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokePaint(size);
    final w = size.width;
    final h = size.height;

    final topCenter = Offset(w * 0.46, h * 0.16);
    final bodyLeft = Offset(w * 0.24, h * 0.62);
    final bodyRight = Offset(w * 0.68, h * 0.62);

    // Corpo della campanella: due curve cubiche simmetriche dal vertice in
    // alto fino alla base, che si allargano verso il basso.
    final bodyPath = Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..cubicTo(
        w * 0.18,
        h * 0.2,
        w * 0.14,
        h * 0.5,
        bodyLeft.dx,
        bodyLeft.dy,
      )
      ..moveTo(topCenter.dx, topCenter.dy)
      ..cubicTo(
        w * 0.62,
        h * 0.2,
        w * 0.66,
        h * 0.5,
        bodyRight.dx,
        bodyRight.dy,
      );
    canvas.drawPath(bodyPath, stroke);

    // Base della campanella: linea orizzontale che chiude il corpo.
    canvas.drawLine(bodyLeft, bodyRight, stroke);

    // Battaglio, appeso al centro sotto la base.
    final clapperCenter = Offset((bodyLeft.dx + bodyRight.dx) / 2, h * 0.7);
    canvas.drawCircle(clapperCenter, w * 0.035, fillPaint());

    // Badge di notifica: piccolo pallino pieno in alto a destra.
    final badgeCenter = Offset(w * 0.76, h * 0.2);
    canvas.drawCircle(badgeCenter, w * 0.07, fillPaint());
  }
}
