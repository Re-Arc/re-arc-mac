import Foundation
import ReArcFoundation
import Testing

struct SearchEngineTests {
    @Test func defaultsToDuckDuckGo() {
        #expect(SearchEngine.default == .duckDuckGo)
    }

    @Test func encodesTheQuery() {
        let url = SearchEngine.duckDuckGo.searchURL(for: "what is c++ & swift?")
        #expect(url.absoluteString == "https://duckduckgo.com/?q=what%20is%20c%2B%2B%20%26%20swift?")
    }

    @Test func everyEngineBuildsAURLWithTheQuery() {
        for engine in SearchEngine.allCases {
            let components = URLComponents(url: engine.searchURL(for: "swift"), resolvingAgainstBaseURL: false)
            #expect(components?.scheme == "https")
            #expect(components?.queryItems == [URLQueryItem(name: "q", value: "swift")])
        }
    }
}
