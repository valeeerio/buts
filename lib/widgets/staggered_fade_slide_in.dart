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
///
/// [playId]/[playedIds] sono opzionali e servono a giocare l'animazione una
/// sola volta per dato, non una volta per ogni ricreazione dello `State`
/// dell'elemento: in una lista lazy (`SliverList`/`itemBuilder`), quando una
/// riga esce dal viewport durante lo scroll e vi rientra, Flutter distrugge
/// e ricrea lo `State` di questo widget (una `Key` stabile protegge solo dal
/// riordino/dalla rimozione nello stesso frame, non dalla ricostruzione lazy
/// legata al viewport) — senza questo meccanismo l'animazione ripartirebbe
/// da capo ad ogni rientro. Se [playId] è già presente in [playedIds]
/// all'`initState`, l'animazione non parte: il widget si mostra subito
/// nella sua posizione/opacità finale. Il controllo/inserimento avviene
/// **in `initState`**, non nel `build` di chi istanzia questo widget: un
/// `itemBuilder` di sliver può essere invocato più volte per la stessa riga
/// durante un singolo ciclo di layout/misurazione senza che questo crei una
/// nuova `Element`/`State` — `initState` gira invece esattamente una volta
/// per ogni vera istanza dello `State`, che è la granularità corretta per
/// questo tracking.
class StaggeredFadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;
  final String? playId;
  final Set<String>? playedIds;

  const StaggeredFadeSlideIn({
    super.key,
    required this.index,
    required this.child,
    this.playId,
    this.playedIds,
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

    final playId = widget.playId;
    final playedIds = widget.playedIds;
    final giaGiocata =
        playId != null && playedIds != null && playedIds.contains(playId);

    if (giaGiocata) {
      // Già mostrata in una build precedente (vedi doc di classe): nessuna
      // animazione, si parte già nello stato finale.
      _controller.value = 1.0;
      return;
    }

    playedIds?.add(playId!);

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
