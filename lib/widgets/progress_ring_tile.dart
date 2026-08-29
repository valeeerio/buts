import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pulse_surface.dart';

/// Tessera per dati di maturazione (ferie/ROL/permessi/ex festività):
/// `PulseSurface` non filled con un anello di progresso e un valore
/// formattato al centro — sostituisce le vecchie righe testuali del
/// dettaglio busta paga con una rappresentazione visiva bold/dark-first.
/// Diametro dell'anello — leggermente più grande dei 52 originali per
/// lasciare più respiro al valore centrale senza assottigliare troppo lo
/// stroke (vedi [_ringInnerContentSize]).
const double _ringSize = 56;

/// Spazio libero (quadrato inscritto) lasciato al testo dentro l'anello,
/// al netto dello stroke colorato — vincola esplicitamente il `FittedBox`
/// del valore così non scala mai fino a toccare l'arco.
const double _ringInnerContentSize = 34;

class ProgressRingTile extends StatelessWidget {
  final String label;
  final String value;

  /// Frazione di completamento, clampata a [0, 1] internamente anche se il
  /// chiamante passa valori fuori range (es. residuo maggiore del maturato
  /// per un edge case dei dati).
  final double progress;

  final Color? accentColor;

  const ProgressRingTile({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ??
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final secondaryText = CupertinoDynamicColor.resolve(
      AppColors.pulseTextSecondary,
      context,
    );
    final clampedProgress = progress.clamp(0.0, 1.0);

    return PulseSurface(
      borderRadius: AppRadius.pulseSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: _ringSize,
            height: _ringSize,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: clampedProgress,
                accent: accent,
              ),
              child: Center(
                // Vincola esplicitamente lo spazio disponibile al testo
                // all'area libera dentro l'anello (non all'intero
                // `_ringSize`, come prima): senza questo `FittedBox` con
                // `BoxFit.scaleDown` scalava il testo fino a riempire
                // l'intero quadrato della `SizedBox`, ignorando lo stroke
                // colorato e finendo quasi a contatto con l'arco (bug
                // visivo reale, non un'ipotesi).
                child: SizedBox(
                  width: _ringInnerContentSize,
                  height: _ringInnerContentSize,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.pulseDisplaySmall.copyWith(
                        fontSize: 12,
                        color: CupertinoDynamicColor.resolve(
                          AppColors.pulseTextPrimary,
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pulseLabel.copyWith(color: secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color accent;

  _ProgressRingPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final strokeWidth = size.shortestSide * 0.12;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final backgroundPaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, backgroundPaint);

    final progressPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
