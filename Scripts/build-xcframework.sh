#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
output="$root/.build/distribution"
mkdir -p "$output"
frameworks=()
labels=(macos ios ios-simulator)
destinations=('generic/platform=macOS' 'generic/platform=iOS' 'generic/platform=iOS Simulator')
for index in "${!labels[@]}"; do
    label="${labels[$index]}"
    printf 'Archiving %s\n' "$label"
    xcodebuild archive -project Distribution/NewsSearch.xcodeproj -scheme NewsSearch \
        -configuration Release -destination "${destinations[$index]}" \
        -archivePath "$output/$label.xcarchive" -derivedDataPath "$output/DerivedData" \
        CODE_SIGNING_ALLOWED=NO MARKETING_VERSION="$(cat VERSION)" > "$output/$label.log" 2>&1 || {
            tail -80 "$output/$label.log" >&2
            exit 1
        }
    frameworks+=(-framework "$output/$label.xcarchive/Products/Library/Frameworks/NewsSearch.framework")
done
rm -rf "$output/NewsSearch.xcframework"
xcodebuild -create-xcframework "${frameworks[@]}" -output "$output/NewsSearch.xcframework"
cp LICENSE COPYRIGHT THIRD_PARTY_NOTICES.md "$output/NewsSearch.xcframework/"

(cd "$output" && /usr/bin/ditto -c -k --keepParent NewsSearch.xcframework NewsSearch.xcframework.zip)
swift package compute-checksum "$output/NewsSearch.xcframework.zip" > "$output/checksum.txt"
printf 'Archive: %s/NewsSearch.xcframework.zip\nSHA-256: ' "$output"
cat "$output/checksum.txt"
