import UIKit
import Flutter
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Set the delegate to self
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ADD THIS METHOD: This is the missing piece for foreground notifications
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {

    // This tells iOS to show the banner, play the sound, and update the badge
    // EVEN IF the app is in the foreground.
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .list, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
}