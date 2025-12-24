import Foundation
import Network
import UIKit

// MARK: - Notification Name (Public)
public extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Network Monitor
public final class NetworkMonitor {

    // MARK: Singleton
    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityKit.NetworkMonitor")

    public private(set) var isConnected: Bool = false

    private var hasStarted = false
    private var isInitialUpdate = true

    private init() {}

    // MARK: Start Monitoring (Public)
    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let newStatus = (path.status == .satisfied)

            DispatchQueue.main.async {
                // Initial state (no banner / notification)
                if self.isInitialUpdate {
                    self.isConnected = newStatus
                    self.isInitialUpdate = false
                    return
                }

                let oldStatus = self.isConnected
                guard newStatus != oldStatus else { return }

                self.isConnected = newStatus

                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: [
                        "isConnected": newStatus,
                        "wasConnected": oldStatus
                    ]
                )
            }
        }

        monitor.start(queue: queue)
    }

    // MARK: Stop Monitoring (Public)
    public func stop() {
        monitor.cancel()
        hasStarted = false
    }
}

// MARK: - Network Banner Manager
public final class NetworkBannerManager {

    // MARK: Singleton
    public static let shared = NetworkBannerManager()

    private var bannerView: NetworkBannerView?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkChange(_:)),
            name: .networkStatusChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Entry Point (Public)
    public func startMonitoring() {
        NetworkMonitor.shared.start()
    }

    // MARK: Network Change Handler
    @objc private func handleNetworkChange(_ notification: Notification) {
        guard
            let isConnected = notification.userInfo?["isConnected"] as? Bool,
            let wasConnected = notification.userInfo?["wasConnected"] as? Bool
        else { return }

        if wasConnected && !isConnected {
            showOfflineBanner()
        }

        if !wasConnected && isConnected {
            showOnlineBanner()
        }
    }

    // MARK: Banner Types
    private func showOfflineBanner() {
        showBanner(
            text: "No Internet Connection",
            color: .systemRed,
            icon: "wifi.slash",
            autoDismiss: false
        )
    }

    private func showOnlineBanner() {
        showBanner(
            text: "Internet Connected",
            color: .systemGreen,
            icon: "wifi",
            autoDismiss: true
        )
    }

    // MARK: Banner Presentation
    private func showBanner(
        text: String,
        color: UIColor,
        icon: String,
        autoDismiss: Bool
    ) {
        hideBanner()

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let banner = NetworkBannerView(
            text: text,
            color: color,
            icon: icon
        )

        keyWindow.addSubview(banner)

        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(
                equalTo: keyWindow.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            banner.leadingAnchor.constraint(
                equalTo: keyWindow.leadingAnchor,
                constant: 16
            ),
            banner.trailingAnchor.constraint(
                equalTo: keyWindow.trailingAnchor,
                constant: -16
            )
        ])

        self.bannerView = banner

        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -20)

        UIView.animate(withDuration: 0.3) {
            banner.alpha = 1
            banner.transform = .identity
        }

        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.hideBanner()
            }
        }
    }

    private func hideBanner() {
        guard let banner = bannerView else { return }

        UIView.animate(withDuration: 0.25, animations: {
            banner.alpha = 0
            banner.transform = CGAffineTransform(translationX: 0, y: -20)
        }) { [weak self] _ in
            banner.removeFromSuperview()
            self?.bannerView = nil
        }
    }
}

// MARK: - Banner View
public final class NetworkBannerView: UIView {

    private let iconView = UIImageView()
    private let label = UILabel()

    // MARK: Public Initializer
    public init(text: String, color: UIColor, icon: String) {
        super.init(frame: .zero)
        setup(text: text, color: color, icon: icon)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(text: String, color: UIColor, icon: String) {
        backgroundColor = color
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 48)
        ])
    }
}
