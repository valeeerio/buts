import 'package:flutter/cupertino.dart';

/// Mini-grafico ad andamento (linea), usato nelle card delle aree.
/// Puramente decorativo/indicativo: non è pensato per leggere valori esatti.
class Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double width;
  final double height;

  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.width = 50,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs() < 0.001 ? 1.0 : (maxVal - minVal);

    final stepX = size.width / (points.length - 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      // Normalizza: valore più alto = linea più in alto (y minore).
      final normalized = (points[i] - minVal) / range;
      final y = size.height - (normalized * size.height);
      final x = i * stepX;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
