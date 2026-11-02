import Photos
import UIKit

final class PhotoLibraryViewController: UIViewController {
    private let imageManager = PHCachingImageManager()
    private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private let tabsScrollView = UIScrollView()
    private let tabsStack = UIStackView()
    private let titleLabel = UILabel()
    private let permissionView = UIView()
    private let permissionTitleLabel = UILabel()
    private let permissionMessageLabel = UILabel()
    private let permissionButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)

    private var albums: [PhotoAlbum] = []
    private var assets: [PHAsset] = []
    private var selectedAlbumIndex = 0
    private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        PHPhotoLibrary.shared().register(self)
        buildInterface()
        updatePermissionState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestAccessIfNeeded()
    }

    func scrollToTop() {
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: true)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    private func buildInterface() {
        titleLabel.text = "Library"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = .label
        moreButton.backgroundColor = .secondarySystemBackground
        moreButton.layer.cornerRadius = 16
        moreButton.accessibilityLabel = "More library options"
        moreButton.addTarget(self, action: #selector(showMoreOptions), for: .touchUpInside)
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moreButton)

        tabsScrollView.showsHorizontalScrollIndicator = false
        tabsScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabsScrollView)

        tabsStack.axis = .horizontal
        tabsStack.alignment = .center
        tabsStack.spacing = 24
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        tabsScrollView.addSubview(tabsStack)

        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 2, bottom: 112, right: 2)
        collectionView.scrollIndicatorInsets = collectionView.contentInset
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoAssetCell.self, forCellWithReuseIdentifier: PhotoAssetCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        buildPermissionView()

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            moreButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            moreButton.widthAnchor.constraint(equalToConstant: 32),
            moreButton.heightAnchor.constraint(equalToConstant: 32),

            tabsScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tabsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsScrollView.heightAnchor.constraint(equalToConstant: 34),

            tabsStack.topAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.topAnchor),
            tabsStack.leadingAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            tabsStack.trailingAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            tabsStack.bottomAnchor.constraint(equalTo: tabsScrollView.contentLayoutGuide.bottomAnchor),
            tabsStack.heightAnchor.constraint(equalTo: tabsScrollView.frameLayoutGuide.heightAnchor),

            collectionView.topAnchor.constraint(equalTo: tabsScrollView.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            permissionView.topAnchor.constraint(equalTo: tabsScrollView.bottomAnchor, constant: 24),
            permissionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            permissionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func buildPermissionView() {
        permissionView.backgroundColor = .secondarySystemBackground
        permissionView.layer.cornerRadius = 18
        permissionView.isHidden = true
        permissionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(permissionView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        permissionView.addSubview(stack)

        permissionTitleLabel.text = "Photos access needed"
        permissionTitleLabel.font = .preferredFont(forTextStyle: .headline)
        permissionTitleLabel.textColor = .label

        permissionMessageLabel.font = .preferredFont(forTextStyle: .body)
        permissionMessageLabel.textColor = .secondaryLabel
        permissionMessageLabel.numberOfLines = 0

        permissionButton.setTitle("Allow Photo Access", for: .normal)
        permissionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        permissionButton.addTarget(self, action: #selector(permissionButtonTapped), for: .touchUpInside)

        [permissionTitleLabel, permissionMessageLabel, permissionButton].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: permissionView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: permissionView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: permissionView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: permissionView.bottomAnchor, constant: -20)
        ])
    }

    private func requestAccessIfNeeded() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    self?.updatePermissionState()
                }
            }
        } else {
            updatePermissionState()
        }
    }

    private func updatePermissionState() {
        let canRead = authorizationStatus == .authorized || authorizationStatus == .limited
        permissionView.isHidden = canRead

        if canRead {
            loadAlbums()
            return
        }

        collectionView.isHidden = true
        switch authorizationStatus {
        case .denied:
            permissionMessageLabel.text = "Cafari Lite needs access to show your photos and videos here. You can enable access in Settings."
            permissionButton.setTitle("Open Settings", for: .normal)
        case .restricted:
            permissionMessageLabel.text = "Photo access is restricted on this device and can’t be changed here."
            permissionButton.isHidden = true
        default:
            permissionMessageLabel.text = "Allow access to fill this library with your real photos and videos."
            permissionButton.setTitle("Allow Photo Access", for: .normal)
        }
    }

    private func loadAlbums() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)

            var fetchedAlbums: [PhotoAlbum] = []
            let recents = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumUserLibrary,
                options: nil)
            if let collection = recents.firstObject {
                fetchedAlbums.append(PhotoAlbum(title: collection.localizedTitle ?? "Recents", collection: collection))
            }

            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil)
            userAlbums.enumerateObjects { collection, _, _ in
                let count = PHAsset.fetchAssets(in: collection, options: options).count
                if count > 0 {
                    fetchedAlbums.append(PhotoAlbum(title: collection.localizedTitle ?? "Album", collection: collection))
                }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.albums = fetchedAlbums
                self.selectedAlbumIndex = min(self.selectedAlbumIndex, max(0, fetchedAlbums.count - 1))
                self.reloadSelectedAlbum(with: options)
                self.buildTabs()
            }
        }
    }

    private func reloadSelectedAlbum(with options: PHFetchOptions? = nil) {
        guard let album = albums[safe: selectedAlbumIndex] else {
            assets = []
            collectionView.reloadData()
            return
        }

        let fetchOptions = options ?? PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
        assets = result.objects(at: IndexSet(integersIn: 0..<result.count))
        collectionView.isHidden = false
        collectionView.reloadData()
    }

    private func buildTabs() {
        tabsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !albums.isEmpty else { return }

        for (index, album) in albums.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(album.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: index == selectedAlbumIndex ? .bold : .medium)
            button.setTitleColor(index == selectedAlbumIndex ? .label : .secondaryLabel, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(albumSelected(_:)), for: .touchUpInside)
            tabsStack.addArrangedSubview(button)
        }
    }

    @objc private func albumSelected(_ sender: UIButton) {
        selectedAlbumIndex = sender.tag
        reloadSelectedAlbum()
        buildTabs()
    }

    @objc private func permissionButtonTapped() {
        if authorizationStatus == .denied {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } else if authorizationStatus == .limited {
            openPhotoSettings()
        } else {
            requestAccessIfNeeded()
        }
    }

    private func openPhotoSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func showMoreOptions() {
        let sheet = UIAlertController(title: "Library", message: nil, preferredStyle: .actionSheet)
        if authorizationStatus == .limited {
            sheet.addAction(UIAlertAction(title: "Manage Photo Access", style: .default) { [weak self] _ in
                self?.openPhotoSettings()
            })
        }
        sheet.addAction(UIAlertAction(title: "Refresh Library", style: .default) { [weak self] _ in
            self?.loadAlbums()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = moreButton
            popover.sourceRect = moreButton.bounds
        }
        present(sheet, animated: true)
    }
}

extension PhotoLibraryViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadAlbums()
        }
    }
}

extension PhotoLibraryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoAssetCell.reuseIdentifier,
            for: indexPath) as! PhotoAssetCell
        cell.configure(asset: assets[indexPath.item], imageManager: imageManager)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 7) / 3)
        return CGSize(width: width, height: width)
    }
}

private struct PhotoAlbum {
    let title: String
    let collection: PHAssetCollection
}

private final class PhotoAssetCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoAssetCell"
    private let imageView = UIImageView()
    private let durationLabel = UILabel()
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        durationLabel.textColor = .white
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        durationLabel.layer.shadowColor = UIColor.black.cgColor
        durationLabel.layer.shadowOpacity = 0.9
        durationLabel.layer.shadowRadius = 2
        durationLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(asset: PHAsset, imageManager: PHCachingImageManager) {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
        }

        imageView.image = UIImage(systemName: asset.mediaType == .video ? "video" : "photo")
        durationLabel.text = asset.mediaType == .video ? formatDuration(asset.duration) : nil

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 420, height: 420),
            contentMode: .aspectFill,
            options: options) { [weak self] image, _ in
                guard let image else { return }
                DispatchQueue.main.async {
                    self?.imageView.image = image
                }
            }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        durationLabel.text = nil
        requestID = PHInvalidImageRequestID
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
