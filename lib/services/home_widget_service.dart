import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/busta_paga.dart';
import '../services/reminder_schedule.dart';
import '../utils/busta_paga_formatting.dart';

/// Chiave sotto cui viene scritto lo snapshot JSON consumato dal widget
/// WidgetKit lato iOS (`BustaPagaWidgetExtension`, vedi `ios/
/// BustaPagaWidgetExtension/`). Stesso valore letto da
/// `BustaPagaWidget.swift` — se cambia qui va cambiato anche lì.
const String homeWidgetSnapshotKey = 'buta_widget_snapshot';

/// Aggiorna il widget iOS della home screen con un unico snapshot JSON
/// (`homeWidgetSnapshotKey`) derivato dall'archivio buste paga corrente.
///
/// Nessuna logica di business duplicata: la "busta paga più recente" usa lo
/// stesso identico criterio di `ultimaBustaPagaProvider`
/// (`lib/providers/buste_paga_provider.dart`, non importato direttamente per
/// non introdurre una dipendenza da Riverpod in questo servizio plain-Dart —
/// le tre righe di filtro/ordinamento sono duplicate qui deliberatamente),
/// e il "mese da importare" riusa le funzioni pure di
/// `lib/services/reminder_schedule.dart` (`periodiMensiliImportati`,
/// `targetPerCiclo`), senza ricalcolare quella logica.
class HomeWidgetService {
  const HomeWidgetService({
    this.appGroupId = 'group.com.buts.buts',
    this.iOSWidgetName = 'BustaPagaWidget',
  });

  final String appGroupId;
  final String iOSWidgetName;

  Future<void> aggiorna(List<BustaPaga> buste) async {
    final mensili =
        buste.where((b) => b.tipo == TipoBustaPaga.mensile).toList();
    final ultima = mensili.isEmpty
        ? null
        : (mensili..sort((a, b) => b.periodo.compareTo(a.periodo))).first;

    final target = targetPerCiclo(DateTime.now());
    final importati = periodiMensiliImportati(buste);
    final daImportare = !importati.contains(target);

    final snapshot = <String, Object?>{
      'bustaId': ultima?.id,
      'mese': ultima == null ? null : periodoLabel(ultima),
      'netto': ultima == null ? null : formatEuroConSegno(ultima.netto),
      'statoConfermato':
          ultima?.statoVerifica == StatoVerificaBustaPaga.confermato,
      'ferieResidue':
          ultima == null ? null : formatNumber(ultima.ferieResidue),
      'exFestivitaResidue':
          ultima == null ? null : formatNumber(ultima.exFestivitaResidue),
      'daImportare': daImportare,
    };

    // L'App Group è impostato una sola volta in `main()` (bootstrap, prima di
    // `runApp`) tramite `HomeWidget.setAppGroupId`: qui si passa comunque
    // `appGroupId` esplicitamente ad ogni chiamata (parametro `appGroupId` di
    // `saveWidgetData`), così questo servizio non dipende da uno stato
    // statico globale già impostato altrove per funzionare correttamente.
    await HomeWidget.saveWidgetData<String>(
      homeWidgetSnapshotKey,
      jsonEncode(snapshot),
      appGroupId: appGroupId,
    );
    await HomeWidget.updateWidget(iOSName: iOSWidgetName);
  }
}
