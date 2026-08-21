import 'package:buts/models/busta_paga.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Giorni del mese in cui viene mostrato un promemoria "importa la busta
/// paga", tutti allo stesso orario ([oraPromemoria]). Tre occasioni per
/// mese invece di una sola per tollerare che l'utente ignori/rimandi le
/// prime notifiche senza perdere del tutto il promemoria di quel ciclo.
const List<int> giorniPromemoria = [1, 8, 15];

/// Ora (24h, orario di **Europe/Rome**, non del device) in cui viene
/// mostrato ogni promemoria — vedi [_timeZoneName] per il perché.
const int oraPromemoria = 9;

/// Nome IANA fisso del fuso orario di scheduling, duplicato deliberatamente
/// da `LocalNotificationsScheduler._timeZoneName`
/// (`lib/services/reminder_notifications.dart`): quel fuso è quello con cui
/// [ReminderScheduler] interpreta davvero i numeri di ogni candidata al
/// momento di schedularla per sistema. Il filtro "già passato" qui sotto
/// deve ragionare nello stesso fuso, altrimenti una candidata può essere
/// scartata/inclusa sulla base dell'ora sbagliata quando il device è in un
/// fuso diverso da quello italiano (bug corretto in questa funzione).
const String _timeZoneName = 'Europe/Rome';

/// `true` dopo la prima inizializzazione del database dei fusi orari in
/// questo isolate: [tz_data.initializeTimeZones] è economica ma non ha
/// bisogno di essere ripetuta ad ogni chiamata di
/// [promemoriaDaSchedulare]. La UI del promemoria vero (bootstrap in
/// `main.dart`, tramite `LocalNotificationsScheduler.init()`) inizializza lo
/// stesso database separatamente: richiamarla di nuovo qui è comunque
/// innocuo (idempotente), serve solo a rendere questa funzione pura
/// utilizzabile anche nei test, che non passano mai da quel bootstrap.
bool _tzInitialized = false;

/// Location Europe/Rome, inizializzando il database dei fusi orari alla
/// prima chiamata se necessario.
tz.Location _romeLocation() {
  if (!_tzInitialized) {
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }
  return tz.getLocation(_timeZoneName);
}

/// Numero di cicli mensili "utili" per cui si generano in anticipo le
/// notifiche — non un numero fisso di mesi di calendario a partire da
/// quello corrente, vedi [promemoriaDaSchedulare]. `flutter_local_notifications`/
/// iOS richiedono di schedulare le notifiche in anticipo (non c'è un job
/// periodico lato sistema che le rigeneri da solo): guardare avanti di più
/// di un mese evita che l'intero meccanismo si "spenga" silenziosamente se
/// l'utente non riapre l'app per settimane, che è esattamente lo scenario
/// in cui i promemoria sono più utili. Con [giorniPromemoria] di lunghezza
/// 3 il totale è al più 9 notifiche pendenti, ben sotto il limite di 64
/// imposto da iOS.
const int cicliAvanti = 3;

/// (anno, mese) delle buste paga di tipo [TipoBustaPaga.mensile] già
/// presenti in archivio. 13ª e 14ª sono escluse deliberatamente: non hanno
/// un proprio ciclo di promemoria (vedi [targetPerCiclo]) e la loro
/// presenza in archivio non deve mai far saltare il ciclo di una mensilità
/// che punta allo stesso (anno, mese).
Set<({int anno, int mese})> periodiMensiliImportati(List<BustaPaga> buste) {
  return buste
      .where((busta) => busta.tipo == TipoBustaPaga.mensile)
      .map((busta) => (anno: busta.periodo.year, mese: busta.periodo.month))
      .toSet();
}

/// (anno, mese) della busta paga a cui punta il ciclo di promemoria che
/// contiene [dataPromemoria] — cioè il mese immediatamente precedente a
/// quello di [dataPromemoria].
///
/// La busta paga di un mese esiste solo a mese concluso (viene emessa a
/// fine mese o nei primi giorni di quello successivo): un promemoria
/// datato all'interno del mese M non può quindi mai riferirsi alla busta
/// di M stesso, che tipicamente non esiste ancora, ma a quella di M-1. Il
/// 1° settembre l'app ricorda la busta di agosto, non quella di settembre.
({int anno, int mese}) targetPerCiclo(DateTime dataPromemoria) {
  final anno = dataPromemoria.year;
  final mese = dataPromemoria.month;
  if (mese == 1) {
    return (anno: anno - 1, mese: 12);
  }
  return (anno: anno, mese: mese - 1);
}

/// Le date esatte (giorno + [oraPromemoria]) in cui andrebbero schedulati i
/// promemoria a partire da [ora], guardando avanti [cicliAvanti] cicli
/// mensili "utili" (vedi sotto per cosa rende un ciclo utile). Ordinate
/// crescenti.
///
/// Un ciclo mensile è **saltato deliberatamente** — nessuna delle tre date
/// in [giorniPromemoria] — se la busta paga a cui punta ([targetPerCiclo])
/// è già presente in [periodiImportati]: non ha senso ricordare all'utente
/// di importare qualcosa che ha già importato. Questo caso **conta** come
/// uno dei [cicliAvanti] cicli dell'orizzonte: è una decisione presa a
/// ragion veduta sul contenuto del ciclo, non una conseguenza del momento
/// in cui [ora] cade.
///
/// Un ciclo mensile può invece produrre zero date per un motivo diverso e
/// puramente temporale: se [ora] cade dopo l'ultimo giorno utile del ciclo
/// (dopo le [oraPromemoria] del 15, l'ultimo valore di [giorniPromemoria]),
/// nessuna delle sue tre date è più strettamente futura. Questo caso — che
/// può verificarsi solo per il ciclo che contiene [ora], visto che i cicli
/// dei mesi successivi hanno sempre tutte le date nel futuro — **non
/// conta** come uno dei [cicliAvanti] cicli: l'orizzonte si allunga di un
/// mese in più per compensare, così che l'utente abbia sempre
/// effettivamente [cicliAvanti] cicli di preavviso (utili o
/// deliberatamente saltati) davanti a sé, anche nella seconda metà del
/// mese. Senza questa distinzione, schedulare a partire dal 20 di un mese
/// lascerebbe meno di due mesi di orizzonte reale, in contrasto con lo
/// scopo dichiarato di [cicliAvanti].
///
/// Solo le date strettamente successive a [ora] vengono incluse: una
/// notifica il cui orario è già passato non va (ri)schedulata — sia
/// perché non avrebbe più senso mostrarla, sia perché schedulare notifiche
/// nel passato non è supportato dai plugin di notifiche locali.
///
/// Il numero di iterazioni è comunque limitato da un tetto di sicurezza
/// (ben oltre quanto potrebbe mai servire in pratica, dato che al più un
/// solo ciclo — quello di [ora] — può essere "non utile" per motivi
/// temporali): la funzione non può quindi degenerare in un loop
/// illimitato anche in presenza di input anomali.
List<DateTime> promemoriaDaSchedulare({
  required DateTime ora,
  required Set<({int anno, int mese})> periodiImportati,
}) {
  final risultato = <DateTime>[];

  // `ora` rappresenta un istante assoluto (`DateTime.now()` nel caso reale,
  // vedi `PayslipReminderService`), ma i suoi componenti wall-clock sono
  // quelli del fuso del *device*. Lo scheduling reale
  // (`LocalNotificationsScheduler.schedule`) interpreta invece i componenti
  // di ogni candidata come orario di *Europe/Rome*: per decidere in modo
  // coerente se una candidata è già passata bisogna quindi confrontare
  // entrambe le date nello stesso fuso. `roma` è lo stesso istante di `ora`,
  // riespresso come wall-clock italiana — a differenza delle candidate qui
  // sotto (costruite direttamente come wall-clock italiana, senza
  // conversione, esattamente come farà poi lo scheduler reale).
  final romeLocation = _romeLocation();
  final roma = tz.TZDateTime.from(ora, romeLocation);

  var anno = roma.year;
  var mese = roma.month;

  var cicliUtili = 0;
  var iterazioni = 0;
  // Tetto di sicurezza: in pratica basterebbe cicliAvanti + 1 (un solo
  // ciclo, quello di `ora`, può essere "non utile" per motivi temporali),
  // ma un margine ampio protegge comunque da eventuali input anomali senza
  // rischiare un loop illimitato.
  const iterazioniMassime = cicliAvanti + 12;

  while (cicliUtili < cicliAvanti && iterazioni < iterazioniMassime) {
    iterazioni++;

    final dataCiclo = DateTime(anno, mese);
    final target = targetPerCiclo(dataCiclo);

    if (periodiImportati.contains(target)) {
      // Ciclo saltato deliberatamente: conta comunque ai fini
      // dell'orizzonte, vedi dartdoc sopra.
      cicliUtili++;
    } else {
      final dateDelCiclo = <DateTime>[];
      for (final giorno in giorniPromemoria) {
        // La candidata restituita resta un `DateTime` "naive" (non un
        // `TZDateTime`): è quello che i chiamanti esistenti (test,
        // `PayslipReminderService`, `LocalNotificationsScheduler.schedule`)
        // si aspettano — quest'ultimo, in particolare, legge solo i
        // componenti wall-clock e li reinterpreta come Europe/Rome (vedi
        // `reminder_notifications.dart`), quindi un `DateTime` naive coi
        // componenti giusti è sufficiente e preserva l'uguaglianza con le
        // istanze `DateTime` naive usate dai chiamanti (`TZDateTime` non è
        // mai `==` a un `DateTime` semplice, anche a parità di istante).
        final dataPromemoria = DateTime(anno, mese, giorno, oraPromemoria);
        // Il confronto "già passato", invece, va fatto nel fuso in cui
        // quella stessa candidata verrà interpretata al momento dello
        // scheduling reale (Europe/Rome) — vedi dartdoc della funzione.
        final dataPromemoriaRoma =
            tz.TZDateTime(romeLocation, anno, mese, giorno, oraPromemoria);
        if (dataPromemoriaRoma.isAfter(roma)) {
          dateDelCiclo.add(dataPromemoria);
        }
      }

      if (dateDelCiclo.isNotEmpty) {
        risultato.addAll(dateDelCiclo);
        cicliUtili++;
      }
      // Se dateDelCiclo è vuoto il ciclo non conta (esaurito solo per il
      // tempo trascorso, non perché saltato deliberatamente): si prosegue
      // al mese successivo senza incrementare cicliUtili, allungando così
      // l'orizzonte.
    }

    mese++;
    if (mese > 12) {
      mese = 1;
      anno++;
    }
  }

  risultato.sort();
  return risultato;
}
