// Phone home. Library is the first screen. Links and Settings sit on the dock.

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
    refreshBadge()
    styleBar(dark: traitCollection.userInterfaceStyle == .dark)
    markSelected(.library)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didApplyLaunchScreen else { return }
    didApplyLaunchScreen = true
    if ProcessInfo.processInfo.environment["CAFARI_OPEN_LINKS"] == "1" {
      show(links, dark: traitCollection.userInterfaceStyle == .dark, selected: .links)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    dockShadow.layer.shadowPath = UIBezierPath(roundedRect: dockShadow.bounds, cornerRadius: 26).cgPath
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
    libraryButton.addTarget(self, action: #selector(libraryTapped), for: .touchUpInside)
    linksButton.addTarget(self, action: #selector(linksTapped), for: .touchUpInside)
    settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
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
  }

  @objc private func libraryTapped() { show(library, dark: traitCollection.userInterfaceStyle == .dark, selected: .library) }
  @objc private func linksTapped() { show(links, dark: false, selected: .links) }

  @objc private func settingsTapped() {
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

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
    styleBar(dark: traitCollection.userInterfaceStyle == .dark)
    markSelected(currentTab)
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
    let playing = (info["playing"] as? NSNumber)?.boolValue ?? (info["playing"] as? Bool ?? false)
    guard playing else { return }
    let key = CarPlaybackKey.make(info)
    if suppressedPlaybackKey == key { return }
    if carControllerOnScreen || remoteIsShowing() { return }
    let host = topPresenter()
    if host is UIAlertController { return }
    let title = (info["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Video"
    let pageURL = info["pageURL"] as? URL
    let duration = (info["duration"] as? NSNumber)?.doubleValue ?? 0
    let clip = ControllerClip(title: title, posterURL: nil, pageURL: pageURL, duration: duration)
    let remote = VideoRemoteViewController(clips: [clip], index: 0, onCar: true, dismissKey: key)
    remote.modalPresentationStyle = .fullScreen
    carControllerOnScreen = true
    Log.write("controller mode \(key)")
    host.present(remote, animated: true)
  }

  @objc private func carControllerClosed(_ note: Notification) {
    carControllerOnScreen = false
    let suppress = (note.userInfo?["suppress"] as? NSNumber)?.boolValue
      ?? (note.userInfo?["suppress"] as? Bool ?? false)
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
