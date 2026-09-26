// swift-tools-version:5.9
import PackageDescription

// This package exists ONLY so the pure-logic route policy can be unit tested with `swift test`
// (no simulator, no Instagram). The app itself is built from project.yml via XcodeGen.
let package = Package(
    name: "RoutePolicy",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: [
        .target(name: "RoutePolicy", path: "Sources/RoutePolicy"),
        .testTarget(name: "RoutePolicyTests", dependencies: ["RoutePolicy"], path: "Tests/RoutePolicyTests"),
    ]
)
