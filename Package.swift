// swift-tools-version:5.9
// BotcampCore = platform-independent models + logic. `swift test` runs on macOS (and Linux).
// The iOS app itself is generated with XcodeGen (project.yml) and compiles these same sources.
import PackageDescription

let package = Package(
    name: "BotcampCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BotcampCore", targets: ["BotcampCore"])],
    targets: [
        .target(name: "BotcampCore", path: "Sources/BotcampCore"),
        .testTarget(name: "BotcampCoreTests", dependencies: ["BotcampCore"], path: "Tests/BotcampCoreTests"),
    ]
)
