#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
consumer="$(mktemp -d "${TMPDIR:-/tmp}/newssearch-platforms.XXXXXX")"
trap 'rm -rf "$consumer"' EXIT
identity="$(basename "$root" | tr '[:upper:]' '[:lower:]')"
mkdir -p "$consumer/Sources/Consumer"
cat > "$consumer/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PlatformConsumer", platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "PlatformConsumer", targets: ["Consumer"])],
    dependencies: [.package(path: "$root")],
    targets: [.target(name: "Consumer", dependencies: [.product(name: "NewsSearch", package: "$identity")])],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > "$consumer/Sources/Consumer/Consumer.swift" <<'SWIFT'
import NewsSearch
public func check() async throws -> [NewsArticle] { try await NewsSearchClient().search("India", limit: 1) }
SWIFT
platforms="$(swift Scripts/ArtifactPlatforms.swift)"
while read -r sdk triple; do
    architecture="${triple%%-apple-*}"
    case "$sdk" in
        macosx) destination='generic/platform=macOS' ;;
        iphoneos) destination='generic/platform=iOS' ;;
        iphonesimulator) destination='generic/platform=iOS Simulator' ;;
        *) exit 1 ;;
    esac
    (cd "$consumer" && xcodebuild -scheme PlatformConsumer -configuration Debug \
        -destination "$destination" ARCHS="$architecture" ONLY_ACTIVE_ARCH=NO \
        -derivedDataPath "$consumer/DerivedData" CODE_SIGNING_ALLOWED=NO build) \
        > "$consumer/$triple.log" 2>&1 || { tail -80 "$consumer/$triple.log" >&2; exit 1; }
done <<< "$platforms"
