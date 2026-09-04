// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BranchLinkSimulator",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Library product for the main app module
        .library(
            name: "BranchLinkSimulatorLib",
            targets: ["BranchLinkSimulatorLib"]
        )
    ],
    dependencies: [
        // BranchSDK dependency from GitHub
        .package(
            url: "https://github.com/BranchMetrics/ios-branch-deep-linking-attribution",
            branch: "master"
        )
    ],
    targets: [
        // Main library target containing app source code
        .target(
            name: "BranchLinkSimulatorLib",
            dependencies: [
                .product(name: "BranchSDK", package: "ios-branch-deep-linking-attribution")
            ],
            path: "BranchLinkSimulator",
            exclude: [
                "Info.plist",
                "BranchLinkSimulator.entitlements",
                "Assets.xcassets",
                "Preview Content"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Unit test target with Swift Testing framework
        .testTarget(
            name: "BranchLinkSimulatorTests",
            dependencies: [
                "BranchLinkSimulatorLib",
                .product(name: "BranchSDK", package: "ios-branch-deep-linking-attribution")
            ],
            path: "BranchLinkSimulatorTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
