import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol NewsTransport: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionNewsTransport: NewsTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("NewsSearch/0.1 (+https://github.com/abhi266raj/NewsSearch)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw NewsSearchError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw NewsSearchError.httpStatus(response.statusCode) }
        guard data.count <= 5_000_000 else { throw NewsSearchError.malformedFeed("Feed exceeds 5 MB.") }
        return data
    }
}

public protocol NewsSearching: Sendable {
    func headlines(category: NewsCategory, limit: Int) async throws -> [NewsArticle]
    func search(_ query: String, limit: Int) async throws -> [NewsArticle]
}

public extension NewsSearching {
    func headlines() async throws -> [NewsArticle] {
        try await headlines(category: .trending, limit: 20)
    }

    func headlines(category: NewsCategory) async throws -> [NewsArticle] {
        try await headlines(category: category, limit: 20)
    }

    func search(_ query: String) async throws -> [NewsArticle] {
        try await search(query, limit: 20)
    }
}

/// Available RSS news feed providers.
public enum NewsRSSProvider: String, CaseIterable, Sendable {
    case google = "google"
    case bing = "bing"

    public var displayName: String {
        switch self {
        case .google: "Google News RSS"
        case .bing: "Bing News RSS"
        }
    }
}

/// Configuration options for news search, duration, caching, and RSS feed discovery.
public struct NewsSearchConfiguration: Sendable, Equatable {
    public static let defaultSearchDuration: TimeInterval = 24 * 3600 // 24 hours
    public static let defaultCacheDuration: TimeInterval = 6 * 3600   // 6 hours
    public static let defaultProviders: [NewsRSSProvider] = [.google, .bing]

    public var rssProviders: [NewsRSSProvider]
    public var searchDuration: TimeInterval
    public var cacheDuration: TimeInterval
    public var region: String
    public var language: String

    public static let `default` = NewsSearchConfiguration()

    public init(
        rssProviders: [NewsRSSProvider] = defaultProviders,
        searchDuration: TimeInterval = defaultSearchDuration,
        cacheDuration: TimeInterval = defaultCacheDuration,
        region: String = "IN",
        language: String = "en"
    ) {
        self.rssProviders = rssProviders
        self.searchDuration = searchDuration
        self.cacheDuration = cacheDuration
        self.region = region
        self.language = language
    }
}

/// Thread-safe in-memory cache for news searches and headlines.
public actor NewsSearchCache {
    public static let shared = NewsSearchCache()

    struct CacheEntry: Sendable {
        let articles: [NewsArticle]
        let timestamp: Date
    }

    private var storage: [String: CacheEntry] = [:]

    public init() {}

    public func get(key: String, maxAge: TimeInterval, now: Date = Date()) -> [NewsArticle]? {
        guard let entry = storage[key] else { return nil }
        if now.timeIntervalSince(entry.timestamp) > maxAge {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.articles
    }

    public func set(key: String, articles: [NewsArticle], now: Date = Date()) {
        storage[key] = CacheEntry(articles: articles, timestamp: now)
    }

    public func remove(key: String) {
        storage.removeValue(forKey: key)
    }

    public func clear() {
        storage.removeAll()
    }
}

/// Executes feed requests in the caller's process; no server, API key or subprocess.
public struct NewsSearchClient: NewsSearching {
    public static let defaultSearchDuration: TimeInterval = NewsSearchConfiguration.defaultSearchDuration
    public static let defaultCacheDuration: TimeInterval = NewsSearchConfiguration.defaultCacheDuration
    public static let defaultProviders: [NewsRSSProvider] = NewsSearchConfiguration.defaultProviders

    public let configuration: NewsSearchConfiguration
    public var region: String { configuration.region }
    public var language: String { configuration.language }
    public var searchDuration: TimeInterval { configuration.searchDuration }
    public var cacheDuration: TimeInterval { configuration.cacheDuration }
    public var rssProviders: [NewsRSSProvider] { configuration.rssProviders }

    private let transport: any NewsTransport
    private let cache: NewsSearchCache
    private let nowProvider: @Sendable () -> Date

    public init(
        configuration: NewsSearchConfiguration = .default,
        transport: any NewsTransport = URLSessionNewsTransport(),
        cache: NewsSearchCache = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.cache = cache
        self.nowProvider = now
    }

    public init(
        transport: any NewsTransport = URLSessionNewsTransport(),
        region: String = "IN",
        language: String = "en",
        searchDuration: TimeInterval = defaultSearchDuration,
        cacheDuration: TimeInterval = defaultCacheDuration,
        rssProviders: [NewsRSSProvider] = defaultProviders,
        cache: NewsSearchCache = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let config = NewsSearchConfiguration(
            rssProviders: rssProviders,
            searchDuration: searchDuration,
            cacheDuration: cacheDuration,
            region: region,
            language: language
        )
        self.init(configuration: config, transport: transport, cache: cache, now: now)
    }

    public func headlines(category: NewsCategory, limit: Int) async throws -> [NewsArticle] {
        try await headlines(category: category, limit: limit, duration: nil, providers: nil, bypassCache: false)
    }

    public func headlines(
        category: NewsCategory = .trending,
        limit: Int = 20,
        duration: TimeInterval? = nil,
        providers: [NewsRSSProvider]? = nil,
        bypassCache: Bool = false
    ) async throws -> [NewsArticle] {
        try await search(category.query, limit: limit, duration: duration, providers: providers, bypassCache: bypassCache)
    }

    public func search(_ query: String, limit: Int) async throws -> [NewsArticle] {
        try await search(query, limit: limit, duration: nil, providers: nil, bypassCache: false)
    }

    public func search(
        _ query: String,
        limit: Int = 20,
        duration: TimeInterval? = nil,
        providers: [NewsRSSProvider]? = nil,
        bypassCache: Bool = false
    ) async throws -> [NewsArticle] {
        try validate(limit: limit)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NewsSearchError.invalidInput("Enter a news search query.") }

        let effectiveDuration = duration ?? searchDuration
        let effectiveCache = cacheDuration
        let effectiveProviders = providers ?? rssProviders
        guard !effectiveProviders.isEmpty else {
            throw NewsSearchError.invalidInput("At least one RSS provider must be configured.")
        }
        let now = nowProvider()

        let providersKey = effectiveProviders.map(\.rawValue).joined(separator: ",")
        let cacheKey = "\(region)|\(language)|\(providersKey)|\(trimmed.lowercased())|\(effectiveDuration)"
        if !bypassCache && effectiveCache > 0 {
            if let cached = await cache.get(key: cacheKey, maxAge: effectiveCache, now: now), !cached.isEmpty {
                return Array(cached.prefix(limit))
            }
        }

        let feeds = try feedURLs(for: trimmed, duration: effectiveDuration, providers: effectiveProviders)
        var attempts: [String] = []
        for feed in feeds {
            try Task.checkCancellation()
            do {
                let data = try await transport.data(from: feed)
                try Task.checkCancellation()
                let items = try FeedParser.parse(data)
                var seen: Set<String> = []
                let cutoff = effectiveDuration > 0 ? now.addingTimeInterval(-effectiveDuration - 900) : nil
                let articles = items.compactMap(\.article).filter { article in
                    if let cutoff, let pubDate = article.publishedAt, pubDate < cutoff {
                        return false
                    }
                    return seen.insert(article.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)).inserted
                }
                if !articles.isEmpty {
                    if !bypassCache && effectiveCache > 0 {
                        await cache.set(key: cacheKey, articles: articles, now: now)
                    }
                    return Array(articles.prefix(limit))
                }
                attempts.append("\(feed.host ?? "Feed"): no articles.")
            } catch {
                if error is CancellationError { throw error }
                try Task.checkCancellation()
                attempts.append("\(feed.host ?? "Feed"): \(error.localizedDescription)")
            }
        }
        throw NewsSearchError.noResults(attempts)
    }

    /// Generates the RSS feed URL for a specific provider and query with duration filtering.
    public func feedURL(
        for query: String,
        provider: NewsRSSProvider = .google,
        duration: TimeInterval? = nil
    ) throws -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NewsSearchError.invalidInput("Enter a news search query.") }
        let effectiveDuration = duration ?? searchDuration

        switch provider {
        case .google:
            let googleQ = googleQuery(for: trimmed, duration: effectiveDuration)
            return try url("https://news.google.com/rss/search", items: [
                .init(name: "q", value: googleQ),
                .init(name: "hl", value: "\(language)-\(region)"),
                .init(name: "gl", value: region),
                .init(name: "ceid", value: "\(region):\(language)")
            ])
        case .bing:
            let cleanBing = bingQuery(for: trimmed)
            var items: [URLQueryItem] = [
                .init(name: "q", value: cleanBing.isEmpty ? trimmed : cleanBing),
                .init(name: "format", value: "rss"),
                .init(name: "mkt", value: "\(language)-\(region)")
            ]
            if let interval = bingInterval(for: effectiveDuration) {
                items.append(.init(name: "qft", value: "interval=\"\(interval)\""))
            }
            return try url("https://www.bing.com/news/search", items: items)
        }
    }

    /// Generates RSS feed URLs for the given query across configured or specified providers.
    public func feedURLs(
        for query: String,
        duration: TimeInterval? = nil,
        providers: [NewsRSSProvider]? = nil
    ) throws -> [URL] {
        let effectiveProviders = providers ?? self.rssProviders
        guard !effectiveProviders.isEmpty else {
            throw NewsSearchError.invalidInput("At least one RSS provider must be configured.")
        }
        return try effectiveProviders.map {
            try feedURL(for: query, provider: $0, duration: duration)
        }
    }

    /// Generates the RSS feed URL for a news category.
    public func feedURL(
        for category: NewsCategory,
        provider: NewsRSSProvider = .google,
        duration: TimeInterval? = nil
    ) throws -> URL {
        try feedURL(for: category.query, provider: provider, duration: duration)
    }

    private func googleQuery(for query: String, duration: TimeInterval) -> String {
        if duration > 0 && !query.contains("when:") {
            let tag = durationTag(for: duration)
            return "\(query) \(tag)"
        }
        return query
    }

    private func bingQuery(for query: String) -> String {
        let cleaned = query.replacingOccurrences(of: #"\bwhen:\S+"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func durationTag(for duration: TimeInterval) -> String {
        if duration <= 48 * 3600 {
            let hours = max(1, Int(ceil(duration / 3600.0)))
            return "when:\(hours)h"
        } else {
            let days = max(1, Int(ceil(duration / 86400.0)))
            return "when:\(days)d"
        }
    }

    private func bingInterval(for duration: TimeInterval) -> String? {
        if duration <= 0 { return nil }
        if duration <= 3600 { return "1" }
        if duration <= 8 * 3600 { return "4" }
        if duration <= 24 * 3600 { return "7" }
        if duration <= 72 * 3600 { return "8" }
        if duration <= 7 * 86400 { return "9" }
        return nil
    }

    private func validate(limit: Int) throws {
        guard (1...100).contains(limit) else { throw NewsSearchError.invalidInput("News result limit must be between 1 and 100.") }
    }

    private func url(_ base: String, items: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: base) else { throw NewsSearchError.invalidResponse }
        components.queryItems = items
        guard let url = components.url else { throw NewsSearchError.invalidResponse }
        return url
    }
}
