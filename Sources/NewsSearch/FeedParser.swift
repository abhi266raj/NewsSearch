import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct FeedItem {
    var title = ""
    var link = ""
    var source = ""
    var date = ""
    var relatedTitle = ""
    var relatedLink = ""
    var relatedSource = ""

    var article: NewsArticle? { makeArticle(title: title, link: link, source: source) }
    var relatedArticle: NewsArticle? { makeArticle(title: relatedTitle, link: relatedLink, source: relatedSource) }

    private func makeArticle(title: String, link: String, source: String) -> NewsArticle? {
        guard !title.isEmpty, let url = URL(string: link),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return NewsArticle(title: title, url: url, source: source.isEmpty ? (url.host ?? "") : source, publishedAt: formatter.date(from: date))
    }
}

/// Each parse owns its delegate. External entities are never resolved.
final class FeedParser: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var current: FeedItem?
    private var path: [String] = []
    private var text = ""
    private var relatedDepth = 0
    private var capturedRelated = false

    static func parse(_ data: Data) throws -> [FeedItem] {
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else {
            throw NewsSearchError.malformedFeed(parser.parserError?.localizedDescription ?? "Invalid XML.")
        }
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        path.append(name)
        text = ""
        if name == "item" { current = FeedItem(); capturedRelated = false }
        if name == "news_item" { relatedDepth += 1 }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { text += String(decoding: CDATABlock, as: UTF8.self) }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = path.last ?? elementName
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if current != nil {
            if relatedDepth > 0 && !capturedRelated {
                switch name {
                case "news_item_title": current?.relatedTitle = value
                case "news_item_url": current?.relatedLink = value
                case "news_item_source": current?.relatedSource = value
                default: break
                }
            } else if path.dropLast().last == "item" {
                switch name {
                case "title": current?.title = value
                case "link": current?.link = value
                case "source": current?.source = value
                case "pubDate": current?.date = value
                default: break
                }
            }
            if name == "news_item" {
                relatedDepth -= 1
                if current?.relatedArticle != nil { capturedRelated = true }
            }
            if name == "item", let item = current { items.append(item); current = nil }
        }
        if !path.isEmpty { path.removeLast() }
        text = ""
    }
}
