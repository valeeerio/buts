import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/busta_paga.dart';
import '../utils/busta_paga_formatting.dart';
import 'reminder_notifications.dart';
import 'reminder_schedule.dart';

/// Orchestrazione del promemoria mensile "importa la busta paga": compone la
/// logica pura di [reminder_schedule] (quali date, se un ciclo va saltato)
/// con [ReminderScheduler] (come schedulare/cancellare per davvero) e con la
/// persistenza dei due flag di consenso (onboarding mostrato, permesso di
/// sistema concesso) via `shared_preferences`.
///
/// Non contiene wiring verso la UI: le schermate (fase successiva) chiamano
/// [onboardingDaMostrare]/[completaOnboarding]/[rifiutaOnboarding] per il
/// flusso di consenso una-tantum, e [reschedule] ogni volta che l'archivio
/// buste paga cambia (import riuscito, eliminazione, avvio app).
class PayslipReminderService {
  PayslipReminderService({
    required this.scheduler,
    required SharedPreferences preferences,
    DateTime Function() adesso = DateTime.now,
  })  : _preferences = preferences,
        _adesso = adesso;

  final ReminderScheduler scheduler;
  final SharedPreferences _preferences;

  /// Iniettato invece di chiamare `DateTime.now()` direttamente nella
  /// logica, per rendere i test deterministici.
  final DateTime Function() _adesso;

  static const String _onboardingCompletatoKey =
      'payslip_reminder_onboarding_completato';
  static const String _permessoConcessoKey =
      'payslip_reminder_permesso_concesso';

  bool get _onboardingCompletato =>
      _preferences.getBool(_onboardingCompletatoKey) ?? false;

  bool get _permessoConcesso =>
      _preferences.getBool(_permessoConcessoKey) ?? false;

  /// Contatore di generazione incrementato a inizio di ogni [reschedule]:
  /// la chiamata cattura il proprio valore in una variabile locale
  /// all'avvio e lo confronta con questo campo dopo ogni `await` verso
  /// [scheduler] — se sono diversi, una chiamata più recente è nel
  /// frattempo partita ed è lei ad avere l'ultima parola, quindi la
  /// chiamata corrente si interrompe senza schedulare altro. Vedi dartdoc
  /// di [reschedule] per la race condition che risolve.
  int _generazioneReschedule = 0;

  /// Future della [reschedule] più recente ancora in esecuzione (già
  /// risolta se nessuna chiamata è in corso): ogni nuova invocazione
  /// attende che quella precedente abbia effettivamente smesso di operare
  /// prima di eseguire il proprio `cancelAll()`. Vedi dartdoc di
  /// [reschedule].
  Future<void> _rescheduleInCorso = Future<void>.value();

  /// `true` se l'alert esplicativo una-tantum sul promemoria non è ancora
  /// stato mostrato (né accettato né rifiutato) — la schermata che ospita
  /// l'onboarding lo mostra finché questo resta `true`.
  bool get onboardingDaMostrare => !_onboardingCompletato;

  /// L'utente ha accettato l'onboarding: segna il flag come completato,
  /// chiede subito il permesso di sistema (l'utente ha già visto il
  /// contesto nell'alert dell'app) e persiste l'esito. Ritorna se il
  /// permesso è stato concesso.
  Future<bool> completaOnboarding() async {
    await _preferences.setBool(_onboardingCompletatoKey, true);
    final concesso = await scheduler.requestPermission();
    await _preferences.setBool(_permessoConcessoKey, concesso);
    return concesso;
  }

  /// L'utente ha rifiutato l'onboarding: segna il flag come completato
  /// senza mai mostrare il prompt di sistema — un rifiuto esplicito
  /// nell'app non deve comunque insistere con quello di iOS.
  Future<void> rifiutaOnboarding() async {
    await _preferences.setBool(_onboardingCompletatoKey, true);
    await _preferences.setBool(_permessoConcessoKey, false);
  }

  /// Ricalcola da zero i promemoria pendenti sulla base di [buste].
  ///
  /// Esce subito senza fare nulla — nemmeno [ReminderScheduler.cancelAll] —
  /// se l'onboarding non è stato ancora completato o se il permesso di
  /// sistema non è stato concesso: questo servizio non deve toccare
  /// notifiche né richiedere permessi impliciti finché l'utente non ha
  /// esplicitamente acconsentito.
  ///
  /// [reschedule] viene invocato da più punti della UI che possono
  /// sovrapporsi (chiamata iniziale all'avvio, spesso su un archivio ancora
  /// vuoto perché il caricamento dal DB è asincrono; `ref.listen`
  /// sull'archivio non appena quel caricamento completa; resume dell'app).
  /// `cancelAll()` e ciascuno `schedule()` sono round-trip veri su platform
  /// channel — punti di sospensione reali, non istantanei — quindi senza
  /// precauzioni una chiamata più vecchia rimasta a metà del proprio loop
  /// potrebbe proseguire *dopo* che una chiamata più recente ha già
  /// corretto lo stato, ri-schedulando notifiche calcolate su dati
  /// stantii (es. un ciclo che la chiamata più recente aveva invece deciso
  /// di saltare perché la busta è già in archivio).
  ///
  /// Per garantire che lo stato schedulato al termine sia sempre e solo
  /// quello dell'ULTIMA chiamata iniziata (mai un misto tra due chiamate):
  /// 1. un contatore di generazione ([_generazioneReschedule]), incrementato
  ///    a inizio di ogni chiamata, fa sì che una chiamata più vecchia smetta
  ///    di schedulare altro non appena si accorge — dopo un `await` — di
  ///    non essere più quella corrente;
  /// 2. le chiamate sono comunque serializzate tramite
  ///    [_rescheduleInCorso]: ogni chiamata attende che quella
  ///    immediatamente precedente abbia davvero terminato (fermata dal
  ///    punto 1, o completata normalmente) prima di eseguire il proprio
  ///    `cancelAll()`. Il punto 1 da solo non basta: l'unica chiamata
  ///    `schedule()` già "in volo" nell'esatto istante in cui la
  ///    generazione cambia completerebbe comunque — non è annullabile a
  ///    metà, [ReminderScheduler] non espone la cancellazione di un singolo
  ///    id — e lascerebbe quella notifica stantia nello stato finale.
  ///    Serializzando, il `cancelAll()` della chiamata più recente gira
  ///    sempre per ultimo, dopo che ogni residuo della chiamata precedente
  ///    si è già fermato, e ripulisce anche quell'eventuale notifica
  ///    residua prima di schedulare lo stato corretto.
  Future<void> reschedule(List<BustaPaga> buste) async {
    if (!_onboardingCompletato || !_permessoConcesso) {
      return;
    }

    final generazione = ++_generazioneReschedule;
    final precedente = _rescheduleInCorso;
    final completer = Completer<void>();
    _rescheduleInCorso = completer.future;

    try {
      // Aspetta che l'eventuale chiamata precedente abbia davvero smesso di
      // operare (vedi dartdoc sopra) prima di procedere.
      await precedente;
      // Nel frattempo potrebbe essere partita una generazione ancora più
      // recente (un'altra reschedule() mentre eravamo in attesa qui sopra):
      // in quel caso non c'è nulla da fare, vince chi è partito per ultimo.
      if (generazione != _generazioneReschedule) return;

      await scheduler.cancelAll();
      if (generazione != _generazioneReschedule) return;

      final periodiImportati = periodiMensiliImportati(buste);
      final date = promemoriaDaSchedulare(
        ora: _adesso(),
        periodiImportati: periodiImportati,
      );

      for (final quando in date) {
        if (generazione != _generazioneReschedule) return;
        await scheduler.schedule(
          id: _idPer(quando),
          quando: quando,
          titolo: _titolo,
          corpo: _corpoPer(quando),
        );
      }
    } finally {
      completer.complete();
    }
  }

  static const String _titolo = 'Nuova busta paga';

  /// Corpo della notifica: si riferisce sempre al mese TARGET del ciclo
  /// (M-1 rispetto al mese in cui scatta [quando], vedi [targetPerCiclo]),
  /// non al mese di [quando] stesso — è l'errore più facile da fare qui,
  /// perché la data di scheduling e il mese nominato nel testo sono sempre
  /// mesi diversi.
  String _corpoPer(DateTime quando) {
    final target = targetPerCiclo(quando);
    final periodoTarget = DateTime(target.anno, target.mese);
    final meseDisplay = periodoDisplayFor(
      periodo: periodoTarget,
      tipo: TipoBustaPaga.mensile,
    );
    return 'Importa la busta paga di $meseDisplay';
  }

  /// Id deterministico: la stessa data di notifica produce sempre lo stesso
  /// id, così ri-schedulare la stessa data (es. due `reschedule` successivi
  /// senza che nulla sia cambiato in archivio) non accumula duplicati.
  ///
  /// Il formato `anno*10000+mese*100+giorno` produce sempre un valore a più
  /// di 8 cifre (~20260101 per gennaio 2026, crescente con l'anno) ma pur
  /// sempre nell'ordine delle decine di milioni per qualunque anno
  /// ragionevole: [_idNotificaDiProva] sta deliberatamente ben al di fuori
  /// di questo spazio, vedi lì.
  int _idPer(DateTime quando) =>
      quando.year * 10000 + quando.month * 100 + quando.day;

  /// Id dedicato della notifica di prova (vedi
  /// [schedulaNotificaDiProvaPerDebug]), scelto ben al di fuori dello spazio
  /// degli id "reali" prodotti da [_idPer] (dell'ordine di
  /// `anno*10000+mese*100+giorno`, quindi sempre sotto 100 milioni per
  /// qualunque anno plausibile). Usare [_idPer] anche qui — come faceva
  /// prima questa correzione — fa collidere la notifica di prova con un
  /// promemoria reale dello stesso giorno se la si schedula il giorno 1, 8 o
  /// 15: `schedule()` con un id già esistente sovrascrive silenziosamente
  /// quella notifica, cancellando di fatto un promemoria vero pur di
  /// mostrarne uno di prova.
  static const int _idNotificaDiProva = 999999999;

  /// Gancio di verifica manuale, NON una feature: schedula una notifica di
  /// prova fra circa 60 secondi, così il comportamento si può osservare su
  /// device senza dover aspettare il vero 1°/8°/15° del mese. Guardato da
  /// [kDebugMode] per restare irraggiungibile in una build di release.
  Future<void> schedulaNotificaDiProvaPerDebug() async {
    if (!kDebugMode) {
      return;
    }
    final quando = _adesso().add(const Duration(seconds: 60));
    await scheduler.schedule(
      id: _idNotificaDiProva,
      quando: quando,
      titolo: '$_titolo (prova)',
      corpo: 'Notifica di prova per verifica manuale, non un promemoria '
          'reale.',
    );
  }
}
