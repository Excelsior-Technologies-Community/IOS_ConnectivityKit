import Foundation
import Network
import UIKit

// MARK: - Notification Extension
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Network Monitor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected: Bool = false
    private var hasStarted = false
    private var isInitialUpdate = true
    
    private init() {}
    
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newStatus = (path.status == .satisfied)
            
            DispatchQueue.main.async {
                // On first update, just set the initial state without notification
                if self.isInitialUpdate {
                    self.isConnected = newStatus
                    self.isInitialUpdate = false
                    print("Initial network status: \(newStatus ? "Connected" : "Disconnected")")
                    return
                }
                
                let oldStatus = self.isConnected
                
                // Only post notification if status actually changed
                guard newStatus != oldStatus else { return }
                
                self.isConnected = newStatus
                
                print("Network status changed - Was: \(oldStatus), Now: \(newStatus)")
                
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
    
    func stop() {
        monitor.cancel()
        hasStarted = false
    }
}

// MARK: - Network Banner Manager
final class NetworkBannerManager {
    static let shared = NetworkBannerManager()
    
    private var bannerWindow: UIWindow?
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
    
    func startMonitoring() {
        NetworkMonitor.shared.start()
    }
    
    @objc private func handleNetworkChange(_ notification: Notification) {
        guard
            let isConnected = notification.userInfo?["isConnected"] as? Bool,
            let wasConnected = notification.userInfo?["wasConnected"] as? Bool
        else { return }
        
        print("Network changed - Was: \(wasConnected), Now: \(isConnected)")
        
        // Lost internet connection
        if wasConnected && !isConnected {
            showOfflineBanner()
        }
        
        // Reconnected to internet
        if !wasConnected && isConnected {
            showOnlineBanner()
        }
    }
    // MARK: - Banner Display
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
    private func showBanner(
        text: String,
        color: UIColor,
        icon: String,
        autoDismiss: Bool
    ) {
        // Remove existing banner first
        hideBanner()
        
        print("Attempting to show banner: \(text)")
        
        // Get the key window from the active scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            print("Failed to get window scene or key window")
            return
        }
        
        // Create banner view
        let banner = NetworkBannerView(
            text: text,
            color: color,
            icon: icon
        )
        
        // Add directly to key window
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
        
        // Store reference
        self.bannerView = banner
        
        print("Banner added to window, animating in...")
        
        // Animate in
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -20)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.alpha = 1
            banner.transform = .identity
        } completion: { _ in
            print("Banner animation complete")
        }
        
        // Auto dismiss if needed
        if autoDismiss {
            print("Banner will auto-dismiss in 2 seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("Auto-dismissing banner")
                self?.hideBanner()
            }
        }
    }
    
    private func hideBanner() {
        guard let banner = bannerView else {
            print("No banner to hide")
            return
        }
        
        print("Hiding banner...")
        
        UIView.animate(withDuration: 0.3, animations: {
            banner.alpha = 0
            banner.transform = CGAffineTransform(translationX: 0, y: -20)
        }) { [weak self] _ in
            print("Banner hidden, removing from view")
            banner.removeFromSuperview()
            self?.bannerView = nil
            self?.bannerWindow?.isHidden = true
            self?.bannerWindow = nil
        }
    }
}

// MARK: - Network Banner View
final class NetworkBannerView: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()
    
    init(text: String, color: UIColor, icon: String) {
        super.init(frame: .zero)
        setupView(text: text, color: color, icon: icon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(text: String, color: UIColor, icon: String) {
        backgroundColor = color
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        
        // Setup icon
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup label
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
