import ComposableArchitecture
import Foundation
import ReArcFoundation

/// Root state for a browser window. Feature reducers (sidebar, Spaces,
/// command bar) are meant to be composed in here as they are built.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var tabs: IdentifiedArrayOf<Tab>
        public var selectedTabID: Tab.ID?

        public init(
            tabs: IdentifiedArrayOf<Tab> = [Tab(url: .startPage, title: "Re-Arc")],
            selectedTabID: Tab.ID? = nil
        ) {
            self.tabs = tabs
            self.selectedTabID = selectedTabID ?? tabs.first?.id
        }

        public var selectedTab: Tab? {
            selectedTabID.flatMap { tabs[id: $0] }
        }
    }

    public enum Action: Equatable {
        case tabSelected(Tab.ID)
        /// The engine reported a change in a tab's page.
        case pageStateChanged(Tab.ID, PageState)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(id):
                guard state.tabs[id: id] != nil else { return .none }
                state.selectedTabID = id
                return .none

            case let .pageStateChanged(id, page):
                state.tabs[id: id]?.apply(page)
                return .none
            }
        }
    }
}

extension AppFeature {
    public struct Tab: Equatable, Identifiable, Sendable {
        public let id: UUID
        public var url: URL
        public var title: String
        public var isLoading: Bool
        public var estimatedProgress: Double
        public var canGoBack: Bool
        public var canGoForward: Bool
        public var faviconURL: URL?

        public init(
            id: UUID = UUID(),
            url: URL,
            title: String,
            isLoading: Bool = false,
            estimatedProgress: Double = 0,
            canGoBack: Bool = false,
            canGoForward: Bool = false,
            faviconURL: URL? = nil
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.isLoading = isLoading
            self.estimatedProgress = estimatedProgress
            self.canGoBack = canGoBack
            self.canGoForward = canGoForward
            self.faviconURL = faviconURL
        }

        mutating func apply(_ page: PageState) {
            if let url = page.url {
                self.url = url
            }
            if let title = page.title, !title.isEmpty {
                self.title = title
            } else if page.url != nil {
                // Untitled pages show their host, not the previous page's title.
                title = url.host() ?? url.absoluteString
            }
            isLoading = page.isLoading
            estimatedProgress = page.estimatedProgress
            canGoBack = page.canGoBack
            canGoForward = page.canGoForward
            faviconURL = page.faviconURL
        }
    }
}
