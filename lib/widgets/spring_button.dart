import 'package:flutter/cupertino.dart';

/// Wrapper di interazione per bottoni/CTA con pressione "a molla": alla
/// pressione scala rapidamente verso il basso, al rilascio rimbalza oltre
/// la scala 1.0 (overshoot) prima di assestarsi — ispirato alla fisica di
/// spring/bounce vista nella demo shadcn/ui confrontata in fase di design
/// (vedi discussione in CLAUDE.md), applicata qui allo stile Cupertino.
class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const SpringButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _pressedScale = 0.96;
  static const Curve _pressCurve = Curves.easeOut;
  // Equivalente a cubic-bezier(0.34, 1.56, 0.64, 1): overshoot elastico.
  static const Curve _releaseCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 110),
      curve: _pressCurve,
    );
  }

  void _release() {
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: _releaseCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (_) {
        _release();
        widget.onPressed();
      },
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * (1.0 - _pressedScale));
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
