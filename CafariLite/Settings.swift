// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// Two switches, kept in UserDefaults so both windows and both launches agree.

import Foundation

enum Settings {
  private static let defaults = UserDefaults.standard

  /// Render the car page at the head unit's own pixel resolution rather than
  /// at the point size iOS hands the window. See BrowserViewController's
  /// viewDidLayoutSubviews for what that means in practice.
  static var carNativeResolution: Bool {
    get {
      if defaults.object(forKey: "carNativeResolution") == nil { return true }
      return defaults.bool(forKey: "carNativeResolution")
    }
    set { defaults.set(newValue, forKey: "carNativeResolution") }
  }

  /// A green outline around the car page, to see exactly what area it covers
  /// on the head unit.
  static var debugBorder: Bool {
    get { defaults.bool(forKey: "debugBorder") }
    set { defaults.set(newValue, forKey: "debugBorder") }
  }

  /// Keep the car page clear of the CarPlay sidebar. The head unit reports it
  /// as a safe-area inset, so honouring the safe area is what avoids it.
  static var avoidSidebar: Bool {
    get {
      if defaults.object(forKey: "avoidSidebar") == nil { return true }
      return defaults.bool(forKey: "avoidSidebar")
    }
    set { defaults.set(newValue, forKey: "avoidSidebar") }
  }

  /// Only let the car screen play while the vehicle is stopped. On by
  /// default; turning it off removes the gate entirely.
  static var playOnlyWhenParked: Bool {
    get {
      if defaults.object(forKey: "playOnlyWhenParked") == nil { return true }
      return defaults.bool(forKey: "playOnlyWhenParked")
    }
    set { defaults.set(newValue, forKey: "playOnlyWhenParked") }
  }

  static var appearanceIndex: Int {
    get { defaults.object(forKey: "appearanceIndex") as? Int ?? 0 }
    set { defaults.set(newValue, forKey: "appearanceIndex") }
  }

  static var ambientLightSync: Bool {
    get { defaults.object(forKey: "ambientLightSync") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "ambientLightSync") }
  }

  static var autoPlayYouTubeQueue: Bool {
    get { defaults.object(forKey: "autoPlayYouTubeQueue") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "autoPlayYouTubeQueue") }
  }

  static var wallpaperShortcuts: Bool {
    get { defaults.object(forKey: "wallpaperShortcuts") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "wallpaperShortcuts") }
  }
}

extension Notification.Name {
  static let cafariLiteSettingsChanged = Notification.Name("CafariLiteSettingsChanged")
}
