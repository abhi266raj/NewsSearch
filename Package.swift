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
            url: "https://github.com/abhi266raj/NewsSearch/releases/download/artifacts-0.1.0/NewsSearch.xcframework.zip",
            checksum: "750bf4a8c38bb852d94e79c0fc9e6adb42fbfe6f5beb50aee5ca0952b1ad36a3"
        ),
        .target(name: "NewsSearchSource", path: "Sources/NewsSearch"),
        .testTarget(name: "NewsSearchTests", dependencies: ["NewsSearchSource"])
    ],
    swiftLanguageModes: [.v6]
)
