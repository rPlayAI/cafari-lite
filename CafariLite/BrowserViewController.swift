// Cafari Lite -- the small, open part of Cafari: a web view on the CarPlay
// screen, and nothing else. The full app, which also casts to Chromecast and
// AirPlay receivers, and its sideload builds, are at
// https://github.com/rPlayAI/cafari-public
//
// The whole app: a web view pointed at YouTube's mobile site, plus the few
// controls a passenger needs. Nothing private, nothing clever -- the trick is
// entirely in which scene this view controller happens to be living in.

import UIKit
import WebKit

final class BrowserViewController: UIViewController, WKNavigationDelegate {
  private let home: URL
  private let showsStatus: Bool
  private var webView: WKWebView!
  private var statusLabel: UILabel?
  // Whether the last page was a sign-in page, so finishing on YouTube after it
  // means an account just changed. See webView(_:didFinish:).
  private var wasSigningIn = false
  private var loggedCarLayout = false
  private var drivingCover: UIView?
  private var loggedCarPlaying = false
  private let carDim = UIView()
  private let playbackRelay = CarPlaybackRelay()

  init(showsStatus: Bool, initialURL: URL? = nil) {
    self.home = initialURL ?? URL(string: "https://m.youtube.com")!
    self.showsStatus = showsStatus
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func viewDidLoad() {
    super.viewDidLoad()
    Log.write("viewDidLoad showsStatus=\(showsStatus)")
    // The car window sits behind video, so black. The phone window gets a
    // colour no system background ever is: in dark mode systemBackground is
    // itself black, so it could not distinguish "our view is up and the page
    // did not draw" from "our window is not on screen", which was the point.
    view.backgroundColor = showsStatus
      ? UIColor(red: 0.07, green: 0.11, blue: 0.22, alpha: 1)
      : .black

    let configuration = WKWebViewConfiguration()
    // Play in place rather than handing off to the full-screen system player,
    // which on the car screen would put the video where we cannot see it.
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    if !showsStatus {
      let hook = WKUserScript(source: Self.playbackHook, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
      configuration.userContentController.addUserScript(hook)
      playbackRelay.owner = self
      configuration.userContentController.add(playbackRelay, name: "cafariPlayback")
    }

    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = true
    webView.scrollView.contentInsetAdjustmentBehavior = .always
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)

    let bar = makeToolbar()
    bar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bar)

    // On the phone the toolbar sits above the page. On the car it floats over
    // it: the head unit window measured 467x263 points, and a 56 point bar was
    // taking a fifth of the height away from the video.
    if showsStatus {
      NSLayoutConstraint.activate([
        bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        webView.topAnchor.constraint(equalTo: bar.bottomAnchor),
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    } else {
      bar.backgroundColor = UIColor.black.withAlphaComponent(0.45)
      bar.layer.cornerRadius = 10
      bar.clipsToBounds = true
      // No constraints on the web view here: viewDidLayoutSubviews sizes it.
      webView.translatesAutoresizingMaskIntoConstraints = true
      NSLayoutConstraint.activate([
        bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
        bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 4),
      ])
    }

    Log.write("loading \(home.absoluteString)")
    webView.load(URLRequest(url: home))

    if showsStatus {
      NotificationCenter.default.addObserver(
        self, selector: #selector(carStateChanged),
        name: .cafariLiteCarConnected, object: nil)
      NotificationCenter.default.addObserver(
        self, selector: #selector(carStateChanged),
        name: .cafariLiteCarDisconnected, object: nil)
    } else {
      // The car window cannot be typed into -- CarPlay offers no keyboard for
      // a web view -- so signing in happens on the phone. Both windows share
      // the app's cookie store, so the car only needs to reload to pick the
      // session up.
      NotificationCenter.default.addObserver(
        self, selector: #selector(accountChanged),
        name: .cafariLiteAccountChanged, object: nil)
      NotificationCenter.default.addObserver(
        self, selector: #selector(sendToCarRequested(_:)),
        name: .cafariLiteSendToCar, object: nil)
      NotificationCenter.default.addObserver(
        self, selector: #selector(settingsChanged),
        name: .cafariLiteSettingsChanged, object: nil)
      NotificationCenter.default.addObserver(
        self, selector: #selector(drivingStateChanged),
        name: CarGate.stateChanged, object: nil)
      NotificationCenter.default.addObserver(
        self, selector: #selector(remoteCommand(_:)),
        name: .cafariLiteCarRemoteCommand, object: nil)
      if Settings.playOnlyWhenParked { CarGate.shared.start() }
      installCarDim()
    }
  }

  deinit {
    guard !showsStatus, let webView else { return }
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "cafariPlayback")
  }

  private func makeToolbar() -> UIView {
    let container = UIStackView()
    container.axis = .horizontal
    container.alignment = .center
    container.spacing = 16
    container.isLayoutMarginsRelativeArrangement = true
    container.layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
    container.backgroundColor = .secondarySystemBackground

    func button(_ systemName: String, _ action: Selector) -> UIButton {
      let b = UIButton(type: .system)
      b.setImage(UIImage(systemName: systemName), for: .normal)
      b.addTarget(self, action: action, for: .touchUpInside)
      return b
    }

    container.addArrangedSubview(button("chevron.backward", #selector(goBack)))
    container.addArrangedSubview(button("chevron.forward", #selector(goForward)))
    container.addArrangedSubview(button("house", #selector(goHome)))
    container.addArrangedSubview(button("arrow.clockwise", #selector(reload)))
    if showsStatus {
      // Hand whatever the phone is showing to the car window. The car cannot
      // be typed into, so finding something is the phone's job and this is how
      // the result gets across.
      let cast = button("tv", #selector(sendToCar))
      cast.accessibilityLabel = "Send to car screen"
      container.addArrangedSubview(cast)
      let gear = button("gearshape", #selector(showSettings))
      gear.accessibilityLabel = "Settings"
      container.addArrangedSubview(gear)
    }

    if showsStatus {
      let label = UILabel()
      label.font = .preferredFont(forTextStyle: .footnote)
      label.textColor = .secondaryLabel
      label.textAlignment = .right
      label.adjustsFontSizeToFitWidth = true
      statusLabel = label
      container.addArrangedSubview(label)
      updateStatus()
    }
    return container
  }

  @objc private func goBack() { webView.goBack() }
  @objc private func goForward() { webView.goForward() }
  @objc private func reload() { webView.reload() }
  @objc private func goHome() { webView.load(URLRequest(url: home)) }

  @objc private func showSettings() {
    let sheet = UIAlertController(title: "Car screen", message: nil,
                                  preferredStyle: .actionSheet)
    let nativeOn = Settings.carNativeResolution
    sheet.addAction(UIAlertAction(
      title: (nativeOn ? "✓ " : "") + "Use the car's own resolution",
      style: .default) { _ in
        Settings.carNativeResolution = !nativeOn
        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
      })
    let borderOn = Settings.debugBorder
    sheet.addAction(UIAlertAction(
      title: (borderOn ? "✓ " : "") + "Show the debug border",
      style: .default) { _ in
        Settings.debugBorder = !borderOn
        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
      })
    let parkedOn = Settings.playOnlyWhenParked
    sheet.addAction(UIAlertAction(
      title: (parkedOn ? "✓ " : "") + "Play only when parked",
      style: .default) { _ in
        Settings.playOnlyWhenParked = !parkedOn
        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
      })
    let sidebarOn = Settings.avoidSidebar
    sheet.addAction(UIAlertAction(
      title: (sidebarOn ? "✓ " : "") + "Keep clear of the sidebar",
      style: .default) { _ in
        Settings.avoidSidebar = !sidebarOn
        NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
      })
    sheet.addAction(UIAlertAction(title: "Done", style: .cancel))
    sheet.popoverPresentationController?.sourceView = view
    sheet.popoverPresentationController?.sourceRect =
      CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1)
    present(sheet, animated: true)
  }

  @objc private func sendToCar() {
    guard let url = webView.url else { return }
    // Cafari sends the car a VIDEO, not a page. Do the same: when the phone is
    // on a YouTube video, hand the car the bare player for that video instead
    // of the whole site. The car window then holds nothing but the picture, at
    // the panel's own size, with no page layout to crop it.
    let destination = Self.playerURL(for: url) ?? url
    Log.write("sendToCar \(url.absoluteString) -> \(destination.absoluteString)")
    NotificationCenter.default.post(
      name: .cafariLiteSendToCar, object: nil, userInfo: ["url": destination])
    let connected = UIApplication.shared.connectedScenes.contains { scene in
      scene.session.role == cafariLiteCarPlayRole
    }
    statusLabel?.text = connected ? "Sent to the car" : "No car screen to send to"
  }

  /// Watch, short-link, shorts, and embed forms. Nil when this is not YouTube.
  static func youtubeID(for url: URL) -> String? {
    guard let host = url.host?.lowercased() else { return nil }
    let parts = url.pathComponents
    if host.contains("youtu.be") {
      let id = parts.dropFirst().first
      return (id?.isEmpty == false) ? id : nil
    }
    guard host.contains("youtube.com") else { return nil }
    if url.path.hasPrefix("/shorts/") || url.path.hasPrefix("/embed/") {
      let id = parts.dropFirst(2).first
      return (id?.isEmpty == false) ? id : nil
    }
    guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
          let id = items.first(where: { $0.name == "v" })?.value, !id.isEmpty else { return nil }
    return id
  }

  /// The bare player for a YouTube link, or nil if this is not one.
  static func playerURL(for url: URL) -> URL? {
    guard let id = youtubeID(for: url) else { return nil }
    // playsinline keeps it in our window rather than handing it to the system
    // player, which on the car screen would put it somewhere we cannot see.
    return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1&rel=0")
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
               withError error: Error) {
    showLoadFailure(error)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
               withError error: Error) {
    showLoadFailure(error)
  }

  private func showLoadFailure(_ error: Error) {
    Log.write("load FAILED: \(error.localizedDescription)")
    // A page that does not load used to leave an empty view and no clue.
    let label = UILabel()
    label.text = error.localizedDescription
    label.textColor = .white
    label.numberOfLines = 0
    label.textAlignment = .center
    label.font = .preferredFont(forTextStyle: .body)
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
    ])
  }

  @objc private func carStateChanged() { updateStatus() }

  @objc private func settingsChanged() {
    loggedCarLayout = false
    view.setNeedsLayout()
    if Settings.playOnlyWhenParked {
      CarGate.shared.start()
    } else {
      CarGate.shared.stop()
    }
    drivingStateChanged()
  }

  @objc private func drivingStateChanged() {
    let blocked = Settings.playOnlyWhenParked && CarGate.shared.isMoving
    blocked ? showDrivingCover() : hideDrivingCover()
  }

  private func showDrivingCover() {
    // Stop the sound as well as the picture: a video the driver can hear is
    // still a video the driver is following.
    webView.evaluateJavaScript(
      "document.querySelectorAll('video').forEach(v => v.pause())", completionHandler: nil)
    guard drivingCover == nil else { return }
    let cover = UIView()
    cover.backgroundColor = .black
    cover.translatesAutoresizingMaskIntoConstraints = false
    let label = UILabel()
    label.text = "Paused while the car is moving"
    label.textColor = .white
    label.textAlignment = .center
    label.numberOfLines = 0
    label.font = .preferredFont(forTextStyle: .headline)
    label.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(label)
    view.addSubview(cover)
    NSLayoutConstraint.activate([
      cover.topAnchor.constraint(equalTo: view.topAnchor),
      cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: cover.leadingAnchor, constant: 16),
    ])
    drivingCover = cover
    Log.write("car gate: covered the car screen")
  }

  private func hideDrivingCover() {
    guard let cover = drivingCover else { return }
    cover.removeFromSuperview()
    drivingCover = nil
    Log.write("car gate: uncovered the car screen")
  }

  @objc private func sendToCarRequested(_ note: Notification) {
    guard let url = note.userInfo?["url"] as? URL else { return }
    webView.load(URLRequest(url: url))
  }

  @objc private func accountChanged() {
    // Never interrupt something that is playing on the car screen.
    webView.evaluateJavaScript(
      "!!document.querySelector('video') && !document.querySelector('video').paused"
    ) { [weak self] playing, _ in
      if (playing as? Bool) == true { return }
      self?.webView.reload()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let screen = view.window?.windowScene?.screen
    Log.write("viewDidAppear view=\(view.bounds.size) web=\(webView.bounds.size) "
      + "window=\(view.window?.bounds.size ?? .zero) "
      + "screen=\(screen?.bounds.size ?? .zero) scale=\(screen?.scale ?? 0) "
      + "native=\(screen?.nativeBounds.size ?? .zero)")
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !showsStatus else { return }  // the phone window uses constraints
    layoutCarWebView()
  }

  // What Cafari does for the car display: take the head unit's OWN resolution
  // and work in it, instead of the point-sized window iOS hands over. The
  // window measured 467x263 points on a 1280x720 panel, so the page was being
  // laid out as if for a phone and the video came out cropped.
  //
  // The web view is given the panel's pixel size as its bounds -- so the page
  // sees a 1280x720 viewport and lays out for it -- then scaled down to fill
  // the window. One page pixel lands on one panel pixel, so nothing is lost.
  private func layoutCarWebView() {
    // The head unit reports its sidebar as a safe-area inset, so the area the
    // page may use is the window minus that -- the same rule Cafari applies to
    // the video it puts on the car. Without it the left edge of the picture
    // sits under the sidebar.
    let bounds = Settings.avoidSidebar ? view.safeAreaLayoutGuide.layoutFrame
                                       : view.bounds
    guard bounds.width > 0, bounds.height > 0 else { return }

    webView.layer.borderColor = UIColor.systemGreen.cgColor
    webView.layer.borderWidth = Settings.debugBorder ? 3 : 0

    guard Settings.carNativeResolution,
          let screen = view.window?.windowScene?.screen else {
      webView.transform = .identity
      webView.frame = bounds
      return
    }
    let native = screen.nativeBounds.size
    // nativeBounds is in the screen's natural orientation; the car panel is
    // landscape, so take the long edge as the width.
    let target = CGSize(width: max(native.width, native.height),
                        height: min(native.width, native.height))
    guard target.width > 0, target.height > 0 else { return }

    webView.transform = .identity
    webView.frame = CGRect(origin: .zero, size: target)
    webView.transform = CGAffineTransform(scaleX: bounds.width / target.width,
                                          y: bounds.height / target.height)
    webView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    if !loggedCarLayout {
      loggedCarLayout = true
      Log.write("car layout native=\(target) area=\(bounds) "
        + "window=\(view.bounds.size) insets=\(view.safeAreaInsets) "
        + "scale=\(screen.scale) sidebar=\(Settings.avoidSidebar)")
    }
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    Log.write("didCommit \(webView.url?.absoluteString ?? "-")")
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Log.write("didFinish \(webView.url?.absoluteString ?? "-") web=\(webView.bounds.size)")
    if !showsStatus {
      webView.evaluateJavaScript(Self.playbackHook, completionHandler: nil)
      return
    }
    let host = webView.url?.host ?? ""
    if host.contains("accounts.google") || host.contains("accounts.youtube") {
      wasSigningIn = true
      return
    }
    if wasSigningIn && host.contains("youtube") {
      wasSigningIn = false
      NotificationCenter.default.post(name: .cafariLiteAccountChanged, object: nil)
    }
  }

  private func updateStatus() {
    // Whether a car window exists is the only thing worth reporting: it is the
    // difference between the app working and the app being a web browser.
    let connected = UIApplication.shared.connectedScenes.contains { scene in
      scene.session.role == cafariLiteCarPlayRole
    }
    statusLabel?.text = connected ? "On the car screen" : "Car screen not connected"
  }

  private func installCarDim() {
    carDim.backgroundColor = .black
    carDim.alpha = 0
    carDim.isUserInteractionEnabled = false
    carDim.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(carDim)
    NSLayoutConstraint.activate([
      carDim.topAnchor.constraint(equalTo: view.topAnchor),
      carDim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      carDim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      carDim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  fileprivate func receiveCarPlayback(_ message: WKScriptMessage) {
    guard let body = message.body as? [String: Any] else { return }
    let playing = (body["playing"] as? NSNumber)?.boolValue ?? false
    let current = (body["current"] as? NSNumber)?.doubleValue ?? 0
    let duration = (body["duration"] as? NSNumber)?.doubleValue ?? 0
    var info: [String: Any] = [
      "playing": playing,
      "current": current,
      "duration": duration,
      "origin": "web",
    ]
    if let title = body["title"] as? String { info["title"] = title }
    if let urlString = body["url"] as? String, let url = URL(string: urlString) {
      info["pageURL"] = url
    }
    if playing && !loggedCarPlaying {
      loggedCarPlaying = true
      Log.write("car web video playing \(info["title"] as? String ?? "-")")
    }
    if !playing { loggedCarPlaying = false }
    NotificationCenter.default.post(name: .cafariLiteCarPlayback, object: nil, userInfo: info)
  }

  @objc private func remoteCommand(_ note: Notification) {
    let info = note.userInfo ?? [:]
    let command = info["command"] as? String ?? ""
    switch command {
    case CarRemoteCommand.toggle:
      evaluateCar("(function(){var v=document.querySelector('video');if(!v)return;if(v.paused){v.play()}else{v.pause()}})()")
    case CarRemoteCommand.seekBy:
      let delta = number(info, "delta")
      evaluateCar("(function(){var v=document.querySelector('video');if(!v)return;var next=Math.max(0,(v.currentTime||0)+(\(js(delta))));if(isFinite(v.duration))next=Math.min(v.duration,next);v.currentTime=next})()")
    case CarRemoteCommand.seekFraction:
      let fraction = min(1, max(0, number(info, "fraction")))
      evaluateCar("(function(){var v=document.querySelector('video');if(!v||!isFinite(v.duration))return;v.currentTime=v.duration*\(js(fraction))})()")
    case CarRemoteCommand.fit:
      let fit: String
      switch info["fit"] as? String {
      case "Fill": fit = "cover"
      case "Stretch": fit = "fill"
      default: fit = "contain"
      }
      evaluateCar("(function(){var v=document.querySelector('video');if(v)v.style.objectFit='\(fit)'})()")
    case CarRemoteCommand.volume:
      evaluateCar("(function(){var v=document.querySelector('video');if(v)v.volume=\(js(number(info, "volume")))})()")
    case CarRemoteCommand.dim:
      let on = flag(info, "on")
      carDim.alpha = on ? 0.55 : 0
      if on { view.bringSubviewToFront(carDim) }
    case CarRemoteCommand.stop:
      evaluateCar("document.querySelectorAll('video').forEach(function(v){v.pause()})")
      loggedCarPlaying = false
      NotificationCenter.default.post(
        name: .cafariLiteCarPlayback, object: nil, userInfo: ["playing": false, "origin": "web"])
    default:
      break
    }
  }

  private func number(_ info: [AnyHashable: Any], _ key: String) -> Double {
    (info[key] as? NSNumber)?.doubleValue ?? 0
  }

  private func flag(_ info: [AnyHashable: Any], _ key: String) -> Bool {
    (info[key] as? NSNumber)?.boolValue ?? false
  }

  private func js(_ value: Double) -> String {
    String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
  }

  private func evaluateCar(_ script: String) {
    webView?.evaluateJavaScript(script, completionHandler: nil)
  }

  private static let playbackHook = """
  (function() {
    if (window.__cafariPlayback) return;
    window.__cafariPlayback = true;
    var last = 0;
    function report(v, force) {
      if (!v || v.tagName !== 'VIDEO') return;
      var now = Date.now();
      var playing = !v.paused && !v.ended;
      if (!force && now - last < 500) return;
      last = now;
      var dur = v.duration;
      try {
        window.webkit.messageHandlers.cafariPlayback.postMessage({
          playing: playing,
          current: v.currentTime || 0,
          duration: (isFinite(dur) ? dur : 0),
          title: document.title || '',
          url: location.href
        });
      } catch (e) {}
    }
    function hook(v) {
      if (!v || v.tagName !== 'VIDEO' || v.__cafariHooked) return;
      v.__cafariHooked = true;
      ['play', 'pause', 'ended', 'seeked'].forEach(function(name) {
        v.addEventListener(name, function() { report(v, true); });
      });
      v.addEventListener('timeupdate', function() { report(v, false); });
    }
    function scan() { document.querySelectorAll('video').forEach(hook); }
    var root = document.documentElement || document;
    new MutationObserver(scan).observe(root, { childList: true, subtree: true });
    document.addEventListener('play', function(e) { hook(e.target); report(e.target, true); }, true);
    scan();
  })();
  """
}

private final class CarPlaybackRelay: NSObject, WKScriptMessageHandler {
  weak var owner: BrowserViewController?
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    owner?.receiveCarPlayback(message)
  }
}
