import UIKit
import Flutter
import FirebaseCore
import firebase_core  // try adding this import if available

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Manually register plugins if needed
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
