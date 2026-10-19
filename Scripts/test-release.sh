#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
test "$(swift Scripts/Release.swift compare 0.1.0 0.0.1)" = true
test "$(swift Scripts/Release.swift compare 0.1.0 0.1.0)" = false
test "$(swift Scripts/Release.swift compare 0.10.0 0.9.9)" = true
for pair in '0.0.1 0.1.0' '01.0.0 0.0.1' '0.1 0.0.1' '0.1.0-rc.1 0.0.1'; do
    read -r next previous <<< "$pair"
    if swift Scripts/Release.swift compare "$next" "$previous" > /dev/null 2>&1; then
        printf 'Unexpected accepted version: %s\n' "$pair" >&2; exit 1
    fi
done
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cp Package.swift "$manifest"
checksum=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
swift Scripts/Release.swift manifest 0.1.0 "$checksum" "$manifest"
/usr/bin/grep -Fq "releases/download/artifacts-0.1.0/NewsSearch.xcframework.zip" "$manifest"
/usr/bin/grep -Fq "checksum: \"$checksum\"" "$manifest"
if swift Scripts/Release.swift manifest 0.1.0 invalid "$manifest" > /dev/null 2>&1; then exit 1; fi
printf 'Release version and manifest checks passed.\n'
