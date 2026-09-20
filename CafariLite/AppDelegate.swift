// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// MIT licensed. See README.md for what the car screen needs to work.

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // Two scenes: the phone's own window, and the car's. The car one arrives
    // only when the build is signed with the CarPlay video entitlement --
    // without it iOS never offers this role and the app is phone-only.
    Log.write("configuring scene role=\(session.role.rawValue)")
    if session.role == cafariLiteCarPlayRole {
      return UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
    }
    return UISceneConfiguration(name: "Phone", sessionRole: session.role)
  }
}
