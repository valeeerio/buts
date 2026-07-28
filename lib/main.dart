import 'package:flutter/cupertino.dart';
import 'navigation/root_scaffold.dart';

void main() {
  runApp(const ButsApp());
}

class ButsApp extends StatelessWidget {
  const ButsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Buts',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        DefaultCupertinoLocalizations.delegate,
      ],
      home: CupertinoPageScaffold(
        child: RootScaffold(),
      ),
    );
  }
}
