#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
version="${1:-}"
identity="$(basename "$root" | tr '[:upper:]' '[:lower:]')"
dependency=".package(path: \"$root\")"
if [ -n "$version" ]; then
    swift Scripts/Release.swift compare "$version" 0.0.0 > /dev/null
    dependency=".package(url: \"https://github.com/abhi266raj/NewsSearch.git\", exact: \"$version\")"
    identity=newssearch
fi
for product in NewsSearch NewsSearchSource; do
    consumer="$(mktemp -d "${TMPDIR:-/tmp}/newssearch-consumer.XXXXXX")"
    trap 'rm -rf "$consumer"' EXIT
    mkdir -p "$consumer/Tests/ConsumerTests"
    for file in "$root"/Tests/NewsSearchTests/*.swift; do
        sed "s/import NewsSearchSource/import $product/" "$file" > "$consumer/Tests/ConsumerTests/$(basename "$file")"
    done
    cat > "$consumer/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "DistributionConsumer", platforms: [.macOS(.v13)],
    dependencies: [$dependency],
    targets: [.testTarget(name: "ConsumerTests", dependencies: [.product(name: "$product", package: "$identity")])],
    swiftLanguageModes: [.v6]
)
SWIFT
    swift test --package-path "$consumer"
    rm -rf "$consumer"
    trap - EXIT
done
