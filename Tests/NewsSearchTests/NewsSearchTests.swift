import Foundation
import Testing
import NewsSearchSource

private actor FixtureTransport: NewsTransport {
    var requests: [URL] = []
    let responses: [Result<Data, NewsSearchError>]
    init(_ responses: [Result<Data, NewsSearchError>]) { self.responses = responses }
    func data(from url: URL) async throws -> Data {
        requests.append(url)
        return try responses[min(requests.count - 1, responses.count - 1)].get()
    }
}

private let baseTimestamp: TimeInterval = 1792404000.0 // Mon, 19 Oct 2026 10:00:00 +0000

private let rss = Data("""
<rss><channel>
<item><title><![CDATA[Space & Science]]></title><link>https://example.com/space</link><source>Publisher</source><pubDate>Mon, 19 Oct 2026 10:00:00 +0000</pubDate></item>
<item><title>space &amp; science</title><link>https://example.com/duplicate</link></item>
<item><title>Unsafe</title><link>javascript:alert(1)</link></item>
</channel></rss>
""".utf8)

@Test func parsesMetadataDeduplicatesAndEncodesQuery() async throws {
    let transport = FixtureTransport([.success(rss)])
    let client = NewsSearchClient(
        transport: transport,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp + 3600) }
    )
    let articles = try await client.search("ISRO & space", limit: 10)
    #expect(articles.count == 1)
    #expect(articles[0].title == "Space & Science")
    #expect(articles[0].source == "Publisher")
    #expect(articles[0].publishedAt != nil)
    let request = try #require(await transport.requests.first)
    let query = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.first(where: { $0.name == "q" })?.value == "ISRO & space when:24h")
}

@Test func fallsBackAfterMalformedFeed() async throws {
    let transport = FixtureTransport([.success(Data("<rss>".utf8)), .success(rss)])
    let client = NewsSearchClient(
        transport: transport,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp + 3600) }
    )
    let articles = try await client.headlines(category: .india, limit: 1)
    #expect(articles.count == 1)
    #expect(await transport.requests.map(\.host) == ["news.google.com", "www.bing.com"])
    let bingRequest = try #require(await transport.requests.last)
    let queryItems = URLComponents(url: bingRequest, resolvingAgainstBaseURL: false)?.queryItems
    #expect(queryItems?.first(where: { $0.name == "q" })?.value == "India breaking news")
    #expect(queryItems?.first(where: { $0.name == "qft" })?.value == "interval=\"7\"")
}

@Test func reportsEverySourceFailure() async throws {
    let client = NewsSearchClient(
        transport: FixtureTransport([.failure(.httpStatus(503)), .success(Data("<rss/>".utf8))]),
        cache: NewsSearchCache()
    )
    do {
        _ = try await client.search("India")
        Issue.record("Expected no-results error")
    } catch NewsSearchError.noResults(let attempts) {
        #expect(attempts.count == 2)
        #expect(attempts[0].contains("503"))
        #expect(attempts[1].contains("no articles"))
    }
}

@Test func rejectsInvalidInputBeforeNetwork() async throws {
    let transport = FixtureTransport([.success(rss)])
    let client = NewsSearchClient(transport: transport, cache: NewsSearchCache())
    await #expect(throws: NewsSearchError.self) { try await client.search("  ") }
    await #expect(throws: NewsSearchError.self) { try await client.search("India", limit: 0) }
    #expect(await transport.requests.isEmpty)
}

@Test func cancellationStopsBeforeTransport() async throws {
    let transport = FixtureTransport([.success(rss)])
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await NewsSearchClient(transport: transport, cache: NewsSearchCache()).search("India")
    }
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.requests.isEmpty)
}

@Test func filtersOutArticlesOlderThanSearchDuration() async throws {
    let feedWithOldAndNew = Data("""
    <rss><channel>
    <item><title>Recent Article</title><link>https://example.com/recent</link><source>New</source><pubDate>Mon, 19 Oct 2026 09:00:00 +0000</pubDate></item>
    <item><title>Stale Article</title><link>https://example.com/stale</link><source>Old</source><pubDate>Sun, 18 Oct 2026 06:00:00 +0000</pubDate></item>
    </channel></rss>
    """.utf8)
    let transport = FixtureTransport([.success(feedWithOldAndNew)])
    let client = NewsSearchClient(
        transport: transport,
        searchDuration: 24 * 3600,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp) }
    )
    let articles = try await client.search("test")
    #expect(articles.count == 1)
    #expect(articles[0].title == "Recent Article")
}

@Test func cachesResultsForConfiguredCacheDuration() async throws {
    let transport = FixtureTransport([.success(rss)])
    let cache = NewsSearchCache()
    let client = NewsSearchClient(
        transport: transport,
        cacheDuration: 6 * 3600,
        cache: cache,
        now: { Date(timeIntervalSince1970: baseTimestamp + 1800) }
    )
    let first = try await client.search("science", limit: 5)
    #expect(first.count == 1)
    #expect(await transport.requests.count == 1)

    // Second call should return cached result without hitting transport
    let second = try await client.search("science", limit: 5)
    #expect(second.count == 1)
    #expect(await transport.requests.count == 1)

    // Bypass cache should hit transport again
    let third = try await client.search("science", limit: 5, bypassCache: true)
    #expect(third.count == 1)
    #expect(await transport.requests.count == 2)
}

@Test func cacheExpiresAfterCacheDuration() async throws {
    let transport = FixtureTransport([.success(rss)])
    let cache = NewsSearchCache()
    final class Clock: @unchecked Sendable {
        var current: TimeInterval
        init(_ current: TimeInterval) { self.current = current }
    }
    let clock = Clock(baseTimestamp + 1800)
    let client = NewsSearchClient(
        transport: transport,
        cacheDuration: 6 * 3600,
        cache: cache,
        now: { Date(timeIntervalSince1970: clock.current) }
    )

    _ = try await client.search("science")
    #expect(await transport.requests.count == 1)

    // Advance 3 hours (still within 6-hour cache)
    clock.current += 3 * 3600
    _ = try await client.search("science")
    #expect(await transport.requests.count == 1)

    // Advance another 4 hours (7 hours total -> expired)
    clock.current += 4 * 3600
    _ = try await client.search("science")
    #expect(await transport.requests.count == 2)
}

@Test func customSearchDurationAppliesQueryTagAndCustomFiltering() async throws {
    let feed = Data("""
    <rss><channel>
    <item><title>Within 4 Hours</title><link>https://example.com/fresh</link><pubDate>Mon, 19 Oct 2026 08:00:00 +0000</pubDate></item>
    <item><title>8 Hours Old</title><link>https://example.com/stale</link><pubDate>Mon, 19 Oct 2026 02:00:00 +0000</pubDate></item>
    </channel></rss>
    """.utf8)
    let transport = FixtureTransport([.success(feed)])
    let client = NewsSearchClient(
        transport: transport,
        searchDuration: 6 * 3600,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp) }
    )
    let articles = try await client.search("fresh news", limit: 5)
    #expect(articles.count == 1)
    #expect(articles[0].title == "Within 4 Hours")
    let request = try #require(await transport.requests.first)
    let query = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.first(where: { $0.name == "q" })?.value == "fresh news when:6h")
}

@Test func findsRSSFeedURLsWithDefaultAndCustomOptions() throws {
    let client = NewsSearchClient()

    // Default provider is Google
    let defaultFeed = try client.feedURL(for: "Chandrayaan")
    #expect(defaultFeed.host == "news.google.com")
    let defaultQuery = URLComponents(url: defaultFeed, resolvingAgainstBaseURL: false)?.queryItems
    #expect(defaultQuery?.first(where: { $0.name == "q" })?.value == "Chandrayaan when:24h")

    // Explicit Bing provider
    let bingFeed = try client.feedURL(for: "Chandrayaan", provider: .bing, duration: 3600)
    #expect(bingFeed.host == "www.bing.com")
    let bingQuery = URLComponents(url: bingFeed, resolvingAgainstBaseURL: false)?.queryItems
    #expect(bingQuery?.first(where: { $0.name == "q" })?.value == "Chandrayaan")
    #expect(bingQuery?.first(where: { $0.name == "qft" })?.value == "interval=\"1\"")

    // Category feed URL
    let categoryFeed = try client.feedURL(for: .trending)
    #expect(categoryFeed.host == "news.google.com")

    // Multiple feed URLs
    let allFeeds = try client.feedURLs(for: "India")
    #expect(allFeeds.count == 2)
    #expect(allFeeds[0].host == "news.google.com")
    #expect(allFeeds[1].host == "www.bing.com")

    // Filter to single provider via config
    let googleOnlyFeeds = try client.feedURLs(for: "India", providers: [.google])
    #expect(googleOnlyFeeds.count == 1)
    #expect(googleOnlyFeeds[0].host == "news.google.com")
}

@Test func respectsConfiguredRSSProviderSelectionInSearch() async throws {
    let transport = FixtureTransport([.success(rss)])
    let client = NewsSearchClient(
        configuration: NewsSearchConfiguration(rssProviders: [.bing]),
        transport: transport,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp + 3600) }
    )
    let articles = try await client.search("India")
    #expect(articles.count == 1)
    let hosts = await transport.requests.map(\.host)
    #expect(hosts == ["www.bing.com"])
}

@Test func filtersOutAudioBriefingsAndDigests() async throws {
    let feedWithBriefings = Data("""
    <rss><channel>
    <item><title>Top News Audio Briefing - 21 Oct 2026, 6 AM - The Times of India</title><link>https://example.com/audio1</link><source>TOI</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    <item><title>HT Morning Briefing: Top stories today</title><link>https://example.com/audio2</link><source>HT</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    <item><title>Podcast: Today's Economic Wrap</title><link>https://example.com/audio3</link><source>Podcast</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    <item><title>Evening News Bulletin - October 21</title><link>https://example.com/audio4</link><source>AIR</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    <item><title>Daily News Digest: Everything you need to know</title><link>https://example.com/audio5</link><source>Digest</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    <item><title>ISRO Gaganyaan Mission Astronauts Complete Final Tests</title><link>https://example.com/real-news</link><source>ISRO</source><pubDate>Wed, 21 Oct 2026 06:00:00 +0000</pubDate></item>
    </channel></rss>
    """.utf8)

    let transport = FixtureTransport([.success(feedWithBriefings)])
    let client = NewsSearchClient(
        transport: transport,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: 1792562400.0) } // Wed, 21 Oct 2026 06:00:00 +0000
    )

    let articles = try await client.search("India")
    #expect(articles.count == 1)
    #expect(articles[0].title == "ISRO Gaganyaan Mission Astronauts Complete Final Tests")
}

@Test func defaultLocationIsIndiaAndSupportsCustomLocationInQueriesAndLabels() {
    #expect(NewsSearchConfiguration.defaultLocation == "India")
    let client = NewsSearchClient()
    #expect(client.location == "India")

    // Default India labels and queries
    #expect(NewsCategory.trending.label == "🔥 India Trending & Viral")
    #expect(NewsCategory.india.label == "🇮🇳 India Top Stories & Breaking")
    #expect(NewsCategory.politics.label == "🏛️ Indian Politics, Elections & Governance")
    #expect(NewsCategory.trending.query(location: "India") == "India viral trending")
    #expect(NewsCategory.india.query(location: "India") == "India breaking news")

    // Custom location labels and queries
    #expect(NewsCategory.trending.label(location: "Mumbai") == "🔥 Mumbai Trending & Viral")
    #expect(NewsCategory.india.label(location: "Mumbai") == "📍 Mumbai Top Stories & Breaking")
    #expect(NewsCategory.funnyIndia.label(location: "Mumbai") == "😂 Mumbai Quirky, Bizarre & Funny")
    #expect(NewsCategory.politics.label(location: "Mumbai") == "🏛️ Mumbai Politics & Governance")
    #expect(NewsCategory.business.label(location: "Mumbai") == "📈 Mumbai Business & Economy")

    #expect(NewsCategory.trending.query(location: "Mumbai") == "Mumbai viral trending")
    #expect(NewsCategory.india.query(location: "Mumbai") == "Mumbai breaking news")
    #expect(NewsCategory.politics.query(location: "Mumbai") == "Mumbai (politics OR elections OR governance OR government)")
    #expect(NewsCategory.business.query(location: "Mumbai") == "Mumbai (business OR economy OR stock market OR inflation)")

    // Empty or whitespace falls back to India
    #expect(NewsCategory.trending.label(location: "   ") == "🔥 India Trending & Viral")
    #expect(NewsCategory.india.query(location: "") == "India breaking news")
}

@Test func headlinesAndFeedURLsRespectSpecifiedLocation() async throws {
    let transport = FixtureTransport([.success(rss)])
    let client = NewsSearchClient(
        configuration: NewsSearchConfiguration(location: "India"),
        transport: transport,
        cache: NewsSearchCache(),
        now: { Date(timeIntervalSince1970: baseTimestamp + 3600) }
    )

    // Override location in headlines call
    let articles = try await client.headlines(category: .india, location: "Delhi", limit: 5)
    #expect(articles.count == 1)
    let request = try #require(await transport.requests.first)
    let query = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.first(where: { $0.name == "q" })?.value == "Delhi breaking news when:24h")

    // Feed URLs for custom location
    let url = try client.feedURL(for: .trending, location: "Bengaluru")
    let feedQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    #expect(feedQuery?.first(where: { $0.name == "q" })?.value == "Bengaluru viral trending when:24h")
}
