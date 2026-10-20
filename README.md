# NewsSearch

Swift 6 news discovery running in your app's process. No application server, Python, subprocess, API key, or third-party package dependencies. macOS 13+, iOS 16+, and Linux.

```swift
// Package.swift
.package(url: "https://github.com/abhi266raj/NewsSearch.git", from: "0.2.0")
// Target dependencies: .product(name: "NewsSearch", package: "NewsSearch")
```

```swift
import NewsSearch

// Uses default configuration: 24-hour search window, 6-hour cache, Google + Bing RSS providers
let client = NewsSearchClient()
let headlines = try await client.headlines(category: .india, limit: 20)
let matches = try await client.search("ISRO launch", limit: 10)

// Finding RSS feed URLs directly
let googleFeed = try client.feedURL(for: "ISRO launch", provider: .google)
let bingFeed = try client.feedURL(for: "ISRO launch", provider: .bing)
let categoryFeed = try client.feedURL(for: .trending)

// Custom configuration options
let config = NewsSearchConfiguration(
    rssProviders: [.google, .bing],  // Default: Google primary with Bing fallback
    searchDuration: 24 * 3600,       // Default: 24 hours
    cacheDuration: 6 * 3600,         // Default: 6 hours
    region: "IN",                    // Default: IN
    language: "en"                   // Default: en
)
let customClient = NewsSearchClient(configuration: config)
```

Articles include title, source, URL, and publication date when provided. Categories cover India, trending, quirky, proud, emotional, politics, culture, Indian technology, technology, world, and business. Defaults to English, India; region and language can be configured in the initializer.

Google News RSS is the primary source; Bing News RSS is tried if it fails or returns no usable articles. Search duration defaults to the last 24 hours (with provider query modifiers and client-side publication date verification) and results are cached in-memory for 6 hours. Results deduplicate titles, honor cancellation, and reject non-HTTP article URLs. Google News links may remain aggregator redirects. Results are discovery leads, not verification of factual claims.

Trending search topics are available separately in [GoogleTrends](https://github.com/abhi266raj/GoogleTrends). This package has no dependency on it.

Internet access is required. Public feed endpoints are provider-controlled and may change or rate-limit requests. Limits must be 1...100. All-source failures throw `NewsSearchError.noResults` with per-source details.

Inject `NewsTransport` for deterministic tests or custom networking. `NewsSearching` is the application boundary. Tests use fixture data; CI runs on macOS and Linux.

License: AGPL-3.0-only.

## Source and binary products

Following [AgentAtom](https://github.com/abhi266raj/AgentAtom), a single URL and version provide two independent products:

- `NewsSearch`: prebuilt dynamic XCFramework; `import NewsSearch`.
- `NewsSearchSource`: same implementation compiled from source; `import NewsSearchSource`.

Choose one product per dependency graph. The binary supports universal macOS, iPhone, and iOS Simulator. The source product also supports Linux. Development checkouts require `Scripts/build-xcframework.sh` before SwiftPM resolution. Published semantic tags download the verified binary automatically.

CI builds all three framework variants, runs fixture tests, tests both products as external consumers, and compiles a binary consumer for every shipped architecture. Only an increased `VERSION` merged into protected main publishes a release; unchanged versions validate only. Tags and assets are immutable. Main stays locked and publication only creates a generated manifest tag commit. See [RELEASING.md](RELEASING.md), [CONTRIBUTING.md](CONTRIBUTING.md) and [Distribution](Distribution/README.md).
