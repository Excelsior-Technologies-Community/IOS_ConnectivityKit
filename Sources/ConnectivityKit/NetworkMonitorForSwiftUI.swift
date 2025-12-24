//
//  NetworkMonitorForSwiftUI.swift
//  ConnectivityKit
//
//  Created by Noman belim on 24/12/25.
//

import Foundation
import Network
import SwiftUI

@MainActor
public final class NetworkMonitorForSwiftUI: ObservableObject {
    
    public static let shared = NetworkMonitorForSwiftUI()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityKit.SwiftUI")
    
    @Published public private(set) var isConnected: Bool = false
    @Published public var showConnectedBanner: Bool = false
    
    private var isInitialUpdate = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let newStatus = (path.status == .satisfied)
                
                // On first update, just set initial state
                if self.isInitialUpdate {
                    self.isConnected = newStatus
                    self.isInitialUpdate = false
                    print("[ConnectivityKit SwiftUI] Initial status: \(newStatus ? "Connected" : "Disconnected")")
                    return
                }
                
                let wasConnected = self.isConnected
                self.isConnected = newStatus
                
                // Show green banner only on reconnect
                if !wasConnected && newStatus {
                    print("[ConnectivityKit SwiftUI] Reconnected - showing green banner")
                    self.showConnectedBanner = true
                    
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await MainActor.run {
                            self.showConnectedBanner = false
                        }
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - SwiftUI View Extension
public extension View {
    func networkOverlay() -> some View {
        modifier(NetworkOverlayModifier())
    }
}

// MARK: - Network Overlay Modifier
struct NetworkOverlayModifier: ViewModifier {
    
    @ObservedObject private var monitor = NetworkMonitorForSwiftUI.shared
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                // Red banner - stays visible while offline
                if !monitor.isConnected {
                    NetworkStatusBanner(
                        text: "No Internet Connection",
                        color: .red,
                        icon: "wifi.slash"
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Green banner - shows for 2 seconds on reconnect
                if monitor.showConnectedBanner {
                    NetworkStatusBanner(
                        text: "Internet Connected",
                        color: .green,
                        icon: "wifi"
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .animation(.spring(), value: monitor.isConnected)
            .animation(.easeInOut, value: monitor.showConnectedBanner)
            .zIndex(999)
        }
    }
}

// MARK: - Network Status Banner
struct NetworkStatusBanner: View {
    
    let text: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color)
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(radius: 6)
    }
}