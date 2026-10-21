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
        .binaryTarget(
            name: "NewsSearch",
            url: "https://github.com/abhi266raj/NewsSearch/releases/download/artifacts-0.2.1/NewsSearch.xcframework.zip",
            checksum: "90c3c9c3bf0133a0bb22a24862dc3f22b21b00d4e4ad6226feef54a26d3d05af"
        ),
        .target(name: "NewsSearchSource", path: "Sources/NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearchSource"])
    ],
    swiftLanguageModes: [.v6]
)
