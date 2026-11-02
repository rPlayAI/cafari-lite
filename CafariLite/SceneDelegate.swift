// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// The phone window. Its own browser, independent of the car's, so the two
// screens never fight over one web view (a WKWebView lives in one window).

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Log.write("phone scene willConnect role=\(session.role.rawValue)")
    guard let windowScene = scene as? UIWindowScene else {
      Log.write("phone scene is NOT a UIWindowScene: \(type(of: scene))")
      return
    }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = PhoneShellController()
    window.makeKeyAndVisible()
    self.window = window
    Log.write("phone window up \(window.bounds.size) root=Library dock=visible")
  }
}
