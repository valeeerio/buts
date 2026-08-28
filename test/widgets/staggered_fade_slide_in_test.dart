import 'package:buts/widgets/staggered_fade_slide_in.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copertura minima per `StaggeredFadeSlideIn`: verifica il ritardo per
/// `index: 0`, il cap del ritardo per un `index` oltre `_maxDelayIndex` (12)
/// e la guardia `mounted` in `initState` quando il widget viene rimosso
/// dall'albero prima che il `Future.delayed` scada.
void main() {
  double opacityOf(WidgetTester tester, Finder finder) {
    return tester
        .widget<FadeTransition>(
          find.ancestor(
            of: finder,
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
  }

  Widget buildApp({required int index, Key? childKey}) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: StaggeredFadeSlideIn(
            index: index,
            child: SizedBox(key: childKey ?? const Key('child'), height: 40),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'index 0: il figlio diventa visibile (opacity 1) dopo pumpAndSettle',
    (tester) async {
      await tester.pumpWidget(buildApp(index: 0));

      // Subito dopo il mount l'animazione non è ancora partita (ritardo,
      // anche se minimo con index 0, gestito da un Future.delayed asincrono).
      await tester.pump();
      await tester.pumpAndSettle();

      final finder = find.byKey(const Key('child'));
      expect(find.byType(StaggeredFadeSlideIn), findsOneWidget);
      expect(opacityOf(tester, finder), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'index alto (20, oltre il cap 12): nessuna eccezione e il ritardo resta '
    'limitato dal cap (non blocca l\'animazione a tempo indefinito)',
    (tester) async {
      await tester.pumpWidget(buildApp(index: 20));

      // Col cap a 12, il ritardo massimo è 40ms * 12 = 480ms: avanzando di
      // poco oltre quella soglia l'animazione deve essere partita e, dato
      // che dura 220ms, arrivata a completamento con pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final finder = find.byKey(const Key('child'));
      expect(opacityOf(tester, finder), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rimuovere il widget dall\'albero prima che il Future.delayed scada non '
    'causa eccezioni (guardia mounted in initState)',
    (tester) async {
      await tester.pumpWidget(buildApp(index: 5));
      // Avanza un po', ma resta sotto il ritardo di 40ms * 5 = 200ms, così
      // il Future.delayed non è ancora scaduto quando rimuoviamo il widget.
      await tester.pump(const Duration(milliseconds: 50));

      // Sostituisce l'intero albero con un widget diverso: lo State di
      // StaggeredFadeSlideIn viene disposto (dispose() del controller)
      // mentre il Future.delayed è ancora pendente.
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(child: SizedBox()),
        ),
      );

      // Lascia scadere il Future.delayed originale: se la guardia `mounted`
      // non fosse presente, il `.then` chiamerebbe `setState`/`forward` su
      // uno State già disposto, sollevando un'eccezione qui.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(StaggeredFadeSlideIn), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
