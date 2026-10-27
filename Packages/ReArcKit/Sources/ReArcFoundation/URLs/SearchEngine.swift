import Foundation

/// Where command bar searches go. The default is privacy-friendly.
public enum SearchEngine: String, CaseIterable, Codable, Sendable {
    case duckDuckGo
    case startpage
    case ecosia
    case kagi
    case bing
    case google

    public static let `default` = SearchEngine.duckDuckGo

    public var name: String {
        switch self {
        case .duckDuckGo: "DuckDuckGo"
        case .startpage: "Startpage"
        case .ecosia: "Ecosia"
        case .kagi: "Kagi"
        case .bing: "Bing"
        case .google: "Google"
        }
    }

    public func searchURL(for query: String) -> URL {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        // URLComponents leaves "+" alone, but search engines read it as a space ("c++").
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    private var baseURL: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .startpage: "https://www.startpage.com/do/search"
        case .ecosia: "https://www.ecosia.org/search"
        case .kagi: "https://kagi.com/search"
        case .bing: "https://www.bing.com/search"
        case .google: "https://www.google.com/search"
        }
    }
}
