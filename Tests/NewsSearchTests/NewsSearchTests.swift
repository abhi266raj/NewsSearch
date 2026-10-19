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

private let rss = Data("""
<rss><channel>
<item><title><![CDATA[Space & Science]]></title><link>https://example.com/space</link><source>Publisher</source><pubDate>Mon, 19 Oct 2026 10:00:00 +0000</pubDate></item>
<item><title>space &amp; science</title><link>https://example.com/duplicate</link></item>
<item><title>Unsafe</title><link>javascript:alert(1)</link></item>
</channel></rss>
""".utf8)

@Test func parsesMetadataDeduplicatesAndEncodesQuery() async throws {
    let transport = FixtureTransport([.success(rss)])
    let articles = try await NewsSearchClient(transport: transport).search("ISRO & space", limit: 10)
    #expect(articles.count == 1)
    #expect(articles[0].title == "Space & Science")
    #expect(articles[0].source == "Publisher")
    #expect(articles[0].publishedAt != nil)
    let request = try #require(await transport.requests.first)
    let query = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems
    #expect(query?.first(where: { $0.name == "q" })?.value == "ISRO & space")
}

@Test func fallsBackAfterMalformedFeed() async throws {
    let transport = FixtureTransport([.success(Data("<rss>".utf8)), .success(rss)])
    let articles = try await NewsSearchClient(transport: transport).headlines(category: .india, limit: 1)
    #expect(articles.count == 1)
    #expect(await transport.requests.map(\.host) == ["news.google.com", "www.bing.com"])
}

@Test func reportsEverySourceFailure() async throws {
    let client = NewsSearchClient(transport: FixtureTransport([.failure(.httpStatus(503)), .success(Data("<rss/>".utf8))]))
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
    let client = NewsSearchClient(transport: transport)
    await #expect(throws: NewsSearchError.self) { try await client.search("  ") }
    await #expect(throws: NewsSearchError.self) { try await client.search("India", limit: 0) }
    #expect(await transport.requests.isEmpty)
}

@Test func cancellationStopsBeforeTransport() async throws {
    let transport = FixtureTransport([.success(rss)])
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await NewsSearchClient(transport: transport).search("India")
    }
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
    #expect(await transport.requests.isEmpty)
}
