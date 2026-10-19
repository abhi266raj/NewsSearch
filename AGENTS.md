# NewsSearch contributor instructions

NewsSearch is an independent Swift 6 package. Work only on package behavior,
tests, documentation, or the example app. Do not add application-specific rules.

- Keep public interfaces source compatible within the documented release range.
- Keep model input separate from instructions. Preserve raw final responses.
- Use actors and async/await; inject sessions. Never put credentials in source.
- Run `Scripts/build-xcframework.sh` before `swift build` and `swift test`. Live model tests are opt-in; do not fake them.
- Verify both products with Scripts/verify-products.sh and Scripts/verify-platforms.sh.
- Keep README, test instructions, examples, and release notes consistent.
- Use AGPL-3.0-only for project code; preserve dependency notices.
- The default branch is `main` and is locked. Never bypass its protection.
  Use feature branches and PRs. Only the owner may temporarily unlock main for
  an approved update; restore the lock immediately afterward.
- Initial bootstrap establishes main before protection is enabled.
- Increase VERSION only when a main merge should publish a release. No develop branch.
- Follow CONTRIBUTING.md and RELEASING.md for checks and publication.
