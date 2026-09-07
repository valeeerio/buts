import 'dart:convert';

import 'package:buts/models/busta_paga.dart';
import 'package:buts/services/home_widget_service.dart';
import 'package:buts/utils/busta_paga_formatting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Costruisce una [BustaPaga] minimale, valorizzando solo i campi rilevanti
/// per questi test e riempiendo gli altri required con valori neutri —
/// stesso pattern di `test/reminder_schedule_test.dart`.
BustaPaga _busta({
  required DateTime periodo,
  TipoBustaPaga tipo = TipoBustaPaga.mensile,
  String? id,
  double netto = 0,
  double ferieResidue = 0,
  double exFestivitaResidue = 0,
  StatoVerificaBustaPaga statoVerifica = StatoVerificaBustaPaga.confermato,
}) {
  return BustaPaga(
    id: id ?? 'busta-${periodo.year}-${periodo.month}-$tipo',
    periodo: periodo,
    lordo: 0,
    netto: netto,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 0,
    ferieGodute: 0,
    ferieResidue: ferieResidue,
    rolMaturati: 0,
    rolGoduti: 0,
    rolResidui: 0,
    permessiGoduti: 0,
    exFestivitaResidue: exFestivitaResidue,
    oreLavorate: 0,
    tipo: tipo,
    statoVerifica: statoVerifica,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');

  late List<MethodCall> chiamate;

  setUpAll(() async {
    // `periodoLabel` (usata internamente da `HomeWidgetService.aggiorna`)
    // formatta il mese in italiano via `intl`: senza inizializzare i dati di
    // locale la formattazione lancia un'eccezione, stesso setup di
    // `payslip_reminder_service_test.dart`.
    await initializeDateFormatting('it_IT');
  });

  setUp(() {
    chiamate = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      chiamate.add(call);
      switch (call.method) {
        case 'saveWidgetData':
          return true;
        case 'updateWidget':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Decodifica lo snapshot JSON passato all'ultima chiamata
  /// `saveWidgetData` registrata in [chiamate].
  Map<String, dynamic> ultimoSnapshot() {
    final saveCall = chiamate.lastWhere((c) => c.method == 'saveWidgetData');
    final data = (saveCall.arguments as Map)['data'] as String;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  group('HomeWidgetService.aggiorna', () {
    const service = HomeWidgetService();

    test('nessuna busta mensile produce uno snapshot vuoto coerente',
        () async {
      await service.aggiorna(const []);

      final snapshot = ultimoSnapshot();
      expect(snapshot['bustaId'], isNull);
      expect(snapshot['mese'], isNull);
      expect(snapshot['netto'], isNull);
      expect(snapshot['statoConfermato'], isFalse);
      expect(snapshot['ferieResidue'], isNull);
      expect(snapshot['exFestivitaResidue'], isNull);
    });

    test('chiama saveWidgetData e poi updateWidget con i parametri attesi',
        () async {
      await service.aggiorna(const []);

      expect(chiamate.map((c) => c.method).toList(), [
        'saveWidgetData',
        'updateWidget',
      ]);

      final saveArgs = chiamate.first.arguments as Map;
      expect(saveArgs['id'], homeWidgetSnapshotKey);
      expect(saveArgs['appGroupId'], 'group.com.buts.buts');

      final updateArgs = chiamate.last.arguments as Map;
      expect(updateArgs['ios'], 'BustaPagaWidget');
    });

    test(
        'usa la busta mensile più recente come "ultima", scartando quelle '
        'più vecchie', () async {
      final buste = [
        _busta(periodo: DateTime(2026, 5, 27), netto: 100),
        _busta(periodo: DateTime(2026, 7, 28), netto: 300),
        _busta(periodo: DateTime(2026, 6, 27), netto: 200),
      ];

      await service.aggiorna(buste);

      final snapshot = ultimoSnapshot();
      expect(snapshot['netto'], formatEuroConSegno(300));
      expect(snapshot['mese'], contains('2026'));
    });

    test(
        'una 13a/14a più recente della mensile non diventa "ultima busta"',
        () async {
      final buste = [
        _busta(
          periodo: DateTime(2026, 3, 27),
          netto: 100,
          id: 'mensile-marzo',
        ),
        _busta(
          periodo: DateTime(2026, 7, 20),
          tipo: TipoBustaPaga.tredicesima,
          netto: 9999,
          id: 'tredicesima',
        ),
      ];

      await service.aggiorna(buste);

      final snapshot = ultimoSnapshot();
      // L'ultima busta resta quella mensile di marzo, non la tredicesima.
      expect(snapshot['bustaId'], 'mensile-marzo');
      expect(snapshot['netto'], formatEuroConSegno(100));
    });

    test('propaga statoConfermato/ferieResidue/exFestivitaResidue',
        () async {
      final buste = [
        _busta(
          periodo: DateTime(2026, 7, 28),
          ferieResidue: 12.5,
          exFestivitaResidue: 3,
          statoVerifica: StatoVerificaBustaPaga.daConfermare,
        ),
      ];

      await service.aggiorna(buste);

      final snapshot = ultimoSnapshot();
      expect(snapshot['statoConfermato'], isFalse);
      expect(snapshot['ferieResidue'], formatNumber(12.5));
      expect(snapshot['exFestivitaResidue'], formatNumber(3));
    });
  });
}
