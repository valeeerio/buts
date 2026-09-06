import 'dart:async';

import 'package:buts/services/home_widget_launch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('home_widget');
  const eventChannel = EventChannel('home_widget/updates');

  tearDown(() {
    pendingBustaDetailId.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, null);
  });

  /// Configura la risposta di `initiallyLaunchedFromHomeWidget` sul
  /// MethodChannel nativo del plugin `home_widget`, come farebbe il lato
  /// nativo restituendo l'URL memorizzato dal tap sul widget (o `null` se
  /// l'app non è stata aperta da un tap sul widget).
  void mockInitiallyLaunched(String? uriString) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'initiallyLaunchedFromHomeWidget') {
        return uriString;
      }
      return null;
    });
  }

  group('consumaHomeWidgetLaunch', () {
    test('URI `buts://busta/<id>` valorizza pendingBustaDetailId con l\'id',
        () async {
      mockInitiallyLaunched('buts://busta/abc123');

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, 'abc123');
    });

    test('non restituisce mai "busta" (che sarebbe l\'host dell\'URI)',
        () async {
      mockInitiallyLaunched('buts://busta/abc123');

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, isNot('busta'));
    });

    test('nessun lancio da widget (URI nullo) non valorizza il notifier',
        () async {
      mockInitiallyLaunched(null);

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, isNull);
    });

    test('URI senza path segments non valorizza il notifier', () async {
      mockInitiallyLaunched('buts://busta');

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, isNull);
    });

    test('URI con path segment vuoto non valorizza il notifier', () async {
      mockInitiallyLaunched('buts://busta/');

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, isNull);
    });

    test('scheme diverso da buts estrae comunque il primo path segment',
        () async {
      // La funzione di parsing non controlla lo scheme: si limita al primo
      // path segment, qualunque sia lo schema dell'URI ricevuto.
      mockInitiallyLaunched('altro://busta/xyz');

      await consumaHomeWidgetLaunch();

      expect(pendingBustaDetailId.value, 'xyz');
    });
  });

  group('registraAscoltoHomeWidgetClicked', () {
    test('un evento con URI `buts://busta/<id>` valorizza il notifier',
        () async {
      final controller = StreamController<String?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        _StreamHandlerFromController(controller),
      );

      final subscription = registraAscoltoHomeWidgetClicked();
      addTearDown(subscription.cancel);

      controller.add('buts://busta/def456');
      // Lascia processare l'evento asincrono dell'EventChannel.
      await Future<void>.delayed(Duration.zero);

      expect(pendingBustaDetailId.value, 'def456');

      await controller.close();
    });

    test('un evento con URI nullo non valorizza il notifier', () async {
      final controller = StreamController<String?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        _StreamHandlerFromController(controller),
      );

      final subscription = registraAscoltoHomeWidgetClicked();
      addTearDown(subscription.cancel);

      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(pendingBustaDetailId.value, isNull);

      await controller.close();
    });
  });
}

/// Adatta uno [StreamController] a [MockStreamHandler] per simulare
/// l'[EventChannel] nativo di `home_widget` (`home_widget/updates`) nei
/// test, senza toccare il plugin reale/un device.
class _StreamHandlerFromController extends MockStreamHandler {
  _StreamHandlerFromController(this._controller);

  final StreamController<String?> _controller;
  StreamSubscription<String?>? _subscription;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _subscription = _controller.stream.listen(
      events.success,
      onError: (Object error, StackTrace stackTrace) {
        events.error(code: 'error', message: error.toString());
      },
      onDone: events.endOfStream,
    );
  }

  @override
  void onCancel(Object? arguments) {
    _subscription?.cancel();
  }
}
