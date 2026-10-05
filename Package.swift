// swift-tools-version:5.9
import PackageDescription

// Pure-logic targets only, so `swift test` runs anywhere (Linux, macOS) without a simulator or Instagram.
// The iOS app is built from project.yml via XcodeGen and compiles these same source folders.
let package = Package(
    name: "InstagramUtilityCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: [
        .target(name: "RoutePolicy", path: "Sources/RoutePolicy"),
        .target(name: "DesignTokens", path: "Sources/DesignTokens"),
        .target(name: "Core", path: "Sources/Core"),
        .testTarget(name: "RoutePolicyTests", dependencies: ["RoutePolicy"], path: "Tests/RoutePolicyTests"),
        .testTarget(name: "DesignTokensTests", dependencies: ["DesignTokens"], path: "Tests/DesignTokensTests"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests"),
    ]
)
