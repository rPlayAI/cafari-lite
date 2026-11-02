import UIKit

final class CarPlayHomeViewController: UIViewController {
    private var links: [SavedLink] = []
    private var collectionView: UICollectionView!
    private var sidebar: UIVisualEffectView!
    private var sidebarWidth: NSLayoutConstraint!
    private var cellRegistration: UICollectionView.CellRegistration<CarPlayFavoriteCell, SavedLink>!

    init(links: [SavedLink] = []) {
        self.links = links.filter(\.starred)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildInterface()
        reloadStarred()
        applyWallpaperDock()
        Log.write("car home starred=\(links.count)")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openRequestedLink(_:)),
            name: .cafariLiteSendToCar,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(linksChanged),
            name: .cafariLiteLinksChanged,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .cafariLiteSettingsChanged,
            object: nil)
    }

    @objc private func linksChanged() {
        reloadStarred()
    }

    @objc private func settingsChanged() {
        applyWallpaperDock()
    }

    private func reloadStarred() {
        links = SavedLinkStore.shared.links.filter(\.starred)
        collectionView?.reloadData()
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    private func applyWallpaperDock() {
        let show = Settings.wallpaperShortcuts
        sidebarWidth?.constant = show ? 96 : 0
        sidebar?.isHidden = !show
        view.layoutIfNeeded()
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    private func buildInterface() {
        sidebar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebar)

        let sideStack = UIStackView()
        sideStack.axis = .vertical
        sideStack.alignment = .center
        sideStack.spacing = 22
        sideStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.contentView.addSubview(sideStack)

        for (symbol, label) in [
            ("map.fill", "Maps"),
            ("music.note", "Music"),
            ("phone.fill", "Phone"),
            ("rectangle.grid.2x2.fill", "Dashboard")
        ] {
            let button = UIButton(type: .system, primaryAction: UIAction { _ in
                Log.write("car home sidebar \(label)")
            })
            button.setImage(UIImage(systemName: symbol), for: .normal)
            button.tintColor = .label
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 18
            button.accessibilityLabel = label
            button.widthAnchor.constraint(equalToConstant: 56).isActive = true
            button.heightAnchor.constraint(equalToConstant: 56).isActive = true
            sideStack.addArrangedSubview(button)
        }

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)

        cellRegistration = UICollectionView.CellRegistration<CarPlayFavoriteCell, SavedLink> { cell, _, item in
            cell.configure(with: item)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant: 96)
        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarWidth,

            sideStack.centerXAnchor.constraint(equalTo: sidebar.contentView.centerXAnchor),
            sideStack.centerYAnchor.constraint(equalTo: sidebar.contentView.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func openRequestedLink(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else {
            Log.write("car home send missing url")
            return
        }
        let title = (note.userInfo?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? url.host()
            ?? "CarPlay Link"
        open(url: url, title: title)
    }

    private func open(url: URL, title: String) {
        Log.write("car home open \(title) \(url.absoluteString)")
        if let browser = navigationController?.viewControllers.last as? BrowserViewController {
            browser.title = title
            browser.show(url: url)
            return
        }
        let browser = BrowserViewController(showsStatus: false, initialURL: url)
        browser.title = title
        navigationController?.pushViewController(browser, animated: false)
    }
}

extension CarPlayHomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        links.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(
            using: cellRegistration,
            for: indexPath,
            item: links[indexPath.item]
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = collectionView.bounds.width - 64
        let width = floor((availableWidth - 48) / 4)
        return CGSize(width: max(width, 180), height: 146)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let url = links[indexPath.item].url else { return }
        open(url: url, title: links[indexPath.item].title)
    }
}

private final class CarPlayFavoriteCell: UICollectionViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let starView = UIImageView(image: UIImage(systemName: "star.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 24
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemBlue
        iconView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        iconView.layer.cornerRadius = 18
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        starView.tintColor = .systemYellow
        starView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(starView)

        NSLayoutConstraint.activate([
            starView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            starView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            starView.widthAnchor.constraint(equalToConstant: 16),
            starView.heightAnchor.constraint(equalToConstant: 16),

            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with link: SavedLink) {
        let isYouTube = link.url?.host()?.contains("youtube.") == true
        let isStream = link.url?.pathExtension.lowercased() == "m3u8"
        iconView.image = UIImage(systemName: isStream ? "film" : isYouTube ? "play.rectangle.fill" : "link")
        titleLabel.text = link.title
        subtitleLabel.text = isStream ? "Apple HLS stream" : isYouTube ? "Watch on CarPlay" : "Saved web link"
        accessibilityLabel = "\(link.title), \(subtitleLabel.text ?? "")"
    }
}
