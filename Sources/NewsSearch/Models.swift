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
        label(location: "India")
    }

    public func label(location: String = "India") -> String {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayLoc = loc.isEmpty ? "India" : loc
        let isIndia = displayLoc.caseInsensitiveCompare("India") == .orderedSame
        switch self {
        case .trending: return isIndia ? "🔥 India Trending & Viral" : "🔥 \(displayLoc) Trending & Viral"
        case .india: return isIndia ? "🇮🇳 India Top Stories & Breaking" : "📍 \(displayLoc) Top Stories & Breaking"
        case .funnyIndia: return isIndia ? "😂 Desi Quirky, Jugaad & Funny India" : "😂 \(displayLoc) Quirky, Bizarre & Funny"
        case .proudIndia: return "🏆 Proud \(displayLoc)"
        case .emotional: return "❤️ Emotional \(displayLoc)"
        case .politics: return isIndia ? "🏛️ Indian Politics, Elections & Governance" : "🏛️ \(displayLoc) Politics & Governance"
        case .culture: return isIndia ? "🪔 Indian Culture, Heritage & Festivals" : "🪔 \(displayLoc) Culture & Heritage"
        case .indiaTech: return isIndia ? "🚀 India Tech, Space (ISRO) & Startups" : "🚀 \(displayLoc) Tech, Space & Startups"
        case .tech: return "💻 Technology & AI"
        case .world: return "🌍 World News"
        case .business: return isIndia ? "📈 Business & Economy" : "📈 \(displayLoc) Business & Economy"
        }
    }

    var query: String {
        query(location: "India")
    }

    public func query(location: String = "India") -> String {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchLoc = loc.isEmpty ? "India" : loc
        let isIndia = searchLoc.caseInsensitiveCompare("India") == .orderedSame

        switch self {
        case .trending:
            return "\(searchLoc) viral trending"
        case .india:
            return "\(searchLoc) breaking news"
        case .funnyIndia:
            if isIndia {
                return "India (viral OR bizarre OR hilarious OR jugaad OR quirky)"
            } else {
                return "\(searchLoc) (viral OR bizarre OR hilarious OR quirky)"
            }
        case .proudIndia:
            return "\(searchLoc) (achievement OR award OR breakthrough OR record)"
        case .emotional:
            return "\(searchLoc) (heartwarming OR rescue OR kindness OR inspiring)"
        case .politics:
            if isIndia {
                return "India (politics OR elections OR parliament OR governance)"
            } else {
                return "\(searchLoc) (politics OR elections OR governance OR government)"
            }
        case .culture:
            if isIndia {
                return "India (culture OR heritage OR festivals OR temples OR art)"
            } else {
                return "\(searchLoc) (culture OR heritage OR festivals OR art OR tradition)"
            }
        case .indiaTech:
            if isIndia {
                return "(ISRO OR Indian startup OR Digital India OR UPI)"
            } else {
                return "\(searchLoc) (startups OR tech innovation OR tech economy)"
            }
        case .tech:
            return "(artificial intelligence OR technology OR NVIDIA OR Apple OR Microsoft)"
        case .world:
            return "(world news OR international OR diplomacy OR United Nations)"
        case .business:
            if isIndia {
                return "(Sensex OR Nifty OR RBI OR Indian economy OR GST)"
            } else {
                return "\(searchLoc) (business OR economy OR stock market OR inflation)"
            }
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
