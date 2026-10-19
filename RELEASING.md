# Releasing

The only integration branch is **main**. There is no develop branch. Main stays
locked, including for administrators; only the owner may approve an update,
temporarily unlock it for the merge, and immediately restore the lock. Never
allow force pushes or deletion or grant outsiders direct write access.

## Automatic release on a version increase

`VERSION` is the release trigger. For this update it is **0.1.0**. Include an
increased stable `MAJOR.MINOR.PATCH` value in the feature PR when a release is
wanted, and update README, CHANGELOG, and the example's displayed version.
Normal merges that leave VERSION unchanged run CI without publishing. Decreases,
leading zeroes, malformed versions, and prerelease suffixes fail validation.

When the owner merges a version increase into main, CI automatically:

1. Builds the three Mac/iPhone XCFramework destinations with library evolution and @rpath,
   using the same sources as NewsSearchSource, and records toolchain/source SHA.
2. Runs the deterministic source suite, isolated public consumer tests for both
   products, binary compilation across the shipped architectures, and platform consumer builds.
3. Publishes the immutable binary asset in the prerelease `artifacts-VERSION`.
   It includes the archive, SHA-256, source commit, toolchain, and license notices.
4. Generates a release-only Package.swift with that public URL and checksum, and
   tests both products again as separate consumers against the public download.
5. Creates a generated manifest commit whose parent is the verified merged source,
   tags it with VERSION, and publishes the matching GitHub Release as latest.

The workflow uses a job-scoped contents-write GitHub token for publication; PR
jobs are read-only. It does not push a commit to main or unlock any protection.
The tag includes the complete corresponding source and docs; only its manifest
changes from its main parent. The asset tag is not a semantic SwiftPM version.

Release tags/assets are never replaced. A retry can reuse the original binary
only if its recorded source SHA matches, and can finish publishing a tag only if
its parent and manifest match. Fixes need a new version once released. Inspect
failed CI logs before rerunning. Workflow dispatch runs validation only.

## Working from a development checkout

The main/feature manifest references the locally built XCFramework. Run
`Scripts/build-xcframework.sh` before SwiftPM resolution, source tests, or opening
the demo from a checkout. Published semantic tags instead reference the remote
archive, so package consumers do not build or stage a framework themselves.
See [distribution guidance](Distribution/README.md) for local verification.

The initial release is 0.1.0; release tags and assets are immutable.
