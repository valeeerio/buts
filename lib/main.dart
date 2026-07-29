import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/buste_paga/buste_paga_section_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  runApp(const ButsApp());
}

/// L'app è a sezione singola: Buste Paga è la root, nessuna sotto-navigazione
/// radice (vedi CLAUDE.md).
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
          child: BustePagaSectionScreen(),
        ),
      ),
    );
  }
}
