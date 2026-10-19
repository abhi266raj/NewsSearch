# Contributing

The public repository is https://github.com/abhi266raj/NewsSearch.
The default branch, `main`, is locked against updates, force pushes, and deletion.
No public contributor has write access. Forks and proposed pull requests do not
change this repository. The owner controls whether an update is accepted.

Contributions are under AGPL-3.0-only; see [LICENSE](LICENSE). Submit an issue or
pull request with a concrete problem, focused change, and validation evidence.
Do not include credentials, private feed data, build output, or personal data.

```sh
git clone https://github.com/abhi266raj/NewsSearch.git
cd NewsSearch
Scripts/build-xcframework.sh
swift build
swift test
Scripts/verify-products.sh
```

The root test suite imports NewsSearchSource. The consumer check tests both public
products separately. Changes to library code require a new versioned XCFramework;
see [distribution guidance](Distribution/README.md) and [RELEASING.md](RELEASING.md).

Tests use deterministic injected transports; no live network in unit tests. Run Scripts/verify-platforms.sh when changing public API.

NewsSearch owns generic feed discovery and parsing. Applications own UI, caching, factual validation and retry policy. Use protocols, Sendable values and async/await; inject transports. New behavior needs focused contract tests.
