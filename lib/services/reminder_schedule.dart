import 'package:buts/models/busta_paga.dart';

/// Giorni del mese in cui viene mostrato un promemoria "importa la busta
/// paga", tutti allo stesso orario ([oraPromemoria]). Tre occasioni per
/// mese invece di una sola per tollerare che l'utente ignori/rimandi le
/// prime notifiche senza perdere del tutto il promemoria di quel ciclo.
const List<int> giorniPromemoria = [1, 8, 15];

/// Ora (24h, locale) in cui viene mostrato ogni promemoria.
const int oraPromemoria = 9;

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

  var anno = ora.year;
  var mese = ora.month;

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
        final dataPromemoria = DateTime(anno, mese, giorno, oraPromemoria);
        if (dataPromemoria.isAfter(ora)) {
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
