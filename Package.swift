// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConnectivityKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ConnectivityKit",
            targets: ["ConnectivityKit"]
        )
    ],
    targets: [
        .target(
            name: "ConnectivityKit",
            path: "Sources/ConnectivityKit",
            swiftSettings: [
                // Enables SwiftUI + UIKit coexistence cleanly
                .define("SPM_BUILD")
            ]
        )
    ]
)
