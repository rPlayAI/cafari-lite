// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// The car window. A UIWindowScene on the head unit -- the plain window role,
// not a CarPlay template scene -- so anything UIKit can draw, including a web
// view, appears on the car screen and takes touches from it.

import UIKit

final class CarPlaySceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Log.write("car scene willConnect role=\(session.role.rawValue)")
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    // The car screen is the one being watched, so it gets no status line and
    // no chrome it does not need.
    window.rootViewController = BrowserViewController(showsStatus: false)
    window.makeKeyAndVisible()
    self.window = window
    NotificationCenter.default.post(name: .cafariLiteCarConnected, object: nil)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    window = nil
    NotificationCenter.default.post(name: .cafariLiteCarDisconnected, object: nil)
  }
}

// UIKit does not surface this scene role in Swift -- there is no
// UISceneSession.Role.carPlay -- so it is compared as the raw string, which is
// the same one the Info.plist scene manifest uses.
let cafariLiteCarPlayRole = UISceneSession.Role(rawValue: "UIWindowSceneSessionRoleCarPlay")

extension Notification.Name {
  static let cafariLiteCarConnected = Notification.Name("CafariLiteCarConnected")
  static let cafariLiteCarDisconnected = Notification.Name("CafariLiteCarDisconnected")
  /// Posted by the phone window when a sign-in finished, so the car window can
  /// reload and pick up the shared session.
  static let cafariLiteAccountChanged = Notification.Name("CafariLiteAccountChanged")
  /// Posted by the phone window to hand the page it is showing to the car.
  static let cafariLiteSendToCar = Notification.Name("CafariLiteSendToCar")
}
