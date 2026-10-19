import Foundation

public struct NewsArticle: Equatable, Sendable {
    public let title: String
    public let url: URL
    public let source: String
    public let publishedAt: Date?

    public init(title: String, url: URL, source: String, publishedAt: Date? = nil) {
        self.title = title
        self.url = url
        self.source = source
        self.publishedAt = publishedAt
    }
}

public enum NewsCategory: String, CaseIterable, Sendable {
    case trending, india, funnyIndia = "funny_india", proudIndia = "proud_india"
    case emotional, politics, culture, indiaTech = "india_tech", tech, world, business

    public var label: String {
        switch self {
        case .trending: "🔥 India Trending & Viral"
        case .india: "🇮🇳 India Top Stories & Breaking"
        case .funnyIndia: "😂 Desi Quirky, Jugaad & Funny India"
        case .proudIndia: "🏆 Proud India"
        case .emotional: "❤️ Emotional India"
        case .politics: "🏛️ Indian Politics, Elections & Governance"
        case .culture: "🪔 Indian Culture, Heritage & Festivals"
        case .indiaTech: "🚀 India Tech, Space (ISRO) & Startups"
        case .tech: "💻 Technology & AI"
        case .world: "🌍 World News"
        case .business: "📈 Business & Economy"
        }
    }

    var query: String {
        switch self {
        case .trending: "India viral trending"
        case .india: "India breaking news"
        case .funnyIndia: "India (viral OR bizarre OR hilarious OR jugaad OR quirky)"
        case .proudIndia: "India (achievement OR award OR breakthrough OR record)"
        case .emotional: "India (heartwarming OR rescue OR kindness OR inspiring)"
        case .politics: "India (politics OR elections OR parliament OR governance)"
        case .culture: "India (culture OR heritage OR festivals OR temples OR art)"
        case .indiaTech: "(ISRO OR Indian startup OR Digital India OR UPI)"
        case .tech: "(artificial intelligence OR technology OR NVIDIA OR Apple OR Microsoft)"
        case .world: "(world news OR international OR diplomacy OR United Nations)"
        case .business: "(Sensex OR Nifty OR RBI OR Indian economy OR GST)"
        }
    }
}

public enum NewsSearchError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case invalidResponse
    case httpStatus(Int)
    case malformedFeed(String)
    case noResults([String])

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message): message
        case .invalidResponse: "News source returned an invalid response."
        case .httpStatus(let code): "News source returned HTTP \(code)."
        case .malformedFeed(let detail): "Could not parse news feed: \(detail)"
        case .noResults(let attempts): "No news results. " + attempts.joined(separator: " ")
        }
    }
}
