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
            url: "https://github.com/abhi266raj/NewsSearch/releases/download/artifacts-0.2.0/NewsSearch.xcframework.zip",
            checksum: "19266e8b8869febc597d386445b059516bc133ed6541b7bd4c324cf744de3432"
        ),
        .target(name: "NewsSearchSource", path: "Sources/NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearchSource"])
    ],
    swiftLanguageModes: [.v6]
)
