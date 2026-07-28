import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'navigation/app_root_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  runApp(const ButsApp());
}

class ButsApp extends StatelessWidget {
  const ButsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: CupertinoApp(
        title: 'Buts',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          DefaultCupertinoLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: AppRootScaffold(),
        ),
      ),
    );
  }
}
