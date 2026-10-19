// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewsSearch",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "NewsSearch", targets: ["NewsSearch"]),
        .library(name: "NewsSearchSource", targets: ["NewsSearchSource"])
    ],
    targets: [
        .binaryTarget(name: "NewsSearch", path: ".build/distribution/NewsSearch.xcframework"),
        .target(name: "NewsSearchSource", path: "Sources/NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearchSource"])
    ],
    swiftLanguageModes: [.v6]
)
