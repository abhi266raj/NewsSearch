#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
source_commit="$(git rev-parse HEAD)"
artifact_tag="artifacts-$version"
repo="abhi266raj/NewsSearch"
archive=".build/distribution/NewsSearch.xcframework.zip"
checksum="$(cat .build/distribution/checksum.txt)"
test "$(swift package compute-checksum "$archive")" = "$checksum"
test -z "$(git status --porcelain)"
existing_tag="$(git rev-parse --verify "refs/tags/$version^{commit}" 2>/dev/null || true)"
notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT
cat > "$notes" <<TEXT
NewsSearch $version XCFramework artifact.

Corresponding source commit: $source_commit (merged main).
SHA-256: $checksum

Deployment targets: macOS 13 and iOS 16 (iPhone).
Three variants: universal Mac, iPhone device, and iOS Simulator.
AGPL-3.0-only; no third-party code dependencies.

Toolchain:
TEXT
cat .build/distribution/toolchain.txt >> "$notes"
if gh release view "$artifact_tag" --repo "$repo" > /dev/null 2>&1; then
    # Retry with the original bytes only for the same merged source commit.
    previous="$(mktemp -d)"
    gh release download "$artifact_tag" --repo "$repo" --pattern NewsSearch.xcframework.zip \
        --pattern checksum.txt --pattern toolchain.txt --dir "$previous"
    test "$(tail -1 "$previous/toolchain.txt")" = "$source_commit"
    checksum="$(cat "$previous/checksum.txt")"
    test "$(swift package compute-checksum "$previous/NewsSearch.xcframework.zip")" = "$checksum"
    cp "$previous/NewsSearch.xcframework.zip" "$previous/checksum.txt" "$previous/toolchain.txt" .build/distribution/
    rm -rf "$previous"
else
    gh release create "$artifact_tag" "$archive" .build/distribution/checksum.txt \
        .build/distribution/toolchain.txt --repo "$repo" --target "$source_commit" \
        --prerelease --title "NewsSearch $version binary artifact" --notes-file "$notes"
fi
# Only the generated tag commit changes; never push a commit to main.
swift Scripts/Release.swift manifest "$version" "$checksum" Package.swift
Scripts/verify-products.sh
if [ -n "$existing_tag" ]; then
    test "$(git rev-parse "$existing_tag^")" = "$source_commit"
    test "$(git show "$existing_tag:Package.swift")" = "$(cat Package.swift)"
else
    git add Package.swift
    git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
        -c commit.gpgsign=false commit -m "Release $version package manifest (source $source_commit)"
    git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
        -c tag.gpgsign=false tag -a "$version" -m "NewsSearch $version"
    git push origin "refs/tags/$version"
fi
Scripts/verify-products.sh "$version"
if gh release view "$version" --repo "$repo" > /dev/null 2>&1; then
    printf 'Release %s already published; nothing to replace.\n' "$version"
    exit 0
fi
cat > "$notes" <<TEXT
NewsSearch $version offers two SwiftPM products from the same package URL:

- **NewsSearch**: recommended precompiled dynamic XCFramework, import NewsSearch.
- **NewsSearchSource**: same implementation built from source, import NewsSearchSource.

Binary artifacts: https://github.com/$repo/releases/tag/$artifact_tag
Corresponding merged main source: $source_commit
Binary SHA-256: $checksum

See the artifact's toolchain.txt for the validated Xcode/Swift toolchain.
Both products require Swift 6.0+.
Deployment targets: macOS 13 and iOS 16.
Both variants remain AGPL-3.0-only. Choose one product per dependency graph.
Choose the source or binary product consistently within a dependency graph.
The tag includes a generated manifest commit whose parent is the merged source;
the protected main branch is not modified by the release workflow.
TEXT
gh release create "$version" --repo "$repo" --verify-tag --latest \
    --title "NewsSearch $version" --notes-file "$notes"
