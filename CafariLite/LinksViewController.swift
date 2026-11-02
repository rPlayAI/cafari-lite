// Links. Light page from the Stitch saved-links screen.
// One of Stream, Web on car, and Mirror stays on.
// Web on car only sets the mode. Stream plays the current item on the car.
// Mirror shows the current page on the phone and sends that page to the car.

import UIKit

private enum Taste {
  private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
    UIColor { traits in
      traits.userInterfaceStyle == .dark ? dark : light
    }
  }

  static let canvas = adaptive(light: .systemBackground, dark: .black)
  static let charcoal = adaptive(light: .label, dark: .white)
  static let whisper = adaptive(
    light: UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 0.7),
    dark: UIColor(white: 1, alpha: 0.12))
  static let electric = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
  static let electricSubtle = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 0.08)
  static let amber = UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1)
  static let amberText = UIColor(red: 252/255, green: 211/255, blue: 77/255, alpha: 1)
  static let amberTile = UIColor(red: 120/255, green: 53/255, blue: 15/255, alpha: 0.92)
  static let yellowText = UIColor(red: 250/255, green: 204/255, blue: 21/255, alpha: 1)
  static let yellowTile = UIColor(red: 66/255, green: 32/255, blue: 6/255, alpha: 1)
  static let zinc = adaptive(light: UIColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 1), dark: UIColor(white: 1, alpha: 0.10))
  static let zincIcon = UIColor(red: 161/255, green: 161/255, blue: 170/255, alpha: 1)
  static let emerald = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
  static let hlsBadge = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 0.85)
  static let webBadge = UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 0.85)
}

final class LinksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let store = SavedLinkStore.shared
  private var selecting = false
  private var checked: Set<UUID> = []
  private let table = UITableView(frame: .zero, style: .plain)
  private let countLabel = UILabel()
  private let selectButton = UIButton(type: .system)
  private let carPill = UIButton(type: .system)
  private let modeButtons: [PlayMode: UIButton] = [
    .stream: UIButton(type: .system),
    .webOnCar: UIButton(type: .system),
    .mirror: UIButton(type: .system),
  ]
  private var carObserver: NSObjectProtocol?
  private var linksObserver: NSObjectProtocol?
  private var modeObserver: NSObjectProtocol?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Taste.canvas

    let header = UIView()
    header.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(header)

    let title = UILabel()
    title.text = "Links"
    title.font = .systemFont(ofSize: 32, weight: .bold)
    title.textColor = Taste.charcoal
    title.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(title)

    carPill.addTarget(self, action: #selector(pillTapped), for: .touchUpInside)
    carPill.layer.cornerRadius = 11
    carPill.layer.borderWidth = 1
    carPill.layer.borderColor = Taste.emerald.withAlphaComponent(0.20).cgColor
    carPill.backgroundColor = Taste.emerald.withAlphaComponent(0.10)
    carPill.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(carPill)

    let add = UIButton(type: .system)
    let plus = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    add.setImage(UIImage(systemName: "plus", withConfiguration: plus), for: .normal)
    add.tintColor = Taste.charcoal
    add.backgroundColor = .white
    add.layer.cornerRadius = 18
    add.layer.borderWidth = 1
    add.layer.borderColor = Taste.whisper.cgColor
    add.layer.shadowColor = UIColor.black.cgColor
    add.layer.shadowOpacity = 0.04
    add.layer.shadowRadius = 3
    add.layer.shadowOffset = CGSize(width: 0, height: 1)
    add.accessibilityLabel = "Add new link"
    add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
    add.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(add)

    let modes = UIStackView()
    modes.axis = .horizontal
    modes.distribution = .fillEqually
    modes.spacing = 2
    modes.backgroundColor = Taste.charcoal.withAlphaComponent(0.04)
    modes.layer.cornerRadius = 18
    modes.layer.borderWidth = 1
    modes.layer.borderColor = Taste.whisper.cgColor
    modes.clipsToBounds = true
    modes.isLayoutMarginsRelativeArrangement = true
    modes.layoutMargins = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
    modes.translatesAutoresizingMaskIntoConstraints = false
    modes.accessibilityLabel = "Streaming modes"
    for mode in [PlayMode.stream, .webOnCar, .mirror] {
      let button = modeButtons[mode]!
      button.tag = tagFor(mode)
      button.addTarget(self, action: #selector(modeTapped(_:)), for: .touchUpInside)
      modes.addArrangedSubview(button)
    }
    header.addSubview(modes)

    let paste = UIButton(type: .custom)
    paste.backgroundColor = .white
    paste.layer.cornerRadius = 18
    paste.layer.borderWidth = 1
    paste.layer.borderColor = Taste.whisper.cgColor
    paste.layer.shadowColor = UIColor.black.cgColor
    paste.layer.shadowOpacity = 0.04
    paste.layer.shadowRadius = 4
    paste.layer.shadowOffset = CGSize(width: 0, height: 1)
    paste.accessibilityLabel = "Paste video or web URL"
    paste.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
    paste.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(paste)

    let linkBadge = UIView()
    linkBadge.backgroundColor = Taste.electricSubtle
    linkBadge.layer.cornerRadius = 10
    linkBadge.isUserInteractionEnabled = false
    linkBadge.translatesAutoresizingMaskIntoConstraints = false
    paste.addSubview(linkBadge)
    let linkIcon = UIImageView(image: UIImage(systemName: "link"))
    linkIcon.tintColor = Taste.electric
    linkIcon.contentMode = .scaleAspectFit
    linkIcon.isUserInteractionEnabled = false
    linkIcon.translatesAutoresizingMaskIntoConstraints = false
    linkBadge.addSubview(linkIcon)
    let pasteLabel = UILabel()
    pasteLabel.text = "Paste video or web URL"
    pasteLabel.font = .systemFont(ofSize: 13, weight: .medium)
    pasteLabel.textColor = Taste.charcoal.withAlphaComponent(0.8)
    pasteLabel.lineBreakMode = .byTruncatingTail
    pasteLabel.isUserInteractionEnabled = false
    pasteLabel.translatesAutoresizingMaskIntoConstraints = false
    paste.addSubview(pasteLabel)
    pasteLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let capsule = UIView()
    capsule.backgroundColor = .white
    capsule.layer.cornerRadius = 18
    capsule.layer.borderWidth = 1
    capsule.layer.borderColor = Taste.whisper.cgColor
    capsule.clipsToBounds = true
    capsule.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(capsule)

    let carPlayAll = iconButton("car", "Play all on car display", #selector(playAllOnCar))
    let phonePlayAll = iconButton("iphone", "Play all on phone", #selector(playAllOnPhone))
    let divider = UIView()
    divider.backgroundColor = Taste.whisper
    divider.translatesAutoresizingMaskIntoConstraints = false
    capsule.addSubview(carPlayAll)
    capsule.addSubview(divider)
    capsule.addSubview(phonePlayAll)

    countLabel.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(countLabel)

    selectButton.setTitle("Select", for: .normal)
    selectButton.setTitleColor(Taste.electric, for: .normal)
    selectButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)
    selectButton.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(selectButton)

    let hairline = UIView()
    hairline.backgroundColor = Taste.whisper
    hairline.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(hairline)

    table.dataSource = self
    table.delegate = self
    table.backgroundColor = .clear
    table.separatorColor = Taste.whisper
    table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    table.rowHeight = 88
    table.register(LinkRowCell.self, forCellReuseIdentifier: LinkRowCell.reuseID)
    table.translatesAutoresizingMaskIntoConstraints = false
    table.contentInset.bottom = 110
    view.addSubview(table)

    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      title.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
      title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      carPill.centerYAnchor.constraint(equalTo: title.centerYAnchor),
      carPill.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
      carPill.heightAnchor.constraint(equalToConstant: 22),
      add.centerYAnchor.constraint(equalTo: title.centerYAnchor),
      add.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      add.widthAnchor.constraint(equalToConstant: 36),
      add.heightAnchor.constraint(equalToConstant: 36),
      modes.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
      modes.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      modes.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      modes.heightAnchor.constraint(equalToConstant: 36),
      paste.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 10),
      paste.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      paste.heightAnchor.constraint(equalToConstant: 36),
      capsule.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      capsule.leadingAnchor.constraint(equalTo: paste.trailingAnchor, constant: 8),
      capsule.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      capsule.heightAnchor.constraint(equalToConstant: 36),
      linkBadge.leadingAnchor.constraint(equalTo: paste.leadingAnchor, constant: 8),
      linkBadge.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      linkBadge.widthAnchor.constraint(equalToConstant: 20),
      linkBadge.heightAnchor.constraint(equalToConstant: 20),
      linkIcon.centerXAnchor.constraint(equalTo: linkBadge.centerXAnchor),
      linkIcon.centerYAnchor.constraint(equalTo: linkBadge.centerYAnchor),
      linkIcon.widthAnchor.constraint(equalToConstant: 12),
      linkIcon.heightAnchor.constraint(equalToConstant: 12),
      pasteLabel.leadingAnchor.constraint(equalTo: linkBadge.trailingAnchor, constant: 8),
      pasteLabel.trailingAnchor.constraint(equalTo: paste.trailingAnchor, constant: -8),
      pasteLabel.centerYAnchor.constraint(equalTo: paste.centerYAnchor),
      carPlayAll.leadingAnchor.constraint(equalTo: capsule.leadingAnchor),
      carPlayAll.topAnchor.constraint(equalTo: capsule.topAnchor),
      carPlayAll.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
      carPlayAll.widthAnchor.constraint(equalToConstant: 40),
      divider.leadingAnchor.constraint(equalTo: carPlayAll.trailingAnchor),
      divider.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
      divider.widthAnchor.constraint(equalToConstant: 1),
      divider.heightAnchor.constraint(equalToConstant: 18),
      phonePlayAll.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
      phonePlayAll.trailingAnchor.constraint(equalTo: capsule.trailingAnchor),
      phonePlayAll.topAnchor.constraint(equalTo: capsule.topAnchor),
      phonePlayAll.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
      phonePlayAll.widthAnchor.constraint(equalToConstant: 40),
      countLabel.topAnchor.constraint(equalTo: paste.bottomAnchor, constant: 16),
      countLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      countLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
      selectButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
      selectButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      selectButton.leadingAnchor.constraint(greaterThanOrEqualTo: countLabel.trailingAnchor, constant: 8),
      hairline.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      hairline.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      hairline.bottomAnchor.constraint(equalTo: header.bottomAnchor),
      hairline.heightAnchor.constraint(equalToConstant: 1),
      table.topAnchor.constraint(equalTo: header.bottomAnchor),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let center = NotificationCenter.default
    carObserver = center.addObserver(forName: .cafariLiteCarConnected, object: nil, queue: .main) { [weak self] _ in
      self?.refreshPill()
    }
    center.addObserver(forName: .cafariLiteCarDisconnected, object: nil, queue: .main) { [weak self] _ in
      self?.refreshPill()
    }
    linksObserver = center.addObserver(forName: .cafariLiteLinksChanged, object: nil, queue: .main) { [weak self] _ in
      self?.refreshList()
    }
    modeObserver = center.addObserver(forName: .cafariLitePlayModeChanged, object: nil, queue: .main) { [weak self] _ in
      self?.refreshModes()
    }
    refreshPill()
    refreshModes()
    refreshList()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
  }

  func scrollToTop() {
    table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: true)
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.links.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: LinkRowCell.reuseID, for: indexPath) as! LinkRowCell
    let link = store.links[indexPath.row]
    cell.fill(link, selecting: selecting, checked: checked.contains(link.id))
    cell.onStar = { [weak self] in
      self?.store.toggleStar(link.id)
    }
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let link = store.links[indexPath.row]
    if selecting {
      if checked.contains(link.id) { checked.remove(link.id) } else { checked.insert(link.id) }
      tableView.reloadRows(at: [indexPath], with: .none)
      return
    }
    guard let url = link.url else { return }
    PhonePlayback.shared.remember(title: link.title, url: url)
    PhonePlayback.shared.setQueue(store.links, index: indexPath.row)
    switch PhonePlayback.shared.mode {
    case .stream:
      CarSender.sendDirect(url)
    case .webOnCar, .mirror:
      CarSender.sendPage(url)
      let page: UIViewController
      if url.host?.contains("youtube.") == true {
        page = BrowserViewController(showsStatus: true, initialURL: url)
      } else {
        page = PageBrowserController(url: url, title: link.title)
      }
      page.modalPresentationStyle = .fullScreen
      present(page, animated: true)
    }
  }

  @objc private func pillTapped() {
    if !CarSender.sendCurrentItem() {
      let alert = UIAlertController(title: "CarPlay", message: "No item to send.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel))
      present(alert, animated: true)
    }
  }

  @objc private func addTapped() {
    let alert = UIAlertController(title: "Add new link", message: nil, preferredStyle: .alert)
    alert.addTextField { $0.placeholder = "Video or web URL" }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
      guard let raw = alert.textFields?.first?.text, let url = LinkURL.normalize(raw) else { return }
      self?.store.add(url: url)
    })
    present(alert, animated: true)
  }

  @objc private func modeTapped(_ sender: UIButton) {
    let mode = modeFor(tag: sender.tag)
    PhonePlayback.shared.mode = mode
    switch mode {
    case .stream:
      playCurrentOnCar(direct: true)
    case .webOnCar:
      break
    case .mirror:
      let url = PhonePlayback.shared.currentURL ?? URL(string: "https://m.youtube.com")!
      let title = PhonePlayback.shared.currentTitle ?? "YouTube"
      PhonePlayback.shared.remember(title: title, url: url)
      CarSender.sendPage(url)
      let page = PageBrowserController(url: url, title: title)
      page.modalPresentationStyle = .fullScreen
      present(page, animated: true)
    }
  }

  @objc private func pasteTapped() {
    guard let raw = UIPasteboard.general.string, let url = LinkURL.normalize(raw) else {
      let alert = UIAlertController(title: "Paste video or web URL", message: "The clipboard has no link.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel))
      present(alert, animated: true)
      return
    }
    store.add(url: url)
  }

  @objc private func playAllOnCar() {
    guard let first = store.links.first, let url = first.url else { return }
    PhonePlayback.shared.setQueue(store.links, index: 0)
    PhonePlayback.shared.remember(title: first.title, url: url)
    playCurrentOnCar(direct: PhonePlayback.shared.mode == .stream)
    _ = url
  }

  @objc private func playAllOnPhone() {
    guard let first = store.links.first, let url = first.url else { return }
    PhonePlayback.shared.setQueue(store.links, index: 0)
    PhonePlayback.shared.remember(title: first.title, url: url)
    let page = PhonePlaybackPresenter.make(
      url: url,
      title: first.title,
      direct: PhonePlayback.shared.mode == .stream)
    page.modalPresentationStyle = .fullScreen
    present(page, animated: true)
  }

  @objc private func selectTapped() {
    selecting.toggle()
    if !selecting { checked.removeAll() }
    selectButton.setTitle(selecting ? "Done" : "Select", for: .normal)
    table.reloadData()
  }

  private func playCurrentOnCar(direct: Bool) {
    guard let url = PhonePlayback.shared.currentURL else { return }
    if direct { CarSender.sendDirect(url) } else { CarSender.sendPage(url) }
  }

  private func refreshList() {
    let text = "SAVED · PLAY ON CAR DISPLAY (\(store.links.count))"
    countLabel.attributedText = NSAttributedString(string: text, attributes: [
      .font: UIFont.systemFont(ofSize: 11, weight: .bold),
      .foregroundColor: Taste.charcoal.withAlphaComponent(0.5),
      .kern: 1.1,
    ])
    table.reloadData()
  }

  private func refreshPill() {
    var config = UIButton.Configuration.plain()
    config.title = "CarPlay"
    config.image = Self.emeraldDot
    config.imagePadding = 5
    config.imagePlacement = .leading
    config.baseForegroundColor = Taste.charcoal.withAlphaComponent(0.7)
    config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var out = incoming
      out.font = .systemFont(ofSize: 11, weight: .medium)
      return out
    }
    carPill.configuration = config
  }

  private static let emeraldDot: UIImage = {
    let size = CGSize(width: 6, height: 6)
    return UIGraphicsImageRenderer(size: size).image { _ in
      Taste.emerald.setFill()
      UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
    }.withRenderingMode(.alwaysOriginal)
  }()

  private func refreshModes() {
    let current = PhonePlayback.shared.mode
    for (mode, button) in modeButtons {
      let on = mode == current
      var config = UIButton.Configuration.plain()
      config.title = titleFor(mode)
      config.cornerStyle = .capsule
      config.baseForegroundColor = on ? Taste.electric : Taste.charcoal.withAlphaComponent(0.6)
      config.background.backgroundColor = on ? .white : .clear
      config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var out = incoming
        out.font = .systemFont(ofSize: 13, weight: .semibold)
        return out
      }
      if on && mode == .webOnCar {
        config.image = UIImage(systemName: "globe")
        config.imagePadding = 4
        config.imagePlacement = .leading
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
      }
      button.configuration = config
    }
  }

  private func titleFor(_ mode: PlayMode) -> String {
    switch mode {
    case .stream: return "Stream"
    case .webOnCar: return "Web on car"
    case .mirror: return "Mirror"
    }
  }

  private func tagFor(_ mode: PlayMode) -> Int {
    switch mode {
    case .stream: return 1
    case .webOnCar: return 2
    case .mirror: return 3
    }
  }

  private func modeFor(tag: Int) -> PlayMode {
    switch tag {
    case 1: return .stream
    case 3: return .mirror
    default: return .webOnCar
    }
  }

  private func iconButton(_ symbol: String, _ access: String, _ action: Selector) -> UIButton {
    let button = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    button.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
    button.tintColor = Taste.charcoal.withAlphaComponent(0.8)
    button.accessibilityLabel = access
    button.addTarget(self, action: action, for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }
}

private final class LinkRowCell: UITableViewCell {
  static let reuseID = "LinkRowCell"
  var onStar: (() -> Void)?
  private let thumb = LinkThumbView()
  private let nameLabel = UILabel()
  private let star = UIButton(type: .system)
  private let check = UIImageView()
  private var titleGap: NSLayoutConstraint!

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    let selected = UIView()
    selected.backgroundColor = Taste.charcoal.withAlphaComponent(0.02)
    selectedBackgroundView = selected

    thumb.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(thumb)

    nameLabel.font = .systemFont(ofSize: 14, weight: .regular)
    nameLabel.textColor = Taste.charcoal
    nameLabel.numberOfLines = 2
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(nameLabel)

    star.accessibilityLabel = "Favorite item"
    star.addTarget(self, action: #selector(starTapped), for: .touchUpInside)
    star.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(star)

    check.translatesAutoresizingMaskIntoConstraints = false
    check.tintColor = Taste.electric
    contentView.addSubview(check)

    titleGap = nameLabel.trailingAnchor.constraint(equalTo: star.leadingAnchor, constant: -8)
    NSLayoutConstraint.activate([
      thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      thumb.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      thumb.widthAnchor.constraint(equalToConstant: 120),
      thumb.heightAnchor.constraint(equalToConstant: 68),
      nameLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
      nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      titleGap,
      star.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
      star.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      star.widthAnchor.constraint(equalToConstant: 32),
      star.heightAnchor.constraint(equalToConstant: 32),
      check.trailingAnchor.constraint(equalTo: star.leadingAnchor, constant: -2),
      check.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      check.widthAnchor.constraint(equalToConstant: 22),
      check.heightAnchor.constraint(equalToConstant: 22),
    ])
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  func fill(_ link: SavedLink, selecting: Bool, checked: Bool) {
    nameLabel.text = link.title
    thumb.apply(style: Self.style(for: link), duration: link.durationLabel)
    let symbol = link.starred ? "star.fill" : "star"
    let starImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    star.setImage(UIImage(systemName: symbol, withConfiguration: starImage), for: .normal)
    star.tintColor = link.starred ? Taste.amber : Taste.charcoal.withAlphaComponent(0.3)
    check.isHidden = !selecting
    check.image = UIImage(systemName: checked ? "checkmark.circle.fill" : "circle")
    titleGap.constant = selecting ? -32 : -8
  }

  private static func style(for link: SavedLink) -> String {
    if let style = link.thumbStyle, !style.isEmpty { return style }
    let host = (link.url?.host ?? "").lowercased()
    if link.urlString.contains("m3u8") { return "hls" }
    if host.contains("youtu") { return "web" }
    return "video"
  }

  @objc private func starTapped() { onStar?() }
}

private final class LinkThumbView: UIView {
  private let gradient = CAGradientLayer()
  private let caption = UILabel()
  private let icon = UIImageView()
  private let playCard = UIView()
  private let badge = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.cornerRadius = 12
    layer.borderWidth = 1
    layer.borderColor = Taste.charcoal.withAlphaComponent(0.2).cgColor
    clipsToBounds = true
    layer.insertSublayer(gradient, at: 0)

    caption.textAlignment = .center
    caption.numberOfLines = 2
    caption.translatesAutoresizingMaskIntoConstraints = false
    addSubview(caption)

    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    addSubview(icon)

    playCard.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.8)
    playCard.layer.cornerRadius = 3
    playCard.layer.borderWidth = 1
    playCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    playCard.translatesAutoresizingMaskIntoConstraints = false
    addSubview(playCard)
    let play = UIImageView(image: UIImage(systemName: "play.fill"))
    play.tintColor = Taste.electric
    play.contentMode = .scaleAspectFit
    play.translatesAutoresizingMaskIntoConstraints = false
    playCard.addSubview(play)

    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.clipsToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false
    addSubview(badge)

    NSLayoutConstraint.activate([
      caption.centerXAnchor.constraint(equalTo: centerXAnchor),
      caption.centerYAnchor.constraint(equalTo: centerYAnchor),
      caption.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      caption.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
      icon.centerXAnchor.constraint(equalTo: centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 24),
      icon.heightAnchor.constraint(equalToConstant: 24),
      playCard.centerXAnchor.constraint(equalTo: centerXAnchor),
      playCard.centerYAnchor.constraint(equalTo: centerYAnchor),
      playCard.widthAnchor.constraint(equalToConstant: 28),
      playCard.heightAnchor.constraint(equalToConstant: 36),
      play.centerXAnchor.constraint(equalTo: playCard.centerXAnchor),
      play.centerYAnchor.constraint(equalTo: playCard.centerYAnchor),
      play.widthAnchor.constraint(equalToConstant: 12),
      play.heightAnchor.constraint(equalToConstant: 12),
      badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      badge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      badge.heightAnchor.constraint(equalToConstant: 14),
    ])
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradient.frame = bounds
  }

  func apply(style: String, duration: String?) {
    caption.isHidden = true
    icon.isHidden = true
    playCard.isHidden = true
    badge.isHidden = true
    gradient.isHidden = true
    switch style {
    case "kt789":
      backgroundColor = Taste.amberTile
      caption.isHidden = false
      caption.text = "KT #789"
      caption.textColor = Taste.amberText
      caption.font = .systemFont(ofSize: 12, weight: .black)
      showWash(bottomHeavy: true)
      showDuration(duration)
    case "kt780":
      backgroundColor = Taste.yellowTile
      caption.isHidden = false
      caption.text = "KT #780 · FLUFFY"
      caption.textColor = Taste.yellowText
      caption.font = .systemFont(ofSize: 10, weight: .black)
      showWash(bottomHeavy: true)
      showDuration(duration)
    case "hls":
      backgroundColor = Taste.zinc
      icon.isHidden = false
      icon.image = UIImage(systemName: "film")
      icon.tintColor = Taste.zincIcon
      showWord("HLS", color: Taste.hlsBadge)
    case "web":
      backgroundColor = Taste.zinc
      icon.isHidden = false
      icon.image = UIImage(systemName: "globe")
      icon.tintColor = Taste.zincIcon
      showWord("WEB", color: Taste.webBadge)
    default:
      backgroundColor = Taste.zinc
      playCard.isHidden = false
      showWash(bottomHeavy: false)
      showDuration(duration)
    }
  }

  private func showWash(bottomHeavy: Bool) {
    gradient.isHidden = false
    if bottomHeavy {
      gradient.colors = [
        UIColor.black.withAlphaComponent(0.85).cgColor,
        UIColor.black.withAlphaComponent(0.25).cgColor,
        UIColor.clear.cgColor,
      ]
      gradient.startPoint = CGPoint(x: 0.5, y: 1)
      gradient.endPoint = CGPoint(x: 0.5, y: 0)
    } else {
      gradient.colors = [
        UIColor.black.withAlphaComponent(0.8).cgColor,
        UIColor.clear.cgColor,
      ]
      gradient.startPoint = CGPoint(x: 0, y: 1)
      gradient.endPoint = CGPoint(x: 1, y: 0)
    }
  }

  private func showDuration(_ text: String?) {
    guard let text, !text.isEmpty else { return }
    badge.isHidden = false
    badge.text = " \(text) "
    badge.textColor = UIColor.white.withAlphaComponent(0.9)
    badge.backgroundColor = UIColor.black.withAlphaComponent(0.75)
    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
  }

  private func showWord(_ text: String, color: UIColor) {
    badge.isHidden = false
    badge.text = " \(text) "
    badge.textColor = .white
    badge.backgroundColor = color
    badge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
  }
}
