// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// Is the car moving? There is no CarPlay API that answers this, so the answer
// comes from location speed: above a walking pace for a few seconds counts as
// driving, and the car window blanks its video until the speed drops again.
//
// Deliberately conservative in one direction only. If location is refused or
// unavailable we report "not moving" rather than blocking playback outright,
// because a gate that cannot measure anything should not pretend it can. The
// switch that turns the gate off entirely lives in Settings.

import CoreLocation
import Foundation
import Observation

@Observable
final class CarGate: NSObject, CLLocationManagerDelegate {
  static let shared = CarGate()

  /// Posted when `isMoving` changes.
  static let stateChanged = Notification.Name("CafariLiteCarGateChanged")

  private(set) var isMoving = false
  @ObservationIgnored private let manager = CLLocationManager()
  @ObservationIgnored private var updatesTask: Task<Void, Never>?
  @ObservationIgnored private var running = false

  // About 11 km/h: faster than a pedestrian, slower than anything that counts
  // as driving, and above the noise floor of a stationary fix.
  private let movingSpeed: CLLocationSpeed = 3.0
  // Consecutive samples needed before the state flips, so one bad fix at a
  // traffic light does not stop the video.
  private let samplesToFlip = 3
  @ObservationIgnored private var agreeing = 0

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.distanceFilter = 10
    manager.pausesLocationUpdatesAutomatically = true
  }

  func start() {
    guard !running else { return }
    running = true
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    }
    updatesTask = Task { @MainActor [weak self] in
      do {
        for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
          guard !Task.isCancelled, let self else { break }
          if let speed = update.location?.speed, speed >= 0 {
            self.processSpeed(speed)
          }
        }
      } catch {
        Log.write("car gate: location error \(error.localizedDescription)")
      }
    }
    Log.write("car gate started, authorization=\(manager.authorizationStatus.rawValue)")
  }

  func stop() {
    guard running else { return }
    running = false
    updatesTask?.cancel()
    updatesTask = nil
    manager.stopUpdatingLocation()
    setMoving(false)
    Log.write("car gate stopped")
  }

  private func processSpeed(_ speed: CLLocationSpeed) {
    let moving = speed > movingSpeed
    if moving == isMoving {
      agreeing = 0
      return
    }
    agreeing += 1
    if agreeing >= samplesToFlip {
      agreeing = 0
      setMoving(moving)
    }
  }

  private func setMoving(_ moving: Bool) {
    guard moving != isMoving else { return }
    isMoving = moving
    Log.write("car gate: \(moving ? "moving" : "parked")")
    NotificationCenter.default.post(name: CarGate.stateChanged, object: nil)
  }

  func locationManager(_ manager: CLLocationManager,
                       didUpdateLocations locations: [CLLocation]) {
    guard let speed = locations.last?.speed, speed >= 0 else { return }
    processSpeed(speed)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // No fix is not evidence of driving. Leave the state alone.
    Log.write("car gate: location error \(error.localizedDescription)")
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Log.write("car gate: authorization now \(manager.authorizationStatus.rawValue)")
    if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
      setMoving(false)
    }
  }
}
