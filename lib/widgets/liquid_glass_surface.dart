import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

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

  /// Spessore del bordo speculare. Default: `1.1`, coerente con ogni altra
  /// card dell'app — solo popup/superfici piccole e centrate possono avere
  /// bisogno di un bordo più marcato per restare riconoscibili.
  final double borderWidth;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.blurSigma = 34,
    this.elevation = 10,
    this.padding,
    this.tint,
    this.borderWidth = 1.1,
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
              // Il riempimento a gradiente è dipinto via `CustomPaint`
              // invece che con un `LayoutBuilder`+`BoxDecoration.gradient`
              // calcolati sull'aspect ratio delle *constraints* in ingresso:
              // dentro una `ListView`/`Row` (es. le mini-card affiancate del
              // dettaglio busta paga) l'altezza in arrivo è spesso illimitata
              // (`hasBoundedHeight == false`), quindi l'aspect ratio
              // ricadeva sempre sul fallback 1.0 (quadrato) — il gradiente
              // tornava così ad essere l'esatta diagonale angolo-angolo
              // che si voleva evitare, quasi orizzontale su una card larga
              // e bassa, visibile come una "cucitura" netta invece che una
              // sfumatura morbida. `CustomPaint.paint(canvas, size)` riceve
              // sempre la size finale reale (mai le constraints), quindi
              // niente fallback: stessa tecnica ad angolo fisso già usata
              // da `_SpecularBorderPainter` per il bordo.
              child: CustomPaint(
                painter: _GlassFillPainter(baseFill: baseFill, isDark: isDark),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SpecularBorderPainter(
                  clipper: clipper,
                  highlight: highlight,
                  shadowEdge: shadowEdge,
                  strokeWidth: borderWidth,
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
  final double strokeWidth;

  _SpecularBorderPainter({
    required this.clipper,
    required this.highlight,
    required this.shadowEdge,
    required this.strokeWidth,
  });

  /// Senza questo override, `RenderCustomPaint.hitTestSelf` ricade sul
  /// default `_painter!.hitTest(position) ?? true` — cioè un `CustomPainter`
  /// che non implementa `hitTest()` reclama qualunque tocco sull'intera area
  /// (qui `Positioned.fill`), impedendo a `Stack` di testare il ramo
  /// sottostante con il contenuto reale (bottoni, righe, sotto-navigazione).
  /// Questo bordo è puramente decorativo: non deve mai intercettare i tocchi.
  @override
  bool? hitTest(Offset position) => false;

  /// Angolo fisso (in gradi, misurato dall'orizzontale) dell'asse del
  /// riflesso di luce: costante indipendentemente dall'aspect ratio della
  /// superficie, così il gradiente non si stira mai verso l'orizzontale
  /// (forme larghe e basse) o verso il verticale (forme strette e alte).
  static const double _lightAngleDeg = 35.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);

    const rad = _lightAngleDeg * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    final center = Offset(size.width / 2, size.height / 2);
    final halfDiag =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final begin = center - dir * halfDiag;
    final end = center + dir * halfDiag;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = ui.Gradient.linear(
        begin,
        end,
        [
          highlight,
          highlight.withValues(alpha: highlight.a * 0.3),
          shadowEdge,
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularBorderPainter oldDelegate) =>
      oldDelegate.highlight != highlight ||
      oldDelegate.shadowEdge != shadowEdge ||
      oldDelegate.clipper.radius != clipper.radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Riempimento a gradiente della superficie: stesso angolo fisso di
/// `_SpecularBorderPainter`, così luce e riempimento restano coerenti.
/// Riceve la `size` reale in `paint()` (mai le constraints di layout, che
/// possono essere illimitate dentro `ListView`/`Row`), quindi il gradiente
/// resta sempre diagonale indipendentemente da dove viene usata la card.
class _GlassFillPainter extends CustomPainter {
  final Color baseFill;
  final bool isDark;

  _GlassFillPainter({required this.baseFill, required this.isDark});

  static const double _lightAngleDeg = 35.0;

  @override
  void paint(Canvas canvas, Size size) {
    const rad = _lightAngleDeg * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    final center = Offset(size.width / 2, size.height / 2);
    final halfDiag =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final begin = center - dir * halfDiag;
    final end = center + dir * halfDiag;

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        begin,
        end,
        [
          baseFill,
          baseFill.withValues(
            alpha: (baseFill.a - (isDark ? 0.05 : 0.08)).clamp(0.0, 1.0),
          ),
        ],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassFillPainter oldDelegate) =>
      oldDelegate.baseFill != baseFill || oldDelegate.isDark != isDark;
}
