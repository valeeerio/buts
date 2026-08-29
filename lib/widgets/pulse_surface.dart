import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Superficie piatta "Pulse": sostituto bold/dark-first di
/// `LiquidGlassSurface` — nessun blur, nessun `BackdropFilter`, solo un
/// riempimento a tinta piena (o un leggero gradiente diagonale quando
/// `filled == true`) con angoli arrotondati circolari classici.
///
/// Usata sia come contenitore generico (card, sezioni) sia come tessera in
/// una griglia (es. `ProgressRingTile`).
class PulseSurface extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Raggio degli angoli. Default: `AppRadius.pulse` (22.0).
  final double borderRadius;

  /// Se `true`, riempie con `AppColors.pulseAccent` (più una leggera
  /// sfumatura verso una variante più scura, per dare rilievo) invece del
  /// neutro `AppColors.pulseSurface`. In questo caso niente ombra.
  final bool filled;

  final VoidCallback? onTap;

  const PulseSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.pulse,
    this.filled = false,
    this.onTap,
  });

  @override
  State<PulseSurface> createState() => _PulseSurfaceState();
}

class _PulseSurfaceState extends State<PulseSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    Decoration decoration;
    if (widget.filled) {
      final accent = CupertinoDynamicColor.resolve(
        AppColors.pulseAccent,
        context,
      );
      final accentDark = Color.alphaBlend(
        CupertinoColors.black.withValues(alpha: 0.22),
        accent,
      );
      decoration = BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accentDark],
        ),
      );
    } else {
      final surface = CupertinoDynamicColor.resolve(
        AppColors.pulseSurface,
        context,
      );
      final isDark =
          MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      decoration = BoxDecoration(
        color: surface,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(
              alpha: isDark ? 0.28 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    Widget content = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _pressed ? 0.75 : 1.0,
      child: DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: content,
    );
  }
}
