// Saved rows on the Links page, and the mode the three mode buttons share.
// The car window is still the web view. A send posts cafariLiteSendToCar.

import UIKit

enum PlayMode: String {
  case stream
  case webOnCar
  case mirror
}

struct SavedLink: Codable, Equatable {
  var id: UUID
  var title: String
  var urlString: String
  var starred: Bool
  var thumbStyle: String? = nil
  var durationLabel: String? = nil

  var url: URL? { URL(string: urlString) }

  /// The five rows on the Stitch Links screen.
  static let stitchRows: [SavedLink] = [
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000001")!,
      title: "How to use my CarPlay Video app",
      urlString: "https://m.youtube.com/results?search_query=How+to+use+my+CarPlay+Video+app",
      starred: true, thumbStyle: "video", durationLabel: "04:12"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0002-4000-8000-000000000002")!,
      title: "KT #789 - TIM BUTTERLY + KIRK FOX",
      urlString: "https://m.youtube.com/results?search_query=KT+789+Tim+Butterly+Kirk+Fox",
      starred: true, thumbStyle: "kt789", durationLabel: "1:20"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0003-4000-8000-000000000003")!,
      title: "KT #780 - FLUFFY - HARLAND WILLIAMS",
      urlString: "https://m.youtube.com/results?search_query=KT+780+Fluffy+Harland+Williams",
      starred: true, thumbStyle: "kt780", durationLabel: "2:05"),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0004-4000-8000-000000000004")!,
      title: "Test stream (Apple HLS sample)",
      urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
      starred: true, thumbStyle: "hls", durationLabel: nil),
    SavedLink(
      id: UUID(uuidString: "A1A1A1A1-0005-4000-8000-000000000005")!,
      title: "YouTube Web Dashboard",
      urlString: "https://m.youtube.com",
      starred: true, thumbStyle: "web", durationLabel: nil),
  ]
}

extension Notification.Name {
  static let cafariLiteLinksChanged = Notification.Name("CafariLiteLinksChanged")
  static let cafariLitePlayModeChanged = Notification.Name("CafariLitePlayModeChanged")
}

final class SavedLinkStore {
  static let shared = SavedLinkStore()
  private(set) var links: [SavedLink] = []
  private let fileURL: URL

  private init() {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("saved-links.json")
    if let data = try? Data(contentsOf: fileURL),
       let decoded = try? JSONDecoder().decode([SavedLink].self, from: data) {
      links = decoded
    }
    let previousStarterIDs: Set<UUID> = [
      UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000001")!,
      UUID(uuidString: "A1A1A1A1-0002-4000-8000-000000000002")!,
      UUID(uuidString: "A1A1A1A1-0003-4000-8000-000000000003")!,
      UUID(uuidString: "A1A1A1A1-0004-4000-8000-000000000004")!,
      UUID(uuidString: "A1A1A1A1-0005-4000-8000-000000000005")!
    ]
    if links.isEmpty || links.contains(where: { previousStarterIDs.contains($0.id) }) {
      links = SavedLink.stitchRows
      if let data = try? JSONEncoder().encode(links) {
        try? data.write(to: fileURL, options: .atomic)
      }
    }
  }

  func add(url: URL, title: String? = nil) {
    let name = title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolved = (name?.isEmpty == false) ? name! : (url.host ?? url.absoluteString)
    links.insert(SavedLink(id: UUID(), title: resolved, urlString: url.absoluteString, starred: false), at: 0)
    save()
  }

  func toggleStar(_ id: UUID) {
    guard let index = links.firstIndex(where: { $0.id == id }) else { return }
    links[index].starred.toggle()
    save()
  }

  private func save() {
    if let data = try? JSONEncoder().encode(links) {
      try? data.write(to: fileURL, options: .atomic)
    }
    NotificationCenter.default.post(name: .cafariLiteLinksChanged, object: nil)
  }
}

/// The item the CarPlay pill sends, and the mode the three Links buttons share.
final class PhonePlayback {
  static let shared = PhonePlayback()

  var mode: PlayMode = .webOnCar {
    didSet { NotificationCenter.default.post(name: .cafariLitePlayModeChanged, object: nil) }
  }

  private(set) var currentTitle: String?
  private(set) var currentURL: URL?
  private(set) var queue: [SavedLink] = []
  private(set) var queueIndex: Int = 0

  func remember(title: String, url: URL?) {
    currentTitle = title
    currentURL = url
  }

  func setQueue(_ links: [SavedLink], index: Int) {
    queue = links
    queueIndex = index
  }
}

enum LinkURL {
  static func normalize(_ raw: String) -> URL? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil { return url }
    return URL(string: "https://\(trimmed)")
  }
}

enum CarSender {
  static var carIsConnected: Bool {
    UIApplication.shared.connectedScenes.contains { scene in
      scene.session.role == cafariLiteCarPlayRole
    }
  }

  /// Web on car and Mirror hand the page across.
  static func sendPage(_ url: URL) {
    Log.write("sendPage \(url.absoluteString)")
    NotificationCenter.default.post(
      name: .cafariLiteSendToCar, object: nil, userInfo: ["url": url])
  }

  /// Stream hands the bare player when the link is a YouTube video.
  static func sendDirect(_ url: URL) {
    let destination = BrowserViewController.playerURL(for: url) ?? url
    Log.write("sendDirect \(url.absoluteString) -> \(destination.absoluteString)")
    NotificationCenter.default.post(
      name: .cafariLiteSendToCar, object: nil, userInfo: ["url": destination])
  }

  @discardableResult
  static func sendCurrentItem() -> Bool {
    guard let url = PhonePlayback.shared.currentURL else { return false }
    if PhonePlayback.shared.mode == .stream {
      sendDirect(url)
    } else {
      sendPage(url)
    }
    return true
  }
}
