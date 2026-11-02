import UIKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case appearance
        case ambient
        case display
        case playback
        case diagnostics
        case legal
    }

    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.contentInset.bottom = 112
        tableView.verticalScrollIndicatorInsets.bottom = 112
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BasicCell")
        tableView.register(SettingsSwitchCell.self, forCellReuseIdentifier: SettingsSwitchCell.reuseIdentifier)
        tableView.register(SettingsDetailCell.self, forCellReuseIdentifier: SettingsDetailCell.reuseIdentifier)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 64))
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
        ])
        tableView.tableHeaderView = header

        appearanceControl.selectedSegmentIndex = min(max(Settings.appearanceIndex, 0), 2)
        appearanceControl.addAction(UIAction { [weak self] _ in self?.appearanceChanged() }, for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        return switch section {
        case .appearance, .ambient: 1
        case .display, .playback: 5
        case .diagnostics: 3
        case .legal: 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return switch section {
        case .appearance: "APPEARANCE"
        case .ambient: "AMBIENT"
        case .display: "CARPLAY DISPLAY"
        case .playback: "PLAYBACK & AUDIO"
        case .diagnostics: "DIAGNOSTICS & LOGS"
        case .legal: "LEGAL"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return switch section {
        case .ambient:
            "Projects dynamic blue ambient lighting behind the dock."
        case .display:
            "Wallpaper Shortcuts shows Maps, Music, Phone, and Dashboard next to your starred links."
        case .diagnostics:
            "Capture real-time playback events and UI states."
        default:
            nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .appearance:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
            cell.selectionStyle = .none
            var content = cell.defaultContentConfiguration()
            content.text = "Theme"
            cell.contentConfiguration = content
            cell.accessoryView = appearanceControl
            return cell
        case .ambient:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            cell.configure(
                title: "Ambient Light Sync",
                subtitle: "Dynamic blue edge glow",
                isOn: Settings.ambientLightSync
            ) { isOn in
                Settings.ambientLightSync = isOn
                Log.write("settings Ambient Light Sync=\(isOn)")
                NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
            }
            return cell
        case .display:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            let rows: [(String, String?, Bool, (Bool) -> Void)] = [
                ("Wallpaper Shortcuts", "Maps, Music, Phone, Dashboard", Settings.wallpaperShortcuts, {
                    Settings.wallpaperShortcuts = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Native CarPlay Resolution", "Pixel-perfect scaling", Settings.carNativeResolution, {
                    Settings.carNativeResolution = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Keep Clear of Sidebar", "Respect safe area", Settings.avoidSidebar, {
                    Settings.avoidSidebar = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Full-Screen Mode", "Hide CarPlay status bar", Settings.fullScreenCar, {
                    Settings.fullScreenCar = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Show Debug Border", "Green layout frame", Settings.debugBorder, {
                    Settings.debugBorder = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                })
            ]
            let row = rows[indexPath.row]
            cell.configure(title: row.0, subtitle: row.1, isOn: row.2) { isOn in
                row.3(isOn)
                Log.write("settings \(row.0)=\(isOn)")
            }
            return cell
        case .playback:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchCell.reuseIdentifier, for: indexPath) as! SettingsSwitchCell
            let rows: [(String, String?, Bool, (Bool) -> Void)] = [
                ("Play Only When Parked", "Pause when moving", Settings.playOnlyWhenParked, {
                    Settings.playOnlyWhenParked = $0
                    NotificationCenter.default.post(name: .cafariLiteSettingsChanged, object: nil)
                }),
                ("Autoplay Next Video", nil, Settings.autoplayNextVideo, {
                    Settings.autoplayNextVideo = $0
                }),
                ("Auto-Play YouTube Queue", nil, Settings.autoPlayYouTubeQueue, {
                    Settings.autoPlayYouTubeQueue = $0
                }),
                ("Mini Player", "Keep playing when collapsed", Settings.miniPlayer, {
                    Settings.miniPlayer = $0
                }),
                ("Show Captions", nil, Settings.showCaptions, {
                    Settings.showCaptions = $0
                })
            ]
            let row = rows[indexPath.row]
            cell.configure(title: row.0, subtitle: row.1, isOn: row.2) { isOn in
                row.3(isOn)
                Log.write("settings \(row.0)=\(isOn)")
            }
            return cell
        case .diagnostics:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsDetailCell.reuseIdentifier, for: indexPath) as! SettingsDetailCell
            let rows = [
                ("Playback errors", "\(SessionCounts.playbackErrorCount) this session"),
                ("Car Action Log", "\(SessionCounts.carActionCount) events"),
                ("Player Bug Catcher", "\(SessionCounts.playerFaultCount) faults")
            ]
            let row = rows[indexPath.row]
            cell.configure(title: row.0, detail: row.1)
            return cell
        case .legal:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = indexPath.row == 0 ? "Privacy Policy" : "Terms of Service"
            cell.contentConfiguration = content
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .diagnostics:
            let titles = ["Playback errors", "Car Action Log", "Player Bug Catcher"]
            let title = titles[indexPath.row]
            let slice = LogSlice(title: title)
            let count = slice.map { Log.lines(for: $0).count } ?? 0
            Log.write("settings diagnostics \(title) lines=\(count)")
            let viewer = UINavigationController(rootViewController: SettingsLogController(pageTitle: title))
            present(viewer, animated: true)
        case .legal:
            let title = indexPath.row == 0 ? "Privacy Policy" : "Terms of Service"
            Log.write("settings legal \(title)")
            let message = indexPath.row == 0
                ? "Cafari Lite keeps your saved links and settings on this device."
                : "Use CarPlay video features responsibly and only while parked where required by law."
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        default:
            break
        }
    }

    private func appearanceChanged() {
        Settings.appearanceIndex = appearanceControl.selectedSegmentIndex
        let names = ["System", "Light", "Dark"]
        let name = names.indices.contains(Settings.appearanceIndex) ? names[Settings.appearanceIndex] : "System"
        Log.write("settings theme \(name)")
        let style: UIUserInterfaceStyle = switch appearanceControl.selectedSegmentIndex {
        case 1: .light
        case 2: .dark
        default: .unspecified
        }
        view.window?.overrideUserInterfaceStyle = style
    }
}

private final class SettingsLogController: UIViewController {
    private let pageTitle: String
    private let slice: LogSlice?
    private let textView = UITextView()

    init(pageTitle: String) {
        self.pageTitle = pageTitle
        self.slice = LogSlice(title: pageTitle)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = pageTitle
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let lines = slice.map { Log.lines(for: $0) } ?? Log.allLines()
        textView.text = lines.isEmpty ? "No matching events yet." : lines.joined(separator: "\n")
    }
}

private final class SettingsSwitchCell: UITableViewCell {
    static let reuseIdentifier = "SettingsSwitchCell"
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryView = toggle
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(self.toggle.isOn)
        }, for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String?, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = title
        content.secondaryText = subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        contentConfiguration = content
        toggle.isOn = isOn
        self.onToggle = onToggle
    }
}

private final class SettingsDetailCell: UITableViewCell {
    static let reuseIdentifier = "SettingsDetailCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, detail: String) {
        var content = UIListContentConfiguration.valueCell()
        content.text = title
        content.secondaryText = detail
        content.secondaryTextProperties.color = .secondaryLabel
        contentConfiguration = content
    }
}
