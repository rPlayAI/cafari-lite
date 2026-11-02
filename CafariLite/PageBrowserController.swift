// The phone page a Links row opens. It does not send to the car.
// The caller sends when the mode says to.

import AVKit
import UIKit
import WebKit

final class PageBrowserController: UIViewController, WKNavigationDelegate {
  private let startURL: URL
  private let pageTitle: String
  private var webView: WKWebView!

  init(url: URL, title: String) {
    self.startURL = url
    self.pageTitle = title
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let bar = UIStackView()
    bar.axis = .horizontal
    bar.alignment = .center
    bar.spacing = 12
    bar.isLayoutMarginsRelativeArrangement = true
    bar.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    bar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bar)

    let close = UIButton(type: .system)
    close.setTitle("Close", for: .normal)
    close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    let back = UIButton(type: .system)
    back.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
    back.accessibilityLabel = "Previous"
    back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    let forward = UIButton(type: .system)
    forward.setImage(UIImage(systemName: "chevron.forward"), for: .normal)
    forward.accessibilityLabel = "Next"
    forward.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
    let title = UILabel()
    title.text = pageTitle
    title.font = .systemFont(ofSize: 15, weight: .semibold)
    title.lineBreakMode = .byTruncatingTail
    bar.addArrangedSubview(close)
    bar.addArrangedSubview(back)
    bar.addArrangedSubview(forward)
    bar.addArrangedSubview(title)

    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)

    NSLayoutConstraint.activate([
      bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.topAnchor.constraint(equalTo: bar.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    webView.load(URLRequest(url: startURL))
  }

  @objc private func closeTapped() { dismiss(animated: true) }
  @objc private func backTapped() { webView.goBack() }
  @objc private func forwardTapped() { webView.goForward() }
}

enum PhonePlaybackPresenter {
  static func make(url: URL, title: String, direct: Bool) -> UIViewController {
    if direct, isMedia(url) {
      let controller = AVPlayerViewController()
      let player = AVPlayer(url: url)
      controller.player = player
      player.play()
      return controller
    }
    return PageBrowserController(url: url, title: title)
  }

  private static func isMedia(_ url: URL) -> Bool {
    let value = url.absoluteString.lowercased()
    return value.contains(".m3u8") || value.hasSuffix(".mp4") || value.hasSuffix(".mov")
  }
}
