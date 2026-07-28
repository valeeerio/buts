import 'package:flutter/cupertino.dart';
import '../models/dashboard_area_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Riepilogo generale in cima alla Dashboard: donut chart con la ripartizione
/// delle 4 aree + totale al centro, e legenda a fianco con nome/percentuale.
class DonutSummary extends StatelessWidget {
  final List<DashboardAreaSummary> areas;
  final double total;

  const DonutSummary({super.key, required this.areas, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(AppColors.surface, context),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _DonutPainter(
                areas: areas,
                total: total,
                context: context,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '€ ${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelPrimary, context),
                      ),
                    ),
                    Text(
                      'totale',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelSecondary, context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final area in areas) ...[
                  _LegendRow(area: area, total: total),
                  if (area != areas.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final dynamic area; // DashboardAreaSummary
  final double total;

  const _LegendRow({required this.area, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = ((area.amount / total) * 100).round();
    final color = CupertinoDynamicColor.resolve(area.type.color, context);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            area.type.shortLabel,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoDynamicColor.resolve(
                  AppColors.labelPrimary, context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$pct%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CupertinoDynamicColor.resolve(
                AppColors.labelPrimary, context),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DashboardAreaSummary> areas;
  final double total;
  final BuildContext context;

  _DonutPainter({
    required this.areas,
    required this.total,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 14.0;
    const gapDegrees = 4.0;

    // Track di sfondo
    final trackPaint = Paint()
      ..color = CupertinoDynamicColor.resolve(AppColors.separator, context)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    var startAngle = -90.0;
    for (final area in areas) {
      final sweep = (area.amount / total) * 360;
      final paint = Paint()
        ..color = CupertinoDynamicColor.resolve(area.type.color, context)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _degToRad(startAngle),
        _degToRad(sweep - gapDegrees),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  double _degToRad(double deg) => deg * 3.1415926535 / 180;

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
