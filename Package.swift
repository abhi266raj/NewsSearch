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
            url: "https://github.com/abhi266raj/NewsSearch/releases/download/artifacts-0.2.2/NewsSearch.xcframework.zip",
            checksum: "9c92728fcb659cf924d0ac0cc1fa285155cd6015612745f547c5b42c14f449e1"
        ),
        .target(name: "NewsSearchSource", path: "Sources/NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearchSource"])
    ],
    swiftLanguageModes: [.v6]
)
