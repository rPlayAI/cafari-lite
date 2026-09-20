// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// A log we can read off the device. The system console needs the phone
// attached over USB, so anything that only reproduces in the car is invisible
// there; this writes to Documents/lite.log, which comes back with
//   xcrun devicectl device copy from --domain-type appDataContainer ...

import Foundation

enum Log {
  private static let url: URL? = {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    return dir?.appendingPathComponent("lite.log")
  }()
  private static let queue = DispatchQueue(label: "lite.log")
  private static var started = false

  static func write(_ message: String) {
    queue.async {
      guard let url else { return }
      if !started {
        started = true
        try? "".write(to: url, atomically: true, encoding: .utf8)
      }
      let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
      if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
      } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
      }
    }
  }
}
