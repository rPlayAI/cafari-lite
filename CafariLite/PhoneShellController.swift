// Phone home. Library is the first screen. Links and Settings sit on the dock.

import Observation
import UIKit

protocol PhoneTabPage: AnyObject {
  func scrollToTop()
}

private enum PhoneTab {
  case library
  case links
  case settings
}

final class PhoneShellController: UIViewController {
  private let library = PhotoLibraryViewController()
  private let links = LinksViewController()
  private let settings = SettingsViewController()
  private var current: UIViewController
  private let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
  private let dockShadow = UIView()
  private let libraryButton = UIButton(type: .system)
  private let linksButton = UIButton(type: .system)
  private let settingsButton = UIButton(type: .system)
  private let badge = UILabel()
  private var barIsDark = true
  private var currentTab: PhoneTab = .library
  private var didApplyLaunchScreen = false
  private var carControllerOnScreen = false
  private var suppressedPlaybackKey: String?
  private let glow = UIView()
  private let miniBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
  private let miniTitle = UILabel()
  private let miniPlay = UIButton(type: .system)
  private var miniClips: [ControllerClip] = []
  private var miniIndex = 0
  private var miniOnCar = true
  private var miniTracksQueue = false
  private var miniVisible = false

  init() {
    current = library
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    Log.write("shell viewDidLoad install Library first")
    install(library)
    buildBar()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshBadge),
      name: .cafariLiteLinksChanged, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(carPlaybackBegan(_:)),
      name: .cafariLiteCarPlayback, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(carControllerClosed(_:)),
      name: .cafariLiteCarControllerClosed, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(openController(_:)),
      name: .cafariLiteOpenController, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(showMini(_:)),
      name: .cafariLiteMiniPlayer, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(settingsChanged),
      name: .cafariLiteSettingsChanged, object: nil)
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
      self.styleBar(dark: self.traitCollection.userInterfaceStyle == .dark)
      self.markSelected(self.currentTab)
      self.setNeedsStatusBarAppearanceUpdate()
    }
    observeBadge()
    applyGlow()
    styleBar(dark: traitCollection.userInterfaceStyle == .dark)
    markSelected(.library)
  }

  private func observeBadge() {
    withObservationTracking {
      refreshBadge()
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observeBadge()
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didApplyLaunchScreen else { return }
    didApplyLaunchScreen = true
    let env = ProcessInfo.processInfo.environment
    if env["CAFARI_OPEN_SETTINGS"] == "1" {
      show(settings, dark: traitCollection.userInterfaceStyle == .dark, selected: .settings)
    } else if env["CAFARI_OPEN_LINKS"] == "1" || env["CAFARI_TRACE_LINK"] == "1" {
      show(links, dark: traitCollection.userInterfaceStyle == .dark, selected: .links)
    }
  }

  override var childForStatusBarStyle: UIViewController? { current }
  override var prefersStatusBarHidden: Bool { false }

  private func buildBar() {
    dockShadow.translatesAutoresizingMaskIntoConstraints = false
    dockShadow.isUserInteractionEnabled = false
    dockShadow.backgroundColor = .clear
    dockShadow.layer.shadowRadius = 16
    dockShadow.layer.shadowOffset = CGSize(width: 0, height: 8)
    view.addSubview(dockShadow)

    bar.layer.cornerRadius = 26
    bar.clipsToBounds = true
    bar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bar)

    libraryButton.accessibilityIdentifier = "photo.on.rectangle"
    linksButton.accessibilityIdentifier = "link"
    settingsButton.accessibilityIdentifier = "gearshape"
    libraryButton.addAction(UIAction { [weak self] _ in self?.libraryTapped() }, for: .touchUpInside)
    linksButton.addAction(UIAction { [weak self] _ in self?.linksTapped() }, for: .touchUpInside)
    settingsButton.addAction(UIAction { [weak self] _ in self?.settingsTapped() }, for: .touchUpInside)
    for button in [libraryButton, linksButton, settingsButton] {
      button.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    badge.font = .systemFont(ofSize: 10, weight: .bold)
    badge.textColor = .white
    badge.backgroundColor = UIColor(red: 1, green: 59/255, blue: 48/255, alpha: 1)
    badge.textAlignment = .center
    badge.layer.cornerRadius = 9
    badge.clipsToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false
    linksButton.addSubview(badge)

    let row = UIStackView(arrangedSubviews: [libraryButton, linksButton, settingsButton])
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 8
    row.isLayoutMarginsRelativeArrangement = true
    row.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    row.translatesAutoresizingMaskIntoConstraints = false
    bar.contentView.addSubview(row)

    NSLayoutConstraint.activate([
      dockShadow.topAnchor.constraint(equalTo: bar.topAnchor),
      dockShadow.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
      dockShadow.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
      dockShadow.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
      bar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
      bar.heightAnchor.constraint(equalToConstant: 56),
      row.topAnchor.constraint(equalTo: bar.contentView.topAnchor),
      row.bottomAnchor.constraint(equalTo: bar.contentView.bottomAnchor),
      row.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor),
      badge.topAnchor.constraint(equalTo: linksButton.topAnchor, constant: -4),
      badge.trailingAnchor.constraint(equalTo: linksButton.trailingAnchor, constant: 4),
      badge.heightAnchor.constraint(equalToConstant: 18),
      badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
    ])
    linksButton.clipsToBounds = false
    installGlow()
    installMiniBar()
  }

  private func installGlow() {
    glow.isUserInteractionEnabled = false
    glow.translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(glow, belowSubview: bar)
    let gradient = CAGradientLayer()
    gradient.colors = [
      UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 0).cgColor,
      UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 0.28).cgColor,
    ]
    gradient.frame = CGRect(x: 0, y: 0, width: 400, height: 180)
    glow.layer.addSublayer(gradient)
    NSLayoutConstraint.activate([
      glow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      glow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      glow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      glow.heightAnchor.constraint(equalToConstant: 180),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    dockShadow.layer.shadowPath = UIBezierPath(roundedRect: dockShadow.bounds, cornerRadius: 26).cgPath
    glow.layer.sublayers?.first?.frame = glow.bounds
  }

  private func installMiniBar() {
    miniBar.isHidden = true
    miniBar.layer.cornerRadius = 18
    miniBar.clipsToBounds = true
    miniBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(miniBar)
    let tap = UITapGestureRecognizer(target: self, action: #selector(miniTapped))
    miniBar.addGestureRecognizer(tap)
    miniTitle.font = .systemFont(ofSize: 14, weight: .semibold)
    miniTitle.textColor = .white
    miniTitle.translatesAutoresizingMaskIntoConstraints = false
    miniPlay.setImage(UIImage(systemName: "playpause.fill"), for: .normal)
    miniPlay.tintColor = .white
    miniPlay.addAction(UIAction { _ in CarRemoteCommand.post(CarRemoteCommand.toggle) }, for: .touchUpInside)
    miniPlay.translatesAutoresizingMaskIntoConstraints = false
    miniBar.contentView.addSubview(miniTitle)
    miniBar.contentView.addSubview(miniPlay)
    NSLayoutConstraint.activate([
      miniBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      miniBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      miniBar.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -8),
      miniBar.heightAnchor.constraint(equalToConstant: 52),
      miniPlay.leadingAnchor.constraint(equalTo: miniBar.contentView.leadingAnchor, constant: 8),
      miniPlay.centerYAnchor.constraint(equalTo: miniBar.contentView.centerYAnchor),
      miniPlay.widthAnchor.constraint(equalToConstant: 36),
      miniTitle.leadingAnchor.constraint(equalTo: miniPlay.trailingAnchor, constant: 8),
      miniTitle.trailingAnchor.constraint(equalTo: miniBar.contentView.trailingAnchor, constant: -12),
      miniTitle.centerYAnchor.constraint(equalTo: miniBar.contentView.centerYAnchor),
    ])
  }

  @objc private func settingsChanged() {
    applyGlow()
  }

  private func applyGlow() {
    glow.isHidden = !Settings.ambientLightSync
  }

  private func libraryTapped() {
    Log.write("shell tab library")
    show(library, dark: traitCollection.userInterfaceStyle == .dark, selected: .library)
  }

  private func linksTapped() {
    Log.write("shell tab links")
    show(links, dark: false, selected: .links)
  }

  private func settingsTapped() {
    Log.write("shell tab settings")
    show(settings, dark: traitCollection.userInterfaceStyle == .dark, selected: .settings)
  }

  private func show(_ page: UIViewController, dark: Bool, selected: PhoneTab) {
    if page === current {
      if page === library { library.scrollToTop() }
      if page === links { links.scrollToTop() }
      return
    }
    current.willMove(toParent: nil)
    current.view.removeFromSuperview()
    current.removeFromParent()
    install(page)
    current = page
    styleBar(dark: dark)
    markSelected(selected)
    setNeedsStatusBarAppearanceUpdate()
  }

  private func install(_ page: UIViewController) {
    addChild(page)
    page.view.frame = view.bounds
    page.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.insertSubview(page.view, at: 0)
    page.didMove(toParent: self)
  }

  private func styleBar(dark: Bool) {
    barIsDark = dark
    bar.effect = UIBlurEffect(style: dark ? .systemMaterialDark : .systemChromeMaterialLight)
    bar.backgroundColor = dark ? nil : UIColor.white.withAlphaComponent(0.92)
    bar.layer.borderWidth = 1
    bar.layer.borderColor = dark
      ? UIColor.white.withAlphaComponent(0.1).cgColor
      : UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 0.9).cgColor
    dockShadow.layer.shadowOpacity = dark ? 0.45 : 0.12
    dockShadow.layer.shadowColor = (dark ? UIColor.black : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)).cgColor
  }

  private func markSelected(_ tab: PhoneTab) {
    currentTab = tab
    let electric = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
    let idle: UIColor = barIsDark
      ? UIColor.white.withAlphaComponent(0.9)
      : UIColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 0.6)
    apply(libraryButton, title: tab == .library ? "Library" : nil, on: tab == .library, idle: idle, electric: electric)
    apply(linksButton, title: tab == .links ? "Links" : nil, on: tab == .links, idle: idle, electric: electric)
    apply(settingsButton, title: tab == .settings ? "Settings" : nil, on: tab == .settings, idle: idle, electric: electric)
    libraryButton.accessibilityLabel = "Media Library"
    linksButton.accessibilityLabel = tab == .links ? "Links Tab (Current)" : "Links"
    settingsButton.accessibilityLabel = "Settings"
    linksButton.clipsToBounds = false
  }

  private func apply(_ button: UIButton, title: String?, on: Bool, idle: UIColor, electric: UIColor) {
    var config = UIButton.Configuration.plain()
    let symbol = button.accessibilityIdentifier ?? "circle"
    config.image = UIImage(systemName: symbol)
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    config.imagePadding = title == nil ? 0 : 6
    config.title = title
    config.baseForegroundColor = on ? .white : idle
    config.background.backgroundColor = on ? electric : .clear
    config.background.cornerRadius = 20
    config.contentInsets = NSDirectionalEdgeInsets(
      top: 8,
      leading: title == nil ? 10 : 14,
      bottom: 8,
      trailing: title == nil ? 10 : 14)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 15, weight: .semibold)
      return out
    }
    button.configuration = config
  }

  @objc private func refreshBadge() {
    badge.text = " \(SavedLinkStore.shared.links.count) "
    badge.isHidden = false
  }

  @objc private func carPlaybackBegan(_ note: Notification) {
    let info = note.userInfo ?? [:]
    let ended = (info["ended"] as? NSNumber)?.boolValue ?? (info["ended"] as? Bool ?? false)
    if ended, Settings.autoplayNextVideo, presentedRemote() == nil, !miniVisible {
      advanceSavedQueue()
      return
    }
    let playing = (info["playing"] as? NSNumber)?.boolValue ?? (info["playing"] as? Bool ?? false)
    guard playing else { return }
    let key = CarPlaybackKey.make(info)
    if suppressedPlaybackKey == key { return }
    if miniVisible || carControllerOnScreen || remoteIsShowing() { return }
    let host = topPresenter()
    if host is UIAlertController { return }
    let title = (info["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Video"
    let pageURL = info["pageURL"] as? URL
    let duration = (info["duration"] as? NSNumber)?.doubleValue ?? 0
    let queued = PhonePlayback.shared.clipQueue()
    let clips = queued.isEmpty
      ? [ControllerClip(title: title, posterURL: nil, pageURL: pageURL, duration: duration)]
      : queued
    let index = queued.isEmpty ? 0 : PhonePlayback.shared.queueIndex
    let remote = VideoRemoteViewController(
      clips: clips, index: index, onCar: true, dismissKey: key, tracksQueue: !queued.isEmpty)
    remote.modalPresentationStyle = .fullScreen
    carControllerOnScreen = true
    Log.write("controller mode \(key)")
    host.present(remote, animated: true)
  }

  @objc private func openController(_ note: Notification) {
    let info = note.userInfo ?? [:]
    let clips = info["clips"] as? [ControllerClip] ?? []
    let index = info["index"] as? Int ?? 0
    let onCar = info["onCar"] as? Bool ?? true
    let tracks = info["tracksQueue"] as? Bool ?? false
    let send = info["send"] as? Bool ?? false
    hideMini()
    if let remote = presentedRemote() {
      remote.replace(clips: clips, index: index, onCar: onCar, tracksQueue: tracks, send: send)
      carControllerOnScreen = onCar
      return
    }
    let remote = VideoRemoteViewController(
      clips: clips, index: index, onCar: onCar, tracksQueue: tracks, sendOnAppear: send)
    remote.modalPresentationStyle = .fullScreen
    carControllerOnScreen = onCar
    Log.write("controller open onCar=\(onCar) clips=\(clips.count)")
    topPresenter().present(remote, animated: true)
  }

  @objc private func showMini(_ note: Notification) {
    let info = note.userInfo ?? [:]
    miniClips = info["clips"] as? [ControllerClip] ?? []
    miniIndex = info["index"] as? Int ?? 0
    miniOnCar = info["onCar"] as? Bool ?? true
    miniTracksQueue = info["tracksQueue"] as? Bool ?? false
    miniTitle.text = info["title"] as? String ?? "Video"
    miniBar.isHidden = false
    miniVisible = true
    Log.write("mini player \(miniTitle.text ?? "")")
  }

  @objc private func miniTapped() {
    let clips = miniClips
    let index = miniIndex
    let onCar = miniOnCar
    let tracks = miniTracksQueue
    hideMini()
    let remote = VideoRemoteViewController(
      clips: clips, index: index, onCar: onCar, tracksQueue: tracks, sendOnAppear: false)
    remote.modalPresentationStyle = .fullScreen
    carControllerOnScreen = onCar
    topPresenter().present(remote, animated: true)
  }

  private func hideMini() {
    miniBar.isHidden = true
    miniVisible = false
  }

  private func advanceSavedQueue() {
    guard let link = PhonePlayback.shared.move(by: 1), let url = link.url else { return }
    Log.write("autoplay next \(link.title)")
    if PhonePlayback.shared.mode == .stream {
      CarSender.sendDirect(url)
    } else {
      CarSender.sendPage(url)
    }
  }

  private func presentedRemote() -> VideoRemoteViewController? {
    var top: UIViewController = self
    while let next = top.presentedViewController {
      if let remote = next as? VideoRemoteViewController { return remote }
      if next.isBeingDismissed { break }
      top = next
    }
    return nil
  }

  @objc private func carControllerClosed(_ note: Notification) {
    carControllerOnScreen = false
    let suppress = (note.userInfo?["suppress"] as? NSNumber)?.boolValue
      ?? (note.userInfo?["suppress"] as? Bool ?? false)
    let key = note.userInfo?["key"] as? String ?? "-"
    Log.write("controller closed suppress=\(suppress) key=\(key)")
    if suppress, let key = note.userInfo?["key"] as? String {
      suppressedPlaybackKey = key
    }
  }

  private func remoteIsShowing() -> Bool {
    var top: UIViewController = self
    while let next = top.presentedViewController {
      if next is VideoRemoteViewController { return true }
      if next.isBeingDismissed { break }
      top = next
    }
    return false
  }

  private func topPresenter() -> UIViewController {
    var top: UIViewController = self
    while let next = top.presentedViewController, !next.isBeingDismissed {
      top = next
    }
    return top
  }
}
