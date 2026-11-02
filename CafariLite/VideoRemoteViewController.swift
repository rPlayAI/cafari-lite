// Phone controller. CarPlay Screen is the remote for a video on the car.
// Phone Screen keeps the picture on the phone. Fit cycles Fit, Fill, and Stretch.

import AVFoundation
import UIKit
import WebKit

struct ControllerClip {
  var title: String
  var posterURL: URL?
  var pageURL: URL?
  var duration: Double
  var assetLocalIdentifier: String? = nil

  init(title: String, posterURL: URL?, pageURL: URL?, duration: Double, assetLocalIdentifier: String? = nil) {
    self.title = title
    self.posterURL = posterURL
    self.pageURL = pageURL
    self.duration = duration
    self.assetLocalIdentifier = assetLocalIdentifier
  }

  init(link: SavedLink) {
    title = link.title
    posterURL = nil
    pageURL = link.url
    duration = ControllerClip.seconds(from: link.durationLabel)
    assetLocalIdentifier = nil
  }

  static func seconds(from label: String?) -> Double {
    guard let label else { return 0 }
    let parts = label.split(separator: ":").compactMap { Double($0) }
    if parts.count == 3 { return parts[0] * 3600 + parts[1] * 60 + parts[2] }
    if parts.count == 2 { return parts[0] * 60 + parts[1] }
    return parts.first ?? 0
  }
}

enum CarRemoteCommand {
  static let toggle = "toggle"
  static let seekBy = "seekBy"
  static let seekFraction = "seekFraction"
  static let fit = "fit"
  static let volume = "volume"
  static let dim = "dim"
  static let stop = "stop"

  static func post(_ command: String, _ extra: [String: Any] = [:]) {
    var info = extra
    info["command"] = command
    NotificationCenter.default.post(name: .cafariLiteCarRemoteCommand, object: nil, userInfo: info)
  }
}

extension Notification.Name {
  static let cafariLiteCarPlayback = Notification.Name("CafariLiteCarPlayback")
  static let cafariLiteCarRemoteCommand = Notification.Name("CafariLiteCarRemoteCommand")
  static let cafariLiteCarControllerClosed = Notification.Name("CafariLiteCarControllerClosed")
  static let cafariLiteOpenController = Notification.Name("CafariLiteOpenController")
  static let cafariLiteMiniPlayer = Notification.Name("CafariLiteMiniPlayer")
}

enum CarPlaybackKey {
  static func make(_ info: [AnyHashable: Any]) -> String {
    if let url = info["pageURL"] as? URL { return "url:" + url.absoluteString }
    if let title = info["title"] as? String, !title.isEmpty { return "title:" + title }
    return "video"
  }
}

private enum ControllerColor {
  static let blue = UIColor(red: 10 / 255, green: 132 / 255, blue: 255 / 255, alpha: 1)
  static let capsule = UIColor(red: 24 / 255, green: 24 / 255, blue: 26 / 255, alpha: 1)
  static let pill = UIColor(red: 24 / 255, green: 24 / 255, blue: 27 / 255, alpha: 1)
  static let zinc300 = UIColor(red: 212 / 255, green: 212 / 255, blue: 216 / 255, alpha: 1)
  static let zinc400 = UIColor(red: 161 / 255, green: 161 / 255, blue: 170 / 255, alpha: 1)
  static let zinc500 = UIColor(red: 113 / 255, green: 113 / 255, blue: 122 / 255, alpha: 1)
}

private final class PillSlider: UISlider {
  override func trackRect(forBounds bounds: CGRect) -> CGRect {
    let rect = super.trackRect(forBounds: bounds)
    return CGRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6)
  }

  static func thumbImage() -> UIImage {
    let size = CGSize(width: 24, height: 14)
    return UIGraphicsImageRenderer(size: size).image { _ in
      UIColor.white.setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7).fill()
    }
  }
}

final class VideoRemoteViewController: UIViewController {
  private var clips: [ControllerClip]
  private var index: Int
  private let pinnedKey: String?
  private var carTarget: Bool
  private var playing: Bool
  private var dimmed = false
  private var fitIndex = 0
  private let fitNames = ["Fit", "Fill", "Stretch"]
  private var knownDuration: Double = 0
  private var tracksQueue: Bool
  private let sendOnAppear: Bool
  private var phonePlayer: AVPlayer?
  private var phoneLayer: AVPlayerLayer?
  private var phoneWeb: WKWebView?
  private var didStartPhone = false
  private var advancedForURL: String?
  private var posterTask: Task<Void, Never>?

  private let playerView = UIView()
  private let posterView = UIImageView()
  private let nameLabel = UILabel()
  private let playButton = UIButton(type: .custom)
  private let slider = PillSlider()
  private let currentTimeLabel = UILabel()
  private let positionLabel = UILabel()
  private let remainingTimeLabel = UILabel()
  private let phoneButton = UIButton(type: .custom)
  private let carButton = UIButton(type: .custom)
  private let fitButton = UIButton(type: .custom)
  private let dimButton = UIButton(type: .custom)
  private let dimView = UIView()
  private let youtubeBadge = UIButton(type: .custom)
  private let durationBadge = UIView()
  private let durationLabel = UILabel()

  init(
    clips: [ControllerClip],
    index: Int,
    onCar: Bool,
    dismissKey: String? = nil,
    tracksQueue: Bool = false,
    sendOnAppear: Bool = false
  ) {
    self.clips = clips.isEmpty
      ? [ControllerClip(title: "Video", posterURL: nil, pageURL: nil, duration: 0)]
      : clips
    self.index = self.clips.indices.contains(index) ? index : 0
    self.carTarget = onCar
    self.playing = onCar
    self.pinnedKey = dismissKey
    self.tracksQueue = tracksQueue
    self.sendOnAppear = sendOnAppear
    super.init(nibName: nil, bundle: nil)
  }

  func replace(clips: [ControllerClip], index: Int, onCar: Bool, tracksQueue: Bool, send: Bool) {
    self.clips = clips.isEmpty
      ? [ControllerClip(title: "Video", posterURL: nil, pageURL: nil, duration: 0)]
      : clips
    self.index = self.clips.indices.contains(index) ? index : 0
    self.tracksQueue = tracksQueue
    carTarget = onCar
    playing = onCar
    stopPhonePicture()
    showCurrentClip()
    applyTargetStyles()
    if send || onCar {
      sendCurrentToCar()
    } else {
      playOnPhone()
    }
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    overrideUserInterfaceStyle = .dark
    buildInterface()
    showCurrentClip()
    NotificationCenter.default.addObserver(
      self, selector: #selector(carPlaybackUpdated(_:)),
      name: .cafariLiteCarPlayback, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(phoneItemEnded),
      name: .AVPlayerItemDidPlayToEndTime, object: nil)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didStartPhone else { return }
    didStartPhone = true
    if carTarget {
      if sendOnAppear { sendCurrentToCar() }
    } else {
      playOnPhone()
    }
  }

  private func collapse() {
    Log.write("remote collapse car=\(carTarget) key=\(controllerKey())")
    if Settings.miniPlayer {
      NotificationCenter.default.post(
        name: .cafariLiteMiniPlayer,
        object: nil,
        userInfo: [
          "title": nameLabel.text ?? "Video",
          "clips": clips,
          "index": index,
          "onCar": carTarget,
          "playing": playing,
          "tracksQueue": tracksQueue,
        ])
    }
    stopPhonePicture()
    NotificationCenter.default.post(
      name: .cafariLiteCarControllerClosed,
      object: nil,
      userInfo: ["suppress": carTarget, "key": controllerKey()])
    dismiss(animated: true)
  }

  private func togglePlay() {
    playing.toggle()
    setPlaySymbol()
    Log.write("remote toggle playing=\(playing) car=\(carTarget)")
    if carTarget {
      CarRemoteCommand.post(CarRemoteCommand.toggle)
      return
    }
    if let player = phonePlayer {
      playing ? player.play() : player.pause()
      return
    }
    Task { [weak phoneWeb] in
      _ = try? await phoneWeb?.evaluateJavaScript(
        "(function(){var v=document.querySelector('video');if(!v)return;if(v.paused){v.play()}else{v.pause()}})()")
    }
  }

  private func rewind10() { seek(by: -10) }
  private func forward10() { seek(by: 10) }

  @objc private func sliderMoved() {
    let fraction = Double(slider.value)
    positionLabel.text = formatDecimal(fraction)
    guard knownDuration > 0 else { return }
    currentTimeLabel.text = clock(fraction * knownDuration)
    remainingTimeLabel.text = clock(max(0, knownDuration - fraction * knownDuration))
    guard !carTarget else { return }
  }

  @objc private func sliderEnded() {
    Log.write("remote seek fraction=\(slider.value) car=\(carTarget)")
    guard carTarget else { return }
    CarRemoteCommand.post(CarRemoteCommand.seekFraction, ["fraction": Double(slider.value)])
  }

  private func choosePhone() {
    guard carTarget else {
      Log.write("remote target phone already")
      return
    }
    carTarget = false
    playing = true
    applyTargetStyles()
    setPlaySymbol()
    Log.write("remote target phone")
    CarRemoteCommand.post(CarRemoteCommand.stop)
    playOnPhone()
  }

  private func chooseCar() {
    guard !carTarget else {
      Log.write("remote target car already")
      return
    }
    stopPhonePicture()
    carTarget = true
    playing = true
    applyTargetStyles()
    setPlaySymbol()
    Log.write("remote target car")
    sendCurrentToCar()
  }

  private func previousItem() { step(-1) }
  private func nextItem() { step(1) }

  private func cycleFit() {
    fitIndex = (fitIndex + 1) % fitNames.count
    applyFitLabel()
    Log.write("remote fit \(fitNames[fitIndex]) car=\(carTarget)")
    guard carTarget else { return }
    CarRemoteCommand.post(CarRemoteCommand.fit, ["fit": fitNames[fitIndex]])
  }

  private func showVolume() {
    let alert = UIAlertController(title: "Volume", message: "\n\n", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Done", style: .cancel))
    present(alert, animated: true) {
      let slider = UISlider(frame: CGRect(x: 12, y: 50, width: 250, height: 32))
      slider.minimumValue = 0
      slider.maximumValue = 1
      slider.value = AVAudioSession.sharedInstance().outputVolume
      slider.addTarget(self, action: #selector(self.volumeChanged(_:)), for: .valueChanged)
      slider.addTarget(self, action: #selector(self.volumeEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
      alert.view.addSubview(slider)
    }
  }

  @objc private func volumeChanged(_ sender: UISlider) {
    guard carTarget else { return }
    CarRemoteCommand.post(CarRemoteCommand.volume, ["volume": Double(sender.value)])
  }

  @objc private func volumeEnded(_ sender: UISlider) {
    let volume = formatDecimal(Double(sender.value))
    Log.write("remote volume \(volume) car=\(carTarget)")
  }

  private func toggleDim() {
    dimmed.toggle()
    dimView.alpha = dimmed ? 0.55 : 0
    applyDimButton()
    Log.write("remote dim \(dimmed) car=\(carTarget)")
    guard carTarget else { return }
    CarRemoteCommand.post(CarRemoteCommand.dim, ["on": dimmed])
  }

  @objc private func carPlaybackUpdated(_ note: Notification) {
    guard carTarget else { return }
    let info = note.userInfo ?? [:]
    let ended = (info["ended"] as? NSNumber)?.boolValue ?? (info["ended"] as? Bool ?? false)
    if ended, Settings.autoplayNextVideo {
      let key = clips[index].pageURL?.absoluteString ?? "index:\(index)"
      if advancedForURL != key {
        advancedForURL = key
        step(1)
      }
      return
    }
    playing = (info["playing"] as? NSNumber)?.boolValue ?? (info["playing"] as? Bool ?? playing)
    if let title = info["title"] as? String {
      let cleaned = cleanedTitle(title)
      let looksLikeFile = cleaned.contains(".mp4") || cleaned.contains(".html") || cleaned.contains("playback")
      if cleaned != "Video", !looksLikeFile { nameLabel.text = cleaned }
    }
    if let url = info["pageURL"] as? URL, clips[index].pageURL == nil, !url.isFileURL {
      clips[index].pageURL = url
      updateSourceBadge()
      if posterView.image == nil { loadPoster() }
    }
    let current = (info["current"] as? NSNumber)?.doubleValue ?? 0
    let duration = (info["duration"] as? NSNumber)?.doubleValue ?? 0
    applyTimes(current: current, duration: duration)
    setPlaySymbol()
  }

  private func step(_ delta: Int) {
    let next = index + delta
    guard clips.indices.contains(next) else {
      Log.write("remote step \(delta) blocked index=\(index)")
      return
    }
    index = next
    if tracksQueue { PhonePlayback.shared.noteIndex(index) }
    Log.write("remote step \(delta) index=\(index) \(clips[index].title)")
    showCurrentClip()
    if carTarget { sendCurrentToCar() } else { playOnPhone() }
  }

  private func showCurrentClip() {
    let clip = clips[index]
    nameLabel.text = cleanedTitle(clip.title)
    knownDuration = clip.duration
    applyTimes(current: 0, duration: clip.duration)
    updateSourceBadge()
    loadPoster()
    playing = carTarget
    setPlaySymbol()
  }

  private func sendCurrentToCar() {
    Task { @MainActor [weak self] in
      guard let self, let url = await self.resolveCurrentURL() else {
        Log.write("remote send no url index=\(self?.index ?? -1)")
        return
      }
      let destination = BrowserViewController.playerURL(for: url) ?? url
      let title = self.clips[self.index].title
      Log.write("remote send \(url.absoluteString) -> \(destination.absoluteString)")
      NotificationCenter.default.post(
        name: .cafariLiteSendToCar,
        object: nil,
        userInfo: ["url": destination, "title": title])
      PhonePlayback.shared.remember(title: title, url: url)
    }
  }

  @objc private func phoneItemEnded(_ note: Notification) {
    guard !carTarget, Settings.autoplayNextVideo else { return }
    guard let item = note.object as? AVPlayerItem, item == phonePlayer?.currentItem else { return }
    step(1)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    phoneLayer?.frame = playerView.bounds
  }

  private func playOnPhone() {
    Task { @MainActor [weak self] in
      guard let self, !self.carTarget, let url = await self.resolveCurrentURL() else { return }
      self.stopPhonePicture()
      self.playing = true
      self.setPlaySymbol()
      if self.playsInPlayer(url) {
        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = self.playerView.bounds
        self.playerView.layer.insertSublayer(layer, above: self.posterView.layer)
        self.phonePlayer = player
        self.phoneLayer = layer
        player.play()
        return
      }
      let configuration = WKWebViewConfiguration()
      configuration.allowsInlineMediaPlayback = true
      configuration.mediaTypesRequiringUserActionForPlayback = []
      let web = WKWebView(frame: .zero, configuration: configuration)
      web.translatesAutoresizingMaskIntoConstraints = false
      web.isOpaque = false
      web.backgroundColor = .black
      self.playerView.insertSubview(web, aboveSubview: self.posterView)
      NSLayoutConstraint.activate([
        web.topAnchor.constraint(equalTo: self.playerView.topAnchor),
        web.leadingAnchor.constraint(equalTo: self.playerView.leadingAnchor),
        web.trailingAnchor.constraint(equalTo: self.playerView.trailingAnchor),
        web.bottomAnchor.constraint(equalTo: self.playerView.bottomAnchor),
      ])
      let destination = BrowserViewController.playerURL(for: url) ?? url
      web.load(URLRequest(url: destination))
      self.phoneWeb = web
    }
  }

  private func playsInPlayer(_ url: URL) -> Bool {
    if url.isFileURL { return true }
    let value = url.absoluteString.lowercased()
    return value.contains(".m3u8") || value.hasSuffix(".mp4") || value.hasSuffix(".mov")
  }

  private func stopPhonePicture() {
    phonePlayer?.pause()
    phonePlayer = nil
    phoneLayer?.removeFromSuperlayer()
    phoneLayer = nil
    phoneWeb?.removeFromSuperview()
    phoneWeb = nil
  }

  private func resolveCurrentURL() async -> URL? {
    let item = index
    if let url = clips[item].pageURL {
      return url
    }
    guard let id = clips[item].assetLocalIdentifier else {
      Log.write("remote no media index=\(item)")
      return nil
    }
    let url = await LibraryVideoExporter.export(localIdentifier: id)
    guard clips.indices.contains(item) else {
      return nil
    }
    if let url { clips[item].pageURL = url }
    guard index == item else {
      return nil
    }
    return url
  }

  private func seek(by delta: Double) {
    Log.write("remote seek delta=\(delta) car=\(carTarget)")
    if knownDuration > 0 {
      let next = min(knownDuration, max(0, Double(slider.value) * knownDuration + delta))
      applyTimes(current: next, duration: knownDuration)
    }
    guard carTarget else { return }
    CarRemoteCommand.post(CarRemoteCommand.seekBy, ["delta": delta])
  }

  private func loadPoster() {
    posterTask?.cancel()
    let currentIndex = index
    let clip = clips[currentIndex]
    posterView.image = nil
    let url = if let page = clip.pageURL, let id = BrowserViewController.youtubeID(for: page) {
      URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    } else {
      clip.posterURL
    }
    guard let url else { return }
    posterTask = Task { @MainActor [weak self] in
      guard let (data, _) = try? await URLSession.shared.data(from: url),
            !Task.isCancelled,
            let image = UIImage(data: data),
            let self,
            self.index == currentIndex else { return }
      self.posterView.image = image
    }
  }

  private func applyTimes(current: Double, duration: Double) {
    let safeCurrent = current.isFinite ? max(0, current) : 0
    let safeDuration = (duration.isFinite && duration > 0) ? duration : knownDuration
    if duration.isFinite, duration > 0 { knownDuration = duration }
    let fraction: Double
    if slider.isTracking {
      fraction = Double(slider.value)
    } else if safeDuration > 0 {
      fraction = min(1, safeCurrent / safeDuration)
      slider.setValue(Float(fraction), animated: false)
    } else {
      fraction = 0
      slider.setValue(0, animated: false)
    }
    let shownCurrent = slider.isTracking && safeDuration > 0 ? fraction * safeDuration : safeCurrent
    currentTimeLabel.text = clock(shownCurrent)
    remainingTimeLabel.text = safeDuration > 0 ? clock(max(0, safeDuration - shownCurrent)) : "0:00"
    positionLabel.text = formatDecimal(fraction)
    if safeDuration > 0.5 {
      durationLabel.text = clock(safeDuration)
      durationBadge.isHidden = false
    }
  }

  private func formatDecimal(_ value: Double) -> String {
    value.formatted(
      .number
        .grouping(.never)
        .precision(.fractionLength(2))
        .locale(Locale(identifier: "en_US_POSIX"))
    )
  }

  private func updateSourceBadge() {
    let page = clips[index].pageURL
    youtubeBadge.isHidden = page.flatMap { BrowserViewController.youtubeID(for: $0) } == nil
  }

  private func controllerKey() -> String {
    if let pinnedKey, !pinnedKey.isEmpty { return pinnedKey }
    if let url = clips[index].pageURL { return "url:" + url.absoluteString }
    return "title:" + (nameLabel.text ?? "Video")
  }

  private func cleanedTitle(_ raw: String) -> String {
    var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let suffix = " - YouTube"
    if title.hasSuffix(suffix) { title = String(title.dropLast(suffix.count)) }
    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Video" : title
  }

  private func clock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    return Duration.seconds(total).formatted(
      .time(pattern: total >= 3600 ? .hourMinuteSecond : .minuteSecond)
    )
  }

  private func buildInterface() {
    let close = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.collapse() })
    let chevron = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
    close.setImage(UIImage(systemName: "chevron.down", withConfiguration: chevron), for: .normal)
    close.tintColor = ControllerColor.zinc300
    close.accessibilityLabel = "Collapse"
    close.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(close)

    nameLabel.textColor = .white
    nameLabel.font = .systemFont(ofSize: 19, weight: .bold)
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(nameLabel)

    playerView.backgroundColor = .black
    playerView.layer.cornerRadius = 16
    playerView.layer.cornerCurve = .continuous
    playerView.layer.borderWidth = 1
    playerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
    playerView.clipsToBounds = true
    playerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(playerView)

    posterView.contentMode = .scaleAspectFill
    posterView.clipsToBounds = true
    posterView.translatesAutoresizingMaskIntoConstraints = false
    playerView.addSubview(posterView)

    dimView.backgroundColor = .black
    dimView.alpha = 0
    dimView.isUserInteractionEnabled = false
    dimView.translatesAutoresizingMaskIntoConstraints = false
    playerView.addSubview(dimView)
    playerView.addSubview(youtubeBadge)
    playerView.addSubview(durationBadge)
    configureYouTubeBadge()
    configureDurationBadge()

    let rewind = roundButton(symbol: "gobackward.10", pointSize: 22, diameter: 64, label: "Rewind 10 Seconds") { [weak self] in
      self?.rewind10()
    }
    configurePlayButton()
    let forward = roundButton(symbol: "goforward.10", pointSize: 22, diameter: 64, label: "Forward 10 Seconds") { [weak self] in
      self?.forward10()
    }
    let transport = UIStackView(arrangedSubviews: [rewind, playButton, forward])
    transport.axis = .horizontal
    transport.alignment = .center
    transport.spacing = 36

    let scrubberShell = UIView()
    scrubberShell.backgroundColor = ControllerColor.capsule
    scrubberShell.layer.cornerRadius = 24
    scrubberShell.layer.cornerCurve = .continuous
    scrubberShell.layer.borderWidth = 1
    scrubberShell.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
    layoutScrubber(in: scrubberShell)

    let targetShell = UIView()
    targetShell.backgroundColor = ControllerColor.pill
    targetShell.layer.cornerRadius = 24
    targetShell.layer.cornerCurve = .continuous
    targetShell.layer.borderWidth = 1
    targetShell.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
    targetShell.clipsToBounds = true
    phoneButton.addAction(UIAction { [weak self] _ in self?.choosePhone() }, for: .touchUpInside)
    carButton.addAction(UIAction { [weak self] _ in self?.chooseCar() }, for: .touchUpInside)
    let targets = UIStackView(arrangedSubviews: [phoneButton, carButton])
    targets.axis = .horizontal
    targets.spacing = 4
    targets.distribution = .fillEqually
    targets.translatesAutoresizingMaskIntoConstraints = false
    targetShell.addSubview(targets)
    applyTargetStyles()

    let previous = toolButton(symbol: "backward.end.fill", title: nil, label: "Previous Track") { [weak self] in
      self?.previousItem()
    }
    let next = toolButton(symbol: "forward.end.fill", title: nil, label: "Next Track") { [weak self] in
      self?.nextItem()
    }
    fitButton.accessibilityLabel = "Video Fit Mode"
    fitButton.addAction(UIAction { [weak self] _ in self?.cycleFit() }, for: .touchUpInside)
    applyFitLabel()
    let volume = toolButton(symbol: "speaker.wave.2.fill", title: nil, label: "Volume") { [weak self] in
      self?.showVolume()
    }
    dimButton.accessibilityLabel = "Dim Mode"
    dimButton.addAction(UIAction { [weak self] _ in self?.toggleDim() }, for: .touchUpInside)
    applyDimButton()
    let tools = UIStackView(arrangedSubviews: [previous, next, fitButton, volume, dimButton])
    tools.axis = .horizontal
    tools.spacing = 8
    tools.distribution = .fillEqually

    let controls = UIStackView(arrangedSubviews: [transport, scrubberShell, targetShell, tools])
    controls.axis = .vertical
    controls.alignment = .center
    controls.spacing = 12
    controls.setCustomSpacing(20, after: transport)
    controls.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(controls)

    let stage = UILayoutGuide()
    view.addLayoutGuide(stage)
    let cardCenter = playerView.centerYAnchor.constraint(equalTo: stage.centerYAnchor)
    cardCenter.priority = .defaultHigh

    NSLayoutConstraint.activate([
      close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      close.widthAnchor.constraint(equalToConstant: 32),
      close.heightAnchor.constraint(equalToConstant: 32),
      nameLabel.centerYAnchor.constraint(equalTo: close.centerYAnchor),
      nameLabel.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 8),
      nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

      controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
      scrubberShell.widthAnchor.constraint(equalTo: controls.widthAnchor),
      targetShell.widthAnchor.constraint(equalTo: controls.widthAnchor),
      tools.widthAnchor.constraint(equalTo: controls.widthAnchor),
      targetShell.heightAnchor.constraint(equalToConstant: 48),
      tools.heightAnchor.constraint(equalToConstant: 48),
      targets.topAnchor.constraint(equalTo: targetShell.topAnchor, constant: 4),
      targets.bottomAnchor.constraint(equalTo: targetShell.bottomAnchor, constant: -4),
      targets.leadingAnchor.constraint(equalTo: targetShell.leadingAnchor, constant: 4),
      targets.trailingAnchor.constraint(equalTo: targetShell.trailingAnchor, constant: -4),

      stage.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 8),
      stage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stage.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -8),
      playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9 / 16),
      cardCenter,
      playerView.topAnchor.constraint(greaterThanOrEqualTo: stage.topAnchor),
      playerView.bottomAnchor.constraint(lessThanOrEqualTo: stage.bottomAnchor),

      posterView.topAnchor.constraint(equalTo: playerView.topAnchor),
      posterView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
      posterView.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
      posterView.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
      dimView.topAnchor.constraint(equalTo: playerView.topAnchor),
      dimView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
      dimView.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
      dimView.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
    ])
  }

  private func layoutScrubber(in shell: UIView) {
    let thumb = PillSlider.thumbImage()
    slider.minimumValue = 0
    slider.maximumValue = 1
    slider.minimumTrackTintColor = ControllerColor.blue
    slider.maximumTrackTintColor = UIColor(white: 0.32, alpha: 1)
    slider.setThumbImage(thumb, for: .normal)
    slider.setThumbImage(thumb, for: .highlighted)
    slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
    slider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    slider.translatesAutoresizingMaskIntoConstraints = false
    func style(_ label: UILabel, color: UIColor, alignment: NSTextAlignment) {
      label.font = .monospacedDigitSystemFont(ofSize: 12, weight: alignment == .center ? .medium : .semibold)
      label.textColor = color
      label.textAlignment = alignment
    }
    style(currentTimeLabel, color: ControllerColor.zinc400, alignment: .left)
    style(positionLabel, color: ControllerColor.zinc500, alignment: .center)
    style(remainingTimeLabel, color: ControllerColor.zinc400, alignment: .right)
    let times = UIStackView(arrangedSubviews: [currentTimeLabel, positionLabel, remainingTimeLabel])
    times.axis = .horizontal
    times.distribution = .fillEqually
    times.translatesAutoresizingMaskIntoConstraints = false
    shell.addSubview(slider)
    shell.addSubview(times)
    NSLayoutConstraint.activate([
      slider.topAnchor.constraint(equalTo: shell.topAnchor, constant: 16),
      slider.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16),
      slider.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -16),
      slider.heightAnchor.constraint(equalToConstant: 24),
      times.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 8),
      times.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16),
      times.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -16),
      times.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -14),
    ])
  }

  private func configureYouTubeBadge() {
    var config = UIButton.Configuration.plain()
    config.title = "YOUTUBE"
    config.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold))
    config.imagePadding = 3
    config.baseForegroundColor = .white
    config.background.backgroundColor = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 0.92)
    config.background.cornerRadius = 9
    config.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 10, weight: .bold)
      return out
    }
    youtubeBadge.configuration = config
    youtubeBadge.isUserInteractionEnabled = false
    youtubeBadge.isHidden = true
    youtubeBadge.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      youtubeBadge.topAnchor.constraint(equalTo: playerView.topAnchor, constant: 10),
      youtubeBadge.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
    ])
  }

  private func configureDurationBadge() {
    durationBadge.backgroundColor = UIColor.black.withAlphaComponent(0.80)
    durationBadge.layer.cornerRadius = 6
    durationBadge.layer.borderWidth = 1
    durationBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
    durationBadge.isHidden = true
    durationBadge.translatesAutoresizingMaskIntoConstraints = false
    let dot = UIView()
    dot.backgroundColor = UIColor(red: 239 / 255, green: 68 / 255, blue: 68 / 255, alpha: 1)
    dot.layer.cornerRadius = 3
    dot.translatesAutoresizingMaskIntoConstraints = false
    durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    durationLabel.textColor = .white
    durationLabel.translatesAutoresizingMaskIntoConstraints = false
    durationBadge.addSubview(dot)
    durationBadge.addSubview(durationLabel)
    NSLayoutConstraint.activate([
      durationBadge.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),
      durationBadge.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -10),
      dot.leadingAnchor.constraint(equalTo: durationBadge.leadingAnchor, constant: 8),
      dot.centerYAnchor.constraint(equalTo: durationBadge.centerYAnchor),
      dot.widthAnchor.constraint(equalToConstant: 6),
      dot.heightAnchor.constraint(equalToConstant: 6),
      durationLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 5),
      durationLabel.trailingAnchor.constraint(equalTo: durationBadge.trailingAnchor, constant: -8),
      durationLabel.topAnchor.constraint(equalTo: durationBadge.topAnchor, constant: 3),
      durationLabel.bottomAnchor.constraint(equalTo: durationBadge.bottomAnchor, constant: -3),
    ])
  }

  private func configurePlayButton() {
    var config = UIButton.Configuration.plain()
    config.baseForegroundColor = .white
    config.background.backgroundColor = UIColor.white.withAlphaComponent(0.10)
    config.background.cornerRadius = 40
    config.background.strokeColor = UIColor.white.withAlphaComponent(0.20)
    config.background.strokeWidth = 1
    playButton.configuration = config
    playButton.accessibilityLabel = "Play or Pause"
    playButton.addAction(UIAction { [weak self] _ in self?.togglePlay() }, for: .touchUpInside)
    playButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      playButton.widthAnchor.constraint(equalToConstant: 80),
      playButton.heightAnchor.constraint(equalToConstant: 80),
    ])
    setPlaySymbol()
  }

  private func setPlaySymbol() {
    var config = playButton.configuration ?? UIButton.Configuration.plain()
    let name = playing ? "pause.fill" : "play.fill"
    config.image = UIImage(
      systemName: name,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: playing ? 28 : 32, weight: .medium))
    config.baseForegroundColor = .white
    playButton.configuration = config
  }

  private func applyTargetStyles() {
    styleTarget(phoneButton, title: "Phone Screen", on: !carTarget)
    styleTarget(carButton, title: "CarPlay Screen", on: carTarget)
  }

  private func styleTarget(_ button: UIButton, title: String, on: Bool) {
    var config = UIButton.Configuration.plain()
    config.title = title
    config.baseForegroundColor = on ? .white : ControllerColor.zinc400
    config.background.backgroundColor = on ? ControllerColor.blue : .clear
    config.background.cornerRadius = 20
    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 12, weight: .semibold)
      return out
    }
    if on {
      config.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
      config.imagePadding = 4
      config.imagePlacement = .leading
    }
    button.configuration = config
    button.accessibilityLabel = title
  }

  private func applyFitLabel() {
    fitButton.configuration = toolConfiguration(symbol: "rectangle", title: fitNames[fitIndex])
  }

  private func applyDimButton() {
    dimButton.configuration = toolConfiguration(symbol: "moon.fill", title: nil, selected: dimmed)
  }

  private func toolButton(symbol: String, title: String?, label: String, handler: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .custom, primaryAction: UIAction { _ in handler() })
    button.configuration = toolConfiguration(symbol: symbol, title: title)
    button.accessibilityLabel = label
    return button
  }

  private func toolConfiguration(symbol: String, title: String?, selected: Bool = false) -> UIButton.Configuration {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(
      systemName: symbol,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: title == nil ? 16 : 13, weight: .semibold))
    config.imagePlacement = .leading
    config.imagePadding = title == nil ? 0 : 4
    config.title = title
    config.baseForegroundColor = ControllerColor.zinc300
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 12, weight: .semibold)
      return out
    }
    config.background.backgroundColor = selected ? UIColor.white.withAlphaComponent(0.16) : ControllerColor.capsule
    config.background.cornerRadius = 16
    config.background.strokeColor = UIColor.white.withAlphaComponent(0.05)
    config.background.strokeWidth = 1
    config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
    return config
  }

  private func roundButton(symbol: String, pointSize: CGFloat, diameter: CGFloat, label: String, handler: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .custom, primaryAction: UIAction { _ in handler() })
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium))
    config.baseForegroundColor = UIColor(white: 0.93, alpha: 1)
    config.background.backgroundColor = UIColor.white.withAlphaComponent(0.10)
    config.background.cornerRadius = diameter / 2
    config.background.strokeColor = UIColor.white.withAlphaComponent(0.10)
    config.background.strokeWidth = 1
    button.configuration = config
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: diameter),
      button.heightAnchor.constraint(equalToConstant: diameter),
    ])
    return button
  }
}
