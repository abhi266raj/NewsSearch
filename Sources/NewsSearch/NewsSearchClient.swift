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
    func trendingTopics(limit: Int) async throws -> [TrendingTopic]
}

/// Executes feed requests in the caller's process; no server, API key or subprocess.
public struct NewsSearchClient: NewsSearching {
    private let transport: any NewsTransport
    private let region: String
    private let language: String

    public init(transport: any NewsTransport = URLSessionNewsTransport(), region: String = "IN", language: String = "en") {
        self.transport = transport
        self.region = region
        self.language = language
    }

    public func headlines(category: NewsCategory = .trending, limit: Int = 20) async throws -> [NewsArticle] {
        try await search(category.query + " when:24h", limit: limit)
    }

    public func search(_ query: String, limit: Int = 20) async throws -> [NewsArticle] {
        try validate(limit: limit)
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw NewsSearchError.invalidInput("Enter a news search query.") }
        let feeds = [
            try url("https://news.google.com/rss/search", items: [
                .init(name: "q", value: query), .init(name: "hl", value: "\(language)-\(region)"),
                .init(name: "gl", value: region), .init(name: "ceid", value: "\(region):\(language)")]),
            try url("https://www.bing.com/news/search", items: [
                .init(name: "q", value: query), .init(name: "format", value: "rss"),
                .init(name: "mkt", value: "\(language)-\(region)")])
        ]
        var attempts: [String] = []
        for feed in feeds {
            try Task.checkCancellation()
            do {
                let data = try await transport.data(from: feed)
                try Task.checkCancellation()
                let items = try FeedParser.parse(data)
                var seen: Set<String> = []
                let articles = items.compactMap(\.article).filter {
                    seen.insert($0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)).inserted
                }
                if !articles.isEmpty { return Array(articles.prefix(limit)) }
                attempts.append("\(feed.host ?? "Feed"): no articles.")
            } catch {
                if error is CancellationError { throw error }
                try Task.checkCancellation()
                attempts.append("\(feed.host ?? "Feed"): \(error.localizedDescription)")
            }
        }
        throw NewsSearchError.noResults(attempts)
    }

    /// Google Trends search topics, formatted as hashtags; these are not social-network rankings.
    public func trendingTopics(limit: Int = 15) async throws -> [TrendingTopic] {
        try validate(limit: limit)
        let feed = try url("https://trends.google.com/trending/rss", items: [.init(name: "geo", value: region)])
        try Task.checkCancellation()
        let data = try await transport.data(from: feed)
        try Task.checkCancellation()
        let items = try FeedParser.parse(data)
        var seen: Set<String> = []
        let topics = items.compactMap { item -> TrendingTopic? in
            let topic = TrendingTopic(topic: item.title, article: item.relatedArticle)
            guard topic.hashtag.count > 1, seen.insert(topic.hashtag.lowercased()).inserted else { return nil }
            return topic
        }
        guard !topics.isEmpty else { throw NewsSearchError.noResults(["Google Trends: no topics."]) }
        return Array(topics.prefix(limit))
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
