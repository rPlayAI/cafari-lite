import UIKit

final class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let appearanceControl = UISegmentedControl(items: ["System", "Light", "Dark"])

    private let sections: [(String, [(String, String, Bool)])] = [
        ("Photos", [
            ("Photos Access", "Use your library for videos on the car display", false)
        ]),
        ("Playback", [
            ("Autoplay Next Video", "", true),
            ("Mini Player", "", true),
            ("Show Captions", "", false),
            ("Ambient Light Sync", "", true)
        ]),
        ("CarPlay", [
            ("Car Display", "Connect a CarPlay display to continue", false),
            ("Auto-Play YouTube Queue", "", true),
            ("Wallpaper shortcuts", "", true),
            ("Full-screen car screen", "Experimental", false)
        ]),
        ("Diagnostics", [
            ("Playback errors", "0", false),
            ("Car Action Log", "0", false),
            ("Player Bug Catcher", "0", false)
        ])
    ]

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "Settings"
        navigationController?.setNavigationBarHidden(false, animated: false)

        appearanceControl.selectedSegmentIndex = Settings.appearanceIndex
        appearanceControl.addTarget(self, action: #selector(appearanceChanged), for: .valueChanged)
        navigationItem.titleView = nil

        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingsSwitchCell.self, forCellReuseIdentifier: SettingsSwitchCell.reuseIdentifier)
        tableView.register(SettingsDetailCell.self, forCellReuseIdentifier: SettingsDetailCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func appearanceChanged() {
        Settings.appearanceIndex = appearanceControl.selectedSegmentIndex
        let style: UIUserInterfaceStyle
        switch appearanceControl.selectedSegmentIndex {
        case 1: style = .light
        case 2: style = .dark
        default: style = .unspecified
        }
        view.window?.overrideUserInterfaceStyle = style
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count + 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Appearance" : sections[section - 1].0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : sections[section - 1].1.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Theme"
            cell.textLabel?.textColor = .label
            cell.accessoryView = appearanceControl
            return cell
        }

        let definition = sections[indexPath.section - 1].1[indexPath.row]
        if definition.2 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsSwitchCell.reuseIdentifier,
                for: indexPath) as! SettingsSwitchCell
            cell.configure(title: definition.0, detail: definition.1, isOn: switchValue(for: definition.0))
            cell.onChanged = { [weak self] isOn in
                self?.setSwitchValue(isOn, for: definition.0)
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: SettingsDetailCell.reuseIdentifier,
            for: indexPath) as! SettingsDetailCell
        cell.configure(title: definition.0, detail: definition.1)
        return cell
    }

    private func switchValue(for title: String) -> Bool {
        switch title {
        case "Ambient Light Sync": return Settings.ambientLightSync
        case "Auto-Play YouTube Queue": return Settings.autoPlayYouTubeQueue
        case "Wallpaper shortcuts": return Settings.wallpaperShortcuts
        default: return true
        }
    }

    private func setSwitchValue(_ value: Bool, for title: String) {
        switch title {
        case "Ambient Light Sync": Settings.ambientLightSync = value
        case "Auto-Play YouTube Queue": Settings.autoPlayYouTubeQueue = value
        case "Wallpaper shortcuts": Settings.wallpaperShortcuts = value
        default: break
        }
    }
}

private final class SettingsSwitchCell: UITableViewCell {
    static let reuseIdentifier = "SettingsSwitchCell"
    private let detailLabel = UILabel()
    private let toggle = UISwitch()
    var onChanged: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.textColor = .label
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        accessoryView = toggle
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String, isOn: Bool) {
        textLabel?.text = title
        detailLabel.text = detail.isEmpty ? nil : detail
        textLabel?.numberOfLines = detail.isEmpty ? 1 : 2
        toggle.isOn = isOn
    }

    @objc private func toggleChanged() {
        onChanged?(toggle.isOn)
    }
}

private final class SettingsDetailCell: UITableViewCell {
    static let reuseIdentifier = "SettingsDetailCell"
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.textColor = .label
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .right
        detailLabel.numberOfLines = 2
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textLabel!.trailingAnchor, constant: 8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String) {
        textLabel?.text = title
        detailLabel.text = detail
        accessoryType = detail.isEmpty ? .disclosureIndicator : .none
    }
}
