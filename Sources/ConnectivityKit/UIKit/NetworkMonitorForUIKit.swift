import Foundation
import Network
import UIKit

// MARK: - Notification Extension
public extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Network Monitor
public final class NetworkMonitor {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    public private(set) var isConnected: Bool = false
    private var hasStarted = false
    private var isInitialUpdate = true
    
    private init() {}
    
    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newStatus = (path.status == .satisfied)
            
            DispatchQueue.main.async {
                if self.isInitialUpdate {
                    self.isConnected = newStatus
                    self.isInitialUpdate = false
                    print("✅ Initial network status: \(newStatus ? "Connected" : "Disconnected")")
                    return
                }
                
                let oldStatus = self.isConnected
                guard newStatus != oldStatus else { return }
                
                self.isConnected = newStatus
                print("🔄 Network status changed - Was: \(oldStatus), Now: \(newStatus)")
                
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
    
    public func stop() {
        monitor.cancel()
        hasStarted = false
    }
}

// MARK: - Network Banner Manager
public final class NetworkBannerManager {
    public static let shared = NetworkBannerManager()
    
    private var currentBanner: NetworkBannerView?
    private var autoDismissTimer: Timer?
    
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
        autoDismissTimer?.invalidate()
    }
    
    public func startMonitoring() {
        NetworkMonitor.shared.start()
    }
    
    @objc private func handleNetworkChange(_ notification: Notification) {
        guard
            let isConnected = notification.userInfo?["isConnected"] as? Bool,
            let wasConnected = notification.userInfo?["wasConnected"] as? Bool
        else { return }
        
        print("📡 Network changed - Was: \(wasConnected), Now: \(isConnected)")
        
        if wasConnected && !isConnected {
            showOfflineBanner()
        }
        
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
        // Cancel any existing timer
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        
        // Remove existing banner immediately
        if let existing = currentBanner {
             existing.removeFromSuperview()
            currentBanner = nil
        }
         
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            print("❌ Failed to get key window")
            return
        }
        
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
        
        currentBanner = banner
        
        // Animate in
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.alpha = 1
            banner.transform = .identity
        } completion: { [weak self] finished in
            guard finished else { return }
          
            // Set up auto-dismiss with Timer
            if autoDismiss {
                 self?.autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                     self?.hideBannerAnimated()
                }
            }
        }
    }
    
    private func hideBannerAnimated() {
        guard let banner = currentBanner else {
             return
        }
         
        // Invalidate timer
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        
        UIView.animate(withDuration: 0.3, animations: {
            banner.alpha = 0
            banner.transform = CGAffineTransform(translationX: 0, y: -20)
        }) { [weak self] finished in
            guard finished else { return }
             banner.removeFromSuperview()
            self?.currentBanner = nil
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
        
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
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
