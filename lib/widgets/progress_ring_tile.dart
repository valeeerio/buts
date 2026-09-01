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
/// Diametro di default dell'anello — leggermente più grande dei 52
/// originali per lasciare più respiro al valore centrale senza
/// assottigliare troppo lo stroke (vedi [_ringInnerContentSize]).
const double _ringSize = 56;

/// Frazione di [ProgressRingTile.diameter] lasciata libera (quadrato
/// inscritto) per il testo dentro l'anello, al netto dello stroke colorato —
/// vincola esplicitamente il `FittedBox` del valore così non scala mai fino
/// a toccare l'arco. Ricavata da 34/56 (i valori fissi originali), applicata
/// proporzionalmente a [ProgressRingTile.diameter] così una variante più
/// grande (es. gli anelli "snapshot" di Statistiche, 60px) mantiene lo
/// stesso rapporto visivo invece di un valore assoluto fisso.
const double _ringInnerContentRatio = 34 / _ringSize;

class ProgressRingTile extends StatelessWidget {
  final String label;
  final String value;

  /// Frazione di completamento, clampata a [0, 1] internamente anche se il
  /// chiamante passa valori fuori range (es. residuo maggiore del maturato
  /// per un edge case dei dati).
  final double progress;

  final Color? accentColor;

  /// Diametro dell'anello. Default [_ringSize] (56, usato dal dettaglio
  /// busta paga/Archivio) — Statistiche passa un valore più grande (58-64)
  /// per gli anelli "snapshot" del blocco Ferie/Permessi/Ex festività, vedi
  /// CLAUDE.md.
  final double diameter;

  /// Se `true`, aggiunge un bordo sottile a gradiente viola→ciano attorno
  /// alla tessera (stesso pattern di `_ChartCard` in Statistiche). Opt-in,
  /// default `false`: l'Archivio (dettaglio busta paga incluso) non lo
  /// richiede e deve restare visivamente invariato — solo Statistiche lo
  /// attiva per gli anelli "snapshot".
  final bool showGradientBorder;

  const ProgressRingTile({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.accentColor,
    this.diameter = _ringSize,
    this.showGradientBorder = false,
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
    final innerContentSize = diameter * _ringInnerContentRatio;

    final tile = PulseSurface(
      borderRadius: AppRadius.pulseSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: diameter,
            height: diameter,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: clampedProgress,
                accent: accent,
              ),
              child: Center(
                // Vincola esplicitamente lo spazio disponibile al testo
                // all'area libera dentro l'anello (non all'intero
                // `diameter`, come prima): senza questo `FittedBox` con
                // `BoxFit.scaleDown` scalava il testo fino a riempire
                // l'intero quadrato della `SizedBox`, ignorando lo stroke
                // colorato e finendo quasi a contatto con l'arco (bug
                // visivo reale, non un'ipotesi).
                child: SizedBox(
                  width: innerContentSize,
                  height: innerContentSize,
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

    if (!showGradientBorder) {
      return tile;
    }

    // Bordo sottile a gradiente viola→ciano, stesso pattern di `_ChartCard`
    // in Statistiche (vedi CLAUDE.md, "gradient mesh"): un `Container` esterno
    // con `BoxDecoration` a gradiente e 1px di `padding` disegna il bordo
    // "attorno" a `PulseSurface`, senza toccare il widget condiviso.
    // Opacità più bassa (~0.22, contro lo 0.35 dei grafici) rispetto a
    // `_ChartCard`: qui la tessera ha già un anello di progresso interno
    // colorato, un bordo esterno troppo marcato avrebbe reso il doppio
    // contorno confuso. Opt-in via [showGradientBorder]: solo Statistiche lo
    // richiede, l'Archivio deve restare invariato rispetto a prima di questo
    // redesign.
    final violet =
        CupertinoDynamicColor.resolve(AppColors.pulseSecondaryGlow, context);
    final cyan = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pulseSmall),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            violet.withValues(alpha: 0.22),
            cyan.withValues(alpha: 0.22),
          ],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: tile,
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
