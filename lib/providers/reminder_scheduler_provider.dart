import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/payslip_reminder_service.dart';
import '../services/reminder_notifications.dart';

/// Istanza di [ReminderScheduler] usata dall'orchestrazione del promemoria
/// mensile (fase successiva, dentro la schermata radice). L'oggetto reale
/// ([LocalNotificationsScheduler]) viene creato e inizializzato (`init()` +
/// `consumaLaunchDetails()`, in quest'ordine) in `main()`, **prima** di
/// `runApp` — vedi `lib/main.dart` — e iniettato qui tramite
/// `overrides:` su `ProviderScope`, non tramite un singleton globale: è
/// l'unico modo pulito di esporre un'istanza creata fuori dall'albero dei
/// provider senza introdurre stato duplicato.
///
/// Il default lancia un errore esplicito se letto senza override: non deve
/// mai succedere in produzione (main() sovrascrive sempre questo provider
/// prima di costruire `BustePagaSectionScreen`), quindi un default silenzioso
/// (es. `LocalNotificationsScheduler()` non inizializzato) nasconderebbe un
/// bug di wiring invece di segnalarlo subito.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  throw UnimplementedError(
    'reminderSchedulerProvider non è stato sovrascritto: main() deve '
    'iniettare l\'istanza di LocalNotificationsScheduler già inizializzata '
    'tramite overrides: su ProviderScope prima di runApp.',
  );
});

/// Orchestrazione del promemoria mensile (onboarding, ri-scheduling), letta
/// dalla schermata radice (`BustePagaSectionScreen`).
///
/// A differenza di [reminderSchedulerProvider], il default qui NON lancia un
/// errore ma espone `null`: costruire [PayslipReminderService] in `main()`
/// dipende da `SharedPreferences.getInstance()` e dall'inizializzazione del
/// plugin di notifiche, entrambe operazioni che possono fallire per motivi
/// fuori dal controllo dell'app (storage del device, plugin nativo assente).
/// Un guasto qui non deve mai impedire l'apertura dell'archivio buste paga
/// (invariante esplicita del task): `main()` inietta l'override solo se la
/// costruzione del servizio è riuscita, altrimenti lascia il default `null`.
/// La UI (`BustePagaSectionScreen`) tratta `null` come "nessun promemoria
/// disponibile in questa sessione", non come un errore da propagare — niente
/// onboarding, niente re-scheduling, nessun crash. Stesso motivo per cui
/// anche i widget test che costruiscono `ButsApp()` senza override
/// continuano a funzionare invariati.
final payslipReminderServiceProvider = Provider<PayslipReminderService?>(
  (ref) => null,
);
