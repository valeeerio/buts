import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Diventa non-`null` quando l'utente ha appena aperto/riportato in
/// foreground l'app toccando il widget iOS della home screen — a freddo
/// (`consumaHomeWidgetLaunch`, letto una volta in bootstrap) o a caldo
/// (`registraAscoltoHomeWidgetClicked`, stream attivo per tutta la sessione).
/// Pattern gemello di `pendingImportRequest` in
/// `lib/services/reminder_notifications.dart`, ma su un canale separato
/// (payload diverso: qui l'id della busta paga da aprire, non un semplice
/// flag booleano).
///
/// Formato URL scelto per il widget: `buts://busta/<id>` — l'id della busta
/// paga viene letto come `host` dell'URI (`Uri.parse('buts://busta/abc').host
/// == 'busta'`, NON `abc`: con questo schema l'unico segmento dopo `busta://`
/// è interpretato da `Uri` come host solo se preceduto da `//`; usando
/// `buts://busta/<id>` l'id finisce nel primo path segment, non nell'host).
/// Si legge quindi `uri.pathSegments.first`, non `uri.host` (che qui varrebbe
/// sempre `'busta'`, la parte statica dello schema).
final ValueNotifier<String?> pendingBustaDetailId = ValueNotifier<String?>(
  null,
);

/// Estrae l'id busta paga da un URI `buts://busta/<id>`, `null` se l'URI è
/// assente o non ha il segmento atteso.
String? _idDaUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first;
  return id.isEmpty ? null : id;
}

/// Legge se l'app è stata aperta a freddo (terminata) da un tap sul widget
/// della home screen e, in tal caso, valorizza [pendingBustaDetailId]. Va
/// chiamato una sola volta durante il bootstrap (`main()`), dopo
/// `HomeWidget.setAppGroupId`.
Future<void> consumaHomeWidgetLaunch() async {
  final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  final id = _idDaUri(uri);
  if (id != null) pendingBustaDetailId.value = id;
}

/// Registra l'ascolto del tap sul widget ad app già in esecuzione
/// (foreground/background, non cold start — quel caso è coperto da
/// [consumaHomeWidgetLaunch]). La subscription resta viva per tutta la
/// sessione app (nessun `cancel()`, stesso spirito di un listener globale):
/// va richiamata una sola volta durante il bootstrap, il chiamante può
/// ignorare la subscription restituita.
StreamSubscription<Uri?> registraAscoltoHomeWidgetClicked() {
  return HomeWidget.widgetClicked.listen((uri) {
    final id = _idDaUri(uri);
    if (id != null) pendingBustaDetailId.value = id;
  });
}
