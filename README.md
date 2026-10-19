# NewsSearch

Swift 6 news discovery running in your app's process. No application server, Python, subprocess, API key, or third-party package dependencies. macOS 13+, iOS 16+, and Linux.

```swift
// Package.swift
.package(url: "https://github.com/abhi266raj/NewsSearch.git", from: "0.1.0")
// Target dependencies: .product(name: "NewsSearch", package: "NewsSearch")
```

```swift
import NewsSearch

let client = NewsSearchClient()
let headlines = try await client.headlines(category: .india, limit: 20)
let matches = try await client.search("ISRO launch", limit: 10)
let topics = try await client.trendingTopics(limit: 15)
```

Articles include title, source, URL, and publication date when provided. Categories cover India, trending, quirky, proud, emotional, politics, culture, Indian technology, technology, world, and business. Defaults to English, India; region and language can be configured in the initializer.

Google News RSS is the primary source; Bing News RSS is tried if it fails or returns no usable articles. Category queries ask for the last 24 hours; publication freshness and ordering remain provider-controlled. Results deduplicate titles, honor cancellation, and reject non-HTTP article URLs. Google News links may remain aggregator redirects. Results are discovery leads, not verification of factual claims.

Trending topics come from Google Trends RSS. `hashtag` formats the search topic as a tag; it does **not** measure hashtag popularity on social platforms. Associated publisher articles are retained when present. Trends failures surface directly, without invented topics.

Internet access is required. Public feed endpoints are provider-controlled and may change or rate-limit requests. This package does not promise parity with every scraper or ranking rule in ScriptMaker. Hosts should implement appropriate caching; the client itself never returns stale data. Limits must be 1...100. All-source failures throw `NewsSearchError.noResults` with per-source details.

Inject `NewsTransport` for deterministic tests or custom networking. `NewsSearching` is the application boundary. Tests use fixture data; CI runs on macOS and Linux.

License: AGPL-3.0-only.
