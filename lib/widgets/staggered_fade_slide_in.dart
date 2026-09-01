import 'package:flutter/cupertino.dart';

/// Wrapper di animazione d'ingresso "a cascata" (fade + slide dal basso) per
/// righe di elenco che compaiono in sequenza — pensato per liste come
/// l'Archivio buste paga, dove ogni riga parte con un ritardo proporzionale
/// alla propria posizione (`index`) rispetto all'inizio della colonna
/// scrollabile.
///
/// [index] deve essere un indice **globale/continuo** su tutta la colonna
/// (non locale ad una sotto-sezione): il ritardo è `40ms * index`, con un cap
/// oltre l'indice 12 (`_maxDelayIndex`) per evitare che le righe più in
/// fondo a liste lunghe restino invisibili troppo a lungo prima di animare.
///
/// Usare una [Key] stabile (es. basata sull'id del dato mostrato) quando si
/// istanzia questo widget in una lista: senza una key stabile, Flutter può
/// ricreare lo State ad ogni rebuild/scroll (per via del riordino/rimozione
/// di elementi) e l'animazione ripartirebbe da capo invece di restare
/// "giocata" solo al primo ingresso in vista.
class StaggeredFadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredFadeSlideIn({
    super.key,
    required this.index,
    required this.child,
  });

  static const _maxDelayIndex = 12;
  static const _delayStep = Duration(milliseconds: 40);
  static const _duration = Duration(milliseconds: 220);

  @override
  State<StaggeredFadeSlideIn> createState() => _StaggeredFadeSlideInState();
}

class _StaggeredFadeSlideInState extends State<StaggeredFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StaggeredFadeSlideIn._duration,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    final cappedIndex = widget.index > StaggeredFadeSlideIn._maxDelayIndex
        ? StaggeredFadeSlideIn._maxDelayIndex
        : widget.index;
    final delay = StaggeredFadeSlideIn._delayStep * cappedIndex;

    Future.delayed(delay).then((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
