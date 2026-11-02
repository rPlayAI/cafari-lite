// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    Log.write("connecting scene role=\(session.role.rawValue)")
    // Info.plist already binds each role to its delegate class, but returning a
    // named configuration here guarantees it even if iOS ignores the manifest
    // entry on a subsequent launch.
    let name = if session.role == cafariLiteCarPlayRole {
      "CarPlay"
    } else {
      "Phone"
    }
    return UISceneConfiguration(name: name, sessionRole: session.role)
  }
}
