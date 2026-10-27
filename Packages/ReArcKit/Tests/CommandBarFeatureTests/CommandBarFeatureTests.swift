import CommandBarFeature
import ComposableArchitecture
import Foundation
import ReArcFoundation
import Testing

@MainActor
struct CommandBarFeatureTests {
    let github = CommandBarFeature.OpenTab(
        id: UUID(),
        title: "GitHub",
        url: URL(string: "https://github.com/Re-Arc")!
    )
    let swift = CommandBarFeature.OpenTab(
        id: UUID(),
        title: "Swift.org",
        url: URL(string: "https://swift.org")!
    )

    @Test func emptyQueryHasNoSuggestions() {
        let state = CommandBarFeature.State(destination: .newTab, openTabs: [github, swift])
        #expect(state.suggestions.isEmpty)
    }

    @Test func typedURLComesFirstWithASearchAfterIt() {
        let state = CommandBarFeature.State(destination: .newTab, query: "example.com")
        #expect(
            state.suggestions == [
                .open(URL(string: "https://example.com")!),
                .search("example.com", .duckDuckGo),
            ]
        )
    }

    @Test func localAddressesDontOfferASearch() {
        let state = CommandBarFeature.State(destination: .newTab, query: "localhost:3000")
        #expect(state.suggestions == [.open(URL(string: "http://localhost:3000")!)])
    }

    @Test func fullURLsDontOfferASearch() {
        let state = CommandBarFeature.State(destination: .newTab, query: "https://swift.org")
        #expect(state.suggestions == [.open(URL(string: "https://swift.org")!)])
    }

    @Test func typedTextSearchesWithTheChosenEngine() {
        let state = CommandBarFeature.State(destination: .newTab, query: "what is swift")
        #expect(state.suggestions == [.search("what is swift", .duckDuckGo)])
    }

    @Test func matchingOpenTabsAreOfferedButNotTheCurrentOne() {
        let state = CommandBarFeature.State(
            destination: .currentTab,
            query: "git",
            openTabs: [github, swift],
            currentTabID: swift.id
        )
        #expect(state.suggestions == [.search("git", .duckDuckGo), .switchToTab(github)])

        let current = CommandBarFeature.State(
            destination: .currentTab,
            query: "swift",
            openTabs: [github, swift],
            currentTabID: swift.id
        )
        #expect(!current.suggestions.contains(.switchToTab(swift)))
    }

    @Test func tabsMatchOnURLToo() {
        let state = CommandBarFeature.State(destination: .newTab, query: "re-arc", openTabs: [github, swift])
        #expect(state.suggestions.contains(.switchToTab(github)))
    }

    @Test func matchingCommandsAndSearchEnginesAreOffered() {
        let state = CommandBarFeature.State(destination: .newTab, query: "reopen")
        #expect(state.suggestions.contains(.command(.reopenClosedTab)))

        let engines = CommandBarFeature.State(destination: .newTab, query: "search engine")
        #expect(engines.suggestions.contains(.useSearchEngine(.kagi)))
        // The engine already in use isn't offered.
        #expect(!engines.suggestions.contains(.useSearchEngine(.duckDuckGo)))

        let byName = CommandBarFeature.State(destination: .newTab, query: "kagi")
        #expect(byName.suggestions == [.search("kagi", .duckDuckGo), .useSearchEngine(.kagi)])
    }

    @Test func singleLettersDontFloodTheList() {
        let state = CommandBarFeature.State(destination: .newTab, query: "e")
        #expect(state.suggestions == [.search("e", .duckDuckGo)])
    }

    @Test func commandsThatOpenTheBarAreNotOffered() {
        let state = CommandBarFeature.State(destination: .newTab, query: "tab")
        #expect(!state.suggestions.contains(.command(.newTab)))
    }

    @Test func typingRefreshesSuggestionsAndResetsHighlight() async {
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab, query: "reopen")) {
            CommandBarFeature()
        }
        await store.send(.highlightMoved(by: 1)) {
            $0.highlightedIndex = 1
        }
        await store.send(.queryChanged("swift.org")) {
            $0.query = "swift.org"
            $0.suggestions = [.open(URL(string: "https://swift.org")!), .search("swift.org", .duckDuckGo)]
            $0.highlightedIndex = 0
        }
    }

    @Test func highlightStaysWithinSuggestions() async {
        let store = TestStore(
            initialState: CommandBarFeature.State(destination: .newTab, query: "git", openTabs: [github])
        ) {
            CommandBarFeature()
        }
        await store.send(.highlightMoved(by: -1))
        await store.send(.highlightMoved(by: 1)) {
            $0.highlightedIndex = 1
        }
        await store.send(.highlightMoved(by: 1))
    }

    @Test func submittingAURLOpensItWhereTheBarWasOpenedFor() async {
        let store = TestStore(
            initialState: CommandBarFeature.State(destination: .currentTab, query: "localhost:3000")
        ) {
            CommandBarFeature()
        }
        await store.send(.submitted)
        await store.receive(.delegate(.open(URL(string: "http://localhost:3000")!, in: .currentTab)))
    }

    @Test func submittingASearchOpensTheEnginesResults() async {
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab, query: "swift")) {
            CommandBarFeature()
        }
        await store.send(.submitted)
        await store.receive(.delegate(.open(SearchEngine.duckDuckGo.searchURL(for: "swift"), in: .newTab)))
    }

    @Test func choosingATabSwitchesToIt() async {
        let store = TestStore(
            initialState: CommandBarFeature.State(destination: .newTab, query: "git", openTabs: [github])
        ) {
            CommandBarFeature()
        }
        await store.send(.highlightMoved(by: 1)) {
            $0.highlightedIndex = 1
        }
        await store.send(.submitted)
        await store.receive(.delegate(.switchToTab(github.id)))
    }

    @Test func clickingACommandRunsIt() async {
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab, query: "close")) {
            CommandBarFeature()
        }
        await store.send(.suggestionClicked(.command(.closeTab)))
        await store.receive(.delegate(.run(.closeTab)))
    }

    @Test func choosingASearchEngineSavesItAndCloses() async {
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab, query: "kagi")) {
            CommandBarFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
        await store.send(.suggestionClicked(.useSearchEngine(.kagi))) {
            $0.$searchEngine.withLock { $0 = .kagi }
        }
        #expect(dismissed.value)
        #expect(CommandBarFeature.State(destination: .newTab, query: "swift").suggestions.first == .search("swift", .kagi))
    }

    @Test func escapeCloses() async {
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab)) {
            CommandBarFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
        await store.send(.cancelled)
        #expect(dismissed.value)
    }

    @Test func submittingWithNothingTypedDoesNothing() async {
        let store = TestStore(initialState: CommandBarFeature.State(destination: .newTab)) {
            CommandBarFeature()
        }
        await store.send(.submitted)
    }
}
