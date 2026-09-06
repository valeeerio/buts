import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/reminder_scheduler_provider.dart';
import 'screens/buste_paga/buste_paga_section_screen.dart';
import 'services/home_widget_launch.dart';
import 'services/payslip_reminder_service.dart';
import 'services/reminder_notifications.dart';

/// Subscription dell'ascolto "tap sul widget ad app già in esecuzione"
/// (`registraAscoltoHomeWidgetClicked`), tenuta viva per l'intera sessione
/// app in una variabile top-level: senza un riferimento esterno mantenuto
/// esplicitamente, non c'è garanzia che l'oggetto non venga raccolto dal
/// garbage collector (lo `StreamSubscription` restituito non viene mai
/// letto/cancellato altrove). Non serve mai leggerla: esiste solo per
/// tenere viva la subscription.
// ignore: unused_element
late final StreamSubscription<Uri?> _homeWidgetClickSub;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  final reminderScheduler = LocalNotificationsScheduler();
  // `null` finché la costruzione sotto non va a buon fine: resta `null` se
  // una qualunque delle chiamate nel `try` fallisce, e in tal caso
  // `payslipReminderServiceProvider` NON viene sovrascritto più sotto — resta
  // sul default `null` del provider (vedi `reminder_scheduler_provider.dart`).
  // Questo è deliberatamente un guard diverso da quello di
  // `reminderSchedulerProvider`, che viene sempre iniettato: qui un guasto
  // (SharedPreferences non disponibile, plugin di notifiche non
  // inizializzabile) non deve mai propagarsi come provider "rotto" da
  // leggere più avanti — l'app deve aprirsi comunque sull'archivio, solo
  // senza promemoria in questa sessione.
  PayslipReminderService? payslipReminderService;
  try {
    // Ordine critico: `consumaLaunchDetails()` legge se l'app è stata aperta
    // dal tap su una notifica mentre era terminata (cold start) e aggiorna
    // `pendingImportRequest` di conseguenza — va fatto PRIMA di `runApp`,
    // perché la schermata radice che osserverà quel valore (fase successiva)
    // viene costruita subito dopo e non deve perdersi il segnale.
    await reminderScheduler.init();
    await reminderScheduler.consumaLaunchDetails();
    // Widget iOS della home screen: stesso spirito del promemoria appena
    // sopra, un guasto qui (App Group non configurato, plugin nativo
    // assente) non deve mai impedire l'apertura dell'archivio buste paga —
    // vedi il commento sul try/catch che avvolge questo intero blocco.
    await HomeWidget.setAppGroupId('group.com.buts.buts');
    await consumaHomeWidgetLaunch();
    _homeWidgetClickSub = registraAscoltoHomeWidgetClicked();
    final preferences = await SharedPreferences.getInstance();
    payslipReminderService = PayslipReminderService(
      scheduler: reminderScheduler,
      preferences: preferences,
    );
  } catch (_) {
    // Un promemoria rotto (permessi, plugin non disponibile, storage delle
    // preferenze non disponibile, qualunque eccezione) non può impedire
    // l'accesso all'archivio delle buste paga: l'app si avvia comunque,
    // semplicemente senza notifiche funzionanti in questa sessione.
  }

  runApp(
    ButsApp(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(reminderScheduler),
        if (payslipReminderService != null)
          payslipReminderServiceProvider.overrideWithValue(
            payslipReminderService,
          ),
      ],
    ),
  );
}

/// L'app è a sezione singola: Buste Paga è la root, nessuna sotto-navigazione
/// radice (vedi CLAUDE.md).
class ButsApp extends StatelessWidget {
  const ButsApp({super.key, this.overrides = const []});

  /// Override dei provider Riverpod da iniettare sul `ProviderScope` radice.
  /// Vuoto di default (usato anche dai widget test, che non hanno bisogno di
  /// un [ReminderScheduler] reale): `main()` lo popola con l'istanza di
  /// [LocalNotificationsScheduler] già inizializzata prima di `runApp`, vedi
  /// [reminderSchedulerProvider].
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: CupertinoApp(
        title: 'Buts',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        localizationsDelegates: const [
          DefaultCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // L'app è forzata a SOLA dark mode (decisione utente): sovrascrive
          // sempre `platformBrightness` a `Brightness.dark`, ignorando
          // l'impostazione di sistema del dispositivo. Necessario perché
          // alcuni widget (es. `LiquidGlassSurface`, `PulseSurface`,
          // `busta_paga_summary_hero.dart`) leggono direttamente
          // `MediaQuery.platformBrightnessOf(context)` invece di affidarsi
          // solo a `CupertinoTheme`/`CupertinoDynamicColor`.
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(platformBrightness: Brightness.dark),
            child: child!,
          );
        },
        home: const CupertinoPageScaffold(
          child: BustePagaSectionScreen(),
        ),
      ),
    );
  }
}
