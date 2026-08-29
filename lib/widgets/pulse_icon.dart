import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Glifi disponibili nel set di icone custom "Pulse" — sostituirà
/// `CupertinoIcons` nell'app (vedi CLAUDE.md, redesign Pulse). Altri glifi
/// verranno aggiunti nelle fasi successive quando serviranno a una
/// schermata specifica.
enum PulseIconGlyph {
  search,
  close,
  chevronBack,
  chevronForward,
  chevronDown,
  edit,
  delete,
  add,
  checkmark,
  document,
  calendar,
  settings,
  archive,
  chart,
}

/// Icona vettoriale custom, disegnata con `CustomPainter` invece che con
/// glifi da font (`CupertinoIcons`): stroke spesso e geometria semplice,
/// coerente con il linguaggio visivo bold/geometrico di Pulse.
class PulseIcon extends StatelessWidget {
  final PulseIconGlyph glyph;
  final double size;
  final Color? color;

  const PulseIcon({
    super.key,
    required this.glyph,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PulseIconPainter(glyph: glyph, color: resolvedColor),
      ),
    );
  }
}

class _PulseIconPainter extends CustomPainter {
  final PulseIconGlyph glyph;
  final Color color;

  _PulseIconPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;

    switch (glyph) {
      case PulseIconGlyph.search:
        final radius = w * 0.28;
        final center = Offset(w * 0.42, h * 0.42);
        canvas.drawCircle(center, radius, stroke);
        canvas.drawLine(
          Offset(
            center.dx + radius * 0.72,
            center.dy + radius * 0.72,
          ),
          Offset(w * 0.82, h * 0.82),
          stroke,
        );
        break;

      case PulseIconGlyph.close:
        canvas.drawLine(
          Offset(w * 0.22, h * 0.22),
          Offset(w * 0.78, h * 0.78),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.78, h * 0.22),
          Offset(w * 0.22, h * 0.78),
          stroke,
        );
        break;

      case PulseIconGlyph.chevronBack:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.62, h * 0.22)
            ..lineTo(w * 0.34, h * 0.5)
            ..lineTo(w * 0.62, h * 0.78),
          stroke,
        );
        break;

      case PulseIconGlyph.chevronForward:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.38, h * 0.22)
            ..lineTo(w * 0.66, h * 0.5)
            ..lineTo(w * 0.38, h * 0.78),
          stroke,
        );
        break;

      case PulseIconGlyph.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.38)
            ..lineTo(w * 0.5, h * 0.66)
            ..lineTo(w * 0.78, h * 0.38),
          stroke,
        );
        break;

      case PulseIconGlyph.edit:
        canvas.drawLine(
          Offset(w * 0.22, h * 0.78),
          Offset(w * 0.42, h * 0.78),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.28, h * 0.72)
            ..lineTo(w * 0.64, h * 0.36)
            ..lineTo(w * 0.78, h * 0.5)
            ..lineTo(w * 0.42, h * 0.86)
            ..close(),
          stroke,
        );
        break;

      case PulseIconGlyph.delete:
        canvas.drawLine(
          Offset(w * 0.24, h * 0.3),
          Offset(w * 0.76, h * 0.3),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.32, h * 0.3, w * 0.68, h * 0.82),
            Radius.circular(w * 0.05),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.42, h * 0.2),
          Offset(w * 0.58, h * 0.2),
          stroke,
        );
        break;

      case PulseIconGlyph.add:
        canvas.drawLine(
          Offset(w * 0.5, h * 0.2),
          Offset(w * 0.5, h * 0.8),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.2, h * 0.5),
          Offset(w * 0.8, h * 0.5),
          stroke,
        );
        break;

      case PulseIconGlyph.checkmark:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.2, h * 0.52)
            ..lineTo(w * 0.42, h * 0.74)
            ..lineTo(w * 0.8, h * 0.28),
          stroke,
        );
        break;

      case PulseIconGlyph.document:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.26, h * 0.14, w * 0.48, h * 0.72),
            Radius.circular(w * 0.06),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.38, h * 0.42),
          Offset(w * 0.62, h * 0.42),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.38, h * 0.58),
          Offset(w * 0.62, h * 0.58),
          stroke,
        );
        break;

      case PulseIconGlyph.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.18, h * 0.24, w * 0.64, h * 0.58),
            Radius.circular(w * 0.06),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.18, h * 0.4),
          Offset(w * 0.82, h * 0.4),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.34, h * 0.16),
          Offset(w * 0.34, h * 0.3),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.66, h * 0.16),
          Offset(w * 0.66, h * 0.3),
          stroke,
        );
        break;

      case PulseIconGlyph.settings:
        final center = Offset(w * 0.5, h * 0.5);
        canvas.drawCircle(center, w * 0.14, stroke);
        for (var i = 0; i < 6; i++) {
          final angle = (i / 6) * 2 * math.pi;
          final inner = Offset(
            center.dx + w * 0.2 * math.cos(angle),
            center.dy + w * 0.2 * math.sin(angle),
          );
          final outer = Offset(
            center.dx + w * 0.34 * math.cos(angle),
            center.dy + w * 0.34 * math.sin(angle),
          );
          canvas.drawLine(inner, outer, stroke);
        }
        break;

      case PulseIconGlyph.archive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.68, h * 0.16),
            Radius.circular(w * 0.04),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.2, h * 0.36, w * 0.6, h * 0.46),
            Radius.circular(w * 0.05),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.4, h * 0.58),
          Offset(w * 0.6, h * 0.58),
          stroke,
        );
        break;

      case PulseIconGlyph.chart:
        canvas.drawLine(
          Offset(w * 0.24, h * 0.8),
          Offset(w * 0.24, h * 0.5),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.5, h * 0.8),
          Offset(w * 0.5, h * 0.28),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.76, h * 0.8),
          Offset(w * 0.76, h * 0.62),
          stroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PulseIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
