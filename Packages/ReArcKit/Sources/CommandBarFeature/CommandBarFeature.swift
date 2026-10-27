import ComposableArchitecture
import Foundation
import ReArcFoundation

/// The floating bar for going somewhere: type a URL or a search, jump to an
/// open tab, or run a command. The parent presents it and handles `delegate`.
@Reducer
public struct CommandBarFeature {
    @ObservableState
    public struct State: Equatable {
        /// Where a typed URL or search opens.
        public var destination: Destination
        public var query: String
        /// Tabs the bar can offer to switch to, captured when it opens.
        public var openTabs: [OpenTab]
        /// The selected tab, which isn't offered as a switch target.
        public var currentTabID: UUID?
        public var suggestions: [Suggestion] = []
        public var highlightedIndex = 0
        @Shared(.appStorage("searchEngine")) public var searchEngine = SearchEngine.default

        public init(
            destination: Destination,
            query: String = "",
            openTabs: [OpenTab] = [],
            currentTabID: UUID? = nil
        ) {
            self.destination = destination
            self.query = query
            self.openTabs = openTabs
            self.currentTabID = currentTabID
            refreshSuggestions()
        }
    }

    public enum Destination: Equatable, Sendable {
        case currentTab
        case newTab
    }

    public enum Action: Equatable {
        case queryChanged(String)
        case highlightMoved(by: Int)
        case submitted
        case suggestionClicked(Suggestion)
        case cancelled
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case open(URL, in: Destination)
            case switchToTab(UUID)
            case run(AppCommand)
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .queryChanged(query):
                state.query = query
                state.refreshSuggestions()
                return .none

            case let .highlightMoved(offset):
                guard !state.suggestions.isEmpty else { return .none }
                state.highlightedIndex = min(max(state.highlightedIndex + offset, 0), state.suggestions.count - 1)
                return .none

            case .submitted:
                guard state.suggestions.indices.contains(state.highlightedIndex) else { return .none }
                return choose(state.suggestions[state.highlightedIndex], state: &state)

            case let .suggestionClicked(suggestion):
                return choose(suggestion, state: &state)

            case .cancelled:
                return .run { [dismiss] _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }

    private func choose(_ suggestion: Suggestion, state: inout State) -> Effect<Action> {
        switch suggestion {
        case let .open(url):
            return .send(.delegate(.open(url, in: state.destination)))
        case let .search(query, engine):
            return .send(.delegate(.open(engine.searchURL(for: query), in: state.destination)))
        case let .switchToTab(tab):
            return .send(.delegate(.switchToTab(tab.id)))
        case let .command(command):
            return .send(.delegate(.run(command)))
        case let .useSearchEngine(engine):
            state.$searchEngine.withLock { $0 = engine }
            return .run { [dismiss] _ in await dismiss() }
        }
    }
}

extension CommandBarFeature {
    /// A tab as the command bar sees it.
    public struct OpenTab: Equatable, Identifiable, Sendable {
        public let id: UUID
        public var title: String
        public var url: URL

        public init(id: UUID, title: String, url: URL) {
            self.id = id
            self.title = title
            self.url = url
        }
    }

    public enum Suggestion: Equatable, Hashable, Sendable {
        case open(URL)
        case search(String, SearchEngine)
        case switchToTab(OpenTab)
        case command(AppCommand)
        case useSearchEngine(SearchEngine)
    }
}

extension CommandBarFeature.OpenTab: Hashable {}

extension CommandBarFeature.State {
    static let maxTabSuggestions = 5
    static let minCommandQueryLength = 2

    /// The typed URL or search first, then matching open tabs, then matching
    /// commands. Highlight goes back to the first row.
    mutating func refreshSuggestions() {
        highlightedIndex = 0
        suggestions = []
        guard let input = AddressInput(query) else { return }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch input {
        case let .url(url):
            suggestions.append(.open(url))
            // `readme.md` might be a site or a search; offer both. Local
            // addresses (`localhost:3000`) open over http and are never searches.
            if !needle.contains("://"), url.scheme == "https" {
                suggestions.append(.search(needle, searchEngine))
            }
        case let .search(text):
            suggestions.append(.search(text, searchEngine))
        }

        let tabs = openTabs.filter { tab in
            tab.id != currentTabID
                && (tab.title.localizedCaseInsensitiveContains(needle)
                    || tab.url.absoluteString.localizedCaseInsensitiveContains(needle))
        }
        suggestions += tabs.prefix(Self.maxTabSuggestions).map(CommandBarFeature.Suggestion.switchToTab)

        // A single letter matches almost every command, so wait for two.
        guard needle.count >= Self.minCommandQueryLength else { return }
        suggestions += AppCommand.allCases
            .filter { $0.showsInCommandBar && $0.title.localizedCaseInsensitiveContains(needle) }
            .map(CommandBarFeature.Suggestion.command)

        suggestions += SearchEngine.allCases
            .filter { $0 != searchEngine && $0.matches(needle) }
            .map(CommandBarFeature.Suggestion.useSearchEngine)
    }
}

extension SearchEngine {
    /// How choosing this engine is offered in the command bar.
    public var commandTitle: String {
        "Use \(name) for Search"
    }

    /// Matches the engine's name, or a query asking about search engines.
    func matches(_ query: String) -> Bool {
        name.localizedCaseInsensitiveContains(query)
            || (query.count >= 6 && "search engine".localizedCaseInsensitiveContains(query))
    }
}
