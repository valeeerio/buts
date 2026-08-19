import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications (verificato leggendo il sorgente installato,
    // 22.3.0) non imposta mai da sé questo delegate su iOS — lo fa solo sulla
    // sua implementazione macOS. Senza questa riga, `didReceiveNotificationResponse`
    // (tap sulla notifica ad app già in esecuzione, vedi
    // `LocalNotificationsScheduler.init` in reminder_notifications.dart) non
    // verrebbe mai inoltrato al plugin. `FlutterAppDelegate` conforma già a
    // `UNUserNotificationCenterDelegate` e inoltra le callback ai plugin
    // registrati come application delegate (incluso questo), quindi qui basta
    // assegnare `self`.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
