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
    private var cellRegistration: UICollectionView.CellRegistration<PhotoAssetCell, PHAsset>!

    private var albums: [PhotoAlbum] = []
    private var assets: [PHAsset] = []
    private var selectedAlbumIndex = 0
    private var columnCount = 3
    private var pinchStartColumnCount = 3
    private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        PHPhotoLibrary.shared().register(self)
        imageManager.allowsCachingHighQualityImages = true
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
        moreButton.addAction(UIAction { [weak self] _ in self?.showMoreOptions() }, for: .touchUpInside)
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

        cellRegistration = UICollectionView.CellRegistration<PhotoAssetCell, PHAsset> { [weak self] cell, _, asset in
            guard let self else { return }
            let cellSide = max(cell.bounds.width, 1) * self.traitCollection.displayScale
            cell.configure(
                asset: asset,
                imageManager: self.imageManager,
                targetSize: CGSize(width: cellSide, height: cellSide))
        }

        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 2, bottom: 112, right: 2)
        collectionView.verticalScrollIndicatorInsets = collectionView.contentInset
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.setCollectionViewLayout(makeGridLayout(columns: columnCount), animated: false)
        collectionView.addGestureRecognizer(UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))))
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

    private func makeGridLayout(columns: Int) -> UICollectionViewLayout {
        let spacing: CGFloat = 2
        let fraction = 1 / CGFloat(columns)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(fraction),
            heightDimension: .fractionalWidth(1))
        let items = (0..<columns).map { _ in
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(
                top: spacing / 2,
                leading: spacing / 2,
                bottom: spacing / 2,
                trailing: spacing / 2)
            return item
        }

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalWidth(fraction))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: items)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 2,
            bottom: 0,
            trailing: 2)
        return UICollectionViewCompositionalLayout(section: section)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pinchStartColumnCount = columnCount
        case .ended, .cancelled:
            let nextColumnCount = if gesture.scale > 1.12 {
                max(2, pinchStartColumnCount - 1)
            } else if gesture.scale < 0.88 {
                min(5, pinchStartColumnCount + 1)
            } else {
                columnCount
            }

            guard nextColumnCount != columnCount else { return }
            columnCount = nextColumnCount
            collectionView.setCollectionViewLayout(
                makeGridLayout(columns: columnCount),
                animated: true)
        default:
            break
        }
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
        permissionButton.addAction(UIAction { [weak self] _ in self?.permissionButtonTapped() }, for: .touchUpInside)

        [permissionTitleLabel, permissionMessageLabel, permissionButton].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: permissionView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: permissionView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: permissionView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: permissionView.bottomAnchor, constant: -20)
        ])
    }

    private func photoAccessLabel() -> String {
        switch authorizationStatus {
        case .authorized: "authorized"
        case .limited: "limited"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "notDetermined"
        @unknown default: "unknown"
        }
    }

    private func requestAccessIfNeeded() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .notDetermined {
            Log.write("library photos requesting")
            Task { @MainActor [weak self] in
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                self?.authorizationStatus = status
                self?.updatePermissionState()
            }
        } else {
            updatePermissionState()
        }
    }

    private func updatePermissionState() {
        Log.write("library photos \(photoAccessLabel())")
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
        Task { [weak self] in
            let (fetchedAlbums, summary) = await Task.detached(priority: .userInitiated) {
                let options = Self.defaultFetchOptions()
                var fetchedAlbums: [PhotoAlbum] = []
                var notes: [String] = []
                let recents = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .smartAlbumUserLibrary,
                    options: nil)
                if let collection = recents.firstObject {
                    let title = collection.localizedTitle ?? "Recents"
                    let count = PHAsset.fetchAssets(in: collection, options: options).count
                    fetchedAlbums.append(PhotoAlbum(title: title, collection: collection))
                    notes.append("\(title)=\(count)")
                }

                let userAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: nil)
                userAlbums.enumerateObjects { collection, _, _ in
                    let title = collection.localizedTitle ?? "Album"
                    let count = PHAsset.fetchAssets(in: collection, options: options).count
                    if count > 0 {
                        fetchedAlbums.append(PhotoAlbum(title: title, collection: collection))
                        notes.append("\(title)=\(count)")
                    }
                }

                let summary = notes.isEmpty ? "none" : notes.joined(separator: ", ")
                return (fetchedAlbums, summary)
            }.value

            guard let self else { return }
            Log.write("library albums \(summary)")
            self.albums = fetchedAlbums
            self.selectedAlbumIndex = min(self.selectedAlbumIndex, max(0, fetchedAlbums.count - 1))
            self.reloadSelectedAlbum()
            self.buildTabs()
        }
    }

    nonisolated private static func defaultFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue)
        return options
    }

    private func reloadSelectedAlbum(with options: PHFetchOptions? = nil) {
        guard let album = albums[safe: selectedAlbumIndex] else {
            assets = []
            collectionView.reloadData()
            Log.write("library show no album")
            return
        }

        let fetchOptions = options ?? Self.defaultFetchOptions()
        let result = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
        let thumbnailSize = CGSize(width: 420, height: 420)
        if !self.assets.isEmpty {
            self.imageManager.stopCachingImages(
                for: self.assets,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: nil)
        }
        self.assets = result.objects(at: IndexSet(integersIn: 0..<result.count))
        self.imageManager.startCachingImages(
            for: self.assets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: nil)
        self.collectionView.isHidden = false
        self.collectionView.reloadData()
        Log.write("library show \(album.title) assets=\(self.assets.count)")
    }

    private func buildTabs() {
        tabsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !albums.isEmpty else { return }

        for (index, album) in albums.enumerated() {
            let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                let title = self.albums[safe: index]?.title ?? "-"
                Log.write("library album \(title)")
                self.selectedAlbumIndex = index
                self.reloadSelectedAlbum()
                self.buildTabs()
            })
            button.setTitle(album.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: index == selectedAlbumIndex ? .bold : .medium)
            button.setTitleColor(index == selectedAlbumIndex ? .label : .secondaryLabel, for: .normal)
            tabsStack.addArrangedSubview(button)
        }
    }

    private func permissionButtonTapped() {
        Log.write("library permission button \(photoAccessLabel())")
        if authorizationStatus == .denied || authorizationStatus == .limited {
            openPhotoSettings()
        } else {
            requestAccessIfNeeded()
        }
    }

    private func openPhotoSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func showMoreOptions() {
        Log.write("library more options")
        let sheet = UIAlertController(title: "Library", message: nil, preferredStyle: .actionSheet)
        if authorizationStatus == .limited {
            sheet.addAction(UIAlertAction(title: "Manage Photo Access", style: .default) { [weak self] _ in
                Log.write("library more manage access")
                self?.openPhotoSettings()
            })
        }
        sheet.addAction(UIAlertAction(title: "Refresh Library", style: .default) { [weak self] _ in
            Log.write("library more refresh")
            self?.loadAlbums()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            Log.write("library more cancel")
        })
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = moreButton
            popover.sourceRect = moreButton.bounds
        }
        present(sheet, animated: true)
    }
}

extension PhotoLibraryViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Log.write("library photos changed")
            self.loadAlbums()
        }
    }
}

extension PhotoLibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(
            using: cellRegistration,
            for: indexPath,
            item: assets[indexPath.item]
        )
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = assets[safe: indexPath.item] else { return }
        let kind = switch asset.mediaType {
        case .video: "video"
        case .image: "image"
        case .audio: "audio"
        case .unknown: "unknown"
        @unknown default: "other"
        }
        let album = albums[safe: selectedAlbumIndex]?.title ?? "-"
        Log.write("library tile \(kind) index=\(indexPath.item) album=\(album)")
        guard asset.mediaType == .video else { return }
        let videos = assets.filter { $0.mediaType == .video }
        let clips = videos.map { item -> ControllerClip in
            let name = PHAssetResource.assetResources(for: item).first?.originalFilename ?? "Video"
            return ControllerClip(
                title: name,
                posterURL: nil,
                pageURL: nil,
                duration: item.duration,
                assetLocalIdentifier: item.localIdentifier)
        }
        let index = videos.firstIndex(of: asset) ?? 0
        NotificationCenter.default.post(
            name: .cafariLiteOpenController,
            object: nil,
            userInfo: [
                "clips": clips,
                "index": index,
                "onCar": true,
                "tracksQueue": false,
                "send": true,
            ])
    }
}

private struct PhotoAlbum: Sendable {
    let title: String
    let collection: PHAssetCollection
}

private final class PhotoAssetCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let durationLabel = UILabel()
    private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private weak var imageManager: PHCachingImageManager?
    private var representedAssetIdentifier: String?

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

    func configure(
        asset: PHAsset,
        imageManager: PHCachingImageManager,
        targetSize: CGSize
    ) {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
        }

        self.imageManager = imageManager
        representedAssetIdentifier = asset.localIdentifier
        imageView.image = UIImage(systemName: asset.mediaType == .video ? "video" : "photo")
        durationLabel.text = asset.mediaType == .video ? formatDuration(asset.duration) : nil

        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options) { [weak self] image, _ in
                guard let image else { return }
                DispatchQueue.main.async {
                    guard let self,
                          self.representedAssetIdentifier == asset.localIdentifier else { return }
                    self.imageView.image = image
                }
            }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if requestID != PHInvalidImageRequestID {
            imageManager?.cancelImageRequest(requestID)
        }
        requestID = PHInvalidImageRequestID
        representedAssetIdentifier = nil
        imageView.image = nil
        durationLabel.text = nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        return Duration.seconds(total).formatted(
            .time(pattern: total >= 3600 ? .hourMinuteSecond : .minuteSecond)
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
