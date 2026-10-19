// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewsSearch",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "NewsSearch", targets: ["NewsSearch"])],
    targets: [
        .target(name: "NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearch"])
    ]
)
