import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/home_widget_service.dart';

/// Istanza condivisa di [HomeWidgetService], letta da
/// `buste_paga_section_screen.dart` per aggiornare il widget iOS della home
/// screen ad ogni mutazione dell'archivio buste paga e all'avvio dell'app.
final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetService(),
);
