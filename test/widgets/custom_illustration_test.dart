import 'package:buts/widgets/custom_illustration.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copertura minima per `CustomIllustration`: monta ciascuna variante dentro
/// un `CupertinoApp` con size piccola e grande, verificando che il
/// `CustomPainter` interno non sollevi eccezioni a nessuna delle due scale
/// (i painter calcolano tutte le coordinate come frazioni di `size`, quindi
/// un errore di layout/asserzione emergerebbe più facilmente agli estremi).
void main() {
  Future<void> pumpIllustration(
    WidgetTester tester,
    CustomIllustrationVariant variant,
    double size,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: CustomIllustration(variant: variant, size: size),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final variant in CustomIllustrationVariant.values) {
    group('CustomIllustration — ${variant.name}', () {
      testWidgets('si monta senza eccezioni con size piccola (48)',
          (tester) async {
        await pumpIllustration(tester, variant, 48);

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomIllustration), findsOneWidget);
      });

      testWidgets('si monta senza eccezioni con size grande (160)',
          (tester) async {
        await pumpIllustration(tester, variant, 160);

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomIllustration), findsOneWidget);
      });

      testWidgets('usa la size richiesta per il proprio SizedBox',
          (tester) async {
        await pumpIllustration(tester, variant, 160);

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(CustomIllustration),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, 160);
        expect(sizedBox.height, 160);
      });
    });
  }
}
