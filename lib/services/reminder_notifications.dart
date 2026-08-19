import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Diventa `true` quando l'utente ha appena aperto l'app toccando una
/// notifica di promemoria — a caldo (`initialize.onDidReceiveNotificationResponse`,
/// impostato da [LocalNotificationsScheduler]) o a freddo, con l'app terminata
/// (`getNotificationAppLaunchDetails`, letto da [ReminderScheduler.consumaLaunchDetails]).
/// La fase di orchestrazione osserva questo valore per decidere se aprire
/// direttamente il flusso di import; non contiene altro stato (nessun payload:
/// in questa app esiste un solo tipo di notifica).
final ValueNotifier<bool> pendingImportRequest = ValueNotifier<bool>(false);

/// Astrazione sottile sopra `flutter_local_notifications`, pensata solo per
/// disaccoppiare l'orchestrazione del promemoria mensile (fase successiva) dal
/// plugin reale — nei test l'orchestrazione riceve un fake di questa
/// interfaccia invece di [LocalNotificationsScheduler], senza bisogno di un
/// device/simulatore.
abstract class ReminderScheduler {
  /// Mostra il prompt di sistema per il consenso alle notifiche. Va chiamato
  /// solo esplicitamente (mai durante l'init, vedi [LocalNotificationsScheduler]),
  /// così l'utente lo vede con un contesto già spiegato in un alert dell'app.
  Future<bool> requestPermission();

  /// Cancella ogni notifica pianificata. L'app ha un solo promemoria
  /// ricorrente, quindi "cancella tutto" è equivalente a "cancella il
  /// promemoria" senza dover tracciare id per conto proprio.
  Future<void> cancelAll();

  /// Pianifica una notifica singola alla data/ora indicata. Chi orchestra
  /// (fase successiva) è responsabile di ricalcolare e ri-schedulare quando
  /// serve un nuovo promemoria: questa interfaccia non gestisce ricorrenza.
  Future<void> schedule({
    required int id,
    required DateTime quando,
    required String titolo,
    required String corpo,
  });

  /// Legge se l'app è stata aperta dal tap su una notifica mentre era
  /// terminata (cold start) e, in tal caso, aggiorna [pendingImportRequest].
  /// Va chiamato una sola volta, durante il bootstrap dell'app.
  Future<void> consumaLaunchDetails();
}

/// Implementazione reale di [ReminderScheduler] sopra
/// `flutter_local_notifications` 22.3.0 — quasi tutta la documentazione in
/// circolazione per questo pacchetto fa riferimento a major precedenti con API
/// diverse: le firme qui sotto sono state verificate leggendo il sorgente
/// effettivamente installato, non a memoria.
class LocalNotificationsScheduler implements ReminderScheduler {
  LocalNotificationsScheduler() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Identificativo del canale/categoria iOS delle notifiche di promemoria.
  /// Un solo tipo di notifica in tutta l'app, quindi un solo canale.
  static const String _categoryIdentifier = 'promemoria_import_busta_paga';

  /// Nome IANA fisso del fuso orario di scheduling. Non viene dedotto dal
  /// fuso del device: è un'app personale con buste paga italiane, quindi ha
  /// senso che il promemoria mensile scatti sempre secondo l'orario italiano
  /// (deterministico anche se l'utente viaggia con l'iPhone su un altro fuso),
  /// e non secondo il fuso in cui l'utente si trova quel giorno.
  static const String _timeZoneName = 'Europe/Rome';

  /// Inizializza plugin e timezone. Va chiamato una sola volta, in bootstrap,
  /// prima di [schedule]/[cancelAll]/[requestPermission].
  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZoneName));

    const iosSettings = DarwinInitializationSettings(
      // I tre flag di richiesta permesso sono volutamente false: l'init non
      // deve mai far comparire il prompt di sistema da solo. Il consenso va
      // chiesto esplicitamente più avanti (requestPermission), dopo che
      // l'app ha già spiegato all'utente perché serve — altrimenti iOS
      // mostrerebbe il prompt al primo avvio, senza contesto.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(iOS: iosSettings);

    await _plugin.initialize(
      settings: settings,
      // Tap sulla notifica ad app già in esecuzione (foreground/background,
      // non cold start): il cold start è gestito a parte da
      // [consumaLaunchDetails].
      onDidReceiveNotificationResponse: (_) {
        pendingImportRequest.value = true;
      },
    );
  }

  @override
  Future<bool> requestPermission() async {
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  @override
  Future<void> cancelAll() async {
    // Nel codebase non esiste nessun'altra fonte di notifiche locali (un
    // solo promemoria ricorrente): "cancella tutto" è quindi sicuro e più
    // semplice che tracciare/cancellare per id.
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime quando,
    required String titolo,
    required String corpo,
  }) async {
    // Costruiamo il TZDateTime direttamente sui componenti di orario di
    // parete di `quando` (anno/mese/giorno/ora/minuto), non con
    // `TZDateTime.from`: quest'ultimo preserva l'istante assoluto di
    // `quando` (interpretato nel fuso del device) e lo riesprime nella
    // location indicata, quindi NON garantisce "le 9:00 italiane" se il
    // device è in un fuso diverso da Europe/Rome — esattamente il caso che
    // questo scheduling dovrebbe coprire (vedi _timeZoneName sopra). Con il
    // costruttore esplicito, invece, i numeri passati sono presi così come
    // sono e interpretati come orario locale della location indicata: le 9
    // restano le 9 italiane indipendentemente da dove si trovi l'iPhone.
    final scheduledDate = tz.TZDateTime(
      tz.getLocation(_timeZoneName),
      quando.year,
      quando.month,
      quando.day,
      quando.hour,
      quando.minute,
    );

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      title: titolo,
      body: corpo,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _categoryIdentifier,
        ),
      ),
      // Il parametro è marcato `required` dalla firma di zonedSchedule in
      // questa versione del plugin anche se l'app è iOS-only e non passa mai
      // AndroidNotificationDetails: è un requisito dell'API cross-platform,
      // non una scelta di targeting Android.
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  @override
  Future<void> consumaLaunchDetails() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      pendingImportRequest.value = true;
    }
  }
}
