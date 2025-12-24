//
//  NetworkMonitor.swift
//  DeliveryTracking
//
//  Created by Noman belim on 24/12/25.
//

import Foundation
import Network
import SwiftUI
@MainActor
public final class NetworkMonitor: ObservableObject {

    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published public private(set) var isConnected: Bool = true
    @Published public var showConnectedBanner: Bool = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }

                let wasConnected = self.isConnected
                let nowConnected = (path.status == .satisfied)

                self.isConnected = nowConnected

                // ✅ Show GREEN banner only on reconnect
                if !wasConnected && nowConnected {
                    self.showConnectedBanner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showConnectedBanner = false
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}
extension View {
    func networkOverlay() -> some View {
        modifier(NetworkOverlay())
    }
}

struct NetworkOverlay: ViewModifier {

    @ObservedObject private var monitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                // 🔴 OFFLINE (persistent)
                if !monitor.isConnected {
                    NetworkStatusBanner(
                        text: "No Internet Connection",
                        color: .red,
                        icon: "wifi.slash"
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 🟢 ONLINE (2 seconds only)
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
        .shadow(radius: 6)
    }
}
  

