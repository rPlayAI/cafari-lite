// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// Switches kept in UserDefaults so both windows and both launches agree.

import Foundation

@propertyWrapper
struct UserDefault<Value> {
  let key: String
  let defaultValue: Value
  var storage: UserDefaults = .standard

  var wrappedValue: Value {
    get { storage.object(forKey: key) as? Value ?? defaultValue }
    set { storage.set(newValue, forKey: key) }
  }
}

enum Settings {
  /// Render the car page at the head unit's own pixel resolution rather than
  /// at the point size iOS hands the window. See BrowserViewController's
  /// viewDidLayoutSubviews for what that means in practice.
  @UserDefault(key: "carNativeResolution", defaultValue: true)
  static var carNativeResolution: Bool

  /// A green outline around the car page, to see exactly what area it covers
  /// on the head unit.
  @UserDefault(key: "debugBorder", defaultValue: false)
  static var debugBorder: Bool

  /// Keep the car page clear of the CarPlay sidebar. The head unit reports it
  /// as a safe-area inset, so honouring the safe area is what avoids it.
  @UserDefault(key: "avoidSidebar", defaultValue: true)
  static var avoidSidebar: Bool

  /// Only let the car screen play while the vehicle is stopped. On by
  /// default; turning it off removes the gate entirely.
  @UserDefault(key: "playOnlyWhenParked", defaultValue: true)
  static var playOnlyWhenParked: Bool

  @UserDefault(key: "appearanceIndex", defaultValue: 0)
  static var appearanceIndex: Int

  @UserDefault(key: "ambientLightSync", defaultValue: true)
  static var ambientLightSync: Bool

  @UserDefault(key: "autoPlayYouTubeQueue", defaultValue: true)
  static var autoPlayYouTubeQueue: Bool

  @UserDefault(key: "wallpaperShortcuts", defaultValue: true)
  static var wallpaperShortcuts: Bool

  /// Advance to the next saved row or library clip when the current video ends.
  @UserDefault(key: "autoplayNextVideo", defaultValue: true)
  static var autoplayNextVideo: Bool

  /// Collapsing the remote leaves a bar on the phone. The car keeps playing.
  @UserDefault(key: "miniPlayer", defaultValue: true)
  static var miniPlayer: Bool

  /// Ask YouTube's player to show captions.
  @UserDefault(key: "showCaptions", defaultValue: false)
  static var showCaptions: Bool

  /// Hide the car toolbar and use the whole panel, including the sidebar inset.
  @UserDefault(key: "fullScreenCar", defaultValue: false)
  static var fullScreenCar: Bool
}

extension Notification.Name {
  static let cafariLiteSettingsChanged = Notification.Name("CafariLiteSettingsChanged")
}
