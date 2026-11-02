// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// Documents/lite.log. A launch appends a session header, then appends lines,
// so the previous session stays in the file. Each line is also mirrored to
// the unified log as "CafariLite ...", which shows while the phone is on the
// cable. Pull the file with:
//   xcrun devicectl device copy from --domain-type appDataContainer ...

import Foundation
import os

enum SessionCounts {
  private static var playbackErrors = 0
  private static var carActions = 0
  private static var playerFaults = 0

  static func playbackError() { playbackErrors += 1 }
  static func carAction() { carActions += 1 }
  static func playerFault() { playerFaults += 1 }

  static var playbackErrorCount: Int { playbackErrors }
  static var carActionCount: Int { carActions }
  static var playerFaultCount: Int { playerFaults }
}

enum LogSlice {
  case playbackErrors
  case carActions
  case player

  init?(title: String) {
    switch title {
    case "Playback errors": self = .playbackErrors
    case "Car Action Log": self = .carActions
    case "Player Bug Catcher": self = .player
    default: return nil
    }
  }

  func includes(_ line: String) -> Bool {
    if line.contains("---- session") { return false }
    switch self {
    case .playbackErrors:
      return line.contains("FAILED")
        || line.contains("car js error")
        || line.contains("car js no web view")
        || line.contains("location error")
        || line.contains("is NOT a UIWindowScene")
    case .carActions:
      return line.contains("car scene")
        || line.contains("car home")
        || line.contains("car browser")
        || line.contains("car remote")
        || line.contains("car gate")
        || line.contains("car layout")
        || line.contains("car web")
        || line.contains("sendPage ")
        || line.contains("sendDirect ")
        || line.contains("sendToCar ")
        || line.contains("controller ")
    case .player:
      return line.contains("remote ")
        || line.contains("car remote")
        || line.contains("car js")
        || line.contains("phone player")
        || line.contains("controller ")
        || line.contains("car web video")
    }
  }
}

enum Log {
  private static let url: URL = URL.documentsDirectory.appending(path: "lite.log")
  private static let logger = Logger(subsystem: "com.cafarilite.app", category: "general")
  private static let queue = DispatchQueue(label: "lite.log")
  private static var started = false

  static func write(_ message: String) {
    queue.async {
      let stamp = Date().formatted(date: .omitted, time: .standard)
      let line = "\(stamp) \(message)"
      if !started {
        started = true
        let when = Date().formatted(date: .numeric, time: .standard)
        let header = "---- session \(when) ----"
        logger.info("CafariLite \(header, privacy: .public)")
        append(header + "\n", to: url)
      }
      logger.info("CafariLite \(line, privacy: .public)")
      append(line + "\n", to: url)
    }
  }

  static func allLines() -> [String] {
    queue.sync {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
      return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
  }

  static func lines(for slice: LogSlice) -> [String] {
    allLines().filter(slice.includes)
  }

  private static func append(_ text: String, to url: URL) {
    if FileManager.default.fileExists(atPath: url.path()),
       let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: Data(text.utf8))
    } else {
      try? text.write(to: url, atomically: true, encoding: .utf8)
    }
  }
}
