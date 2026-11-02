// Copies a Photos video into Caches so the car web view can play it.
// The Photos URL itself is not readable from WKWebView.

import AVFoundation
import Photos

actor LibraryVideoExporter {
  static let shared = LibraryVideoExporter()

  private var inFlight: [String: Task<URL?, Never>] = [:]

  static func export(localIdentifier: String) async -> URL? {
    await shared.export(localIdentifier: localIdentifier)
  }

  func export(localIdentifier: String) async -> URL? {
    let destination = Self.fileURL(for: localIdentifier)
    if FileManager.default.fileExists(atPath: destination.path()) {
      return destination
    }
    if let existing = inFlight[localIdentifier] {
      return await existing.value
    }
    let task = Task<URL?, Never> {
      let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
      guard let asset = result.firstObject, asset.mediaType == .video else {
        return nil
      }
      guard let avAsset = await Self.requestAVAsset(for: asset) else {
        return nil
      }
      if let exported = await Self.export(avAsset, to: destination, preset: AVAssetExportPresetPassthrough) {
        return exported
      }
      return await Self.export(avAsset, to: destination, preset: AVAssetExportPreset1280x720)
    }
    inFlight[localIdentifier] = task
    let output = await task.value
    inFlight[localIdentifier] = nil
    return output
  }

  private static func requestAVAsset(for asset: PHAsset) async -> AVAsset? {
    await withCheckedContinuation { continuation in
      let options = PHVideoRequestOptions()
      options.isNetworkAccessAllowed = true
      options.deliveryMode = .highQualityFormat
      PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
        continuation.resume(returning: avAsset)
      }
    }
  }

  private static func export(_ asset: AVAsset, to destination: URL, preset: String) async -> URL? {
    try? FileManager.default.removeItem(at: destination)
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      return nil
    }
    if #available(iOS 18.0, *) {
      do {
        try await session.export(to: destination, as: .mp4)
        return destination
      } catch {
        try? FileManager.default.removeItem(at: destination)
        if preset != AVAssetExportPresetPassthrough {
          Log.write("library export failed \(error.localizedDescription)")
        }
        return nil
      }
    } else {
      session.outputURL = destination
      session.outputFileType = .mp4
      await session.export()
      if session.status == .completed {
        return destination
      }
      try? FileManager.default.removeItem(at: destination)
      if preset != AVAssetExportPresetPassthrough {
        Log.write("library export failed \(session.error?.localizedDescription ?? preset)")
      }
      return nil
    }
  }

  private static func fileURL(for identifier: String) -> URL {
    let folder = URL.cachesDirectory.appending(path: "library-videos", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let safe = identifier.replacingOccurrences(of: "/", with: "-")
    return folder.appending(path: "\(safe).mp4")
  }
}
