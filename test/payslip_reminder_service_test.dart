import 'dart:async';

import 'package:buts/models/busta_paga.dart';
import 'package:buts/services/payslip_reminder_service.dart';
import 'package:buts/services/reminder_notifications.dart';
import 'package:buts/services/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake di [ReminderScheduler]: registra le chiamate ricevute invece di
/// toccare il plugin reale/un device, cosi' [PayslipReminderService] si
/// verifica senza simulatore.
class _FakeReminderScheduler implements ReminderScheduler {
  int cancelAllCallCount = 0;
  int requestPermissionCallCount = 0;
  bool permessoDaConcedere = true;
  final List<
      ({
        int id,
        DateTime quando,
        String titolo,
        String corpo,
      })> scheduledCalls = [];

  /// Stato "attualmente pianificato", a differenza di [scheduledCalls] (un
  /// registro storico di tutte le chiamate, mai ripulito): [cancelAll]
  /// svuota questa mappa, [schedule] la ripopola — simula quindi lo stato
  /// osservabile lato sistema operativo (dove `cancelAll` cancella
  /// davvero ogni notifica pendente, incluse quelle schedulate da una
  /// `reschedule()` precedente), usato dal test sulla race condition per
  /// verificare cosa resterebbe effettivamente pianificato al termine.
  final Map<int, DateTime> live = {};

  /// Se impostato, la prossima chiamata a [schedule] resta sospesa finché
  /// il test non completa questo [Completer] — usato per "congelare" una
  /// `reschedule()` a metà del proprio loop e simulare la sovrapposizione
  /// con una `reschedule()` successiva. Consumato (rimesso a `null`) alla
  /// prima chiamata che lo trova impostato, così non blocca anche le
  /// chiamate seguenti.
  Completer<void>? pausaProssimaSchedule;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return permessoDaConcedere;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
    live.clear();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime quando,
    required String titolo,
    required String corpo,
  }) async {
    final pausa = pausaProssimaSchedule;
    if (pausa != null) {
      pausaProssimaSchedule = null;
      await pausa.future;
    }
    scheduledCalls.add((id: id, quando: quando, titolo: titolo, corpo: corpo));
    live[id] = quando;
  }

  @override
  Future<void> consumaLaunchDetails() async {}
}

/// Costruisce una [BustaPaga] minimale, valorizzando solo [periodo]/[tipo] e
/// riempiendo gli altri required con valori neutri — stesso pattern di
/// `test/reminder_schedule_test.dart`.
BustaPaga _busta({
  required DateTime periodo,
  TipoBustaPaga tipo = TipoBustaPaga.mensile,
}) {
  return BustaPaga(
    id: 'periodo-${periodo.year}-${periodo.month}-$tipo',
    periodo: periodo,
    lordo: 0,
    netto: 0,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 0,
    ferieGodute: 0,
    ferieResidue: 0,
    rolMaturati: 0,
    rolGoduti: 0,
    rolResidui: 0,
    permessiGoduti: 0,
    oreLavorate: 0,
    tipo: tipo,
  );
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  group('reschedule', () {
    test(
        'onboarding non completato: nessuna chiamata al scheduler, nemmeno '
        'cancelAll', () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.reschedule(const []);

      expect(scheduler.cancelAllCallCount, 0);
      expect(scheduler.scheduledCalls, isEmpty);
    });

    test('permesso negato: nessuna chiamata al scheduler', () async {
      final scheduler = _FakeReminderScheduler()..permessoDaConcedere = false;
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.completaOnboarding();
      // completaOnboarding chiama gia' requestPermission una volta: azzera
      // quel contatore per isolare le chiamate fatte da reschedule
      // (cancelAllCallCount e' gia' 0 a questo punto: completaOnboarding
      // non tocca mai cancelAll).
      scheduler.requestPermissionCallCount = 0;

      await service.reschedule(const []);

      expect(scheduler.cancelAllCallCount, 0);
      expect(scheduler.scheduledCalls, isEmpty);
    });

    test(
        'caso felice: cancelAll una volta, poi uno schedule per ogni data '
        'attesa', () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.completaOnboarding();

      await service.reschedule(const []);

      expect(scheduler.cancelAllCallCount, 1);

      final attese = promemoriaDaSchedulare(
        ora: DateTime(2026, 8, 1, 0, 0),
        periodiImportati: const {},
      );
      expect(scheduler.scheduledCalls.length, attese.length);
      expect(
        scheduler.scheduledCalls.map((c) => c.quando).toList(),
        equals(attese),
      );
    });

    test(
        'il corpo della notifica nomina il mese precedente a quello schedulato',
        () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.completaOnboarding();
      await service.reschedule(const []);

      final primaNotifica = scheduler.scheduledCalls
          .firstWhere((c) => c.quando == DateTime(2026, 8, 1, 9));

      // La notifica scatta ad agosto ma si riferisce alla busta di luglio
      // (mese precedente), non ad agosto stesso.
      expect(primaNotifica.corpo, 'Importa la busta paga di Luglio 2026');
      expect(primaNotifica.titolo, isNotEmpty);
    });

    test(
        'id deterministici e coerenti con la formula anno*10000+mese*100+giorno',
        () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.completaOnboarding();
      await service.reschedule(const []);

      for (final call in scheduler.scheduledCalls) {
        final atteso = call.quando.year * 10000 +
            call.quando.month * 100 +
            call.quando.day;
        expect(call.id, atteso);
      }

      final idPrimaNotifica = scheduler.scheduledCalls
          .firstWhere((c) => c.quando == DateTime(2026, 8, 1, 9))
          .id;
      expect(idPrimaNotifica, 2026 * 10000 + 8 * 100 + 1);

      // Ri-schedulare la stessa identica situazione produce gli stessi id
      // (deterministico), non id nuovi ad ogni chiamata.
      scheduler.scheduledCalls.clear();
      await service.reschedule(const []);
      final idPrimaNotificaRipetuta = scheduler.scheduledCalls
          .firstWhere((c) => c.quando == DateTime(2026, 8, 1, 9))
          .id;
      expect(idPrimaNotificaRipetuta, idPrimaNotifica);
    });

    test(
        'una busta paga gia\' importata per il mese target: il ciclo '
        'corrispondente non produce notifiche', () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );

      await service.completaOnboarding();

      // Ciclo di agosto punta a luglio 2026: se luglio e' gia' in archivio,
      // nessuna delle tre date del ciclo di agosto va schedulata.
      final buste = [_busta(periodo: DateTime(2026, 7, 28))];

      await service.reschedule(buste);

      final cicloAgosto = scheduler.scheduledCalls
          .where((c) => c.quando.year == 2026 && c.quando.month == 8);
      expect(cicloAgosto, isEmpty);

      // I cicli successivi (settembre, ottobre) restano.
      expect(scheduler.scheduledCalls, isNotEmpty);
    });

    test(
        'due reschedule sovrapposte: lo stato finale e\' solo quello '
        'dell\'ultima chiamata iniziata, mai un misto tra le due', () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
        adesso: () => DateTime(2026, 8, 1, 0, 0),
      );
      await service.completaOnboarding();

      // Riproduce lo scenario reale: la chiamata iniziale (initState) parte
      // su un archivio ancora vuoto e resta sospesa a meta' del proprio
      // loop (bloccata sulla primissima schedule(), come farebbe un vero
      // round-trip su platform channel non ancora tornato) mentre la
      // correzione (il ref.listen che riceve l'archivio reale appena
      // caricato) parte e finisce per intero.
      final pausa = Completer<void>();
      scheduler.pausaProssimaSchedule = pausa;
      final rescheduleIniziale = service.reschedule(const []);

      // Lascia che la chiamata iniziale raggiunga davvero il punto di
      // sospensione prima di far partire la seconda, altrimenti il
      // completer verrebbe assegnato ma mai atteso.
      await Future<void>.delayed(Duration.zero);

      // La busta di luglio e' gia' in archivio: la correzione salta il
      // ciclo di agosto (quello per cui la chiamata iniziale, su dati
      // stantii, sta invece ancora cercando di schedulare la prima data).
      final buste = [_busta(periodo: DateTime(2026, 7, 28))];
      final rescheduleCorretta = service.reschedule(buste);

      // Sblocca la chiamata iniziale: deve accorgersi di essere stata
      // superata e fermarsi senza schedulare il resto delle sue nove date,
      // invece di proseguire sopra la correzione.
      pausa.complete();
      await Future.wait([rescheduleIniziale, rescheduleCorretta]);

      final atteseCorrette = promemoriaDaSchedulare(
        ora: DateTime(2026, 8, 1, 0, 0),
        periodiImportati: periodiMensiliImportati(buste),
      );

      expect(
        scheduler.live.values.toSet(),
        equals(atteseCorrette.toSet()),
      );
      // La prima data della chiamata iniziale (1 agosto, ciclo che la
      // chiamata corretta ha invece saltato perche' luglio e' gia' in
      // archivio) non deve sopravvivere nello stato finale.
      expect(
        scheduler.live.values.contains(DateTime(2026, 8, 1, 9)),
        isFalse,
      );
    });
  });

  group('onboarding', () {
    test(
        'completaOnboarding con permesso concesso: flag persistiti e '
        'onboardingDaMostrare diventa false', () async {
      final scheduler = _FakeReminderScheduler()..permessoDaConcedere = true;
      final preferences = await _preferences();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: preferences,
      );

      expect(service.onboardingDaMostrare, isTrue);

      final concesso = await service.completaOnboarding();

      expect(concesso, isTrue);
      expect(service.onboardingDaMostrare, isFalse);
      expect(scheduler.requestPermissionCallCount, 1);
      expect(
        preferences.getBool('payslip_reminder_onboarding_completato'),
        isTrue,
      );
      expect(
        preferences.getBool('payslip_reminder_permesso_concesso'),
        isTrue,
      );
    });

    test(
        'completaOnboarding con permesso negato: flag persistiti e '
        'onboardingDaMostrare diventa comunque false', () async {
      final scheduler = _FakeReminderScheduler()..permessoDaConcedere = false;
      final preferences = await _preferences();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: preferences,
      );

      final concesso = await service.completaOnboarding();

      expect(concesso, isFalse);
      expect(service.onboardingDaMostrare, isFalse);
      expect(
        preferences.getBool('payslip_reminder_permesso_concesso'),
        isFalse,
      );
    });

    test(
        'rifiutaOnboarding: onboardingDaMostrare false, nessuna richiesta '
        'di permesso al fake', () async {
      final scheduler = _FakeReminderScheduler();
      final service = PayslipReminderService(
        scheduler: scheduler,
        preferences: await _preferences(),
      );

      await service.rifiutaOnboarding();

      expect(service.onboardingDaMostrare, isFalse);
      expect(scheduler.requestPermissionCallCount, 0);
    });
  });
}
