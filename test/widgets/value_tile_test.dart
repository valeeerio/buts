import 'package:buts/widgets/value_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ValueTile mostra valore e label senza indicatore di progresso',
      (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: ValueTile(label: 'Ferie', value: '12'),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Ferie'), findsOneWidget);
    expect(find.byType(CustomPaint).evaluate().any((e) {
      final widget = e.widget as CustomPaint;
      return widget.painter.runtimeType.toString().contains('Ring');
    }), isFalse);
  });
}
