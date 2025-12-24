//
//  NetworkMonitor.swift
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
    @Published public private(set) var isReady: Bool = false

    @Published public private(set) var isConnected: Bool = true
    @Published public var showConnectedBanner: Bool = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let newStatus = (path.status == .satisfied)

                // First update: set state silently
                if !self.isReady {
                    self.isConnected = newStatus
                    self.isReady = true
                    return
                }

                let wasConnected = self.isConnected
                self.isConnected = newStatus

                // Show green banner only on reconnect
                if !wasConnected && newStatus {
                    self.showConnectedBanner = true

                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            self.showConnectedBanner = false
                        }
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
                if monitor.isReady && !monitor.isConnected {
                    NetworkStatusBanner(
                        text: "No Internet Connection",
                        color: .red,
                        icon: "wifi.slash"
                    )
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
  

