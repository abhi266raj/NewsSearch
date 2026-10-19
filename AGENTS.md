# NewsSearch contributor instructions

NewsSearch is an independent Swift 6 package. Work only on package behavior,
tests, documentation, or distribution tooling. Do not add application-specific rules.

- Keep public interfaces source compatible within the documented release range.
- Keep feed discovery and parsing generic. Applications own UI, caching and factual verification.
- Use actors and async/await; inject transports. Never put credentials in source.
- Run `Scripts/build-xcframework.sh` before `swift build` and `swift test`. Unit tests use deterministic fixtures; live feed checks are opt-in.
- Verify both products with Scripts/verify-products.sh and Scripts/verify-platforms.sh.
- Keep README, test instructions, and release notes consistent.
- Use AGPL-3.0-only for project code; preserve dependency notices.
- The default branch is `main` and is locked. Never bypass its protection.
  Use feature branches and PRs. Only the owner may temporarily unlock main for
  an approved update; restore the lock immediately afterward.
- Initial bootstrap establishes main before protection is enabled.
- Increase VERSION only when a main merge should publish a release. No develop branch.
- Follow CONTRIBUTING.md and RELEASING.md for checks and publication.
